'use client';

import {useRef,useState,type FormEvent} from 'react';
import {createClient} from '@/lib/supabase/client';
import {isolatedApiSchema} from '@/lib/supabase/config';
import {logbookWib} from '@/lib/labLogbook';
import {parseSamplePage,type SamplePage,type SampleSite,type SampleRequestRow} from '@/lib/plantSampleRequests';
import styles from '../lab-routine/routine.module.css';
import cards from '../lab-logbook/logbook.module.css';

type Lot={id:string;lot_code:string;hybrid:string;stage_code:string;plant_site:string};
type Filter={site:string|null;search:string;status:string};
type Action='CREATE'|'SEND'|'RECEIVE'|'DECLINE'|'CANCEL';
type Editor={action:Action;row?:SampleRequestRow};
const statuses:Record<string,string>={ALL:'Semua',ACTIVE:'Belum selesai',REQUESTED:'Menunggu Plant',SENT:'Dikirim · menunggu Lab',RECEIVED:'Diterima Lab',DECLINED:'Tidak dapat dipenuhi',CANCELLED:'Dibatalkan'};
const actions:Record<Action,string>={CREATE:'Kirim permintaan',SEND:'Catat sudah dikirim',RECEIVE:'Konfirmasi sampel diterima',DECLINE:'Tidak bisa memenuhi',CANCEL:'Batalkan permintaan'};
const initial:Filter={site:null,search:'',status:'ACTIVE'};
const rejected=new Set(['22023','42501','55000','23505']);
function message(code?:string){return code==='42501'?'Akses atau lokasi tidak sesuai.':code==='55000'?'Status sudah berubah. Muat ulang daftar untuk melihat catatan terbaru.':code==='23505'?'Tindakan ini sudah tercatat dengan rincian lain. Muat ulang daftar.':'Periksa isian, termasuk label fisik dan berat.';}

export default function SampleRequests({module,writesEnabled,initialPage}:{module:'PLANT'|'LAB';writesEnabled:boolean;initialPage:SamplePage|null}){
 const lab=module==='LAB', [data,setData]=useState<SamplePage|null>(initialPage),[sites,setSites]=useState<SampleSite[]>(initialPage?.sites??[]),[filter,setFilter]=useState<Filter>({...initial,site:initialPage?.selected_site_id??null});
 const [search,setSearch]=useState(''),[busy,setBusy]=useState(false),[error,setError]=useState(initialPage?'':'Daftar belum bisa dimuat. Periksa koneksi atau penugasan Anda, lalu coba lagi.'),[notice,setNotice]=useState('');
 const [editor,setEditor]=useState<Editor|null>(null),[note,setNote]=useState(''),[label,setLabel]=useState(''),[weight,setWeight]=useState(''),[savedArgs,setSavedArgs]=useState<Record<string,unknown>|null>(null);
 const [lot,setLot]=useState<Lot|null>(null),[lotQuery,setLotQuery]=useState(''),[searchedLot,setSearchedLot]=useState(''),[lots,setLots]=useState<Lot[]>([]),[lotMore,setLotMore]=useState(false),[lotOffset,setLotOffset]=useState(0);
 const [editorError,setEditorError]=useState(''),[confirmed,setConfirmed]=useState(false);
 const lock=useRef(false);
 async function load(f:Filter,offset=0){
  if(lock.current)return;
  lock.current=true;setBusy(true);setError('');setFilter(f);setData(null);
  try{
   const {data:p,error}=await createClient().schema(isolatedApiSchema).rpc('list_plant_sample_requests',{p_module:module,p_site_id:f.site,p_search:f.search,p_status:f.status,p_offset:offset});
   if(error)throw Error();
   const parsed=parseSamplePage(p,offset,f.site);
   setData(parsed);setSites(parsed.sites);setFilter({...f,site:parsed.selected_site_id});
  }catch{setError('Daftar belum bisa dimuat. Periksa koneksi atau penugasan Anda, lalu coba lagi.');}
  finally{lock.current=false;setBusy(false);}
 }

 function open(action:Action,row?:SampleRequestRow){
  setEditor({action,row});setNote('');setLabel('');setWeight('');setConfirmed(false);setSavedArgs(null);setLot(null);setLots([]);setLotQuery('');setSearchedLot('');setLotOffset(0);setLotMore(false);setEditorError('');setNotice('');
 }
 async function findLots(q:string,offset=0){
  if(lock.current||!data)return;
  lock.current=true;setBusy(true);setEditorError('');setLots([]);setLotMore(false);
  try{
   const r=await createClient().schema(isolatedApiSchema).rpc('get_routine_lab_options',{p_lab_site_id:data.selected_site_id,p_search:q,p_offset:offset});
   if(r.error||r.data?.selected_lab_site_id!==data.selected_site_id||r.data?.can_write!==true||!Array.isArray(r.data.lots))throw Error();
   setLots(r.data.lots);setLotMore(r.data.has_more);setSearchedLot(q);setLotOffset(offset);
  }catch{setEditorError('Lot belum bisa dimuat. Coba cari lagi.');}
  finally{lock.current=false;setBusy(false);}
 }
 async function save(event:FormEvent){
  event.preventDefault();
  if(!editor||!data?.can_write||!writesEnabled||lock.current)return;
  const action=editor.action, weighs=action==='SEND'||action==='RECEIVE';
  const amount=weight.trim().replace(',','.');
  if(!savedArgs&&(!note.trim()||!confirmed||(action==='CREATE'&&!lot)||(weighs&&(!label.trim()||!/^[0-9]{1,9}(\.[0-9]{1,3})?$/.test(amount)||Number(amount)<=0))||(action==='RECEIVE'&&label.trim()!==editor.row?.sample_label))){
   setEditorError('Lengkapi isian dan konfirmasi. Untuk penerimaan, label fisik harus sama dengan label kiriman.');return;
  }
  lock.current=true;setBusy(true);setEditorError('');
  const args=savedArgs??{p_module:module,p_action:action,p_action_id:crypto.randomUUID(),p_request_id:editor.row?.id??null,p_lab_site_id:action==='CREATE'?data.selected_site_id:null,p_lot_id:action==='CREATE'?lot?.id:null,p_note:note.trim(),p_sample_label:weighs?label.trim():null,p_grams:weighs?Number(amount):null};
  let completed=false;
  try{
   setSavedArgs(args);
   const r=await createClient().schema(isolatedApiSchema).rpc('record_plant_sample_request',args);
   if(r.error&&rejected.has(r.error.code)){setSavedArgs(null);setEditorError(message(r.error.code));return;}
   if(r.error||!r.data?.id)throw Error();
   setNotice('Catatan tersimpan.');setSavedArgs(null);setEditor(null);completed=true;
  }catch{setEditorError('Belum ada balasan dari server. Coba kirim ulang isian yang sama agar tidak tercatat dua kali.');}
  finally{lock.current=false;setBusy(false);}
  if(completed)void load(filter);
 }
 const canWrite=!!data?.can_write&&writesEnabled;
 const weighs=editor?.action==='SEND'||editor?.action==='RECEIVE';
 return <div className={styles.workspace}>
  <header><p className={styles.eyebrow}>SERAH TERIMA SAMPEL</p><h1>{lab?'Permintaan sampel ke Plant':'Permintaan sampel dari Lab'}</h1><p>{lab?'Minta sampel lot yang sudah tercatat. Konfirmasi setelah label fisik cocok dan sampel benar-benar diterima.':'Lihat permintaan Lab untuk lokasi Anda. Catat pengiriman hanya setelah sampel benar-benar dikirim.'} Menu ini tidak memulai uji atau melepas lot.</p></header>
  <form className={styles.panel} onSubmit={e=>{e.preventDefault();void load({...filter,search:search.trim()});}}>
   <h2>Cari permintaan</h2><fieldset className={styles.fields} disabled={busy||!!editor}>
    <label>{lab?'Lokasi Lab':'Lokasi Plant'}<select value={filter.site??''} onChange={e=>void load({...filter,site:e.target.value})}>{!sites.length&&<option value="">Sesuai penugasan</option>}{sites.map(s=><option key={s.id} value={s.id}>{s.site_name}</option>)}</select></label>
    <label>Cari lot, hybrid, atau label<input value={search} maxLength={120} onChange={e=>setSearch(e.target.value)}/></label>
    <label>Status<select value={filter.status} onChange={e=>void load({...filter,status:e.target.value})}>{Object.entries(statuses).map(([k,v])=><option key={k} value={k}>{v}</option>)}</select></label>
   </fieldset><div className={styles.actions}><button className="btn" disabled={busy||!!editor}>Tampilkan</button>{lab&&canWrite&&<button className="btn btn-primary" type="button" disabled={busy||!!editor} onClick={()=>{open('CREATE');void findLots('');}}>Minta sampel</button>}</div>
  </form>
  {notice&&<p role="status">{notice}</p>}{busy&&<p role="status">Memuat…</p>}
  {error&&<div className={styles.notice} role="alert">{error} <button className="btn" onClick={()=>void load(filter)}>Muat ulang</button></div>}
  {editor&&<section className={styles.panel} aria-label={actions[editor.action]}>
   <h2>{actions[editor.action]}</h2>
   {editor.row&&<p>Lot {editor.row.lot_code} · {editor.row.plant_site} → {editor.row.lab_site}</p>}
   {editor.action==='CREATE'&&<form className={styles.search} onSubmit={e=>{e.preventDefault();void findLots(lotQuery.trim());}}><label>Cari lot untuk diminta<input maxLength={100} disabled={busy||!!savedArgs} value={lotQuery} onChange={e=>setLotQuery(e.target.value)}/></label><button className="btn" disabled={busy||!!savedArgs}>Cari lot</button></form>}
   {editor.action==='CREATE'&&<><p>{lot?'Dipilih: '+lot.lot_code+' · '+lot.plant_site:'Pilih lot yang benar. Tujuan otomatis mengikuti Plant pemilik lot.'}</p>
    {!savedArgs&&<><div className={styles.lots}>{lots.map(l=><button type="button" key={l.id} className={styles.lot} aria-pressed={lot?.id===l.id} disabled={busy} onClick={()=>setLot(l)}><strong>{l.lot_code}</strong><span>{l.hybrid} · {l.stage_code} · {l.plant_site}</span></button>)}</div>
    <div className={styles.actions}>{lotOffset>0&&<button className="btn" disabled={busy} onClick={()=>void findLots(searchedLot,lotOffset-50)}>Lot sebelumnya</button>}{lotMore&&<button className="btn" disabled={busy} onClick={()=>void findLots(searchedLot,lotOffset+50)}>Lot berikutnya</button>}</div></>}
   </>}
   {editor.action==='RECEIVE'&&<p>Label kiriman Plant: <strong>{editor.row?.sample_label}</strong>. Jika berbeda, jangan konfirmasi penerimaan; hubungi Plant.</p>}
   <form onSubmit={save}>
    <fieldset className={styles.fields} disabled={busy||!!savedArgs}>
     {weighs&&<><label>Label pada sampel fisik<input required maxLength={120} value={label} onChange={e=>setLabel(e.target.value)}/></label>
      <label>Berat aktual (gram)<input required inputMode="decimal" value={weight} onChange={e=>setWeight(e.target.value)}/></label></>}
     <label>{editor.action==='CREATE'?'Keperluan sampel':weighs?'Kondisi kemasan/sampel':'Alasan'}<textarea required maxLength={500} value={note} onChange={e=>setNote(e.target.value)}/></label>
     <label className={styles.check}><input required type="checkbox" checked={confirmed} onChange={e=>setConfirmed(e.target.checked)}/>{editor.action==='SEND'?'Sampel benar-benar sudah dikirim.':editor.action==='RECEIVE'?'Sampel fisik sudah diterima dan labelnya cocok.':'Saya sudah memeriksa lot dan rincian tindakan ini.'}</label>
    </fieldset>
    {editorError&&<p role="alert">{editorError}</p>}
    <div className={styles.actions}><button className="btn btn-primary" disabled={busy}>{savedArgs?'Coba kirim ulang':actions[editor.action]}</button>
     <button className="btn" type="button" disabled={busy||!!savedArgs} onClick={()=>setEditor(null)}>Tutup isian</button></div>
   </form>
  </section>}
  {data&&<section className={styles.panel}>
   <h2>{data.total} permintaan</h2>
   {!data.rows.length&&<p>Tidak ada permintaan pada lokasi dan filter ini.</p>}
   <div className={cards.entries}>{data.rows.map(row=><article key={row.id} className={cards.entry}>
    <h3>{row.lot_code} · {row.hybrid}</h3><p><strong>{statuses[row.status]}</strong></p>
    <p>{row.plant_site} → {row.lab_site}</p><p>Keperluan: {row.purpose} · {logbookWib(row.requested_at)}</p>
    {row.sample_label&&<p>Label: <strong>{row.sample_label}</strong></p>}
    {row.sent_at&&<p>Dikirim: {row.sent_grams} g · {row.sent_note} · {logbookWib(row.sent_at)}</p>}
    {row.received_at&&<p>Diterima: {row.received_grams} g · {row.received_note} · {logbookWib(row.received_at)}</p>}
    {row.closure_note&&<p>Alasan: {row.closure_note}</p>}
    {canWrite&&!editor&&<div className={styles.actions}>{(lab?(row.status==='SENT'?['RECEIVE']:row.status==='REQUESTED'?['CANCEL']:[]):row.status==='REQUESTED'?['SEND','DECLINE']:[]).map(action=><button key={action} className="btn" disabled={busy} onClick={()=>open(action as Action,row)}>{actions[action as Action]}</button>)}</div>}
   </article>)}</div>
   <div className={styles.actions}><button className="btn" disabled={busy||!!editor||data.offset===0} onClick={()=>void load(filter,Math.max(0,data.offset-data.limit))}>Sebelumnya</button><button className="btn" disabled={busy||!!editor||!data.has_more} onClick={()=>void load(filter,data.offset+data.limit)}>Berikutnya</button></div>
  </section>}
 </div>;
}

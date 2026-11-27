'use client';
import {useRef,useState,type FormEvent} from 'react';
import Link from 'next/link';
import {createClient} from '@/lib/supabase/client';
import {isolatedApiSchema,canonicalWritesEnabled} from '@/lib/supabase/config';
import {wibInput,fromWibInput,type RoutineOptions,type RoutineLot} from '@/lib/routineLabDraft';
import {emptyMoistureContent,moistureMeanPreview,moistureStatus,type MoistureContent,type MoistureDraft,type MoisturePage} from '@/lib/labMoisture';
import MoistureRecordWorkflow from './MoistureRecordWorkflow';
import RoutineSampleReferencePicker from '../lab-routine/RoutineSampleReferencePicker';
import styles from '../lab-routine/routine.module.css';
import { LabFormSections, LabHelp } from '../LabUi';
import { MoistureMean, MoistureReadingFacts, MoistureSampleFacts } from './MoistureEvidence';
import local from './moisture.module.css';
type Editor={id:string;revision:number;lot:RoutineLot;content:MoistureContent};
export default function MoistureWorkspace({initialOptions,initialPage}:{initialOptions:RoutineOptions;initialPage:MoisturePage|null}){
 const [options,setOptions]=useState(initialOptions),[page,setPage]=useState(initialPage),[editor,setEditor]=useState<Editor|null>(null);
 const [search,setSearch]=useState(''),[applied,setApplied]=useState(''),[busy,setBusy]=useState(false),[error,setError]=useState(''),[message,setMessage]=useState('');
 const [stored,setStored]=useState<MoistureContent|null>(null);
 const attempt=useRef<{text:string;action:string}|null>(null),api=()=>createClient().schema(isolatedApiSchema),canWrite=options.can_write&&canonicalWritesEnabled;
 function patch(value:Partial<MoistureContent>){setEditor(e=>e?{...e,content:{...e.content,...value}}:e);setMessage('');}
 function openEditor(next:Editor){setEditor(next);setStored(next.revision>0?next.content:null);attempt.current=null;setMessage('');setError('');}
 function closeEditor(){if(!editor)return;if(editor.content!==stored&&!confirm('Tutup isian? Perubahan yang belum disimpan akan hilang.'))return;setEditor(null);setStored(null);attempt.current=null;setError('');setMessage('');}
 async function catalog(site:string,offset:number,term:string){if(busy)return;setBusy(true);setError('');try{
  const result=await api().rpc('get_routine_lab_options',{p_lab_site_id:site,p_offset:offset,p_search:term});if(result.error)throw Error();
  setOptions(result.data);setApplied(term);
  if(site!==options.selected_lab_site_id){setPage(null);const r=await api().rpc('list_lab_moisture_drafts',{p_lab_site_id:site});if(r.error)throw Error();setPage(r.data);}
 }catch{setError('Pilihan belum dimuat. Periksa koneksi dan akses; lot tidak diganti otomatis.');}finally{setBusy(false);}}
 async function refresh(offset=0){if(busy)return;setBusy(true);setError('');try{const r=await api().rpc('list_lab_moisture_drafts',{p_lab_site_id:options.selected_lab_site_id,p_offset:offset});if(r.error)throw Error();setPage(r.data);}catch{setError('Daftar belum dimuat. Isian yang belum disimpan tetap ada.');}finally{setBusy(false);}}
 async function save(event:FormEvent){event.preventDefault();if(busy||!editor||!canWrite)return;
  const args={p_draft_id:editor.id,p_expected_revision:editor.revision,p_lab_site_id:options.selected_lab_site_id,p_lot_id:editor.lot.id,p_content:editor.content},text=JSON.stringify(args);
  if(attempt.current?.text!==text)attempt.current={text,action:crypto.randomUUID()};
  setBusy(true);setError('');setMessage('');try{const r=await api().rpc('save_lab_moisture_draft',{...args,p_action_id:attempt.current!.action});
   if(r.error){setError((r.error.code==='40001' || r.error.code==='PT409')?'Revisi berubah. Jangan timpa; muat ulang daftar dan periksa revisi terakhir.':'Belum tersimpan. Periksa angka 0–100, urutan waktu dan penugasan; isian tetap ada.');return;}
   setEditor(e=>e?{...e,revision:r.data.revision}:e);setStored(editor.content);attempt.current=null;setMessage(`MC Lab tersimpan · revisi ${r.data.revision}. Belum diperiksa QA.`);
   const records=await api().rpc('list_lab_moisture_drafts',{p_lab_site_id:options.selected_lab_site_id});if(!records.error)setPage(records.data);else setError('Simpanan berhasil, daftar belum diperbarui. Jangan membuat catatan kedua.');
  }catch{setError('Koneksi terputus. Coba Simpan lagi dengan isian yang sama untuk memastikan; jangan membuat catatan baru.');}finally{setBusy(false);}}
 async function download(draft:MoistureDraft,format:'pdf'|'xlsx'){if(busy)return;setBusy(true);setError('');try{
  const r=await fetch(`/api/lab-moisture/${draft.id}/export?format=${format}&revision=${draft.revision}`,{cache:'no-store',redirect:'error'});
  if(!r.ok){const detail=await r.json().catch(()=>({}));throw Error(detail.message||'Unduhan belum berhasil. Muat ulang catatan.');}
  const type=format==='pdf'?'application/pdf':'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';if(!r.headers.get('content-type')?.startsWith(type))throw Error('File tidak sesuai. Coba login kembali.');
  const blob=await r.blob(),magic=new Uint8Array(await blob.slice(0,5).arrayBuffer());if(blob.size>5*1024*1024||(format==='pdf'?String.fromCharCode(...magic)!=='%PDF-':magic[0]!==80||magic[1]!==75))throw Error('File belum lengkap atau terlalu besar.');
  const url=URL.createObjectURL(blob),a=document.createElement('a');a.href=url;a.download=`Form-MC-Lab-${draft.id}-r${draft.revision}.${format}`;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
 }catch(e){setError(e instanceof Error?e.message:'Unduhan belum berhasil.');}finally{setBusy(false);}}
 const preview=editor?moistureMeanPreview(editor.content.readings):null;
 return <div className={styles.workspace}><header><Link href="/lab-requests">← Antrean & hasil Lab</Link><h1>Catatan MC Lab</h1></header>
 {!editor && <LabHelp><p>Ini MC Lab mandiri, bukan MC PI/Plant. Rata-rata baru muncul setelah tiga pembacaan lengkap. Simpan revisi sebelum kirim ke QA.</p><p>QA memverifikasi catatan, bukan menilai lulus/gagal atau melepas lot.</p></LabHelp>}
 {!editor&&error&&<p role="alert">{error}</p>}{!editor&&message&&<p role="status">{message}</p>}
 {!editor&&<section className={styles.panel}><h2>Pilih lot MC Lab</h2><fieldset className={styles.fields} disabled={busy}><label>Lab tempat pengukuran<select value={options.selected_lab_site_id} onChange={e=>void catalog(e.target.value,0,search)}>{options.lab_sites.map(s=><option key={s.id} value={s.id}>{s.site_name}</option>)}</select></label></fieldset>
 <form className={styles.search} onSubmit={e=>{e.preventDefault();void catalog(options.selected_lab_site_id,0,search);}}><label>Cari kode lot atau hybrid<input value={search} onChange={e=>setSearch(e.target.value)} maxLength={100}/></label><button className="btn" disabled={busy}>Cari lot</button></form>
 {!canWrite&&<p>QA memeriksa catatan yang telah dikirim; input bacaan tetap dilakukan Analis yang ditugaskan.</p>}<p>{options.total} lot cocok · maksimal 50 per halaman.</p>
 <div className={styles.lots}>{options.lots.map(lot=><button className={styles.lot} data-testid="select-moisture-lot" key={lot.id} disabled={!canWrite||busy} onClick={()=>openEditor({id:crypto.randomUUID(),revision:0,lot,content:emptyMoistureContent()})}><strong>{lot.lot_code}</strong><span>{lot.hybrid} · {lot.stage_code}</span><small>{lot.plant_site}</small></button>)}</div>{!options.lots.length&&<p>Lot belum ditemukan. Jangan memilih lot pengganti.</p>}
 <div className={styles.actions}><button className="btn" disabled={busy||options.offset===0} onClick={()=>void catalog(options.selected_lab_site_id,Math.max(0,options.offset-50),applied)}>Sebelumnya</button><button className="btn" disabled={busy||!options.has_more} onClick={()=>void catalog(options.selected_lab_site_id,options.offset+50,applied)}>Berikutnya</button></div></section>}
 {editor&&<form className={styles.panel} data-testid="moisture-editor" onSubmit={save}><h2>{editor.lot.lot_code} · {editor.lot.hybrid} · {editor.lot.stage_code}</h2><LabFormSections sections={[{id:'mc-identity',label:'Identitas'},{id:'mc-time',label:'Waktu (WIB)'},{id:'mc-counts',label:'Pembacaan'}]} /><fieldset id="mc-identity" data-lab-jump tabIndex={-1} aria-label="Identitas pengukuran" className={styles.fields} disabled={busy||!canWrite}>
 <RoutineSampleReferencePicker labSiteId={options.selected_lab_site_id} lotId={editor.lot.id} value={editor.content.sample_reference??''} locked={false} rpcName="list_mc_sample_references" onChange={v=>patch({sample_reference:v||null})}/>
 {(['sample_type','analyst_name','instrument','method'] as const).map((k,i)=><label key={k}>{['Jenis sampel pada form','Nama pelaksana MC Lab','Alat / nomor identitas alat','Metode pengukuran aktual'][i]}<input maxLength={120} value={editor.content[k]??''} onChange={e=>patch({[k]:e.target.value||null})}/></label>)}
 </fieldset><fieldset id="mc-time" data-lab-jump tabIndex={-1} aria-label="Waktu (WIB)" className={styles.fields} disabled={busy||!canWrite}>
 {(['received_at','measured_at'] as const).map((k,i)=><label key={k}>{i?'Tanggal dan jam ukur aktual (WIB)':'Sampel tersedia di Lab (WIB)'}<input type="datetime-local" value={wibInput(editor.content[k])} onChange={e=>patch({[k]:fromWibInput(e.target.value)})}/></label>)}
 </fieldset><fieldset id="mc-counts" data-lab-jump tabIndex={-1} className={local.readings} disabled={busy||!canWrite}>
 <legend>Tiga pembacaan kadar air</legend><p>Kosong berarti belum dicatat, bukan nol. Isi dalam persen (0–100).</p>
 <div className={local.inputs}>{editor.content.readings.map((v,i)=><label key={i}>Pembacaan MC {i+1} (%)<input type="number" inputMode="decimal" min={0} max={100} step="any" value={v??''} onChange={e=>patch({readings:editor.content.readings.map((x,j)=>j===i?(e.target.value===''?null:Number(e.target.value)):x)})}/></label>)}</div>
 {preview&&<MoistureMean preview value={preview.mean} entered={preview.entered}/>}</fieldset>
 <label>Catatan pengukuran<textarea maxLength={1000} value={editor.content.note??''} onChange={e=>patch({note:e.target.value||null})}/></label>
 <footer className={local.editorActions} aria-label="Tindakan draft MC">
 {error&&<p role="alert">{error}</p>}
 <div><strong>{editor.lot.lot_code}</strong><p role="status">{message||(editor.revision===0?'Draft baru':editor.content===stored?`Revisi ${editor.revision} tersimpan`:`Perubahan belum tersimpan · revisi terakhir ${editor.revision}`)}</p></div>
 <div><button className="btn btn-primary" disabled={busy||!canWrite}>Simpan draft MC Lab</button><button type="button" className="btn" disabled={busy} onClick={closeEditor}>Tutup isian</button></div>
 </footer></form>}
 <section className={styles.panel}><h2>Catatan MC tersimpan</h2><button className="btn" disabled={busy} onClick={()=>void refresh()}>Muat ulang daftar MC</button><p>{page?`${page.total} catatan MC Lab`:'Daftar belum dimuat; bukan berarti kosong.'}</p>
 {page?.drafts.map(d=><article className={styles.saved} key={d.id}><header className={local.heading}><h3>{d.lot_code}</h3><span className={local.status} data-status={d.status}>{moistureStatus(d.status)}</span></header><p className={local.revision}>{d.hybrid} · {d.stage_code} · Revisi {d.revision} · Label: {d.content.sample_reference??'belum dicatat'}</p><MoistureReadingFacts values={d.content.readings}/><MoistureMean value={d.mean_percent}/><details className={local.recordDetails}><summary>Rincian pengukuran tersimpan</summary><MoistureSampleFacts content={d.content}/></details>
 {d.review&&<p>QA: {d.review.reviewer_name} · {d.review.decision==='RETURN'?'Dikembalikan':'Catatan diverifikasi'} · revisi {d.review.revision} · {wibInput(d.review.reviewed_at).replace('T',' ')} WIB{d.review.note&&<><br/>{d.review.note}</>}</p>}
 {d.record_review_enabled&&<MoistureRecordWorkflow key={`${d.id}-${d.revision}-${d.status}`} record={d} disabled={busy||!!editor} onChanged={()=>void refresh(page.offset)}/>}
 {d.can_edit&&canWrite&&!d.can_submit&&<LabHelp label="Syarat kirim ke QA"><p>Lengkapi label, jenis sampel, dua waktu aktual, pelaksana, alat, metode, dan tiga bacaan. Catatan yang dikembalikan harus disimpan sebagai revisi baru.</p></LabHelp>}
 <div className={styles.actions}>{d.can_edit&&canWrite&&<button className="btn" disabled={busy||!!editor} onClick={()=>openEditor({id:d.id,revision:d.revision,lot:{id:d.lot_id,lot_code:d.lot_code,hybrid:d.hybrid,stage_code:d.stage_code,plant_site:''},content:structuredClone(d.content)})}>Lanjut isi MC</button>}<button className="btn" disabled={busy} onClick={()=>void download(d,'pdf')}>Unduh form MC PDF</button><button className="btn" disabled={busy} onClick={()=>void download(d,'xlsx')}>Unduh form MC Excel</button></div></article>)}
 <div className={styles.actions}><button className="btn" disabled={busy||!page||page.offset===0} onClick={()=>void refresh(Math.max(0,(page?.offset??0)-50))}>Sebelumnya</button><button className="btn" disabled={busy||!page?.has_more} onClick={()=>void refresh((page?.offset??0)+50)}>Berikutnya</button></div></section></div>;
}

'use client';
import {useEffect,useRef,useState,type FormEvent,type ReactNode} from 'react';
import {createClient} from '@/lib/supabase/client';
import {canonicalWritesEnabled,isolatedApiSchema} from '@/lib/supabase/config';
import {fromWibInput,wibInput} from '@/lib/routineLabDraft';
import {samplePlanLabel,type RevalidationOptions,type RevalidationPage,type RevalidationSource,type RevalidationAuthorization} from '@/lib/labRevalidation';
import {LabSkeleton} from '../LabUi';
import styles from './revalidation.module.css';

type ListView = 'sources' | 'plans';

function Fact({ label, children, code = false }: { label: string; children: ReactNode; code?: boolean }) {
  return <div><dt>{label}</dt><dd className={code ? styles.code : undefined}>{children}</dd></div>;
}

function StageTrack({ stage }: { stage: number }) {
  return <ol className={styles.stages} role="list" aria-label="Tahap Revalidation">
    {[1, 2, 3].map(n => <li key={n} aria-current={n === stage ? 'step' : undefined}>
      Tahap {n}
    </li>)}
  </ol>;
}

export default function RevalidationPanel({labSiteId,onCreated}:{labSiteId:string;onCreated:()=>Promise<void>}){
 const [options,setOptions]=useState<RevalidationOptions|null>(null),[page,setPage]=useState<RevalidationPage|null>(null);
 const [search,setSearch]=useState(''),[applied,setApplied]=useState(''),[busy,setBusy]=useState(false),[error,setError]=useState(''),[message,setMessage]=useState('');
 const [view,setView]=useState<ListView|null>(null),[showGuide,setShowGuide]=useState(false);
 const listView=view??(options?.can_authorize?'sources':'plans');
 const [source,setSource]=useState<RevalidationSource|null>(null),[selected,setSelected]=useState<RevalidationAuthorization|null>(null),[mode,setMode]=useState<'START'|'CANCEL'>('START');
 const [name,setName]=useState(''),[reason,setReason]=useState(''),[evidence,setEvidence]=useState(''),[plan,setPlan]=useState(''),[reference,setReference]=useState(''),[available,setAvailable]=useState(''),[reps,setReps]=useState(2),[confirmed,setConfirmed]=useState(false);
 const lock=useRef(false),action=useRef<{payload:string;id:string}|null>(null),api=()=>createClient().schema(isolatedApiSchema);
 const editorTitle=useRef<HTMLHeadingElement>(null),opener=useRef<HTMLButtonElement>(null);
 const editing=!!source||!!selected;
 useEffect(()=>{if(editing)editorTitle.current?.focus();},[editing]);
 async function read(cOffset=options?.offset??0,aOffset=page?.offset??0,term=applied){
  const [c,a]=await Promise.all([api().rpc('get_lab_revalidation_options',{p_lab_site_id:labSiteId,p_search:term,p_offset:cOffset}),api().rpc('list_lab_revalidations',{p_lab_site_id:labSiteId,p_offset:aOffset})]);
  if(c.error||a.error)throw Error();setOptions(c.data);setPage(a.data);setApplied(term);
 }
 async function load(cOffset=0,aOffset=0,term=search){if(lock.current)return;lock.current=true;setBusy(true);setError('');try{await read(cOffset,aOffset,term);}catch{setError('Revalidation belum dimuat. Periksa akses dan koneksi, lalu coba lagi. Ini bukan berarti daftar kosong.');}finally{lock.current=false;setBusy(false);}}
 function reset(){setSource(null);setSelected(null);setConfirmed(false);setReason('');setEvidence('');setPlan('');setName('');setAvailable('');setReference('');setError('');setMessage('');}
 function dismiss(){
  reset();
  requestAnimationFrame(()=>opener.current?.focus());
 }
 async function save(e:FormEvent){
  e.preventDefault();if(lock.current||!confirmed||!canonicalWritesEnabled)return;
  let command:string,args:Record<string,unknown>;
  if(source){if(!options?.can_authorize||!name.trim()||reason.trim().length<3||evidence.trim().length<3||!plan)return;
   command='authorize_lab_revalidation';args={p_lab_site_id:labSiteId,p_source_run_id:source.run_id,p_authorizer_name:name.trim(),p_reason:reason.trim(),p_sample_plan:plan,p_sample_evidence:evidence.trim()};
  }else if(selected&&mode==='START'){if(!selected.can_start||!reference.trim()||!available)return;
   command='start_lab_revalidation';args={p_authorization_id:selected.id,p_sample_reference:reference.trim(),p_available_at:fromWibInput(available),p_replicate_count:reps,p_sample_confirmed:true};
  }else if(selected&&mode==='CANCEL'){if(!selected.can_cancel||reason.trim().length<3)return;
   command='cancel_lab_revalidation';args={p_authorization_id:selected.id,p_reason:reason.trim()};
  }else return;
  const payload=JSON.stringify({command,...args});if(action.current?.payload!==payload)action.current={payload,id:crypto.randomUUID()};
  lock.current=true;setBusy(true);setError('');setMessage('');
  try{const r=await api().rpc(command,{...args,p_action_id:action.current.id});if(r.error)throw Error(r.error.code);
   const created=command==='start_lab_revalidation';await read(0,0,applied);action.current=null;reset();
   setMessage(created?'Catatan Revalidation baru sudah disiapkan dengan hitungan kosong. Buka Lanjut isi pada daftar catatan rutin di bawah.':command==='authorize_lab_revalidation'?'Persetujuan tersimpan. Analis mencocokkan sampel nyata sebelum menyiapkan catatan baru.':'Persetujuan dibatalkan. Alasan tetap tersimpan; tidak menghapus hasil uji.');
   if(created)await onCreated();
  }catch(e){setError(e instanceof Error&&['55000','40001','PT409'].includes(e.message)?'Tahap/status sudah berubah. Muat ulang daftar; jangan membuat persetujuan atau catatan kedua.':'Belum berhasil dikonfirmasi. Periksa nama, rencana/label sampel, tanggal dan hak akses. Jika koneksi terputus, ulangi isian sama.');}finally{lock.current=false;setBusy(false);}
 }
 return (
  <details className={styles.panel} data-testid="lab-revalidation">
   <summary className={styles.summary}>
    <strong>Revalidation 1–3</strong>
    <span>Persetujuan Admin Lab · cek sampel oleh Analis</span>
   </summary>
   <div className={styles.body}>
    <div className={styles.guide}>
     <button type="button" className="btn" aria-expanded={showGuide} onClick={()=>setShowGuide(!showGuide)}>Cara kerja Revalidation</button>
     {showGuide && <ul>
      <li>Gunakan hasil sumber yang sudah disetujui QA. Tahap berikutnya menunggu persetujuan QA pada tahap sebelumnya.</li>
      <li>Admin memberi persetujuan manual per kasus, dengan alasan dan rencana sampel. Ini bukan jadwal otomatis atau pelepasan lot.</li>
      <li>Analis mencocokkan sampel fisik. Sampel simpanan memakai label sumber; sampel baru memakai label fisiknya.</li>
      <li>Alur ini tidak membuat pengiriman Plant atau menyalin hasil lama. Uji ulang QA tetap pada tahap yang sama.</li>
     </ul>}
    </div>
    <form className={styles.search} onSubmit={e=>{
     e.preventDefault();
     if(search.trim())setView('sources');
     void load(0,0,search);
    }}>
     <label>Cari lot, hybrid atau nomor uji sumber<input type="search" maxLength={120} value={search} disabled={busy} onChange={e=>setSearch(e.target.value)}/></label>
     <button className="btn" disabled={busy}>Muat Revalidation</button>
    </form>
    {busy&&!options&&!page && <LabSkeleton label="Memuat Revalidation…" />}
    {error&&!editing && <p className={styles.error} role="alert">{error}</p>}
    {message && <p className={styles.message} role="status">{message}</p>}
    {(source||selected) && <form className={styles.editor} onSubmit={save}>
     <div className={styles.editorHeading}>
      <h3 ref={editorTitle} tabIndex={-1}>{(source??selected)!.lot_code}</h3>
      <p>{`Revalidation ${source?.next_stage??selected!.stage} · ${source?'Persetujuan':mode==='START'?'Cek sampel':'Pembatalan'}`}</p>
     </div>
     <StageTrack stage={source?.next_stage??selected!.stage}/>
     <dl className={styles.facts}>
      <Fact label="Nomor uji sumber" code>{source?.run_code??selected!.source_run_code}</Fact>
      <Fact label="Metode">{(source??selected)!.method_name}</Fact>
      {source && <Fact label="Label sumber" code>{source.sample_reference}</Fact>}
     </dl>
     <fieldset className={styles.fields} disabled={busy}>
      <legend>{source?'Rencana Revalidation':mode==='START'?'Cocokkan sampel fisik':'Alasan pembatalan'}</legend>
      {source ? <>
       <label>Nama petugas pemberi persetujuan<input required maxLength={120} value={name} onChange={e=>setName(e.target.value)}/></label>
       <label>Rencana sampel
        <select aria-label="Rencana sampel" required value={plan} onChange={e=>{setPlan(e.target.value);setConfirmed(false);}}>
         <option value="">Pilih rencana sampel</option>
         <option value="RETAINED_LAB">Sampel simpanan Lab</option>
         <option value="NEW_SAMPLE">Sampel baru</option>
        </select>
       </label>
       <label>Alasan Revalidation<textarea required minLength={3} maxLength={1000} value={reason} onChange={e=>setReason(e.target.value)}/></label>
       <label>Rujukan / lokasi / catatan sampel yang diperiksa<textarea required minLength={3} maxLength={1000} value={evidence} onChange={e=>setEvidence(e.target.value)}/></label>
      </> : mode==='START' ? <>
       <div className={styles.sampleBrief}>
        <strong>{samplePlanLabel(selected!.sample_plan)}</strong>
        <span>{selected!.sample_evidence}</span>
       </div>
       <label>Label sampel fisik<input required readOnly={selected!.sample_plan==='RETAINED_LAB'}
        placeholder={selected!.sample_plan==='NEW_SAMPLE'?'Label pada kemasan sampel baru':undefined}
        maxLength={120} value={reference} onChange={e=>setReference(e.target.value)}/></label>
       <label>Sampel tersedia untuk Revalidation (WIB)<input required type="datetime-local" value={available} onChange={e=>setAvailable(e.target.value)}/></label>
       <label>Jumlah ulangan<select aria-label="Jumlah ulangan" value={reps} onChange={e=>setReps(Number(e.target.value))}>
        {selected!.method_code==='SAND_25C'
         ? <><option value={2}>2 × 100 benih</option><option value={4}>4 × 100 benih</option></>
         : <option value={reps}>{reps} × 100 benih</option>}
       </select></label>
      </> : <label className={styles.fieldHint}>Alasan pembatalan<textarea required minLength={3} maxLength={1000} value={reason} onChange={e=>setReason(e.target.value)}/></label>}
     </fieldset>
     <label className={styles.check}>
      <input type="checkbox" disabled={busy} checked={confirmed} onChange={e=>setConfirmed(e.target.checked)}/>
      {source
       ? 'Saya sudah memeriksa hasil sumber dan rencana sampel. Ini persetujuan pekerjaan baru, bukan persetujuan hasil mutu.'
       : mode==='START'
        ? 'Saya sudah mencocokkan label dan sampel fisik dengan persetujuan Admin. Hitungan dan waktu uji baru belum diisi.'
        : 'Persetujuan ini belum dimulai. Alasan pembatalan harus tetap tersimpan.'}
     </label>
     <div className={styles.actions}>
      <button className="btn btn-primary" disabled={busy||!confirmed}>{busy?'Menyimpan…':source?'Simpan persetujuan':mode==='START'?'Siapkan catatan kosong':'Simpan pembatalan'}</button>
      <button type="button" className="btn" disabled={busy} onClick={dismiss}>Batal</button>
     </div>
     {error && <p className={styles.error} role="alert">{error}</p>}
    </form>}
    {options&&page && <div className={styles.switcher} role="group" aria-label="Daftar Revalidation">
     <button type="button" className="btn" aria-pressed={listView==='sources'} onClick={()=>setView('sources')}>Hasil sumber</button>
     <button type="button" className="btn" aria-pressed={listView==='plans'} onClick={()=>setView('plans')}>Persetujuan</button>
    </div>}
    {options&&listView==='sources' && <section className={styles.list} aria-label="Hasil sumber">
     <h3>Sumber analisis yang disetujui QA · {options.total}</h3>
     {!options.can_authorize && <p>Persetujuan hanya untuk petugas dengan wewenang Admin Revalidation. QA biasa atau Analis tidak otomatis menjadi Admin.</p>}
     {options.candidates.length===0 && <p>Tidak ada hasil sumber pada halaman ini.</p>}
     <div className={styles.cards}>
      {options.candidates.map(s=><article className={styles.card} key={s.run_id}>
       <h4>{s.lot_code} · {s.hybrid}</h4>
       <p>{s.method_name}</p>
       <div className={styles.badges}>
        <span data-tone="verified">Hasil sumber disetujui QA</span>
        <span>{s.next_stage<=3?`Tahap berikutnya: Revalidation ${s.next_stage}`:'Sudah mencapai Revalidation 3'}</span>
       </div>
       <StageTrack stage={s.next_stage}/>
       <dl className={styles.facts}>
        <Fact label="Nomor uji sumber" code>{s.run_code}</Fact>
        <Fact label="Label sampel" code>{s.sample_reference}</Fact>
       </dl>
       {s.blocked_reason
        ? <p className={styles.blocked}><strong>Belum bisa diberi persetujuan</strong>{s.blocked_reason}</p>
        : options.can_authorize&&canonicalWritesEnabled && <div className={styles.actions}>
         <button className="btn" disabled={busy||editing} onClick={e=>{opener.current=e.currentTarget;reset();setSource(s);}}>Beri persetujuan Revalidation {s.next_stage}</button>
        </div>}
      </article>)}
     </div>
     <div className={styles.actions}>
      <button className="btn" disabled={busy||options.offset===0} onClick={()=>void load(Math.max(0,options.offset-50),page?.offset??0,applied)}>Sumber sebelumnya</button>
      <button className="btn" disabled={busy||!options.has_more} onClick={()=>void load(options.offset+50,page?.offset??0,applied)}>Sumber berikutnya</button>
     </div>
    </section>}
    {page&&listView==='plans' && <section className={styles.list} aria-label="Persetujuan Revalidation">
     <h3>Persetujuan Revalidation · {page.total}</h3>
     {page.authorizations.length===0 && <p>Belum ada persetujuan pada halaman ini.</p>}
     <div className={styles.cards}>
      {page.authorizations.map(a=><article className={styles.card} key={a.id}>
       <h4>{a.lot_code} · Revalidation {a.stage}</h4>
       <p>{a.method_name}</p>
       <div className={styles.badges}>
        <span data-tone={a.status==='CANCELLED'?'closed':a.status==='DRAFT_CREATED'?'neutral':'pending'}>
         {a.status==='CANCELLED'?'Dibatalkan':a.status==='DRAFT_CREATED'?'Catatan sudah dibuat':'Menunggu cek sampel'}
        </span>
       </div>
       {a.status!=='AUTHORIZED' && <p>{a.status==='CANCELLED'
        ? `Alasan pembatalan: ${a.cancellation_reason}`
        : 'Buka catatan uji dari daftar catatan rutin.'}</p>}
       <StageTrack stage={a.stage}/>
       <dl className={styles.facts}>
        <Fact label="Nomor uji sumber" code>{a.source_run_code}</Fact>
        <Fact label="Label sumber" code>{a.sample_reference}</Fact>
        <Fact label={samplePlanLabel(a.sample_plan)}>{a.sample_evidence}</Fact>
       </dl>
       <details className={styles.approvalDetail}>
        <summary>Rincian persetujuan</summary>
        <dl className={styles.facts}>
         <Fact label="Disetujui oleh">{a.authorizer_name} · {wibInput(a.authorized_at).replace('T',' ')} WIB</Fact>
         <Fact label="Alasan Revalidation">{a.reason}</Fact>
        </dl>
       </details>
       <div className={styles.actions}>
        {a.can_start&&canonicalWritesEnabled && <button className="btn btn-primary" disabled={busy||editing} onClick={e=>{
         opener.current=e.currentTarget;reset();setSelected(a);setMode('START');
         setReference(a.sample_plan==='RETAINED_LAB'?a.sample_reference:'');setReps(a.method_code==='RET_16C_72H'?4:2);
        }}>Siapkan catatan Revalidation {a.stage}</button>}
        {a.can_cancel&&canonicalWritesEnabled && <button className="btn" disabled={busy||editing} onClick={e=>{opener.current=e.currentTarget;reset();setSelected(a);setMode('CANCEL');}}>Batalkan persetujuan yang belum dimulai</button>}
       </div>
      </article>)}
     </div>
     <div className={styles.actions}>
      <button className="btn" disabled={busy||page.offset===0} onClick={()=>void load(options?.offset??0,Math.max(0,page.offset-50),applied)}>Persetujuan sebelumnya</button>
      <button className="btn" disabled={busy||!page.has_more} onClick={()=>void load(options?.offset??0,page.offset+50,applied)}>Persetujuan berikutnya</button>
     </div>
    </section>}
   </div>
  </details>
 );
}

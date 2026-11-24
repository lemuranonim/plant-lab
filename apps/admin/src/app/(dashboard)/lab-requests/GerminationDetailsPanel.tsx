'use client';
import {useRef,useState,type FormEvent} from 'react';
import {useRouter} from 'next/navigation';
import {createClient} from '@/lib/supabase/client';
import {canonicalWritesEnabled,isolatedApiSchema} from '@/lib/supabase/config';
import {wibInput,fromWibInput} from '@/lib/routineLabDraft';
import {emptyRequestGerminationContent,requestCountFields,requestCountLabels,type RequestGerminationContent,type RequestGerminationDetail} from '@/lib/requestGerminationDetail';
import styles from '../lab-routine/routine.module.css';

export default function GerminationDetailsPanel({requestId,runCode,canApprove,onLoaded,kind='GERMINATION'}:{requestId:string;runCode:string;canApprove:boolean;onLoaded:(hasDetail:boolean)=>void;kind?:'GERMINATION'|'VIGOUR'}){
 const vigor=kind==='VIGOUR',rpcKind=vigor?'vigour':'germination';
 const router=useRouter(),[record,setRecord]=useState<RequestGerminationDetail|null>(null),[content,setContent]=useState<RequestGerminationContent|null>(null);
 const [busy,setBusy]=useState(false),[dirty,setDirty]=useState(false),[confirmed,setConfirmed]=useState(false),[error,setError]=useState(''),[message,setMessage]=useState('');
 const [reviewerName,setReviewerName]=useState(''),[reason,setReason]=useState(''),[decision,setDecision]=useState<'APPROVE'|'RETEST'>('APPROVE');
 const lock=useRef(false),action=useRef<{payload:string;id:string}|null>(null),api=()=>createClient().schema(isolatedApiSchema);
 async function read(){const r=await api().rpc(`get_request_${rpcKind}_detail`,{p_request_id:requestId,p_run_code:runCode});if(r.error)throw Error(r.error.code);const saved=r.data as RequestGerminationDetail;setRecord(saved);setContent(saved.content??(saved.can_edit?{...emptyRequestGerminationContent(),temperature_text:vigor?null:'25'}:null));onLoaded(saved.has_detail);return saved;}
 async function load(){if(lock.current||dirty&&!confirm('Muat ulang? Perubahan yang belum disimpan akan hilang.'))return;lock.current=true;setBusy(true);setError('');try{await read();setDirty(false);setConfirmed(false);}catch{setError('Rincian belum dimuat. Periksa koneksi dan akses, lalu coba lagi. Data lama tidak diisi otomatis.');}finally{lock.current=false;setBusy(false);}}
 function patch(p:Partial<RequestGerminationContent>){setContent(c=>c?{...c,...p}:c);setDirty(true);setConfirmed(false);setMessage('');}
 async function invoke(operation:'SAVE'|'SUBMIT'|'REVIEW'){
  if(lock.current||!record||!content||!canonicalWritesEnabled)return;
  if(operation==='SAVE'&&!record.can_edit||operation==='SUBMIT'&&(!record.can_edit||dirty||!record.readiness.ready||!confirmed)||operation==='REVIEW'&&(!record.can_review||!confirmed||!reviewerName.trim()||(vigor&&reason.trim().length<3)||(decision==='RETEST'&&!reason.trim())))return;
  const args={p_request_id:requestId,p_run_code:runCode,p_expected_revision:record.revision,...(operation==='SAVE'?{p_content:content}:operation==='SUBMIT'?{p_confirmed:true}:{p_decision:decision,p_reviewer_name:reviewerName.trim(),p_reason:reason.trim()||null})};
  const payload=JSON.stringify({operation,...args});if(action.current?.payload!==payload)action.current={payload,id:crypto.randomUUID()};
  lock.current=true;setBusy(true);setError('');setMessage('');
  try{
   const name=`${operation==='SAVE'?'save':operation==='SUBMIT'?'submit':'review'}_request_${rpcKind}_detail`;
   const r=await api().rpc(name,{...args,p_action_id:action.current.id});if(r.error)throw Error(r.error.code);
   const saved=await read();action.current=null;setDirty(false);setConfirmed(false);setMessage(operation==='SAVE'?`Rincian tersimpan · revisi ${saved.revision}.`:operation==='SUBMIT'?'Revisi tersimpan dikirim ke QA dan dikunci.':decision==='RETEST'?'QA meminta uji ulang. Percobaan ini tetap tersimpan.':'Analisis disetujui QA; bukan pelepasan lot.');
   if(operation!=='SAVE')router.refresh();
  }catch(e){setError(e instanceof Error&&['40001','PT409','55000'].includes(e.message)?'Revisi, percobaan atau status berubah. Muat ulang sebelum melanjutkan.':'Belum berhasil dikonfirmasi. Periksa isian dan koneksi; coba lagi dengan isian sama jika koneksi terputus. Jangan membuat catatan kedua.');}finally{lock.current=false;setBusy(false);}
 }
 const save=(e:FormEvent)=>{e.preventDefault();void invoke('SAVE');};
 return <section className={styles.workspace} style={{padding:0,marginTop:16}} data-testid={`request-${rpcKind}-detail`}>
  <button type="button" className="btn" disabled={busy} onClick={()=>void load()}>{record?'Muat ulang rincian pengamatan':'Buka pengamatan & petugas'}</button>
  {error&&<p role="alert">{error}</p>}{message&&<p role="status">{message}</p>}
  {record&&<p>Lot: {record.lot_code} · Sampel: {record.sample_reference}<br/>{record.request_code} · {record.lab_name}</p>}
  {record&&!content&&<p>Catatan ini dibuat sebelum rincian aktual tersedia. Hitungan dan hasil lama tetap dipertahankan; tanggal tanam, fresh/hard atau nama yang belum dicatat tidak dibuat otomatis.</p>}
  {record&&content&&<><aside className={styles.notice}><strong>{vigor?'Vigor':'Germinasi'} request · 2 × 100 benih</strong><p>Tanggal di bawah adalah waktu pekerjaan nyata, bukan jam menekan tombol. First count tidak ditambahkan ke final. Normal + abnormal + fresh + hard + mati = 100 tiap ulangan. Simpan dahulu; kirim hanya revisi yang sudah diperiksa. Catatan lama tidak ditimpa.</p>{vigor&&<p>Mulai perlakuan: {record.treatment_started_at?new Date(record.treatment_started_at).toLocaleString('id-ID',{timeZone:'Asia/Jakarta'})+' WIB':'belum tercatat'}. Tanggal tanam dicatat terpisah. Suhu diisi sesuai kondisi aktual, tidak otomatis 25 °C.</p>}</aside>
   <form onSubmit={save}><p>{record.revision?`Revisi tersimpan ${record.revision}`:'Belum disimpan'}{dirty?' · ada perubahan belum disimpan':''}</p>
    <fieldset className={styles.fields} disabled={busy||!record.can_edit||!canonicalWritesEnabled}>
     {(['crop_species','analyst_name','temperature_text'] as const).map((key,i)=><label key={key}>{['Tanaman / spesies','Nama Analis yang mengerjakan','Suhu uji aktual (°C)'][i]}<input maxLength={120} value={content[key]??''} onChange={e=>patch({[key]:e.target.value||null})}/></label>)}
     {(['available_at','planted_at','first_count_at','final_at'] as const).map((key,i)=><label key={key}>{['Sampel tersedia di Lab (WIB)','Mulai tanam aktual (WIB)','Pengamatan first count (WIB)','Pengamatan final aktual (WIB)'][i]}<input type="datetime-local" value={wibInput(content[key])} onChange={e=>patch({[key]:fromWibInput(e.target.value)})}/></label>)}
     <label>Catatan kondisi / alat<textarea maxLength={1000} value={content.note??''} onChange={e=>patch({note:e.target.value||null})}/></label>
    </fieldset>
    <div className={styles.observations}>{content.observations.map((row,i)=><fieldset key={i} disabled={busy||!record.can_edit||!canonicalWritesEnabled}><legend>Ulangan {i+1} · 100 benih</legend>
     {requestCountFields.map(key=><label key={key}>{requestCountLabels[key]}<input aria-label={`Ulangan ${i+1} ${requestCountLabels[key]}`} type="number" min={0} max={100} step={1} value={row[key]??''} onChange={e=>patch({observations:content.observations.map((r,j)=>j===i?{...r,[key]:e.target.value===''?null:Number(e.target.value)}:r)})}/></label>)}
     {(['abnormal_kind','remarks'] as const).map((key,n)=><label key={key}>{n?'Catatan ulangan':'Jenis abnormal (wajib bila abnormal > 0)'}<textarea aria-label={`Ulangan ${i+1} ${n?'Catatan ulangan':'Jenis abnormal'}`} maxLength={500} value={row[key]??''} onChange={e=>patch({observations:content.observations.map((r,j)=>j===i?{...r,[key]:e.target.value||null}:r)})}/></label>)}
    </fieldset>)}</div>
    {record.can_edit&&canonicalWritesEnabled&&<button className="btn btn-primary" disabled={busy}>Simpan rincian pengamatan</button>}
   </form>
   {record.reviewer_name&&<p>Nama pemeriksa QA: {record.reviewer_name}</p>}
   {record.can_edit&&<div className={styles.workflow}><h4>Periksa sebelum kirim ke QA</h4>{record.readiness.blockers.map((b,i)=><p key={i}>{b}</p>)}{record.readiness.warnings.map((w,i)=><p key={i}>{w}</p>)}{dirty&&<p>Simpan perubahan dahulu. Pemeriksaan kesiapan masih memakai revisi tersimpan.</p>}
    <label className={styles.check}><input type="checkbox" disabled={busy||dirty||!record.revision||!record.readiness.ready} checked={confirmed} onChange={e=>setConfirmed(e.target.checked)}/>Saya sudah memeriksa revisi tersimpan dan pengamatan ini benar-benar dilakukan.</label><button className="btn btn-primary" disabled={busy||dirty||!confirmed||!record.readiness.ready} onClick={()=>void invoke('SUBMIT')}>Kirim revisi ini ke QA</button>
   </div>}
   {record.can_review&&<fieldset className={styles.fields} disabled={busy}><legend>Pemeriksaan QA · revisi {record.revision}</legend>
    <label>Nama pemeriksa QA<input maxLength={120} value={reviewerName} onChange={e=>setReviewerName(e.target.value)}/></label>
    <label>Keputusan QA<select value={decision} onChange={e=>{setDecision(e.target.value as 'APPROVE'|'RETEST');setConfirmed(false);}}><option value="APPROVE" disabled={!canApprove}>Setujui analisis</option><option value="RETEST">Minta uji ulang</option></select></label>
    <label>Catatan QA / alasan uji ulang<textarea maxLength={500} value={reason} onChange={e=>setReason(e.target.value)}/></label>
    {!canApprove&&<p>Approval ditahan karena toleransi tidak tersedia atau terlampaui. Pilih uji ulang dengan alasan.</p>}
    <label className={styles.check}><input type="checkbox" checked={confirmed} onChange={e=>setConfirmed(e.target.checked)}/>Saya telah memeriksa identitas, waktu aktual dan seluruh pengamatan. Persetujuan analisis bukan pelepasan lot.</label>
    {vigor&&<p>Catatan pemeriksaan QA wajib diisi, minimal 3 karakter.</p>}
    <button className="btn btn-primary" disabled={!confirmed||!reviewerName.trim()||(vigor&&reason.trim().length<3)||(decision==='RETEST'?!reason.trim():!canApprove)} onClick={()=>void invoke('REVIEW')}>Simpan keputusan QA</button>
   </fieldset>}
  </>}
 </section>;
}

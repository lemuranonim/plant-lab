'use client';
import {useRef,useState} from 'react';
import {createClient} from '@/lib/supabase/client';
import {isolatedApiSchema} from '@/lib/supabase/config';
type Attempt={run_code:string;status:string;attempt_no:number};
export function RequestSeedlingDownload({runCode,status,kind}:{runCode:string;status:string;kind:'Germinasi'|'Vigor'}){
 const [busy,setBusy]=useState(false),[error,setError]=useState(''),lock=useRef(false);
 async function download(format:'pdf'|'xlsx'){
  if(lock.current)return;lock.current=true;setBusy(true);setError('');
  try{
   const response=await fetch(`/api/lab-request-form/${encodeURIComponent(runCode)}/export?`+new URLSearchParams({format,status}),{cache:'no-store',redirect:'error'});
   if(!response.ok){const data=await response.json().catch(()=>({}));throw Error(data.message||'Unduhan belum berhasil.');}
   const name=response.headers.get('content-disposition')?.match(/filename="(Form-(?:Germinasi|Vigor)-Request-[0-9a-f-]{36}-(?:IN_PROGRESS|SUBMITTED|IN_REVIEW|APPROVED|RETEST|REJECTED|CANCELLED|APPROVAL_INCOMPLETE)\.(?:pdf|xlsx))"/i)?.[1];
   if(!name?.startsWith(`Form-${kind}-Request-`)||!name.endsWith('.'+format)||response.headers.get('content-type')?.split(';')[0]!== (format==='pdf'?'application/pdf':'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'))throw Error('File unduhan tidak sesuai.');
   const blob=await response.blob(),first=new Uint8Array(await blob.slice(0,5).arrayBuffer());if(blob.size<5||blob.size>5*1024*1024||(format==='pdf'?String.fromCharCode(...first)!=='%PDF-':first[0]!==80||first[1]!==75))throw Error('File belum lengkap atau terlalu besar.');
   const url=URL.createObjectURL(blob),a=document.createElement('a');a.href=url;a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
  }catch(e){setError(e instanceof Error?e.message:'Unduhan belum berhasil.');}finally{lock.current=false;setBusy(false);}
 }
 return <section aria-label={`Form ${kind} ${runCode}`}><p>Form {kind} permintaan Plant · {runCode}. Satu file per percobaan, sesuai hitungan sumber. Kolom yang belum dicatat tetap kosong.</p>
  <div style={{display:'flex',flexWrap:'wrap',gap:8}}><button className="btn" disabled={busy} onClick={()=>void download('pdf')}>Unduh {kind} PDF</button><button className="btn" disabled={busy} onClick={()=>void download('xlsx')}>Unduh {kind} Excel</button></div>
  {busy&&<p role="status">Menyiapkan form…</p>}{error&&<p role="alert">{error}</p>}
 </section>;
}
export function GerminationRequestHistory({requestId,runCode}:{requestId:string;runCode:string}){
 const [runs,setRuns]=useState<Attempt[]|null>(null),[error,setError]=useState(''),[busy,setBusy]=useState(false),lock=useRef(false);
 async function load(){if(lock.current)return;lock.current=true;setBusy(true);setError('');setRuns(null);
  try{const result=await createClient().schema(isolatedApiSchema).rpc('list_request_germination_form_runs',{p_request_id:requestId});if(result.error)throw Error();const data=result.data;if(data.request_id!==requestId||data.read_only!==true||data.total!==data.runs.length)throw Error();setRuns((data.runs as Attempt[]).filter(r=>r.run_code!==runCode));}
  catch{setError('Riwayat belum dimuat. Periksa koneksi dan penugasan Lab, lalu coba lagi.');}finally{lock.current=false;setBusy(false);}
 }
 return <details><summary>Cetakan percobaan Germinasi lainnya</summary><button className="btn" disabled={busy} onClick={()=>void load()}>{busy?'Memuat…':'Muat riwayat percobaan'}</button>
   {error&&<p role="alert">{error}</p>}{runs?.length===0&&<p>Tidak ada percobaan lain dalam permintaan ini.</p>}
   {runs?.map(r=><div key={r.run_code}><p>Percobaan {r.attempt_no} · {r.status}</p><RequestSeedlingDownload runCode={r.run_code} status={r.status} kind="Germinasi"/></div>)}
  </details>;
}
export function GerminationRequestForms({requestId,runCode,status}:{requestId:string;runCode:string;status:string}){
 return <><RequestSeedlingDownload runCode={runCode} status={status} kind="Germinasi"/>
  <GerminationRequestHistory requestId={requestId} runCode={runCode}/></>;
}

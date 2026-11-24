'use client';
import {useRef,useState} from 'react';
export default function RetRequestFormDownload({runCode,status}:{runCode:string;status:string}){
 const [busy,setBusy]=useState(false),[error,setError]=useState(''),lock=useRef(false);
 async function download(format:'pdf'|'xlsx'){
  if(lock.current)return;lock.current=true;setBusy(true);setError('');
  try{
   const q=new URLSearchParams({format,status}),response=await fetch(`/api/lab-ret-request/${encodeURIComponent(runCode)}/export?${q}`,{cache:'no-store',redirect:'error'});
   if(!response.ok){const data=await response.json().catch(()=>({}));throw Error(data.message||'Unduhan belum berhasil.');}
   const name=response.headers.get('content-disposition')?.match(/filename="(Form-RET-Request-[0-9a-f-]{36}-(?:IN_PROGRESS|SUBMITTED|IN_REVIEW|APPROVED|RETEST|REJECTED|CANCELLED|APPROVAL_INCOMPLETE)\.(?:pdf|xlsx))"/i)?.[1];
   const mime=format==='pdf'?'application/pdf':'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
   if(!name||!name.endsWith('.'+format)||response.headers.get('content-type')?.split(';')[0]!==mime)throw Error('File unduhan tidak sesuai.');
   const blob=await response.blob(),first=new Uint8Array(await blob.slice(0,5).arrayBuffer());
   if(blob.size<5||blob.size>5*1024*1024||(format==='pdf'?String.fromCharCode(...first)!=='%PDF-':first[0]!==80||first[1]!==75))throw Error('File belum lengkap atau terlalu besar.');
   const url=URL.createObjectURL(blob),a=document.createElement('a');a.href=url;a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
  }catch(e){setError(e instanceof Error?e.message:'Unduhan belum berhasil.');}finally{lock.current=false;setBusy(false);}
 }
 return <section aria-label={`Form RET ${runCode}`}><p>Form RET permintaan Plant · {runCode}. Satu file per percobaan, memakai catatan tersimpan. Status QA ikut tercetak; bukan pelepasan lot.</p>
  <div style={{display:'flex',flexWrap:'wrap',gap:8}}><button className="btn" disabled={busy} onClick={()=>void download('pdf')}>Unduh RET PDF</button><button className="btn" disabled={busy} onClick={()=>void download('xlsx')}>Unduh RET Excel</button></div>
  {busy&&<p role="status">Menyiapkan form RET…</p>}{error&&<p role="alert">{error}</p>}
 </section>;
}

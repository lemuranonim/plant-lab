'use client';
import {useState} from 'react';
export default function TswFormDownload({record}:{record:{id:string;row_version:number}}){
 const [busy,setBusy]=useState(false),[error,setError]=useState('');
 async function download(format:'pdf'|'xlsx'){
  if(busy)return;setBusy(true);setError('');
  try{const r=await fetch(`/api/pi-quality/${record.id}/export?format=${format}&revision=${record.row_version}`,{cache:'no-store',redirect:'error'});
   if(!r.ok){const d=await r.json().catch(()=>({}));throw Error(d.message||'Unduhan belum berhasil. Muat ulang sumber.');}
   const type=format==='pdf'?'application/pdf':'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
   if(!r.headers.get('content-type')?.startsWith(type))throw Error('File tidak sesuai. Coba login kembali.');
   const blob=await r.blob(),magic=new Uint8Array(await blob.slice(0,5).arrayBuffer());
   if(blob.size<5||blob.size>5*1024*1024||(format==='pdf'?String.fromCharCode(...magic)!=='%PDF-':magic[0]!==80||magic[1]!==75))throw Error('File belum lengkap atau terlalu besar.');
   const url=URL.createObjectURL(blob),a=document.createElement('a');a.href=url;a.download=`Form-TSW-PI-${record.id}-v${record.row_version}.${format}`;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
  }catch(e){setError(e instanceof Error?e.message:'Unduhan belum berhasil.');}finally{setBusy(false);}
 }
 return <section aria-label="Unduhan TSW sumber PI"><h3>Unduh form TSW</h3><p>Satu catatan, versi tersimpan {record.row_version}. Simpan perubahan sebelum diunduh. Status sumber PI ikut tercetak; bukan approval Lab atau pelepasan lot.</p><div style={{display:'flex',gap:12,flexWrap:'wrap',marginBlock:12}}><button disabled={busy} onClick={()=>void download('pdf')}>Unduh TSW PDF</button><button disabled={busy} onClick={()=>void download('xlsx')}>Unduh TSW Excel</button></div>{busy&&<p role="status">Menyiapkan form TSW…</p>}{error&&<p role="alert">{error}</p>}</section>;
}

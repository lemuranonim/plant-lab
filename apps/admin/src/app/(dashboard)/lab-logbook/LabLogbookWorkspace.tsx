'use client';
import {useRef,useState,type FormEvent} from 'react';
import Link from 'next/link';
import {createClient} from '@/lib/supabase/client';
import {isolatedApiSchema} from '@/lib/supabase/config';
import {emptyLogbookFilters,logbookArgs,logbookExportQuery,logbookStatuses,logbookWib,type LogbookFilters,type LogbookPage} from '@/lib/labLogbook';
import styles from '../lab-routine/routine.module.css';
import local from './logbook.module.css';
import lab from '../lab-surface.module.css';
import { LabHelp, LabSkeleton } from '../LabUi';
import LogbookEntryCard from './LogbookEntryCard';
export default function LabLogbookWorkspace({initialPage}:{initialPage:LogbookPage|null}){
 const initial={...emptyLogbookFilters,site:initialPage?.selected_lab_site_id??''};
 const [form,setForm]=useState<LogbookFilters>(initial),[applied,setApplied]=useState(initial),[page,setPage]=useState(initialPage),[catalog,setCatalog]=useState(initialPage);
 const [busy,setBusy]=useState(false),[error,setError]=useState(initialPage?'':'Catatan belum dimuat. Coba muat ulang; bukan berarti tidak ada data.');
 const lock=useRef(false),last=useRef({filters:initial,offset:0});
 const [downloadError,setDownloadError]=useState('');
 const [downloading,setDownloading]=useState(false);
 function patch(key:keyof LogbookFilters,value:string){setForm(f=>({...f,[key]:value}));}
 async function load(filters:LogbookFilters,offset=0){
  if(lock.current)return;
  if(filters.from&&filters.to&&filters.from>filters.to){setError('Tanggal awal tidak boleh melebihi tanggal akhir.');return;}
  lock.current=true;last.current={filters,offset};setBusy(true);setError('');setDownloadError('');setPage(null);
  try{const result=await createClient().schema(isolatedApiSchema).rpc('get_lab_logbook',logbookArgs(filters,offset));if(result.error||!result.data)throw Error();
   const data=result.data as LogbookPage;setPage(data);setCatalog(data);setApplied({...filters,site:data.selected_lab_site_id});setForm(f=>({...f,site:data.selected_lab_site_id}));
  }catch{setError('Catatan belum dimuat. Periksa koneksi dan penugasan Lab, lalu coba lagi. Data lama tidak ditampilkan sebagai hasil filter baru.');}
  finally{lock.current=false;setBusy(false);}
 }
 function submit(e:FormEvent){e.preventDefault();void load(form);}
 const pending=JSON.stringify(form)!==JSON.stringify(applied);
 const appliedLabels=[
  page?.lab_sites.find(s=>s.id===applied.site)?.site_name,
  applied.search.trim()&&`Cari: ${applied.search.trim()}`,
  ({PLANT:'Permintaan Plant',ROUTINE:'Uji rutin Lab',MC:'MC Lab'} as Record<string,string>)[applied.origin],
  applied.method!=='ALL'&&(page?.method_options.find(m=>m.method_code===applied.method)?.method_name??applied.method),
  applied.status!=='ALL'&&(logbookStatuses[applied.status]??applied.status),
  (applied.from||applied.to)&&`${applied.date_basis==='OBSERVED'?'Pengamatan':'Pencatatan'}: ${applied.from||'tanpa awal'} – ${applied.to||'tanpa akhir'} (WIB)`,
 ].filter(Boolean);
 async function download(){
  if(lock.current||!page||pending)return;lock.current=true;setBusy(true);setDownloading(true);setDownloadError('');
  try{
   const response=await fetch('/api/lab-logbook/export?'+logbookExportQuery(applied),{cache:'no-store',redirect:'error'});
   if(!response.ok){const d=await response.json().catch(()=>({}));throw Error(d.message||'Unduhan belum berhasil. Coba lagi.');}
   const name=response.headers.get('content-disposition')?.match(/filename="(Rekap-Lab-\d{8}T\d{6}Z\.xlsx)"/)?.[1];
   if(!name||response.headers.get('content-type')?.split(';')[0]!=='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')throw Error('File unduhan tidak sesuai.');
   const blob=await response.blob(),magic=new Uint8Array(await blob.slice(0,4).arrayBuffer());if(blob.size<5||blob.size>5*1024*1024||magic[0]!==80||magic[1]!==75)throw Error('File belum lengkap atau terlalu besar.');
   const url=URL.createObjectURL(blob),a=document.createElement('a');a.href=url;a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
  }catch(e){setDownloadError(e instanceof Error?e.message:'Unduhan belum berhasil.');}finally{lock.current=false;setBusy(false);setDownloading(false);}
 }
 return <div className={styles.workspace}>
  <header><Link className={local.back} href="/lab-requests">← Antrean pengujian Lab</Link><p className={styles.eyebrow}>CATATAN OPERASIONAL</p><h1>Buku pengujian Lab</h1><span className={lab.readBadge}>Baca saja</span><p>Cari catatan permintaan Plant, uji rutin Lab, dan draft MC. Untuk menambah atau memperbaiki isian, buka menu pekerjaan asal.</p></header>
  <LabHelp label="Cara membaca buku pengujian"><p>Satu catatan adalah satu percobaan, draft, atau item yang belum mulai. Uji ulang terpisah; ini bukan jumlah lot atau benih. Histori Excel ada di menu terpisah. Persetujuan analisis bukan izin pelepasan lot.</p></LabHelp>
  <form className={styles.panel} onSubmit={submit}><h2>Cari catatan</h2><fieldset className={styles.fields} disabled={busy}>
   <label>Lab<select aria-label="Lab" value={form.site} onChange={e=>patch('site',e.target.value)}>{!catalog&&<option value="">Lab sesuai penugasan</option>}{catalog?.lab_sites.map(s=><option key={s.id} value={s.id}>{s.site_name}</option>)}</select></label>
   <label>Cari lot, hybrid, label, atau nomor uji<input maxLength={120} value={form.search} onChange={e=>patch('search',e.target.value)} placeholder="Contoh: DEMO-R-0002"/></label>
  </fieldset>
  <details className={local.filters}><summary>Filter lanjutan</summary><fieldset className={styles.fields} disabled={busy}>
   <label>Dasar tanggal<select aria-label="Dasar tanggal" value={form.date_basis} onChange={e=>patch('date_basis',e.target.value)}><option value="RECORDED">Pertama dicatat di aplikasi</option><option value="OBSERVED">Pengamatan final / ukur MC aktual</option></select></label>
   <label>Asal catatan<select aria-label="Asal catatan" value={form.origin} onChange={e=>patch('origin',e.target.value)}><option value="ALL">Semua asal</option><option value="PLANT">Permintaan Plant</option><option value="ROUTINE">Uji rutin Lab</option><option value="MC">MC Lab · draft</option></select></label>
   <label>Dari tanggal (WIB)<input className={local.date} type="date" value={form.from} onChange={e=>patch('from',e.target.value)}/></label>
   <label>Sampai tanggal (WIB)<input className={local.date} type="date" value={form.to} onChange={e=>patch('to',e.target.value)}/></label>
   <label>Metode<select aria-label="Metode" value={form.method} onChange={e=>patch('method',e.target.value)}><option value="ALL">Semua metode</option>{catalog?.method_options.map(m=><option key={m.method_code} value={m.method_code}>{m.method_name}</option>)}</select></label>
   <label>Status<select aria-label="Status" value={form.status} onChange={e=>patch('status',e.target.value)}><option value="ALL">Semua status</option>{Object.entries(logbookStatuses).map(([v,label])=><option key={v} value={v}>{label}</option>)}</select></label>
  </fieldset><p>Batas tanggal termasuk hari awal dan akhir (WIB). Jika memakai tanggal pengamatan, catatan yang belum punya waktu pengamatan tidak masuk rentang tanggal.</p></details>
  <div className={styles.actions}><button className="btn btn-primary" disabled={busy}>Tampilkan catatan</button><button type="button" className="btn" disabled={busy} onClick={()=>{const f={...emptyLogbookFilters,site:form.site};setForm(f);void load(f);}}>Hapus filter</button></div>
  {pending&&page&&<p role="status">Pilihan filter berubah. Tekan Tampilkan catatan untuk menerapkannya; hasil di bawah masih memakai filter sebelumnya.</p>}</form>
  {error&&<div role="alert" className={styles.panel}><p>{error}</p><button className="btn" disabled={busy} onClick={()=>void load(last.current.filters,last.current.offset)}>Coba muat ulang</button></div>}
  {busy&&(downloading ? <p role="status">Menyiapkan rekap Excel…</p> : <LabSkeleton label="Memuat catatan…" />)}
  {page&&<section className={styles.panel} aria-label="Hasil buku pengujian">
   <div className={local.resultHeader}><div><h2>{page.total} catatan cocok</h2><p>Dimuat {logbookWib(page.as_of)}</p></div>
    <button className="btn" disabled={busy||pending||page.total>2000} onClick={()=>void download()}>Unduh rekap Excel</button></div>
   {appliedLabels.length>0&&<ul className={local.scope} aria-label="Filter yang diterapkan">{appliedLabels.map((label,i)=><li key={i}>{label}</li>)}</ul>}
   {pending&&<p>Terapkan perubahan filter dahulu sebelum mengunduh.</p>}{page.total>2000&&<p>Lebih dari 2000 catatan cocok. Persempit tanggal atau filter agar rekap tidak terpotong.</p>}{downloadError&&<p role="alert">{downloadError}</p>}
   <details className={local.summary}><summary>Ringkasan &amp; cara baca</summary>
    <dl className={local.totals}>{[[page.summary.approved,'Analisis disetujui QA'],[page.summary.draft,'Draft'],[page.summary.waiting_qa,'Menunggu QA'],[page.summary.retest,'Perlu uji ulang'],[page.summary.other,'Status lainnya']].map(([n,t])=><div key={t}><dt>{t}</dt><dd>{n}</dd></div>)}</dl>
    <p>{page.summary.missing_observation_time} catatan belum punya waktu pengamatan final / ukur MC.</p>
    <p>Rekap Excel mengambil seluruh hasil filter saat diunduh (maksimal 2000 catatan), bukan hanya halaman ini. Form PDF/Excel di rincian adalah satu catatan dan satu revisi.</p>
   </details>
   {!page.entries.length&&<p>Tidak ada catatan yang cocok. Periksa lot, tanggal, dan filter; jangan memilih lot lain sebagai pengganti.</p>}
   <div className={local.entries}>{page.entries.map(e=><LogbookEntryCard key={`${e.entry_kind}:${e.entry_id}:${e.revision ?? ''}`} entry={e} blocked={busy||pending} />)}</div><p>{page.total?`${page.offset+1}–${Math.min(page.offset+page.entries.length,page.total)} dari ${page.total}`:'0 dari 0'} catatan</p>
   <div className={styles.actions}><button className="btn" disabled={busy||page.offset===0} onClick={()=>void load(applied,Math.max(0,page.offset-page.limit))}>Sebelumnya</button><button className="btn" disabled={busy||!page.has_more} onClick={()=>void load(applied,page.offset+page.limit)}>Berikutnya</button><button className="btn" disabled={busy} onClick={()=>void load(applied,page.offset)}>Muat ulang hasil</button></div>
  </section>}
 </div>;
}

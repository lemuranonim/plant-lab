'use client';
import {useRef,useState,type FormEvent} from 'react';
import Link from 'next/link';
import {createClient} from '@/lib/supabase/client';
import {isolatedApiSchema} from '@/lib/supabase/config';
import {emptyMonitorFilters,hoursLabel,monitorArgs,monitorQuickGroups,validateMonitorPage,workGroups,type MonitorFilters,type MonitorPage} from '@/lib/labMonitoring';
import {logbookWib} from '@/lib/labLogbook';
import styles from '../lab-routine/routine.module.css';
import local from '../lab-logbook/logbook.module.css';
import monitorStyles from './monitoring.module.css';
import lab from '../lab-surface.module.css';
import { LabHelp, LabSkeleton } from '../LabUi';
import MonitoringEntryCard from './MonitoringEntryCard';
export default function LabMonitoring({initialPage}:{initialPage:MonitorPage|null}){
 const initial={...emptyMonitorFilters,site:initialPage?.selected_lab_site_id??''};
 const [form,setForm]=useState<MonitorFilters>(initial),[applied,setApplied]=useState(initial),[page,setPage]=useState(initialPage),[catalog,setCatalog]=useState(initialPage);
 const [busy,setBusy]=useState(false),[error,setError]=useState(initialPage?'':'Pemantauan belum dimuat. Coba lagi; bukan berarti tidak ada pekerjaan.');
 const lock=useRef(false),last=useRef({filters:initial,offset:0});
 function patch(key:keyof MonitorFilters,value:string){setForm(f=>({...f,[key]:value}));}
 async function load(filters:MonitorFilters,offset=0){
  if(lock.current)return;if(filters.from&&filters.to&&filters.from>filters.to){setError('Tanggal awal tidak boleh melebihi tanggal akhir.');return;}
  lock.current=true;last.current={filters:{...filters},offset};setBusy(true);setError('');setPage(null);
  try{const response=await createClient().schema(isolatedApiSchema).rpc('get_lab_work_monitoring',monitorArgs(filters,offset));if(response.error)throw Error();
   const p=validateMonitorPage(response.data);if(filters.site&&p.selected_lab_site_id!==filters.site)throw Error();setPage(p);setCatalog(p);setApplied({...filters,site:p.selected_lab_site_id});setForm(f=>({...f,site:p.selected_lab_site_id}));
  }catch{setError('Pemantauan belum dimuat. Periksa koneksi dan penugasan Lab, lalu coba lagi. Hasil lama tidak dipakai untuk filter baru.');}
  finally{lock.current=false;setBusy(false);}
 }
 const pending=JSON.stringify(form)!==JSON.stringify(applied),s=page?.summary;
 function submit(e:FormEvent){e.preventDefault();void load(form);}
 function quickGroup(work_group:string){
  if(busy||pending||work_group===applied.work_group)return;
  const filters={...applied,work_group};
  setForm(filters);void load(filters);
 }
 return <div className={`${styles.workspace} ${monitorStyles.page}`}>
  <header><Link href="/lab-requests">← Antrean pengujian Lab</Link><p className={styles.eyebrow}>PEMANTAUAN KERJA</p><h1>Pemantauan kerja Lab</h1><span className={lab.readBadge}>Baca saja</span><p>Pantau pekerjaan yang masih menunggu, waktu pengerjaan, dan pemeriksaan QA tanpa mengisi rekap lagi.</p></header>
  <LabHelp label="Cara membaca pemantauan"><p>Jumlah dihitung per percobaan, item yang belum mulai, atau draft, bukan per sampel atau lot. Waktu diambil dari catatan tersimpan; tidak ada penilaian SLA. Histori Excel terpisah.</p><p>MC tidak masuk rata-rata atau persentase keputusan analisis. Revalidation bukan uji ulang QA; uji ulang yang sudah punya percobaan lanjutan tidak dihitung aktif.</p></LabHelp>
  <form className={styles.panel} onSubmit={submit}><h2>Pilih pekerjaan yang dipantau</h2><fieldset className={styles.fields} disabled={busy}>
   <label>Lab<select value={form.site} onChange={e=>patch('site',e.target.value)}>{!catalog&&<option value="">Lab sesuai penugasan</option>}{catalog?.lab_sites.map(l=><option key={l.id} value={l.id}>{l.site_name}</option>)}</select></label>
   <label>Cari lot, hybrid, label, atau nomor uji<input maxLength={120} value={form.search} onChange={e=>patch('search',e.target.value)}/></label>
   </fieldset><details className={monitorStyles.details}><summary>Filter lanjutan</summary><fieldset className={styles.fields} disabled={busy}>
   <label>Asal catatan<select value={form.origin} onChange={e=>patch('origin',e.target.value)}><option value="ALL">Semua asal</option><option value="PLANT">Permintaan Plant</option><option value="ROUTINE">Uji rutin Lab</option><option value="MC">MC Lab</option></select></label>
   <label>Metode<select value={form.method} onChange={e=>patch('method',e.target.value)}><option value="ALL">Semua metode</option>{catalog?.method_options.map(m=><option key={m.method_code} value={m.method_code}>{m.method_name}</option>)}</select></label>
   <label>Kelompok pekerjaan<select value={form.work_group} onChange={e=>patch('work_group',e.target.value)}>{Object.entries(workGroups).map(([v,n])=><option key={v} value={v}>{n}</option>)}</select></label>
   <label>Dasar tanggal<select value={form.date_basis} onChange={e=>patch('date_basis',e.target.value)}><option value="RECORDED">Pertama dicatat di aplikasi</option><option value="RECEIVED">Sampel diterima / tersedia di Lab</option><option value="REVIEWED">Keputusan QA</option></select></label>
   <label>Dari tanggal (WIB)<input className={local.date} type="date" value={form.from} onChange={e=>patch('from',e.target.value)}/></label>
   <label>Sampai tanggal (WIB)<input className={local.date} type="date" value={form.to} onChange={e=>patch('to',e.target.value)}/></label>
  </fieldset><LabHelp label="Cara pakai filter tanggal"><p>Hari awal dan akhir ikut dihitung. Catatan tanpa tanggal pada dasar yang dipilih tidak masuk hasil. Pilih Keputusan QA untuk rekap keputusan per periode.</p></LabHelp></details>
   <div className={styles.actions}><button className="btn btn-primary" disabled={busy}>Tampilkan pemantauan</button><button className="btn" type="button" disabled={busy} onClick={()=>{const f={...emptyMonitorFilters,site:form.site};setForm(f);void load(f);}}>Hapus filter</button></div>
   {pending&&page&&<p role="status">Filter berubah. Tekan Tampilkan pemantauan; hasil di bawah masih memakai pilihan sebelumnya.</p>}
  </form>
  {error&&<section className={styles.panel} role="alert"><p>{error}</p><button className="btn" disabled={busy} onClick={()=>void load(last.current.filters,last.current.offset)}>Coba muat ulang</button></section>}
  {busy&&<LabSkeleton label="Memuat pemantauan…" />}
  {page&&s&&<section className={styles.panel} aria-label="Hasil pemantauan">
   <div className={local.resultHeader}><div><h2>{page.total} pekerjaan cocok</h2><p>Dimuat {logbookWib(page.as_of)}</p></div>
    <button className="btn" disabled={busy} onClick={()=>void load(applied,page.offset)}>Muat ulang pemantauan</button></div>
   <p className={monitorStyles.applied}>Ditampilkan: {[
    workGroups[applied.work_group],
    page.lab_sites.find(site=>site.id===applied.site)?.site_name,
    applied.search.trim()&&`Cari: ${applied.search.trim()}`,
   ].filter(Boolean).join(' · ')}</p>
   <div role="group" aria-label="Filter cepat kelompok pekerjaan" className={monitorStyles.quick}>
    {monitorQuickGroups.map(([group,label])=><button type="button" className="btn" key={group}
      aria-pressed={applied.work_group===group} disabled={busy||pending} onClick={()=>quickGroup(group)}>{label}</button>)}
   </div>
   <details className={monitorStyles.details}><summary>Ringkasan jumlah &amp; waktu pengerjaan</summary>
   <p>Seluruh hasil filter. Waktu dihitung sampai saat pemuatan, tanpa penilaian SLA.</p>
   <dl className={`${local.totals} ${monitorStyles.kpis}`}>{([[s.waiting_sample,'Menunggu sampel','waiting'],[s.waiting_test,'Belum mulai uji','waiting'],[s.testing,'Sedang dikerjakan','active'],[s.waiting_qa,'Menunggu QA','qa'],[s.retest,'Perlu uji ulang','retest'],[s.returned,'Catatan dikembalikan','retest'],[s.incomplete,'Catatan belum lengkap','waiting'],[s.approved_analysis,'Analisis disetujui QA','verified'],[s.verified_mc,'Catatan MC diverifikasi','verified']] as const).map(([n,label,tone])=><div key={label} data-tone={tone}><dt>{label}</dt><dd>{n}{page.total > 0 && <meter aria-hidden="true" min={0} max={page.total} value={n} />}</dd></div>)}</dl>
   <h3>Waktu pengerjaan pada hasil filter</h3><dl className={monitorStyles.timings}>
    <dt>Rata-rata sampel diterima sampai kirim hasil analisis</dt><dd>{hoursLabel(s.sample_tat_hours)} · {s.sample_tat_count} percobaan dengan waktu lengkap</dd>
    <dt>Rata-rata hasil analisis dikirim sampai keputusan QA</dt><dd>{hoursLabel(s.qa_tat_hours)} · {s.qa_tat_count} percobaan dengan waktu lengkap</dd>
    <dt>Rata-rata pemeriksaan catatan MC oleh QA</dt><dd>{hoursLabel(s.mc_qa_hours)} · {s.mc_qa_count} catatan dengan waktu lengkap</dd>
    <dt>Keputusan QA yang meminta uji ulang</dt><dd>{s.retest_rate_percent===null?'Belum ada keputusan analisis':`${s.retest_decisions} dari ${s.analytical_decisions} keputusan (${new Intl.NumberFormat('id-ID',{maximumFractionDigits:2}).format(s.retest_rate_percent)}%)`}</dd>
   </dl>
   <p>{s.missing_sample_time} catatan belum punya waktu sampel diterima/tersedia. {s.missing_qa_time} pekerjaan menunggu QA belum punya waktu kirim. {s.clock_issues} catatan punya urutan waktu yang perlu diperiksa. Waktu yang belum lengkap/tidak berurutan tidak diganti nol.</p>
   </details>
   {!page.entries.length&&<p>Tidak ada pekerjaan yang cocok. Periksa filter atau tanggal yang dipilih.</p>}
   <div className={local.entries}>{page.entries.map(e=><MonitoringEntryCard key={`${e.entry_kind}:${e.entry_id}`} entry={e} />)}</div><p>{page.total?`${page.offset+1}–${Math.min(page.offset+page.entries.length,page.total)} dari ${page.total}`:'0 dari 0'} pekerjaan</p>
   <div className={styles.actions}><button className="btn" disabled={busy||page.offset===0} onClick={()=>void load(applied,Math.max(0,page.offset-page.limit))}>Sebelumnya</button><button className="btn" disabled={busy||!page.has_more} onClick={()=>void load(applied,page.offset+page.limit)}>Berikutnya</button><Link href="/lab-logbook">Buka Buku pengujian / rekap Excel</Link></div>
  </section>}
 </div>;
}

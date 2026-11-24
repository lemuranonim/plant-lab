'use client';
import {useRef,useState,type FormEvent} from 'react';
import Link from 'next/link';
import {createClient} from '@/lib/supabase/client';
import {isolatedApiSchema} from '@/lib/supabase/config';
import {emptyMonitorFilters,hoursLabel,monitorArgs,validateMonitorPage,workGroups,type MonitorFilters,type MonitorPage} from '@/lib/labMonitoring';
import {logbookWib,logbookOrigins,logbookStatuses} from '@/lib/labLogbook';
import styles from '../lab-routine/routine.module.css';
import local from '../lab-logbook/logbook.module.css';
import monitorStyles from './monitoring.module.css';
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
 return <div className={`${styles.workspace} ${monitorStyles.page}`}>
  <header><Link href="/lab-requests">← Antrean pengujian Lab</Link><p className={styles.eyebrow}>PEMANTAUAN KERJA · BACA SAJA</p><h1>Pemantauan kerja Lab</h1><p>Pantau pekerjaan yang masih menunggu, waktu pengerjaan, dan pemeriksaan QA tanpa mengisi rekap lagi.</p></header>
  <aside className={styles.notice}><p>Jumlah di sini adalah pekerjaan per percobaan uji, item yang belum mulai, atau draft. Satu sampel bisa dipakai beberapa metode; angka ini bukan jumlah sampel fisik atau lot.</p><p>Waktu diambil dari catatan tersimpan. Belum ada batas waktu/SLA yang ditetapkan, jadi aplikasi tidak memberi cap terlambat. Histori Excel tidak dicampur.</p></aside>
  <form className={styles.panel} onSubmit={submit}><h2>Pilih pekerjaan yang dipantau</h2><fieldset className={styles.fields} disabled={busy}>
   <label>Lab<select value={form.site} onChange={e=>patch('site',e.target.value)}>{!catalog&&<option value="">Lab sesuai penugasan</option>}{catalog?.lab_sites.map(l=><option key={l.id} value={l.id}>{l.site_name}</option>)}</select></label>
   <label>Cari lot, hybrid, label, atau nomor uji<input maxLength={120} value={form.search} onChange={e=>patch('search',e.target.value)}/></label>
   <label>Asal catatan<select value={form.origin} onChange={e=>patch('origin',e.target.value)}><option value="ALL">Semua asal</option><option value="PLANT">Permintaan Plant</option><option value="ROUTINE">Uji rutin Lab</option><option value="MC">MC Lab</option></select></label>
   <label>Metode<select value={form.method} onChange={e=>patch('method',e.target.value)}><option value="ALL">Semua metode</option>{catalog?.method_options.map(m=><option key={m.method_code} value={m.method_code}>{m.method_name}</option>)}</select></label>
   <label>Kelompok pekerjaan<select value={form.work_group} onChange={e=>patch('work_group',e.target.value)}>{Object.entries(workGroups).map(([v,n])=><option key={v} value={v}>{n}</option>)}</select></label>
   <label>Dasar tanggal<select value={form.date_basis} onChange={e=>patch('date_basis',e.target.value)}><option value="RECORDED">Pertama dicatat di aplikasi</option><option value="RECEIVED">Sampel diterima / tersedia di Lab</option><option value="REVIEWED">Keputusan QA</option></select></label>
   <label>Dari tanggal (WIB)<input className={local.date} type="date" value={form.from} onChange={e=>patch('from',e.target.value)}/></label>
   <label>Sampai tanggal (WIB)<input className={local.date} type="date" value={form.to} onChange={e=>patch('to',e.target.value)}/></label>
  </fieldset><p>Batas tanggal termasuk hari awal dan akhir. Catatan tanpa tanggal pada dasar yang dipilih tidak masuk rentang tanggal. Pilih Keputusan QA untuk rekap keputusan pada periode tertentu.</p>
   <div className={styles.actions}><button className="btn btn-primary" disabled={busy}>Tampilkan pemantauan</button><button className="btn" type="button" disabled={busy} onClick={()=>{const f={...emptyMonitorFilters,site:form.site};setForm(f);void load(f);}}>Hapus filter</button></div>
   {pending&&page&&<p role="status">Filter berubah. Tekan Tampilkan pemantauan; hasil di bawah masih memakai pilihan sebelumnya.</p>}
  </form>
  {error&&<section className={styles.panel} role="alert"><p>{error}</p><button className="btn" disabled={busy} onClick={()=>void load(last.current.filters,last.current.offset)}>Coba muat ulang</button></section>}
  {busy&&<p role="status">Memuat pemantauan…</p>}
  {page&&s&&<section className={styles.panel} aria-label="Hasil pemantauan"><h2>{page.total} pekerjaan cocok</h2><p>Ringkasan seluruh hasil filter, bukan hanya halaman ini. Dimuat {logbookWib(page.as_of)}. Waktu dihitung sampai saat pemuatan; tekan Muat ulang untuk memperbarui.</p>
   <dl className={local.totals}>{[[s.waiting_sample,'Menunggu sampel'],[s.waiting_test,'Belum mulai uji'],[s.testing,'Sedang dikerjakan'],[s.waiting_qa,'Menunggu QA'],[s.retest,'Perlu uji ulang'],[s.returned,'Catatan dikembalikan'],[s.incomplete,'Catatan belum lengkap'],[s.approved_analysis,'Analisis disetujui QA'],[s.verified_mc,'Catatan MC diverifikasi']].map(([n,label])=><div key={label}><dt>{label}</dt><dd>{n}</dd></div>)}</dl>
   <h3>Waktu pengerjaan pada hasil filter</h3><dl className={monitorStyles.timings}>
    <dt>Rata-rata sampel diterima sampai kirim hasil analisis</dt><dd>{hoursLabel(s.sample_tat_hours)} · {s.sample_tat_count} percobaan dengan waktu lengkap</dd>
    <dt>Rata-rata hasil analisis dikirim sampai keputusan QA</dt><dd>{hoursLabel(s.qa_tat_hours)} · {s.qa_tat_count} percobaan dengan waktu lengkap</dd>
    <dt>Rata-rata pemeriksaan catatan MC oleh QA</dt><dd>{hoursLabel(s.mc_qa_hours)} · {s.mc_qa_count} catatan dengan waktu lengkap</dd>
    <dt>Keputusan QA yang meminta uji ulang</dt><dd>{s.retest_rate_percent===null?'Belum ada keputusan analisis':`${s.retest_decisions} dari ${s.analytical_decisions} keputusan (${new Intl.NumberFormat('id-ID',{maximumFractionDigits:2}).format(s.retest_rate_percent)}%)`}</dd>
   </dl><p>MC tidak dimasukkan ke rata-rata dan persentase keputusan analisis. Revalidation bukan otomatis uji ulang QA. Riwayat uji ulang yang sudah punya percobaan lanjutan tidak dihitung sebagai pekerjaan aktif.</p>
   <p>{s.missing_sample_time} catatan belum punya waktu sampel diterima/tersedia. {s.missing_qa_time} pekerjaan menunggu QA belum punya waktu kirim. {s.clock_issues} catatan punya urutan waktu yang perlu diperiksa. Waktu yang belum lengkap/tidak berurutan tidak diganti nol.</p>
   {!page.entries.length&&<p>Tidak ada pekerjaan yang cocok. Periksa filter atau tanggal yang dipilih.</p>}
   <div className={local.entries}>{page.entries.map(e=><article className={local.entry} key={e.entry_kind+e.entry_id} data-testid="monitor-entry"><p className={styles.eyebrow}>{logbookOrigins[e.entry_kind]??e.entry_kind}</p><h3>{e.lot_code}</h3><p>{e.hybrid} · {e.method_name}</p><strong>{workGroups[e.work_group]}</strong><p>{logbookStatuses[e.status]??e.status}{e.attempt_no?` · Percobaan ${e.attempt_no}`:''}</p><p>{[e.request_code,e.run_code,e.sample_reference].filter(Boolean).join(' / ')||'Label / nomor uji belum dicatat'}</p>
    <dl><dt>Sampel diterima / tersedia</dt><dd>{logbookWib(e.received_at)}</dd><dt>Kirim ke QA</dt><dd>{logbookWib(e.submitted_at)}</dd><dt>Keputusan QA</dt><dd>{logbookWib(e.decision_at)}</dd>
     {e.open_sample_hours!==null&&<><dt>Sejak sampel diterima, belum kirim hasil</dt><dd>{hoursLabel(e.open_sample_hours)}</dd></>}
     {e.waiting_qa_hours!==null&&<><dt>Sudah menunggu QA</dt><dd>{hoursLabel(e.waiting_qa_hours)}</dd></>}
     {e.retest_wait_hours!==null&&<><dt>Sejak QA meminta uji ulang</dt><dd>{hoursLabel(e.retest_wait_hours)}</dd></>}
     {e.sample_to_submit_hours!==null&&<><dt>Sampel diterima sampai kirim hasil</dt><dd>{hoursLabel(e.sample_to_submit_hours)}</dd></>}
     {e.qa_tat_hours!==null&&<><dt>Kirim hasil sampai keputusan QA</dt><dd>{hoursLabel(e.qa_tat_hours)}</dd></>}
    </dl>{e.receipt_basis==='RECEIPT_EVENT_TIME'&&<p>Waktu penerimaan mengikuti catatan serah-terima aplikasi, bukan tanggal tanam/pengamatan.</p>}{e.clock_issue&&<p>Urutan waktu perlu diperiksa pada catatan asal. Tidak diberi nilai waktu tebakan.</p>}
    <Link className="btn" href={e.entry_kind==='MC_DRAFT'?'/lab-moisture':e.entry_kind==='ROUTINE'?'/lab-routine':'/lab-requests'}>Buka menu pekerjaan asal</Link>
   </article>)}</div><p>{page.total?`${page.offset+1}–${Math.min(page.offset+page.entries.length,page.total)} dari ${page.total}`:'0 dari 0'} pekerjaan</p>
   <div className={styles.actions}><button className="btn" disabled={busy||page.offset===0} onClick={()=>void load(applied,Math.max(0,page.offset-page.limit))}>Sebelumnya</button><button className="btn" disabled={busy||!page.has_more} onClick={()=>void load(applied,page.offset+page.limit)}>Berikutnya</button><button className="btn" disabled={busy} onClick={()=>void load(applied,page.offset)}>Muat ulang pemantauan</button><Link href="/lab-logbook">Buka Buku pengujian / rekap Excel</Link></div>
  </section>}
 </div>;
}

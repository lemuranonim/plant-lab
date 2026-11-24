'use client';

import { useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import { createClient } from '@/lib/supabase/client';
import { canonicalWritesEnabled, isolatedApiSchema } from '@/lib/supabase/config';
import styles from './operations.module.css';
import { statusLabel } from '@/lib/workflowPresentation';

type Field = { key: string; label: string; type: string; required?: boolean; unit?: string; min?: number; max?: number; options?: string[] };
type Form = { process_code: string; version: number; title: string; fields: Field[] };
type Material = { direction: string; lot_id?: string | null; reference_code?: string | null; component?: string | null; quantity_kg: number | '' };
type Consumption = { material_name: string; unit_code: string; quantity: number | '' };
type Options = {
  forms: Form[];
  sites: { id: string; site_code: string; site_name: string; can_write: boolean }[];
  products: { id: number; name: string; sku: string }[];
  lots: { id: string; lot_code: string; site_id: string; product_id: number; stage_code: string }[];
};
type Run = {
  id: string; site_id: string; site_code: string; lot_id: string | null; lot_code: string | null; product_id: number; product_name: string;
  process_code: string; values: Record<string, string | number>; started_at: string; finished_at: string | null;
  materials: Material[]; consumptions: Consumption[]; status: string; row_version: number; created_by: string;
  revision_of_id: string | null; revision_no: number; review_reason?: string | null;
};
type ReportRow = { date: string; site_code: string; process_code: string; run_id: string; input_kg: number | null; output_kg: number | null; reject_kg: number | null; recovery_percent: number | null; duration_hours: number | null };
const localTime = (value: string | null) => {
  if (!value) return '';
  const date = new Date(value);
  return new Date(date.getTime() - date.getTimezoneOffset() * 60000).toISOString().slice(0, 16);
};
const messageFor = (code?: string, message?: string) => code === '42501' ? 'Role atau site Anda tidak diizinkan untuk tindakan ini.'
  : code === '40001' ? 'Rekaman sudah berubah. Muat ulang sebelum melanjutkan.'
    : code === '55000' ? 'Rekaman sudah dikunci. Gunakan revisi terkontrol.' : message || 'Tidak tersimpan. Periksa koneksi dan coba lagi; isian tetap dipertahankan.';

export default function PlantOperations({ userId, reviewer }: { userId: string; reviewer: boolean }) {
  const [options, setOptions] = useState<Options | null>(null);
  const [records, setRecords] = useState<Run[]>([]);
  const [total, setTotal] = useState(0);
  const [offset, setOffset] = useState(0);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');
  const [busy, setBusy] = useState(false);
  const [reload, setReload] = useState(0);
  const [site, setSite] = useState('');
  const [product, setProduct] = useState('');
  const [lot, setLot] = useState('');
  const [query, setQuery] = useState('');
  const [process, setProcess] = useState('RECEIVING');
  const [start, setStart] = useState('');
  const [end, setEnd] = useState('');
  const [values, setValues] = useState<Record<string, string | number>>({});
  const [materials, setMaterials] = useState<Material[]>([]);
  const [consumptions, setConsumptions] = useState<Consumption[]>([]);
  const [editing, setEditing] = useState<Run | null>(null);
  const [revisionOf, setRevisionOf] = useState<string | null>(null);
  const attempt = useRef('');
  const [review, setReview] = useState<Run | null>(null);
  const [decision, setDecision] = useState('APPROVED');
  const [reason, setReason] = useState('');
  const reviewAttempt = useRef('');
  const [report, setReport] = useState<ReportRow[] | null>(null);
  const [from, setFrom] = useState('');
  const [to, setTo] = useState('');

  useEffect(() => {
    let active = true;
    const api = createClient().schema(isolatedApiSchema);
    Promise.all([api.rpc('get_plant_operation_options'), api.rpc('list_plant_operations', { p_limit: 20, p_offset: offset })])
      .then(([a, b]) => {
        if (!active) return;
        if (a.error || b.error) { setError('Modul input Plant belum bisa dimuat. Data antrean Lab tetap tersedia.'); return; }
        setOptions(a.data as Options); setRecords(b.data.records as Run[]); setTotal(b.data.total);
        setSite(current => current || a.data.sites[0]?.id || '');
      }).catch(() => { if (active) setError('Koneksi terputus. Muat ulang modul tanpa mengulang transaksi.'); });
    return () => { active = false; };
  }, [offset, reload]);

  const form = options?.forms.find(f => f.process_code === process);
  const canWrite = canonicalWritesEnabled && options?.sites.find(s => s.id === site)?.can_write;
  const lots = options?.lots.filter(l => l.site_id === site && (!product || l.product_id === Number(product)) &&
    (l.id === lot || l.lot_code.toUpperCase().includes(query.trim().toUpperCase()))) ?? [];

  function reset() {
    setEditing(null); setRevisionOf(null); attempt.current = ''; setProduct(''); setLot(''); setQuery('');
    setStart(''); setEnd(''); setValues({}); setMaterials([]); setConsumptions([]);
  }
  function openRun(run: Run, revision: boolean) {
    setSite(run.site_id); setProduct(String(run.product_id)); setLot(run.lot_id || ''); setProcess(run.process_code);
    setStart(localTime(run.started_at)); setEnd(localTime(run.finished_at));
    setValues(Object.fromEntries(Object.entries(run.values).map(([key, value]) =>
      [key, options?.forms.find(f => f.process_code === run.process_code)?.fields.find(f => f.key === key)?.type === 'timestamp' ? localTime(String(value)) : value])));
    setMaterials(run.materials.map(m => ({ direction: m.direction, lot_id: m.lot_id, reference_code: m.reference_code, component: m.component, quantity_kg: m.quantity_kg })));
    setConsumptions(run.consumptions.map(c => ({ material_name: c.material_name, unit_code: c.unit_code, quantity: c.quantity })));
    setEditing(revision ? null : run); setRevisionOf(revision ? run.id : run.revision_of_id); attempt.current = revision ? '' : run.id;
    setNotice(revision ? 'Revisi baru disiapkan. Rekaman lama tetap utuh.' : 'Draft dibuka.');
    document.getElementById('operation-input')?.scrollIntoView({ behavior: 'smooth' });
  }
  async function save(submit: boolean) {
    if (busy || !form || !canWrite) return;
    setError(''); setNotice('');
    if (!site || !product || !start || (process !== 'RECEIVING' && !lot)) { setError('Lengkapi site, produk, waktu mulai, serta lot untuk proses setelah receiving.'); return; }
    if (submit && !end) { setError('Isi waktu selesai nyata sebelum submit.'); return; }
    for (const field of form.fields) if (submit && field.required && (values[field.key] === undefined || values[field.key] === '')) { setError(`Lengkapi ${field.label}.`); return; }
    if (materials.some(m => m.quantity_kg === '') || consumptions.some(c => c.quantity === '')) { setError('Lengkapi jumlah setiap baris bahan atau hapus baris kosong.'); return; }
    const payload = Object.fromEntries(Object.entries(values).filter(([, value]) => value !== '').map(([key, value]) => {
      const field = form.fields.find(f => f.key === key);
      return [key, field?.type === 'timestamp' ? new Date(String(value)).toISOString() : value];
    }));
    attempt.current ||= crypto.randomUUID();
    setBusy(true);
    try {
      const result = await createClient().schema(isolatedApiSchema).rpc('save_plant_operation', { p_document: {
        id: attempt.current, site_id: site, product_id: Number(product), lot_id: lot || null, process_code: process,
        started_at: new Date(start).toISOString(), finished_at: end ? new Date(end).toISOString() : null,
        values: payload, materials, consumptions, submit, expected_version: editing?.row_version ?? 0, revision_of_id: revisionOf,
      } });
      if (result.error) { setError(messageFor(result.error.code, result.error.message)); return; }
      setNotice(submit ? 'Tersimpan sebagai SUBMITTED. Menunggu review Plant SPV; bukan release lot.' : 'Draft tersimpan di server.');
      if (submit) reset(); else setEditing(result.data as Run);
      setReload(v => v + 1);
    } catch { setError('Koneksi terputus. Isian dan ID transaksi dipertahankan; aman mencoba kembali.'); }
    finally { setBusy(false); }
  }
  async function submitReview() {
    if (!review || busy || reason.trim().length < 5) return;
    reviewAttempt.current ||= crypto.randomUUID(); setBusy(true); setError('');
    try {
      const result = await createClient().schema(isolatedApiSchema).rpc('review_plant_operation', { p_run_id: review.id,
        p_expected_version: review.row_version, p_decision: decision, p_reason: reason, p_action_id: reviewAttempt.current });
      if (result.error) { setError(messageFor(result.error.code, result.error.message)); return; }
      setReview(null); setNotice('Keputusan Plant tercatat. Tidak mengubah hasil Lab atau pasangan resmi.'); setReload(v => v + 1);
    } catch { setError('Keputusan belum terkonfirmasi. Coba kembali dengan isian yang sama.'); } finally { setBusy(false); }
  }
  async function loadReport() {
    if (!from || !to) { setError('Pilih tanggal awal dan akhir laporan.'); return; }
    setBusy(true); setError('');
    try {
      const result = await createClient().schema(isolatedApiSchema).rpc('get_plant_daily_report', { p_from: from, p_to: to });
      if (result.error) { setError(messageFor(result.error.code, result.error.message)); return; }
      setReport(result.data.rows as ReportRow[]);
    } catch { setError('Laporan belum berhasil dimuat.'); } finally { setBusy(false); }
  }
  function downloadReport() {
    if (!report) return;
    const safe = (value: unknown) => '"' + String(value ?? '').replace(/^[=+@-]/, "'$&").replaceAll('"', '""') + '"';
    const keys: (keyof ReportRow)[] = ['date', 'site_code', 'process_code', 'run_id', 'input_kg', 'output_kg', 'reject_kg', 'recovery_percent', 'duration_hours'];
    const body = [keys.join(','), ...report.map(r => keys.map(k => safe(r[k])).join(','))].join('\r\n');
    const url = URL.createObjectURL(new Blob(['\uFEFF' + body], { type: 'text/csv;charset=utf-8' }));
    const a = document.createElement('a'); a.href = url; a.download = `Plant-Daily-${from}-${to}.csv`; a.click(); URL.revokeObjectURL(url);
  }

  return <div className={styles.page}>
    <header><Link href="/lab-requests">← Antrean Lab</Link><h1>Input Harian Plant</h1>
      <p>Catat pekerjaan dan hasil ukur nyata. Simpan draft, submit, lalu review terpisah oleh Plant SPV.</p></header>
    <aside className={styles.guide}><strong>{reviewer ? 'Tugas Supervisor Plant' : 'Tugas Operator Plant'}</strong><p>{reviewer ? 'Periksa rekaman tim di bagian Rekaman operasional. Persetujuan pencatatan tidak menggantikan review mutu Lab.' : 'Pilih proses dan isi kejadian nyata. Simpan draft untuk dilanjutkan, atau kirim ke SPV jika lengkap. Tanda * berarti wajib.'}</p><a href="#operation-records">Lihat rekaman & pemeriksaan ↓</a></aside>
    {error && <div className={styles.error} role="alert">{error}<button onClick={() => { setError(''); setReload(v => v + 1); }}>Muat ulang</button></div>}
    {notice && <p className={styles.notice} role="status">{notice}</p>}
    {!options ? <p>Memuat modul input Plant…</p> : <>
      <section className={styles.card} id="operation-input"><h2>{editing ? 'Lanjutkan draft' : revisionOf ? 'Revisi terkontrol' : 'Pencatatan baru'}</h2>
        <p>Input online. Draft tersimpan di server; jangan memasukkan data contoh sebagai pekerjaan produksi.</p>
        <div className={styles.grid}>
          <label>Site<select value={site} disabled={busy || !!editing || !!revisionOf} onChange={e => { setSite(e.target.value); setLot(''); }}>
            <option value="">Pilih site</option>{options.sites.map(s => <option key={s.id} value={s.id}>{s.site_name}</option>)}</select></label>
          <label>Proses<select value={process} disabled={busy || !!editing || !!revisionOf} onChange={e => { setProcess(e.target.value); setValues({}); setMaterials([]); setConsumptions([]); }}>
            {options.forms.map(f => <option key={f.process_code} value={f.process_code}>{f.title}</option>)}</select></label>
          <label>Produk / Hybrid<select value={product} disabled={busy || !!editing || !!revisionOf} onChange={e => { setProduct(e.target.value); setLot(''); }}>
            <option value="">Pilih produk terverifikasi</option>{options.products.map(p => <option key={p.id} value={p.id}>{p.name} · {p.sku}</option>)}</select></label>
          <label>Cari lot<input value={query} onChange={e => setQuery(e.target.value)} placeholder="Kode lot, termasuk R/RR" /></label>
          <label>Lot {process === 'RECEIVING' ? '(opsional jika belum terbentuk)' : '*'}<select value={lot} disabled={busy} onChange={e => { setLot(e.target.value); const selected = options.lots.find(l => l.id === e.target.value); if (selected) setProduct(String(selected.product_id)); }}>
            <option value="">Pilih lot</option>{lots.map(l => <option key={l.id} value={l.id}>{l.lot_code} · {l.stage_code}</option>)}</select></label>
          <label>Mulai nyata *<input type="datetime-local" value={start} onChange={e => setStart(e.target.value)} /></label>
          <label>Selesai nyata<input type="datetime-local" value={end} onChange={e => setEnd(e.target.value)} /></label>
          {form?.fields.map(field => <label key={field.key}>{field.label}{field.required ? ' *' : ''}{field.unit ? ` (${field.unit})` : ''}
            {field.type === 'select' ? <select value={values[field.key] ?? ''} onChange={e => setValues(v => ({ ...v, [field.key]: e.target.value }))}>
              <option value="">Pilih</option>{field.options?.map(value => <option key={value}>{value}</option>)}</select> :
              <input type={field.type === 'timestamp' ? 'datetime-local' : ['number', 'integer'].includes(field.type) ? 'number' : field.type === 'date' ? 'date' : 'text'}
                value={values[field.key] ?? ''} min={field.min} max={field.max} step={field.type === 'integer' ? 1 : 'any'} maxLength={500}
                onChange={e => setValues(v => ({ ...v, [field.key]: ['number', 'integer'].includes(field.type) && e.target.value !== '' ? Number(e.target.value) : e.target.value }))} />}</label>)}
        </div>
        {process !== 'RECEIVING' && <fieldset><legend>Material masuk / keluar / reject (kg)</legend><p>Rujukan ini tidak mengganti pasangan DSS–DCS resmi.</p>
          {materials.map((m, i) => <div className={styles.line} key={i}>
            <label>Arus<select value={m.direction} onChange={e => setMaterials(a => a.map((v, n) => n === i ? { ...v, direction: e.target.value } : v))}><option>INPUT</option><option>OUTPUT</option><option>REJECT</option></select></label>
            <label>Kode referensi<input value={m.reference_code ?? ''} maxLength={100} onChange={e => setMaterials(a => a.map((v, n) => n === i ? { ...v, reference_code: e.target.value } : v))} /></label>
            <label>Komponen<input value={m.component ?? ''} maxLength={100} placeholder="Contoh: color sorter" onChange={e => setMaterials(a => a.map((v, n) => n === i ? { ...v, component: e.target.value } : v))} /></label>
            <label>Berat kg<input type="number" min="0" step="any" value={m.quantity_kg} onChange={e => setMaterials(a => a.map((v, n) => n === i ? { ...v, quantity_kg: e.target.value === '' ? '' : Number(e.target.value) } : v))} /></label>
            <button onClick={() => setMaterials(a => a.filter((_, n) => n !== i))}>Hapus baris</button>
          </div>)}<button onClick={() => setMaterials(a => [...a, { direction: 'INPUT', quantity_kg: '' }])}>Tambah material</button></fieldset>}
        {['TREATMENT', 'PACKING'].includes(process) && <fieldset><legend>Pemakaian aktual bahan / kemasan</legend>
          {consumptions.map((c, i) => <div className={styles.line} key={i}>
            <label>Bahan<input value={c.material_name} maxLength={100} onChange={e => setConsumptions(a => a.map((v, n) => n === i ? { ...v, material_name: e.target.value } : v))} /></label>
            <label>Unit<select value={c.unit_code} onChange={e => setConsumptions(a => a.map((v, n) => n === i ? { ...v, unit_code: e.target.value } : v))}>{['GRAM', 'KG', 'ML', 'L', 'PIECE'].map(unit => <option key={unit}>{unit}</option>)}</select></label>
            <label>Jumlah<input type="number" step="any" min="0" value={c.quantity} onChange={e => setConsumptions(a => a.map((v, n) => n === i ? { ...v, quantity: e.target.value === '' ? '' : Number(e.target.value) } : v))} /></label>
            <button onClick={() => setConsumptions(a => a.filter((_, n) => n !== i))}>Hapus baris</button>
          </div>)}<button onClick={() => setConsumptions(a => [...a, { material_name: '', unit_code: 'PIECE', quantity: '' }])}>Tambah pemakaian</button></fieldset>}
        {!canWrite && <p>Anda memiliki akses baca. Input memerlukan role operator pada site ini.</p>}
        <div className={styles.actions}><button disabled={busy || !canWrite} onClick={() => save(false)}>Simpan draft</button>
          <button className={styles.primary} disabled={busy || !canWrite} onClick={() => save(true)}>{busy ? 'Memproses…' : 'Submit ke SPV'}</button>
          <button disabled={busy} onClick={reset}>Pencatatan baru</button></div>
      </section>
      <section id="operation-records"><h2>Rekaman operasional ({total})</h2><div className={styles.records}>
        {records.map(run => <article className={styles.card} key={run.id}><div className={styles.recordTitle}><strong>{options.forms.find(f => f.process_code === run.process_code)?.title ?? run.process_code} · {run.lot_code || 'Receiving sebelum lot'}</strong><span title={run.status}>{run.status === 'APPROVED' ? 'Pencatatan disetujui SPV' : statusLabel(run.status)}</span></div>
          <p>{run.site_code} · {run.product_name} · revisi {run.revision_no}</p><p>{new Date(run.started_at).toLocaleString('id-ID')} — {run.finished_at ? new Date(run.finished_at).toLocaleString('id-ID') : 'Belum selesai'}</p>
          <details><summary>Input, material dan catatan</summary><dl>{Object.entries(run.values).map(([key, value]) => <div key={key}><dt>{options.forms.find(f => f.process_code === run.process_code)?.fields.find(f => f.key === key)?.label || key}</dt><dd>{String(value)}</dd></div>)}</dl>
            {run.materials.map((m, i) => <p key={i}>{m.direction} · {m.reference_code || '—'} · {m.component || '—'} · {m.quantity_kg} kg</p>)}
            {run.consumptions.map((c, i) => <p key={i}>{c.material_name}: {c.quantity} {c.unit_code}</p>)}</details>
          {run.review_reason && <p>Catatan review: {run.review_reason}</p>}
          <div className={styles.actions}>{run.created_by === userId && run.status === 'DRAFT' && <button onClick={() => openRun(run, false)}>Lanjutkan draft</button>}
            {run.created_by === userId && ['APPROVED', 'NEED_REVISION'].includes(run.status) && <button onClick={() => openRun(run, true)}>Buat revisi</button>}
            {reviewer && run.created_by !== userId && run.status === 'SUBMITTED' && <button onClick={() => { setReview(run); setReason(''); setDecision('APPROVED'); reviewAttempt.current = ''; }}>Review rekaman</button>}</div>
        </article>)}{records.length === 0 && <p>Belum ada rekaman operasional pada site Anda. Histori Excel tidak diubah menjadi pekerjaan approved.</p>}</div>
        <div className={styles.actions}><button disabled={offset === 0 || busy} onClick={() => setOffset(v => Math.max(0, v - 20))}>Sebelumnya</button><span>{offset + (total ? 1 : 0)}–{Math.min(offset + 20, total)} / {total}</span><button disabled={offset + 20 >= total || busy} onClick={() => setOffset(v => v + 20)}>Berikutnya</button></div>
      </section>
      <section className={styles.card}><h2>Laporan harian</h2><p>Hanya revisi operasional terakhir yang sudah disetujui. Bukan keputusan release lot; null tidak diganti nol.</p>
        <div className={styles.actions}><label>Dari<input type="date" value={from} onChange={e => { setFrom(e.target.value); setReport(null); }} /></label><label>Sampai<input type="date" value={to} onChange={e => { setTo(e.target.value); setReport(null); }} /></label><button disabled={busy} onClick={loadReport}>Tampilkan</button><button disabled={!report?.length} onClick={downloadReport}>Unduh CSV</button></div>
        {report?.length === 0 && <p>Tidak ada rekaman approved pada periode ini.</p>}
        {!!report?.length && <div className={styles.tableWrap}><table><thead><tr><th>Tanggal / Site</th><th>Proses</th><th>Masuk kg</th><th>Keluar kg</th><th>Reject kg</th><th>Recovery %</th><th>Jam</th></tr></thead><tbody>{report.map(r => <tr key={r.run_id}><td>{r.date}<br />{r.site_code}</td><td>{r.process_code}</td>{[r.input_kg, r.output_kg, r.reject_kg, r.recovery_percent, r.duration_hours].map((value, i) => <td key={i}>{value == null ? '—' : Number(value).toLocaleString('id-ID', { maximumFractionDigits: 3 })}</td>)}</tr>)}</tbody></table></div>}
      </section>
    </>}
    {review && <div className={styles.overlay}><section className={styles.dialog} role="dialog" aria-modal="true" aria-labelledby="review-title"><h2 id="review-title">Review {review.process_code}</h2><p>{review.lot_code || 'Receiving'} · {review.site_code}</p>
      <label>Keputusan<select value={decision} onChange={e => { setDecision(e.target.value); reviewAttempt.current = ''; }}><option value="APPROVED">Setujui pencatatan</option><option value="NEED_REVISION">Kembalikan untuk revisi</option><option value="VOIDED">Batalkan pencatatan</option></select></label>
      <label>Alasan dan rujukan bukti<textarea minLength={5} maxLength={500} value={reason} onChange={e => { setReason(e.target.value); reviewAttempt.current = ''; }} /></label>
      <p>Persetujuan ini bukan approval mutu Lab atau release lot.</p><div className={styles.actions}><button disabled={busy} onClick={() => setReview(null)}>Batal</button><button disabled={busy || reason.trim().length < 5} onClick={submitReview}>Simpan keputusan</button></div></section></div>}
  </div>;
}

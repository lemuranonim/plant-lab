'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import { createClient } from '@/lib/supabase/client';
import { canonicalWritesEnabled, isolatedApiSchema } from '@/lib/supabase/config';
import styles from '../plant-operations/operations.module.css';
import { statusLabel } from '@/lib/workflowPresentation';
import type {TswRaw} from '@/lib/piTsw';
import TswWeights,{TswSummary} from './TswWeights';
import TswFormDownload from './TswFormDownload';
import { LabPiSources, LabPiSourceReview } from './LabPiSources';

type Lot = { id: string; lot_code: string; site_code: string; product_name: string; crop_category_code: string; can_write: boolean };
export type Evidence = { id: string; path: string; filename: string; captured_at: string; bytes: number };
export type RecordValue = {
  id: string; test_code: string; lot_id: string; lot_code: string; site_code: string; test_type: string; numeric_value: number | null; unit_code: string;
  tested_at: string; attempt_no: number; revision_of_id: string | null; material_form: string; crop_kind: string; programme: string;
  method_reference: string; equipment_reference: string; notes: string; seed_count: number | null;
  source_status: string; row_version: number; components: Record<string, number>; evidence: Evidence[];
  assessment: { basis?: string; assessment?: string; minimum_percent?: number; maximum_percent?: number };
  can_write: boolean; can_review: boolean; can_revise: boolean; review_reason?: string;
  lab_requests: { id: string; request_code: string; can_review: boolean }[];
  lab_reviews: { request_id: string; decision: string; reason: string; reviewed_at: string }[];
  tsw_raw?: TswRaw|null;
};
export type PiReview = { record: RecordValue; requestId?: string; decision: string; reason: string; action: string };
type Options = { lots: Lot[]; evidence_bucket: string; max_image_bytes: number; pp_components: string[] };
type Draft = { id: string; lot_id: string; test_type: string; material_form: string; crop_kind: string; programme: string;
  numeric_value: string; tested_at: string; method_reference: string; equipment_reference: string; notes: string;
  components: Record<string, string>; expected_version: number; revision_of_id: string | null;tsw_weights:(number|null)[]|null };
type Upload = { file: File; path: string; registered: boolean };
const labels: Record<string, string> = {
  WORKING_SAMPLE_GRAM: 'Sampel kerja', PURE_SEED_GRAM: 'Pure seed', INERT_MATTER_GRAM: 'Inert matter',
  FUNGI_GRAM: 'Fungi', DAMAGE_GRAM: 'Damage', PREGERM_GRAM: 'Pregerm', SMALL_SEED_GRAM: 'Small seed', OTHER_SEED_GRAM: 'Other seed', TOTAL_COMPONENT_GRAM: 'Total komponen terukur',
};
function blank(): Draft { return { id: crypto.randomUUID(), lot_id: '', test_type: 'PP', material_form: 'SEED', crop_kind: 'UNKNOWN', programme: 'UNKNOWN', numeric_value: '', tested_at: '', method_reference: '', equipment_reference: '', notes: '', components: {}, expected_version: 0, revision_of_id: null,tsw_weights:null }; }
function localTime(iso: string) { const d = new Date(iso); return new Date(d.getTime() - d.getTimezoneOffset() * 60000).toISOString().slice(0, 16); }
function fromRecord(r: RecordValue, revision = false): Draft {
  return { ...blank(), id: revision ? crypto.randomUUID() : r.id, lot_id: r.lot_id, test_type: r.test_type,
    material_form: r.material_form, crop_kind: r.crop_kind, programme: r.programme,
    numeric_value: revision ? '' : r.numeric_value === null ? '' : String(r.numeric_value), tested_at: revision ? '' : localTime(r.tested_at),
    method_reference: r.method_reference, equipment_reference: r.equipment_reference, notes: revision ? '' : r.notes,
    components: revision ? {} : Object.fromEntries(Object.entries(r.components).map(([k, v]) => [k, String(v)])),
    expected_version: revision ? 0 : r.row_version, revision_of_id: revision ? r.id : r.revision_of_id,
    tsw_weights:r.tsw_raw?(revision?Array(8).fill(null):r.tsw_raw.weights_g):null };
}
export async function imageKind(file: File) {
  const b = new Uint8Array(await file.slice(0, 12).arrayBuffer());
  if (b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff) return { mime: 'image/jpeg', extension: 'jpg' };
  if ([137,80,78,71,13,10,26,10].every((v, i) => b[i] === v)) return { mime: 'image/png', extension: 'png' };
  if (String.fromCharCode(...b.slice(0, 4)) === 'RIFF' && String.fromCharCode(...b.slice(8, 12)) === 'WEBP') return { mime: 'image/webp', extension: 'webp' };
  throw new Error('Gunakan foto JPEG, PNG atau WebP asli, bukan dokumen yang diganti ekstensi.');
}
function message(error: unknown) { return error instanceof Error ? error.message : 'Permintaan belum terkonfirmasi. Data form dipertahankan; coba lagi atau muat ulang rekaman.'; }
async function fetchPage(offset: number) {
  const api = createClient().schema(isolatedApiSchema);
  const [o, r] = await Promise.all([api.rpc('get_pi_test_options'), api.rpc('list_pi_tests', { p_limit: 20, p_offset: offset })]);
  if (o.error || r.error) throw new Error('Data mutu PI belum dapat dimuat. Periksa koneksi dan penugasan akun.');
  return { options: o.data as Options, records: r.data.records as RecordValue[], total: r.data.total as number };
}

export default function PiQuality({ variant }: { variant: 'PLANT' | 'LAB' }) {
  const [options, setOptions] = useState<Options>();
  const [records, setRecords] = useState<RecordValue[]>([]);
  const [total, setTotal] = useState(0); const [offset, setOffset] = useState(0);
  const [loadedOffset, setLoadedOffset] = useState<number | null>(null);
  const [draft, setDraft] = useState<Draft>(blank); const [saved, setSaved] = useState<RecordValue>();
  const [error, setError] = useState(''); const [notice, setNotice] = useState(''); const [busy, setBusy] = useState(false);
  const [uploads, setUploads] = useState<Upload[]>([]); const [capturedAt, setCapturedAt] = useState('');
  const [signed, setSigned] = useState<{ path: string; url: string }>();
  const [review, setReview] = useState<PiReview>();
  const action = useRef<{ fingerprint: string; id: string } | null>(null);
  const errorPanel = useRef<HTMLDivElement>(null);
  const reviewOpen = !!review;
  useEffect(() => { if (error && !reviewOpen) errorPanel.current?.scrollIntoView({ block: 'center' }); }, [error, reviewOpen]);
  const load = useCallback(async () => {
    const page = await fetchPage(offset);
    setOptions(page.options); setRecords(page.records); setTotal(page.total); setLoadedOffset(offset);
  }, [offset]);
  useEffect(() => { let active = true; fetchPage(offset).then(page => {
    if (active) { setOptions(page.options); setRecords(page.records); setTotal(page.total); setLoadedOffset(offset); }
  }).catch(e => { if (active) setError(message(e)); }); return () => { active = false; }; }, [offset]);
  const writable = variant === 'PLANT' && canonicalWritesEnabled ? options?.lots.filter(l => l.can_write) ?? [] : [];
  const change = (key: keyof Draft, value: string) => { setDraft(d => ({ ...d, [key]: value })); setNotice(''); };
  function edit(r: RecordValue, revision = false) { setDraft(fromRecord(r, revision)); setSaved(revision ? undefined : r); setUploads([]); setCapturedAt(''); setNotice(''); action.current = null; window.scrollTo({ top: 0, behavior: 'smooth' }); }
  function fresh() { setDraft(blank()); setSaved(undefined); setUploads([]); setCapturedAt(''); setNotice(''); action.current = null; }
  async function save(submit: boolean) {
    setBusy(true); setError(''); setNotice('');
    try {
      if (!draft.lot_id || !draft.tested_at) throw new Error('Pilih lot dan waktu pengukuran nyata terlebih dahulu.');
      const values = Object.fromEntries(Object.entries(draft.components).filter(([, v]) => v !== '').map(([k, v]) => [k, Number(v)]));
      const {tsw_weights,...base}=draft;
      const payload = { ...base,...(draft.test_type==='TSW'&&tsw_weights!==null?{tsw_weights}:{}), components: values, numeric_value: tsw_weights!==null||draft.numeric_value === '' ? null : Number(draft.numeric_value),
        tested_at: new Date(draft.tested_at).toISOString(), seed_count: draft.test_type === 'TSW' ? 1000 : null, submit };
      const fingerprint = JSON.stringify(payload);
      if (action.current?.fingerprint !== fingerprint) action.current = { fingerprint, id: crypto.randomUUID() };
      const { data, error: failure } = await createClient().schema(isolatedApiSchema).rpc('save_pi_test', { p_document: { ...payload, action_id: action.current.id } });
      if (failure) throw new Error(failure.code === '40001' ? 'Versi sudah berubah. Muat ulang draft sebelum melanjutkan.' : failure.code === '42501' ? 'Penugasan PI yang valid diperlukan untuk lot/site ini.' : 'Belum tersimpan. Periksa nilai, metode/alat, dan foto: PP minimal 1, MC minimal 3.');
      const r = data as RecordValue; setSaved(r); setDraft(fromRecord(r)); action.current = null;
      setNotice(submit ? 'Sumber dikirim ke SPV. Nilai terkunci; ini bukan release lot atau approval Lab.' : 'Draft tersimpan di server. Foto dapat diunggah sebelum submit.');
      await load();
    } catch (e) { setError(message(e)); } finally { setBusy(false); }
  }
  async function chooseFiles(files: FileList | null) {
    if (!files || !saved?.can_write || !options) return;
    try {
      const pending: Upload[] = [];
      for (const file of Array.from(files)) {
        if (!file.size || file.size > options.max_image_bytes) throw new Error('Setiap foto harus berukuran 1 byte–8 MB.');
        if (file.name.length > 150) throw new Error('Nama file maksimal 150 karakter.');
        const kind = await imageKind(file);
        pending.push({ file, path: `${saved.id}/${crypto.randomUUID()}.${kind.extension}`, registered: false });
      }
      if (saved.evidence.length + pending.length > 12) throw new Error('Maksimal 12 foto per hasil PI.');
      setUploads(pending); setError('');
    } catch (e) { setError(message(e)); }
  }
  async function upload() {
    if (!saved || !options) return;
    setBusy(true); setError('');
    try {
      if (!capturedAt || !uploads.length) throw new Error('Pilih foto dan masukkan waktu pengambilan foto yang sebenarnya.');
      const captured = new Date(capturedAt).toISOString(); const client = createClient();
      for (const task of uploads) {
        if (task.registered) continue;
        const kind = await imageKind(task.file);
        const { error: failure } = await client.storage.from(options.evidence_bucket).upload(task.path, task.file, { contentType: kind.mime, upsert: false });
        // A lost acknowledgement may leave our immutable, uniquely named object.
        // Registration verifies object owner/path/type/size instead of overwriting it.
        if (failure && failure.statusCode !== '409') throw new Error('Upload foto belum terkonfirmasi. Pilihan file dan path dipertahankan untuk retry.');
        const { data, error: registration } = await client.schema(isolatedApiSchema).rpc('register_pi_evidence', {
          p_test_id: saved.id, p_path: task.path, p_filename: task.file.name, p_captured_at: captured,
        });
        if (registration) throw new Error('Foto belum terdaftar pada draft. Jangan submit dulu; coba lagi dengan file dan waktu yang sama.');
        setUploads(current => current.map(t => t.path === task.path ? { ...t, registered: true } : t));
        setSaved(data as RecordValue); setDraft(d => ({ ...d, expected_version: data.row_version }));
      }
      setNotice('Foto tersimpan privat dan objeknya diverifikasi server. Waktu foto merupakan pernyataan pengguna.');
      setUploads([]); await load();
    } catch (e) { setError(message(e)); } finally { setBusy(false); }
  }
  async function viewEvidence(e: Evidence) {
    const { data, error: failure } = await createClient().storage.from(options!.evidence_bucket).createSignedUrl(e.path, 60);
    if (failure || !data?.signedUrl) { setError('Foto tidak dapat dibuka dalam cakupan akses Anda.'); return; }
    setSigned({ path: e.path, url: data.signedUrl });
  }
  async function sendReview() {
    if (!review) return; setBusy(true); setError('');
    try {
      if (review.reason.trim().length < 3) throw new Error('Tuliskan alasan dan rujukan bukti minimal 3 karakter.');
      const parameters = { p_test_id: review.record.id, p_decision: review.decision, p_reason: review.reason, p_action_id: review.action };
      const api = createClient().schema(isolatedApiSchema);
      const { error: failure } = review.requestId
        ? await api.rpc('review_pi_source', { ...parameters, p_request_id: review.requestId })
        : await api.rpc('review_pi_test', { ...parameters, p_expected_version: review.record.row_version });
      if (failure) throw new Error('Review belum terkonfirmasi. Periksa status, versi dan cakupan role; isi alasan dipertahankan.');
      setReview(undefined); setNotice('Review sumber tercatat. Nilai PI, hasil Lab dan status release lot tidak diubah.'); await load();
    } catch (e) { setError(message(e)); } finally { setBusy(false); }
  }
  if (variant === 'LAB') {
    return <>
      <LabPiSources
        records={records} total={total} offset={offset} pageReady={loadedOffset === offset}
        busy={busy} error={reviewOpen ? '' : error} notice={notice} errorRef={errorPanel}
        componentLabels={labels} signed={signed}
        onEvidence={viewEvidence}
        onRetry={async () => {
          setBusy(true); setError('');
          try { await load(); } catch (e) { setError(message(e)); }
          finally { setBusy(false); }
        }}
        onPage={next => { setError(''); setOffset(next); }}
        onReview={(record, requestId) => {
          setError('');
          setReview({ record, requestId, decision: requestId ? 'ACKNOWLEDGED' : 'VERIFIED', reason: '', action: crypto.randomUUID() });
        }}
      />
      {review && <LabPiSourceReview review={review} busy={busy} error={error}
        onChange={patch => setReview(v => v && ({ ...v, ...patch, action: crypto.randomUUID() }))}
        onClose={() => { setReview(undefined); setError(''); }}
        onSave={sendReview} />}
    </>;
  }
  return <div className={styles.page}>
    <header><Link href="/lab-requests">← Antrean Lab</Link><h1>Mutu PI · PP / MC / TSW</h1>
      <p>PI mencatat pengukuran dan bukti. SPV memverifikasi sumber; Lab membaca dan memberi catatan tanpa mengetik ulang nilai Plant.</p></header>
    <aside className={styles.guide}><strong>Arti pengukuran</strong><p>PP = kemurnian fisik · MC = kadar air · TSW = berat 1.000 benih. Verifikasi sumber bukan persetujuan hasil uji Lab atau pelepasan lot.</p></aside>
    {error && <div ref={errorPanel} role="alert" className={styles.error}>{error}<button disabled={busy} onClick={() => load().catch(e => setError(message(e)))}>Muat ulang daftar</button></div>}
    {notice && <div role="status" className={styles.notice}>{notice}</div>}
    {options && writable.length === 0 && <section className={styles.card}><h2>Akses input khusus PI</h2>
      <p>Akun ini belum memiliki penugasan PLANT_PI yang valid. Operator dan SPV tidak otomatis mendapat hak input PP/MC/TSW. Daftar dan review tetap mengikuti izin masing-masing.</p></section>}
    {writable.length > 0 && <section className={styles.card} aria-label="Form pengukuran PI"><h2>{draft.revision_of_id ? 'Revisi · pengukuran baru' : 'Catat pengukuran PI'}</h2>
      <p>Input online, bukan impor histori. PP adalah angka terukur (%); aplikasi tidak menghitung 100 dikurangi seluruh defect. Komponen di bawah dalam gram, bukan jumlah kernel.</p>
      <fieldset disabled={busy || !!saved && !saved.can_write}><div className={styles.grid}>
        <label>Lot / Hybrid / Site<select value={draft.lot_id} disabled={draft.expected_version > 0 || !!draft.revision_of_id} onChange={e => { const l = writable.find(l => l.id === e.target.value); setDraft(d => ({ ...d, lot_id: e.target.value, crop_kind: ['FC','SWC'].includes(l?.crop_category_code ?? '') ? l!.crop_category_code : 'UNKNOWN' })); }}><option value="">Pilih lot berizin</option>{writable.map(l => <option key={l.id} value={l.id}>{l.lot_code} · {l.product_name} · {l.site_code}</option>)}</select></label>
        <label>Jenis pengukuran<select value={draft.test_type} disabled={draft.expected_version > 0 || !!draft.revision_of_id} onChange={e => setDraft(d => ({ ...d, test_type: e.target.value, material_form: 'SEED', numeric_value: '', components: {},tsw_weights:null }))}>{['PP','MC','TSW'].map(t => <option key={t}>{t}</option>)}</select></label>
        <label>Bentuk sampel<select value={draft.material_form} onChange={e => change('material_form', e.target.value)}><option value="SEED">Pipil / seed</option>{draft.test_type === 'MC' && <option value="GLEONDONG">Gleondong (khusus acuan MC 32%)</option>}</select></label>
        <label>Waktu pengukuran nyata<input type="datetime-local" value={draft.tested_at} onChange={e => change('tested_at', e.target.value)} /></label>
        {draft.test_type==='TSW'&&<label>Dasar penimbangan TSW<select aria-label="Dasar penimbangan TSW" value={draft.tsw_weights===null?'DIRECT':'EIGHT'} disabled={draft.expected_version>0||!!draft.revision_of_id} onChange={e=>setDraft(d=>({...d,tsw_weights:e.target.value==='EIGHT'?Array(8).fill(null):null,numeric_value:''}))}><option value="DIRECT">Timbang langsung 1.000 benih</option><option value="EIGHT">8 ulangan × 100 benih (sesuai form)</option></select></label>}
        {draft.tsw_weights===null&&<label>Nilai terukur ({draft.test_type === 'TSW' ? 'g per 1.000 benih' : '%'})<input type="number" min="0" max={draft.test_type === 'TSW' ? 1000000 : 100} step="any" value={draft.numeric_value} onChange={e => change('numeric_value', e.target.value)} /></label>}
        {draft.test_type === 'TSW'&&draft.tsw_weights===null && <p>Masukkan berat yang benar-benar mewakili 1.000 benih. Bukan berat 100 benih yang diberi label TSW.</p>}
        <label>Jenis jagung (deklarasi pengukuran)<select value={draft.crop_kind} onChange={e => change('crop_kind', e.target.value)}><option value="UNKNOWN">Belum dikonfirmasi</option><option value="FC">Field Corn</option><option value="SWC">Sweet Corn</option></select></label>
        <label>Programme (bukan mengubah master)<select value={draft.programme} onChange={e => change('programme', e.target.value)}><option value="UNKNOWN">Belum dikonfirmasi</option><option value="COMMERCIAL">Commercial</option><option value="PARENT_SEED">Parent Seed</option></select></label>
        <label>Metode / rujukan prosedur<input maxLength={300} value={draft.method_reference} onChange={e => change('method_reference', e.target.value)} /></label>
        <label>Alat / timbangan / moisture meter<input maxLength={300} value={draft.equipment_reference} onChange={e => change('equipment_reference', e.target.value)} /></label>
      </div>
      {draft.test_type==='TSW'&&draft.tsw_weights!==null&&<TswWeights weights={draft.tsw_weights} onChange={tsw_weights=>setDraft(d=>({...d,tsw_weights}))}/>}
      {draft.test_type === 'PP' && <details><summary>Komponen terukur opsional (gram)</summary><div className={styles.grid}>{options?.pp_components.map(k => <label key={k}>{labels[k] ?? k} (g)<input type="number" min="0" max="1000000" step="any" value={draft.components[k] ?? ''} onChange={e => setDraft(d => ({ ...d, components: { ...d.components, [k]: e.target.value } }))} /></label>)}</div></details>}
      <label>Catatan / rujukan sampel / bukti<input maxLength={1000} value={draft.notes} onChange={e => change('notes', e.target.value)} /></label>
      <div className={styles.actions}><button onClick={() => save(false)}>Simpan draft PI</button><button className={styles.primary} onClick={() => save(true)}>Kirim sumber ke SPV</button></div></fieldset>
      {saved?.can_write && <fieldset disabled={busy}><legend>Foto privat · PP minimal 1, MC minimal 3</legend><p>Simpan perubahan nilai sebelum submit. Foto tidak ditimpa/dihapus; koreksi hasil dengan attempt baru.</p>
        <label>Waktu pengambilan foto nyata<input type="datetime-local" value={capturedAt} onChange={e => setCapturedAt(e.target.value)} /></label>
        <label>Pilih foto (JPEG/PNG/WebP, maksimal 8 MB per foto)<input type="file" accept="image/jpeg,image/png,image/webp" multiple onChange={e => chooseFiles(e.target.files)} /></label>
        {uploads.map(t => <p key={t.path}>{t.file.name} · {t.registered ? 'Terdaftar' : 'Menunggu upload'}</p>)}
        <button disabled={!uploads.length} onClick={upload}>Unggah dan daftarkan foto</button><p>{saved.evidence.length} foto terdaftar pada draft.</p>
      </fieldset>}
      {saved?.test_type==='TSW'&&<TswFormDownload record={saved}/>}
      <div className={styles.actions}><button disabled={busy} onClick={fresh}>Pengukuran baru</button></div>
    </section>}
    <section><h2>Sumber pengukuran ({total})</h2><p>VERIFIED adalah verifikasi sumber Plant, bukan label lulus mutu atau release lot. Histori Excel tidak diubah menjadi pengukuran baru.</p>
      {!records.length && <div className={styles.card}>Belum ada sumber PI dalam cakupan akun Anda.</div>}
      <div className={styles.records}>{records.map(r => <article className={styles.card} key={r.id}>
        <div className={styles.recordTitle}><h2>{r.test_code} · {r.test_type}</h2><span title={r.source_status}>{statusLabel(r.source_status)}</span></div>
        <p>{r.lot_code} · {r.site_code} · Attempt {r.attempt_no}</p><p>Nilai: {r.numeric_value ?? 'Belum diisi'} {r.unit_code === 'PERCENT' ? '%' : 'g'} · {r.material_form}</p>
        <p>Waktu: {new Date(r.tested_at).toLocaleString('id-ID')} · Metode: {r.method_reference || 'Belum diisi'} · Alat: {r.equipment_reference || 'Belum diisi'}</p>
        <p>Jenis/Programme: {r.crop_kind} / {r.programme}. {r.notes}</p>
        {!!r.assessment.basis && <p>Acuan internal: {r.assessment.minimum_percent != null ? `≥${r.assessment.minimum_percent}%` : r.assessment.maximum_percent != null ? `≤${r.assessment.maximum_percent}%` : 'Belum tersedia / klasifikasi belum lengkap'} · {r.assessment.assessment}. Bukan sertifikasi regulasi/SOP produk.</p>}
        {r.tsw_raw&&<TswSummary raw={r.tsw_raw}/>}
        {r.test_type==='TSW'&&<TswFormDownload record={r}/>}
        {!!Object.keys(r.components).length && <details><summary>Komponen gram sumber</summary><dl>{Object.entries(r.components).map(([k, v]) => <div key={k}><dt>{labels[k] ?? k}</dt><dd>{v} g</dd></div>)}</dl></details>}
        <div className={styles.actions}>{r.evidence.map(e => <span key={e.id}><button disabled={busy} onClick={() => viewEvidence(e)}>Buka foto · {e.filename}</button>{signed?.path === e.path && <a href={signed.url} target="_blank" rel="noopener noreferrer">Lihat foto (tautan 60 detik)</a>}</span>)}</div>
        {r.review_reason && <p>Catatan SPV: {r.review_reason}</p>}
        {r.lab_reviews.map((v, i) => <p key={i}>Lab · {v.decision}: {v.reason}</p>)}
        <div className={styles.actions}>
          {r.can_write && <button disabled={busy} onClick={() => edit(r)}>Lanjutkan draft</button>}
          {r.can_revise && <button disabled={busy} onClick={() => edit(r, true)}>Buat attempt revisi</button>}
          {canonicalWritesEnabled && r.can_review && <button disabled={busy} onClick={() => setReview({ record: r, decision: 'VERIFIED', reason: '', action: crypto.randomUUID() })}>Review sumber PI</button>}
        </div>
      </article>)}</div>
      <div className={styles.actions}><button disabled={busy || offset === 0} onClick={() => setOffset(o => Math.max(0, o - 20))}>Sebelumnya</button><span>{total ? offset + 1 : 0}–{Math.min(offset + 20, total)} / {total}</span><button disabled={busy || offset + 20 >= total} onClick={() => setOffset(o => o + 20)}>Berikutnya</button></div>
    </section>
    {review && <div className={styles.overlay}><section className={styles.dialog} role="dialog" aria-modal="true" aria-labelledby="pi-review-title"><h2 id="pi-review-title">{review.requestId ? 'Review sumber oleh Lab' : 'Verifikasi sumber oleh SPV'}</h2>
      <p>{review.record.test_code}. Tindakan ini tidak mengubah nilai sumber, hasil Lab, atau release lot.</p>
      {error && <p role="alert" className={styles.error}>{error}</p>}
      <label>Keputusan<select value={review.decision} disabled={busy} onChange={e => setReview(v => v && ({ ...v, decision: e.target.value, action: crypto.randomUUID() }))}>{(review.requestId ? [['ACKNOWLEDGED','Sumber sudah diperiksa'],['CLARIFICATION_REQUIRED','Minta klarifikasi Plant']] : [['VERIFIED','Sumber terverifikasi'],['REVISION_REQUIRED','Perlu revisi / attempt baru']]).map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select></label>
      <label>Alasan dan rujukan bukti<textarea maxLength={1000} value={review.reason} disabled={busy} onChange={e => setReview(v => v && ({ ...v, reason: e.target.value, action: crypto.randomUUID() }))} /></label>
      <div className={styles.actions}><button disabled={busy} onClick={() => setReview(undefined)}>Batal</button><button disabled={busy} className={styles.primary} onClick={sendReview}>Simpan review sumber</button></div>
    </section></div>}
  </div>;
}

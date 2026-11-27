'use client';

import { useRef, useState, type FormEvent } from 'react';
import Link from 'next/link';
import { createClient } from '@/lib/supabase/client';
import { isolatedApiSchema, canonicalWritesEnabled } from '@/lib/supabase/config';
import { emptyRoutineContent, emptyRoutineForm, fromWibInput, routineDraftHtml, routineStatus, wibInput,
  routinePurpose,routineRevalidationNotes,type RoutineContent, type RoutineDraft, type RoutineOptions, type RoutinePage } from '@/lib/routineLabDraft';
import type {RevalidationContext} from '@/lib/labRevalidation';
import styles from './routine.module.css';
import RoutineWorkflowPanel from './RoutineWorkflowPanel';
import RoutineSampleReferencePicker from './RoutineSampleReferencePicker';
import RoutineFormDetailsFields from './RoutineFormDetails';
import RoutineObservationFields from './RoutineObservationFields';
import RevalidationPanel from './RevalidationPanel';
import { LabFormSections, LabHelp } from '../LabUi';

type Editor = { id: string; revision: number; lot_id: string; lot_code: string; lot_label: string; method_code: string; content: RoutineContent; retest?: boolean;revalidation?:RevalidationContext|null };
export default function RoutineLabWorkspace({ initialOptions, initialPage }: { initialOptions: RoutineOptions; initialPage: RoutinePage | null }) {
  const [options, setOptions] = useState({ ...initialOptions, can_write: initialOptions.can_write && canonicalWritesEnabled });
  const [page, setPage] = useState(initialPage);
  const [search, setSearch] = useState('');
  const [appliedSearch, setAppliedSearch] = useState('');
  const [editor, setEditor] = useState<Editor | null>(null);
  const [catalogOpen, setCatalogOpen] = useState(initialOptions.can_write && !initialPage?.drafts.length);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');
  const attempt = useRef<{ text: string; action: string } | null>(null);
  const [storedContent, setStoredContent] = useState<RoutineContent | null>(null);
  const api = () => createClient().schema(isolatedApiSchema);
  async function loadCatalog(site: string, offset: number, term: string) {
    if (busy) return;
    setBusy(true); setError('');
    try {
      const result = await api().rpc('get_routine_lab_options', { p_lab_site_id: site, p_search: term, p_offset: offset });
      if (result.error) throw Error();
      setOptions({ ...result.data as RoutineOptions, can_write: result.data.can_write && canonicalWritesEnabled });
      setAppliedSearch(term);
      if (site !== options.selected_lab_site_id) {
        setPage(null);
        const records = await api().rpc('list_routine_lab_drafts', { p_lab_site_id: site });
        if (records.error) throw Error();
        setPage(records.data as RoutinePage);
      }
    } catch { setError('Pilihan belum bisa dimuat. Coba muat ulang; pilihan lot tidak diganti otomatis.'); }
    finally { setBusy(false); }
  }
  async function loadDrafts(offset: number) {
    if (busy) return;
    setBusy(true); setError('');
    try {
      const result = await api().rpc('list_routine_lab_drafts', { p_lab_site_id: options.selected_lab_site_id, p_offset: offset });
      if (result.error) throw Error();
      setPage(result.data as RoutinePage);
      setCatalogOpen(false);
    } catch { setError('Draft belum bisa dimuat. Catatan yang sedang diisi tetap dipertahankan.'); }
    finally { setBusy(false); }
  }
  function patchContent(patch: Partial<RoutineContent>) {
    setEditor(current => current ? { ...current, content: { ...current.content, ...patch } } : current);
    setMessage('');
  }
  async function save(event: FormEvent) {
    event.preventDefault();
    if (busy || !editor || !options.can_write) return;
    const args = { p_draft_id: editor.id, p_expected_revision: editor.revision,
      p_lab_site_id: options.selected_lab_site_id, p_lot_id: editor.lot_id,
      p_method_code: editor.method_code, p_content: editor.content };
    const text = JSON.stringify(args);
    if (attempt.current?.text !== text) attempt.current = { text, action: crypto.randomUUID() };
    setBusy(true); setError(''); setMessage('');
    try {
      const result = await api().rpc('save_routine_lab_draft', { ...args, p_action_id: attempt.current!.action });
      if (result.error) {
        setError((result.error.code === '40001' || result.error.code === 'PT409') ? 'Ada versi draft yang lebih baru. Muat ulang daftar lalu buka versi terakhir; isian ini tidak ditimpa otomatis.'
          : result.error.code === '42501' ? 'Simpan memerlukan penugasan Analis di Lab ini dan draft milik Anda.'
          : 'Draft belum tersimpan. Cek jumlah benih, urutan waktu, lot, dan metode. Isian tetap ada; jangan buat catatan ganda.');
        return;
      }
      setEditor(current => current ? { ...current, revision: result.data.revision } : null);
      setStoredContent(editor.content);
      attempt.current = null;
      setMessage(`Draft tersimpan di server · revisi ${result.data.revision}. Belum dikirim ke QA.`);
      setCatalogOpen(false);
      const records = await api().rpc('list_routine_lab_drafts', { p_lab_site_id: options.selected_lab_site_id });
      if (!records.error) setPage(records.data as RoutinePage);
      else setError('Draft tersimpan, tetapi daftar belum diperbarui. Muat ulang daftar, jangan membuat draft kedua.');
    } catch { setError('Koneksi terputus. Isian tetap ada. Tekan Simpan lagi dengan isian yang sama untuk memeriksa penyimpanan.'); }
    finally { setBusy(false); }
  }
  function download(draft: RoutineDraft) {
    const url = URL.createObjectURL(new Blob([routineDraftHtml(draft)], { type: 'text/html;charset=utf-8' }));
    const anchor = document.createElement('a'); anchor.href = url; anchor.download = `Draft-Lab-${draft.id}-r${draft.revision}.html`; anchor.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  }
  async function downloadForm(draft: RoutineDraft, format: 'pdf'|'xlsx') {
    if (busy) return;
    setBusy(true); setError('');
    try {
      const response = await fetch(`/api/${draft.method_code === 'RET_16C_72H' ? 'lab-ret' : 'lab-routine'}/${draft.id}/export?format=${format}&revision=${draft.revision}`, { cache: 'no-store', redirect: 'error' });
      if (!response.ok) {
        const detail = await response.json().catch(() => ({}));
        throw Error(detail.message || 'Unduhan belum berhasil. Coba muat ulang catatan.');
      }
      const expected = format === 'pdf' ? 'application/pdf' : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      if (!response.headers.get('content-type')?.startsWith(expected)) throw Error('File unduhan tidak sesuai. Coba login kembali.');
      const blob = await response.blob();
      if (blob.size > 5 * 1024 * 1024) throw Error('File terlalu besar. Hubungi pengelola.');
      const magic = new Uint8Array(await blob.slice(0, 5).arrayBuffer());
      if (format === 'pdf' ? String.fromCharCode(...magic) !== '%PDF-' : magic[0] !== 0x50 || magic[1] !== 0x4b) throw Error('File unduhan belum lengkap. Coba lagi.');
      const url = URL.createObjectURL(blob), anchor = document.createElement('a');
      anchor.href = url; anchor.download = `Form-${draft.method_code === 'SAND_25C' ? 'Germinasi' : draft.method_code === 'RET_16C_72H' ? 'RET' : 'Vigor'}-${draft.id}-r${draft.revision}.${format}`; anchor.click();
      setTimeout(() => URL.revokeObjectURL(url), 1000);
    } catch (e) { setError(e instanceof Error ? e.message : 'Unduhan belum berhasil. Coba kembali.'); }
    finally { setBusy(false); }
  }
  const ret = editor?.method_code === 'RET_16C_72H';
  const reviewTarget = editor && editor.content === storedContent
    && page?.drafts.find(draft => draft.id === editor.id && draft.revision === editor.revision
      && draft.can_edit && !draft.workflow);
  function closeEditor() {
    setEditor(null); attempt.current = null; setStoredContent(null); setMessage(''); setError('');
  }
  function goToReview(draft: RoutineDraft) {
    closeEditor();
    requestAnimationFrame(() => {
      const article = document.getElementById(`routine-draft-${draft.id}`);
      article?.focus({ preventScroll: true });
      article?.scrollIntoView({ block: 'start' });
    });
  }
  return <div className={styles.workspace}>
    <header><Link href="/lab-requests">← Antrean request Plant</Link><h1>Catatan uji rutin</h1></header>
    {!editor && <LabHelp><p>Uji rutin tidak memerlukan request atau pengiriman Plant. Simpan draft dahulu, periksa, lalu kirim ke QA. Revisi yang dikirim dikunci; persetujuan QA bukan pelepasan lot.</p>
      <p>PDF dan Excel diunduh per pengujian dan memakai revisi tersimpan.</p></LabHelp>}
    {!editor && <>{error && <p role="alert" className={styles.notice}>{error}</p>}{message && <p role="status" className={styles.notice}>{message}</p>}</>}
    {!editor&&<RevalidationPanel key={options.selected_lab_site_id} labSiteId={options.selected_lab_site_id} onCreated={()=>loadDrafts(0)}/>}
    <section className={styles.panel} aria-label="Pilih lot pengujian rutin" hidden={!!editor}>
      <details open={catalogOpen} onToggle={event => setCatalogOpen(event.currentTarget.open)}>
      <summary>Pilih lot untuk catatan baru</summary>
      <fieldset disabled={busy || !!editor} className={styles.fields}><label>Lab tempat pengujian<select value={options.selected_lab_site_id} onChange={e => void loadCatalog(e.target.value, 0, search)}>{options.lab_sites.map(s => <option key={s.id} value={s.id}>{s.site_name}</option>)}</select></label></fieldset>
      {!options.can_write && <p>Akun QA dapat membaca draft. Pencatatan dilakukan Analis, bukan memakai akun QA.</p>}
      <form onSubmit={e => { e.preventDefault(); void loadCatalog(options.selected_lab_site_id, 0, search); }} className={styles.search}>
        <label>Cari kode lot atau hybrid<input value={search} onChange={e => setSearch(e.target.value)} maxLength={100} /></label><button className="btn" disabled={busy}>Cari lot</button>
      </form>
      <p>{options.total} lot sesuai pencarian · ditampilkan paling banyak 50 per halaman. Kode lot dipilih dari master, tidak dibuat di sini.</p>
      <div className={styles.lots}>{options.lots.map(lot => <button data-testid="select-routine-lot" type="button" className={styles.lot} key={lot.id} disabled={busy || !!editor || !options.can_write} onClick={() => {
        const method = options.methods.find(m => m.method_code === 'SAND_25C') ?? options.methods[0];
        if (method) { const content=emptyRoutineContent(method); if(method.method_code!=='RET_16C_72H')content.form=emptyRoutineForm(method.method_code,content.observations.length);setEditor({ id: crypto.randomUUID(), revision: 0, lot_id: lot.id, lot_code: lot.lot_code, lot_label: `${lot.lot_code} · ${lot.hybrid} · ${lot.stage_code}`, method_code: method.method_code, content }); setMessage(''); setError(''); }
      }}><strong>{lot.lot_code}</strong><span>{lot.hybrid} · {lot.stage_code}</span><small>{lot.plant_site}</small></button>)}</div>
      {!options.lots.length && <p>Lot tidak ditemukan. Jangan pilih lot pengganti; periksa kode atau hubungi petugas master Plant.</p>}
      <div className={styles.actions}><button className="btn" disabled={busy || options.offset === 0} onClick={() => void loadCatalog(options.selected_lab_site_id, Math.max(0, options.offset - 50), appliedSearch)}>Sebelumnya</button><button className="btn" disabled={busy || !options.has_more} onClick={() => void loadCatalog(options.selected_lab_site_id, options.offset + 50, appliedSearch)}>Berikutnya</button></div>
      </details>
    </section>
    {editor && <form data-testid="routine-editor" className={styles.panel} onSubmit={save}><h2>{editor.lot_label}</h2><p>{editor.revision ? `Draft revisi ${editor.revision}. Lot dan metode sudah dikunci.` : 'Catatan baru, belum tersimpan.'}</p>
      <p>Jenis uji: {editor.revalidation ? routinePurpose(editor) : editor.retest ? 'Uji ulang QA' : 'Pengujian awal'}</p>
      <LabFormSections sections={[{id:'routine-identity',label:'Identitas'},{id:'routine-time',label:'Waktu (WIB)'},{id:'routine-counts',label:'Ulangan'}]} />
      {editor.revalidation&&<LabHelp label="Rujukan Revalidation">{routineRevalidationNotes(editor).map(n=><p key={n}>{n}</p>)}</LabHelp>}
      <fieldset id="routine-identity" data-lab-jump tabIndex={-1} aria-label="Identitas pengujian" disabled={busy} className={styles.fields}><label>Metode<select value={editor.method_code} disabled={editor.revision > 0} onChange={e => {
        if (!window.confirm('Ganti metode akan mengosongkan waktu uji dan pengamatan yang belum disimpan. Lanjut?')) return;
        const method = options.methods.find(m => m.method_code === e.target.value)!;
        const next=emptyRoutineContent(method);if(method.method_code!=='RET_16C_72H')next.form=emptyRoutineForm(method.method_code,next.observations.length);
        setEditor({ ...editor, method_code: method.method_code, content: { ...next, sample_reference: editor.content.sample_reference, received_at: editor.content.received_at, note: editor.content.note } });
      }}>{options.methods.map(m => <option key={m.method_code} value={m.method_code}>{m.method_name}</option>)}</select></label>
      <label>Jumlah ulangan<select data-testid="routine-replicates" value={editor.content.replicate_count} disabled={editor.revision > 0} onChange={e => {
        const count = Number(e.target.value);
        if ((editor.content.observations.some(row => Object.values(row).some(value => value !== null)) || editor.content.form?.annotations.some(row=>row.abnormal_kind||row.remarks)) && !window.confirm('Ganti jumlah ulangan akan mengosongkan hitungan dan catatan subulangan yang belum disimpan. Lanjut?')) return;
        const method = options.methods.find(m => m.method_code === editor.method_code)!;
        const observations=emptyRoutineContent(method,count).observations;
        patchContent({ replicate_count: count, observations, ...(editor.content.form?{form:{...editor.content.form,annotations:emptyRoutineForm(method.method_code,observations.length).annotations}}:{}) });
      }}>{(options.methods.find(m => m.method_code === editor.method_code)?.replicate_counts ?? [editor.content.replicate_count]).map(n => <option key={n} value={n}>{n} × 100 benih</option>)}</select></label>
      <p>Jumlah ulangan dikunci setelah simpan pertama.</p>
      <RoutineSampleReferencePicker key={`${options.selected_lab_site_id}:${editor.id}`} labSiteId={options.selected_lab_site_id}
        lotId={editor.lot_id} value={editor.content.sample_reference ?? ''} locked={!!editor.retest||editor.revalidation?.sample_plan==='RETAINED_LAB'}
        onChange={value => patchContent({ sample_reference: value || null })} /></fieldset>
      <fieldset id="routine-time" data-lab-jump tabIndex={-1} aria-label="Waktu pengujian (WIB)" disabled={busy} className={styles.fields}>
      {(['received_at', 'started_at', 'final_at'] as const).map((key, i) => <label key={key}>{['Sampel tersedia di Lab', ret ? 'Mulai ditempatkan pada 16 °C' : 'Mulai uji / tanam', 'Pengamatan final'][i]} (WIB)<input type="datetime-local" readOnly={editor.retest && key === 'received_at'} value={wibInput(editor.content[key])} onChange={e => patchContent({ [key]: fromWibInput(e.target.value) })} /></label>)}
      {!ret && (editor.content.form ? <RoutineFormDetailsFields value={editor.content.form} onChange={form=>patchContent({form})} germination={editor.method_code==='SAND_25C'}/>
        : <button type="button" className="btn" onClick={()=>patchContent({form:emptyRoutineForm(editor.method_code,editor.content.observations.length)})}>Lengkapi rincian form cetak</button>)}
      <label>Catatan kondisi, alat, atau pekerjaan<textarea maxLength={1000} value={editor.content.note ?? ''} onChange={e => patchContent({ note: e.target.value || null })} /></label></fieldset>
      {editor.retest && <p>Uji ulang: sampel yang sama, waktu mulai baru sesudah keputusan QA.</p>}
      <section id="routine-counts" data-lab-jump tabIndex={-1} aria-label="Ulangan">
      <h3 className={styles.observationHeading}>Ulangan</h3>
      <p>{ret ? 'Radikula ≥2 mm · minimal 72 jam pada 16 °C sebelum kirim ke QA.' : 'Kosong bukan nol. First count tidak ditambah ke final.'}</p>
      <LabHelp label="Cara isi hitungan"><p>{ret ? 'RET memakai 4 × 100 benih. Jangan isi hitungan kecambah normal.' : `${editor.content.replicate_count} × 100 benih; masing-masing a/b berisi 50 benih. Catat fresh, hard, dan mati secara terpisah. Tanggal tanam berbeda dari mulai perlakuan Vigor. DAP mengikuti tanggal aktual dalam WIB.`}</p></LabHelp>
      <RoutineObservationFields content={editor.content} ret={ret} disabled={busy} onChange={patchContent} />
      </section>
      <footer className={styles.editorActions} aria-label="Tindakan draft">
        {error && <p role="alert" className={styles.editorError}>{error}</p>}
        <div className={styles.editorProgress}>
          <strong>{editor.lot_code}</strong>
          <p role="status">{message || (editor.revision === 0 ? 'Draft baru'
            : editor.content === storedContent ? `Revisi ${editor.revision} tersimpan`
            : `Perubahan belum tersimpan · revisi terakhir ${editor.revision}`)}</p>
        </div>
        <div className={styles.editorButtons}>
          <button className="btn btn-primary" disabled={busy}>{busy ? 'Menyimpan…' : 'Simpan draft'}</button>
          {reviewTarget && <button type="button" className="btn" disabled={busy} onClick={() => goToReview(reviewTarget)}>Ke pemeriksaan QA</button>}
          <button type="button" className="btn" disabled={busy} onClick={() => {
            if (editor.content === storedContent || window.confirm('Tutup isian? Perubahan sejak penyimpanan terakhir tidak ikut disimpan.')) closeEditor();
          }}>Tutup isian</button>
        </div>
      </footer>
    </form>}
    <section className={styles.panel} aria-label="Catatan yang tersimpan"><div className={styles.actions}><h2>Catatan tersimpan</h2><button className="btn" disabled={busy} onClick={() => void loadDrafts(page?.offset ?? 0)}>Muat ulang daftar</button></div>
      <p>{page ? `${page.total} catatan rutin di Lab ini, terpisah dari jumlah request Plant. Periksa status masing-masing catatan.` : 'Daftar belum dimuat. Tekan Muat ulang daftar.'}</p>
      {page?.drafts.map(draft => <article key={draft.id} id={`routine-draft-${draft.id}`} data-lab-jump tabIndex={-1} className={styles.saved}><h3>{draft.lot_code} <span className={styles.badge}>{routineStatus(draft.status)}</span></h3><p>{draft.hybrid} · {draft.stage_code} · {draft.method_name}</p><p>Revisi {draft.revision} · disimpan {wibInput(draft.updated_at).replace('T', ' ')} WIB</p>
        <RoutineWorkflowPanel key={draft.revision} draft={draft} disabled={busy || !!editor} onChanged={async result => { setMessage(result.status === 'DRAFT' ? 'Draft uji ulang dibuat. Lanjutkan melalui catatan baru dengan hitungan kosong.' : `Status diperbarui: ${routineStatus(String(result.status))}.`); await loadDrafts(0); }} />
        <div className={styles.actions}>{draft.can_edit && options.can_write && <button className="btn" disabled={busy || !!editor} onClick={() => { const content = structuredClone(draft.content); setStoredContent(content); setEditor({ id: draft.id, revision: draft.revision, lot_id: draft.lot_id, lot_code: draft.lot_code, lot_label: `${draft.lot_code} · ${draft.hybrid} · ${draft.stage_code}`, method_code: draft.method_code, content, retest: !!draft.retest_of_run_id,revalidation:draft.revalidation }); setMessage(''); setError(''); }}>Lanjut isi</button>}<button className="btn" disabled={busy} onClick={() => void downloadForm(draft,'pdf')}>Unduh form PDF</button><button className="btn" disabled={busy} onClick={() => void downloadForm(draft,'xlsx')}>Unduh form Excel</button><button className="btn" onClick={() => download(draft)}>Unduh ringkasan HTML</button></div>
      </article>)}
      {page && !page.drafts.length && <p>Belum ada draft di Lab ini. Request Plant tetap ada di halaman antrean.</p>}
      <div className={styles.actions}><button className="btn" disabled={busy || !page?.offset} onClick={() => void loadDrafts(Math.max(0, (page?.offset ?? 0) - 50))}>Draft sebelumnya</button><button className="btn" disabled={busy || !page?.has_more} onClick={() => void loadDrafts((page?.offset ?? 0) + 50)}>Draft berikutnya</button></div>
    </section>
  </div>;
}

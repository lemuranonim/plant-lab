'use client';

import { useEffect, useRef, type Ref } from 'react';
import Link from 'next/link';
import { logbookWib } from '@/lib/labLogbook';
import { canonicalWritesEnabled } from '@/lib/supabase/config';
import { statusLabel } from '@/lib/workflowPresentation';
import { LabHelp, LabSkeleton } from '../LabUi';
import lab from '../lab-surface.module.css';
import type { Evidence, PiReview, RecordValue } from './PiQuality';
import TswFormDownload from './TswFormDownload';
import { TswSummary } from './TswWeights';
import styles from './lab-pi-sources.module.css';

const testNames: Record<string, string> = {
  PP: 'Kemurnian fisik', MC: 'Kadar air', TSW: 'Berat 1.000 benih',
};
const sourceStates: Record<string, string> = {
  DRAFT: 'Draft PI',
  SUBMITTED: 'Menunggu verifikasi SPV',
  VERIFIED: 'Diverifikasi SPV',
  REVISION_REQUIRED: 'Perlu revisi Plant',
};
const assessments: Record<string, string> = {
  MEETS_INTERNAL_REFERENCE: 'Sesuai acuan internal',
  OUTSIDE_INTERNAL_REFERENCE: 'Di luar acuan internal',
  PENDING_CLASSIFICATION: 'Klasifikasi belum lengkap',
  NO_APPROVED_REFERENCE: 'Acuan belum tersedia',
};
const decisions: Record<string, string> = {
  ACKNOWLEDGED: 'Sumber sudah diperiksa',
  CLARIFICATION_REQUIRED: 'Minta klarifikasi Plant',
};
const numeric = new Intl.NumberFormat('id-ID', { maximumFractionDigits: 20 });
const measurementUnit = (r: RecordValue) => r.unit_code === 'PERCENT' ? '%' : r.test_type === 'TSW' ? 'g / 1.000 benih' : 'g';

type Props = {
  records: RecordValue[]; total: number; offset: number; pageReady: boolean; busy: boolean;
  error: string; notice: string; errorRef: Ref<HTMLDivElement>;
  signed?: { path: string; url: string }; componentLabels: Record<string, string>;
  onRetry: () => void; onPage: (offset: number) => void;
  onEvidence: (evidence: Evidence) => void; onReview: (record: RecordValue, requestId?: string) => void;
};

export function LabPiSources({
  records, total, offset, pageReady, busy, error, notice, errorRef, signed,
  componentLabels, onRetry, onPage, onEvidence, onReview,
}: Props) {
  return <div className={styles.page}>
    <header className={lab.panelHero}>
      <Link href="/lab-requests">← Antrean Lab</Link>
      <h1>Sumber Mutu Plant</h1>
      <span className={lab.readBadge}>Nilai baca saja</span>
      <p>Hasil pengukuran PI untuk permintaan Lab yang terkait.</p>
    </header>
    <LabHelp label="Tentang sumber mutu">
      <p>PI mencatat pengukuran dan bukti. SPV Plant memverifikasi sumber. QA Lab yang berizin bisa mengonfirmasi sumber atau meminta klarifikasi tanpa mengubah nilai Plant.</p>
      <p>Verifikasi sumber bukan persetujuan hasil uji Lab, sertifikasi mutu, atau pelepasan lot.</p>
    </LabHelp>
    {error && <div className={styles.error} ref={errorRef} role="alert">
      <p>{error}</p>
      <button className="btn" type="button" disabled={busy} onClick={onRetry}>Muat ulang daftar</button>
    </div>}
    {notice && <p className={styles.notice} role="status">{notice}</p>}
    {!pageReady && !error && <LabSkeleton label="Memuat sumber mutu…" />}
    {pageReady && <section className={styles.list} aria-labelledby="pi-lab-list-title">
      <h2 id="pi-lab-list-title">Sumber pengukuran <span>{total}</span></h2>
      {!records.length && <div className={styles.card}>Belum ada sumber PI dalam cakupan akun Anda.</div>}
      <div className={styles.cards}>
        {records.map(r => <article className={styles.card} aria-label={`${r.lot_code} · ${r.test_code}`} key={r.id}>
          <div className={styles.topline}>
            <div><h3>{r.lot_code}</h3><p>{r.site_code} · {r.test_code}</p></div>
            <span className={styles.badge} data-source-status={r.source_status}>{sourceStates[r.source_status] ?? statusLabel(r.source_status)}</span>
          </div>
          <div className={styles.reading}>
            <p>{r.test_type}{testNames[r.test_type] && ` · ${testNames[r.test_type]}`}</p>
            {r.numeric_value !== null
              ? <p><strong>{numeric.format(r.numeric_value)}</strong> <span>{measurementUnit(r)}</span></p>
              : <p>Nilai belum dicatat</p>}
          </div>
          <p className={styles.caption}>{logbookWib(r.tested_at)} · Percobaan {r.attempt_no}</p>
          {r.lab_requests.length > 0 && <ul className={styles.requests} aria-label="Permintaan terkait">
            {r.lab_requests.map(q => <li key={q.id}>
              {canonicalWritesEnabled && q.can_review
                ? <button className="btn" type="button" disabled={busy} onClick={() => onReview(r, q.id)}>Review sumber · {q.request_code}</button>
                : <span className={styles.requestCode}>{q.request_code}</span>}
            </li>)}
          </ul>}
          <details className={styles.detail}>
            <summary>Rincian sumber</summary>
            <dl className={styles.facts}>
              <div><dt>Bentuk sampel</dt><dd>{r.material_form}</dd></div>
              <div><dt>Metode</dt><dd>{r.method_reference || 'Belum dicatat'}</dd></div>
              <div><dt>Alat</dt><dd>{r.equipment_reference || 'Belum dicatat'}</dd></div>
              <div><dt>Jenis / programme</dt><dd>{r.crop_kind} / {r.programme}</dd></div>
              {r.notes && <div><dt>Catatan PI</dt><dd>{r.notes}</dd></div>}
              {r.review_reason && <div><dt>Catatan SPV</dt><dd>{r.review_reason}</dd></div>}
              {!!r.assessment.basis && <div><dt>Acuan internal</dt><dd>
                {r.assessment.minimum_percent != null ? `≥${numeric.format(r.assessment.minimum_percent)}% · `
                  : r.assessment.maximum_percent != null ? `≤${numeric.format(r.assessment.maximum_percent)}% · ` : ''}
                {assessments[r.assessment.assessment ?? ''] ?? r.assessment.assessment ?? 'Belum tersedia'}
              </dd></div>}
            </dl>
            {Object.keys(r.components).length > 0 && <details className={styles.detail}>
              <summary>Komponen terukur (g)</summary>
              <dl className={styles.facts}>{Object.entries(r.components).map(([key, value]) =>
                <div key={key}><dt>{componentLabels[key] ?? key}</dt><dd>{numeric.format(value)} g</dd></div>)}</dl>
            </details>}
            {r.tsw_raw && <TswSummary raw={r.tsw_raw} />}
            {r.evidence.length > 0 && <div className={styles.evidence}><h4>Foto bukti ({r.evidence.length})</h4>
              {r.evidence.map(e => <div className={styles.actions} key={e.id}>
                <button type="button" className="btn" disabled={busy} onClick={() => onEvidence(e)}>Buka foto · {e.filename}</button>
                {signed?.path === e.path && <a href={signed.url} target="_blank" rel="noopener noreferrer">Lihat foto (tautan 60 detik)</a>}
              </div>)}</div>}
            {r.lab_reviews.length > 0 && <details className={styles.detail}>
              <summary>Riwayat review Lab ({r.lab_reviews.length})</summary>
              <ul className={styles.history}>{r.lab_reviews.map((v, index) => <li key={`${v.request_id}:${v.reviewed_at}:${index}`}>
                <strong>{decisions[v.decision] ?? v.decision}</strong>
                <p>{r.lab_requests.find(q => q.id === v.request_id)?.request_code ?? 'Permintaan Lab'} · {logbookWib(v.reviewed_at)}</p>
                <p>{v.reason}</p>
              </li>)}</ul>
            </details>}
            {canonicalWritesEnabled && r.can_review && <button className="btn" type="button" disabled={busy} onClick={() => onReview(r)}>Review sumber PI (SPV)</button>}
          </details>
          {r.test_type === 'TSW' && <TswFormDownload record={r} compact />}
        </article>)}
      </div>
      {total > 0 && <nav className={styles.pagination} aria-label="Halaman sumber pengukuran">
        <button className="btn" type="button" disabled={busy || offset === 0} onClick={() => onPage(Math.max(0, offset - 20))}>Sebelumnya</button>
        <span>{offset + 1}–{Math.min(offset + records.length, total)} dari {total}</span>
        <button className="btn" type="button" disabled={busy || offset + 20 >= total} onClick={() => onPage(offset + 20)}>Berikutnya</button>
      </nav>}
    </section>}
  </div>;
}

export function LabPiSourceReview({ review, busy, error, onChange, onClose, onSave }: {
  review: PiReview; busy: boolean; error: string;
  onChange: (patch: Partial<Pick<PiReview, 'reason' | 'decision'>>) => void;
  onClose: () => void; onSave: () => void;
}) {
  const dialog = useRef<HTMLDialogElement>(null);
  useEffect(() => {
    const node = dialog.current;
    node?.showModal();
    return () => node?.close();
  }, []);
  function close() {
    if (busy) return;
    dialog.current?.close();
    onClose();
  }
  const request = review.record.lab_requests.find(q => q.id === review.requestId);
  return <dialog ref={dialog} className={styles.dialog} aria-labelledby="lab-pi-review-title"
    onCancel={event => { event.preventDefault(); close(); }}>
    <form className={styles.review} onSubmit={event => { event.preventDefault(); if (!busy) onSave(); }}>
      <h2 id="lab-pi-review-title">{review.requestId ? 'Review sumber oleh Lab' : 'Verifikasi sumber oleh SPV'}</h2>
      <p>{review.record.lot_code} · {review.record.test_code}{request && ` · ${request.request_code}`}</p>
      <p className={styles.caption}>Tidak mengubah nilai Plant, hasil uji Lab, atau status pelepasan lot.</p>
      <fieldset disabled={busy}>
        <label>Keputusan<select aria-label="Keputusan" value={review.decision} onChange={e => onChange({ decision: e.target.value })}>
          {Object.entries(review.requestId ? decisions : { VERIFIED: 'Sumber terverifikasi', REVISION_REQUIRED: 'Perlu revisi / attempt baru' }).map(([value, label]) =>
            <option key={value} value={value}>{label}</option>)}
        </select></label>
        <label>Alasan dan rujukan bukti<textarea aria-label="Alasan dan rujukan bukti" maxLength={1000} value={review.reason} onChange={e => onChange({ reason: e.target.value })} /></label>
      </fieldset>
      {error && <p role="alert" className={styles.error}>{error}</p>}
      <div className={styles.actions}>
        <button className="btn" type="button" disabled={busy} onClick={close}>Batal</button>
        <button className="btn btn-primary" disabled={busy}>{busy ? 'Menyimpan…' : 'Simpan review sumber'}</button>
      </div>
    </form>
  </dialog>;
}

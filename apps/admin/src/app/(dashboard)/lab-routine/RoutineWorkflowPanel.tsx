'use client';

import { useRef, useState } from 'react';
import { createClient } from '@/lib/supabase/client';
import { canonicalWritesEnabled, isolatedApiSchema } from '@/lib/supabase/config';
import { routineStatus,routinePurpose,routineRevalidationNotes, wibInput, type RoutineDraft, type RoutineReadiness, type RoutineSummary } from '@/lib/routineLabDraft';
import styles from './routine.module.css';

export function RoutineSummaryView({ summary }: { summary: RoutineSummary }) {
  const value = summary.germination_percent ?? summary.vigour_percent;
  const reference = summary.uac_quality_reference;
  return <div className={styles.summary}>
    <p>Hasil analisis <strong>{value}%</strong> · sebelum pembulatan {summary.unrounded_percent}%</p>
    <p>{summary.replicates.length} × 100 benih · toleransi {summary.replicates.length} ulangan</p>
    <p>Selisih {summary.gap_pp} poin persentase · batas {summary.limit_pp ?? 'belum tersedia'} · {summary.within_tolerance === true ? 'Dalam toleransi' : summary.within_tolerance === false ? 'Di luar toleransi' : 'Approval ditahan: aturan belum tersedia'}</p>
    {reference && typeof reference.minimum_percent === 'number' ? <p>Acuan minimum {reference.minimum_percent}%. {typeof value === 'number' && value < reference.minimum_percent ? 'Hasil di bawah acuan.' : 'Hasil memenuhi angka acuan.'} Persetujuan analisis bukan pelepasan lot.</p>
      : <p>Klasifikasi programme/acuan mutu belum lengkap. Tidak menerbitkan label lulus spesifikasi atau pelepasan lot.</p>}
    <ul>{summary.replicates.map((r, index) => <li key={index}>Ulangan {index + 1}: {'radicle_at_least_2mm' in r ? `Radikula ≥2 mm ${r.radicle_at_least_2mm}/100` : `Normal ${r.normal}, abnormal ${r.abnormal}, fresh ${r.fresh}, hard ${r.hard}, mati ${r.dead}`}</li>)}</ul>
    {summary.elapsed_hours !== undefined && <p>RET: {summary.elapsed_hours} jam sejak ditempatkan pada 16°C.</p>}
    <details><summary>Rujukan hitungan</summary><p>{summary.calculation_code} · versi {summary.calculation_version}. Hitungan final kumulatif, tidak ditambah first count.</p></details>
  </div>;
}

export default function RoutineWorkflowPanel({ draft, disabled, onChanged }: {
  draft: RoutineDraft; disabled: boolean; onChanged: (result: Record<string, unknown>) => Promise<void>;
}) {
  const [check, setCheck] = useState<RoutineReadiness | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [confirmed, setConfirmed] = useState(false);
  const [reason, setReason] = useState('');
  const [reviewerName,setReviewerName]=useState('');
  const formReview=draft.content.form?.version===1;
  const attempt = useRef<{ text: string; action: string } | null>(null);
  const workflow = draft.workflow;
  async function inspect() {
    if (busy || disabled) return;
    setBusy(true); setError(''); setConfirmed(false);
    try {
      const result = await createClient().schema(isolatedApiSchema).rpc('check_routine_lab_draft', { p_draft_id: draft.id, p_expected_revision: draft.revision });
      if (result.error) throw Error();
      setCheck(result.data as RoutineReadiness);
    } catch { setError('Pemeriksaan belum bisa dimuat. Muat ulang revisi tersimpan dan cek koneksi.'); }
    finally { setBusy(false); }
  }
  async function command(name: string, args: Record<string, unknown>) {
    if (busy || disabled || !canonicalWritesEnabled) return;
    const text = JSON.stringify({ name, args });
    if (attempt.current?.text !== text) attempt.current = { text, action: crypto.randomUUID() };
    setBusy(true); setError('');
    try {
      const result = await createClient().schema(isolatedApiSchema).rpc(name, { ...args, p_action_id: attempt.current!.action });
      if (result.error) {
        setError((result.error.code === '40001' || result.error.code === 'PT409') ? 'Revisi berubah. Muat ulang lalu periksa ulang; jangan mengirim revisi lama.'
          : result.error.code === '23505' ? 'Ada pekerjaan/metode aktif atau aksi yang sama dengan rincian berbeda. Periksa catatan yang sudah ada, jangan membuat duplikat.'
          : 'Aksi belum selesai. Periksa kelengkapan, status, role, toleransi, dan waktu nyata. Isian tidak ditimpa.');
        return;
      }
      attempt.current = null; setCheck(null); setConfirmed(false); setReason('');
      await onChanged(result.data as Record<string, unknown>);
    } catch { setError('Koneksi terputus. Ulangi aksi yang sama untuk memastikan, jangan membuat catatan baru.'); }
    finally { setBusy(false); }
  }
  return <div className={styles.workflow}>
    {draft.revalidation&&<details><summary>{routinePurpose(draft)} · sumber {draft.revalidation.source_run_code}</summary>{routineRevalidationNotes(draft).map((n,i)=><p key={i}>{n}</p>)}</details>}
    {draft.content.form && <details><summary>Rincian form tersimpan · revisi {draft.revision}</summary>
      <p>Tanaman / spesies: {draft.content.form.crop_species ?? 'belum dicatat'}<br/>Pelaksana: {draft.content.form.analyst_name ?? 'belum dicatat'}<br/>Suhu pada form: {draft.content.form.temperature_text ?? 'belum dicatat'} °C<br/>Tanam: {wibInput(draft.content.form.planted_at).replace('T',' ') || 'belum dicatat'} WIB<br/>First count: {wibInput(draft.content.form.first_count_at).replace('T',' ') || 'belum dicatat'} WIB</p>
      <ul>{draft.content.form.annotations.map((a,i)=><li key={i}>Subulangan {Math.floor(i/2)+1}{i%2?'b':'a'} · jenis abnormal: {a.abnormal_kind ?? 'belum dicatat'} · catatan: {a.remarks ?? 'belum dicatat'}</li>)}</ul>
    </details>}
    {workflow && <><p><strong>{routineStatus(workflow.status)}</strong> · {workflow.run_code} · percobaan {workflow.attempt_no}</p>
      {workflow.summary && <RoutineSummaryView summary={workflow.summary} />}
      {workflow.review_reason && <p>Catatan QA: {workflow.review_reason}</p>}
      {workflow.reviewed_at && <p>Diperiksa {wibInput(workflow.reviewed_at).replace('T', ' ')} WIB</p>}
      <details><summary>Jejak pencatatan</summary><p>ID Analis: {workflow.analyst_id}<br />ID QA: {workflow.reviewer_id ?? 'belum ada'}<br />Run sebelumnya: {workflow.parent_run_id ?? 'pengujian awal'}</p></details>
    </>}
    {error && <p role="alert">{error}</p>}
    {!workflow && draft.can_edit && canonicalWritesEnabled && <>
      <p>Pengiriman memakai revisi {draft.revision} yang sudah tersimpan. Simpan lalu tutup isian sebelum memeriksa.</p>
      <button type="button" className="btn" disabled={disabled || busy} onClick={() => void inspect()}>Periksa sebelum kirim ke QA</button>
    </>}
    {check && <section className={styles.notice} aria-label="Pemeriksaan revisi tersimpan">
      <h4>Revisi {check.revision}: {check.ready ? 'lengkap untuk dikirim' : 'masih perlu dilengkapi'}</h4>
      <ul>{check.blockers.map(b => <li key={b.code}>{b.message}</li>)}{check.warnings.map(w => <li key={w}>{w}</li>)}</ul>
      {check.summary && <RoutineSummaryView summary={check.summary} />}
      <p>Setelah dikirim, revisi ini dikunci. Koreksi/uji ulang mengikuti keputusan QA, tidak menimpa hasil sebelumnya.</p>
      <label className={styles.check}><input type="checkbox" checked={confirmed} onChange={e => setConfirmed(e.target.checked)} />Saya memastikan sampel benar tersedia di Lab dan isian merupakan pengamatan nyata, bukan latihan.</label>
      <button type="button" className="btn btn-primary" disabled={busy || disabled || !check.ready || !confirmed}
        onClick={() => void command('submit_routine_lab_draft', { p_draft_id: draft.id, p_expected_revision: check.revision, p_actual_work_confirmed: confirmed })}>Kirim revisi ini ke QA</button>
    </section>}
    {workflow?.can_review && canonicalWritesEnabled && <fieldset disabled={busy || disabled}>
      <legend>Pemeriksaan QA independen</legend>
      {formReview&&<label>Nama pemeriksa pada form<input value={reviewerName} maxLength={120} onChange={e=>setReviewerName(e.target.value)}/></label>}
      <label>Catatan pemeriksaan / alasan uji ulang<textarea value={reason} onChange={e => setReason(e.target.value)} minLength={3} maxLength={1000} /></label>
      <label className={styles.check}><input type="checkbox" checked={confirmed} onChange={e => setConfirmed(e.target.checked)} />Saya sudah memeriksa identitas sampel, hitungan, kondisi, waktu nyata, dan toleransi.</label>
      <div className={styles.actions}><button type="button" className="btn btn-primary" disabled={!confirmed || reason.trim().length < 3 || (formReview&&reviewerName.trim().length<2) || workflow.summary?.within_tolerance !== true}
        onClick={() => void command(formReview?'review_routine_lab_form_result':'review_routine_lab_result', { p_run_id: workflow.run_id, p_decision: 'APPROVE', p_reason: reason, p_protocol_checked: confirmed,...(formReview?{p_reviewer_name:reviewerName}:{} ) })}>Setujui analisis</button>
      <button type="button" className="btn" disabled={!confirmed || reason.trim().length < 3 || (formReview&&reviewerName.trim().length<2)}
        onClick={() => void command(formReview?'review_routine_lab_form_result':'review_routine_lab_result', { p_run_id: workflow.run_id, p_decision: 'RETEST', p_reason: reason, p_protocol_checked: confirmed,...(formReview?{p_reviewer_name:reviewerName}:{} ) })}>Minta uji ulang</button></div>
    </fieldset>}
    {workflow?.can_retest && canonicalWritesEnabled && <button type="button" className="btn" disabled={busy || disabled}
      onClick={() => void command('create_routine_retest_draft', { p_run_id: workflow.run_id })}>Buat catatan uji ulang</button>}
  </div>;
}

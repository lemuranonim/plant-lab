'use client';

import { useRef, useState, type FormEvent } from 'react';
import { useRouter } from 'next/navigation';
import { createClient } from '@/lib/supabase/client';
import { canonicalWritesEnabled, isolatedApiSchema, hostedPilot } from '@/lib/supabase/config';
import { ProvisionalResultSnapshot, type QualityReference } from './ProvisionalQualityReference';
import styles from './queue.module.css';
import { statusLabel } from '@/lib/workflowPresentation';
import RetRequestFormDownload from './RetRequestFormDownload';
import {RequestSeedlingDownload} from './RequestSeedlingForms';
import GerminationDetailsPanel from './GerminationDetailsPanel';

export type VigourMethod = { method_code: string; method_name: string; procedure_summary?: string };
export type VigourOptions = { methods: VigourMethod[]; ret_enabled: boolean };
type Counts = { normal?: number; abnormal?: number; dead?: number; fresh?:number;hard?:number;tested?: number; radicle_at_least_2mm?: number };
type Summary = {
  vigour_percent: number; unrounded_percent: number; replicates: Counts[];
  gap_pp: number; limit_pp: number | null; within_tolerance: boolean | null;
  observed_at: string; observation_note: string; uac_quality_reference?: QualityReference;
  tolerance_lookup_percent?: number;
};
export type VigourRun = {
  request_id: string; item_id: string; method_code: string; method_name: string;
  item_status: string; run_id: string | null; run_code: string | null;
  status: string | null; attempt_no: number | null; actual_started_at: string | null;
  conditions_note: string | null; summary: Summary | null; decision_reason: string | null;
  is_assigned_analyst: boolean;
  prior_attempts: { run_code: string; attempt_no: number; status: string; summary: Summary | null }[];
};
const countFields = [['normal', 'Normal'], ['abnormal', 'Abnormal'], ['dead', 'Mati']] as const;
const dateLabel = (date: string) => new Date(date).toLocaleString('id-ID');
// Called only by the submit handler, so the clock reflects the user action.
function actualEventDate(value:string){const date=new Date(value);return value&&Number.isFinite(date.getTime())&&date.getTime()<=Date.now()?date:null;}

export function VigourPanel({ run, requestStatus, analyst, reviewer }: {
  run: VigourRun; requestStatus: string; analyst: boolean; reviewer: boolean;
}) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [hasDetails,setHasDetails] = useState<boolean|null>(null);
  const attempt = useRef<{ payload: string; id: string } | null>(null);
  const canStart = analyst && ((!run.run_id && ['RECEIVED', 'TESTING'].includes(requestStatus)) || run.status === 'RETEST');
  const canSubmit = analyst && run.status === 'IN_PROGRESS' && run.is_assigned_analyst;
  const canReview = reviewer && run.status === 'IN_REVIEW' && !run.is_assigned_analyst;
  const ret = run.method_code === 'RET_16C_72H';
  const fields = ret ? [['radicle_at_least_2mm', 'Radikula ≥2 mm']] as const : countFields;
  const readyAt = ret && run.actual_started_at ? new Date(new Date(run.actual_started_at).getTime() + 72 * 3600000) : null;
  const [counts, setCounts] = useState<string[][]>(() => Array.from({length:ret ? 4 : 2}, () => Array.from({length:ret ? 1 : 3}, () => '')));
  const validCounts = counts.every(row => row.every(v => /^\d{1,3}$/.test(v) && Number(v) <= 100) && (ret || row.reduce((s, v) => s + Number(v), 0) === 100));

  async function invoke(name: string, payload: Record<string, unknown>) {
    if (!canonicalWritesEnabled || busy) return;
    const serialized = JSON.stringify({ name, ...payload });
    if (attempt.current?.payload !== serialized) attempt.current = { payload: serialized, id: crypto.randomUUID() };
    setBusy(true); setError('');
    try {
      const result = await createClient().schema(isolatedApiSchema).rpc(name, { ...payload, p_action_id: attempt.current.id });
      if (result.error) {
        setError(result.error.code === '23514' ? 'Approval ditolak: toleransi belum tersedia atau terlampaui. Periksa hasil dan ajukan uji ulang bila diperlukan.'
          : result.error.code === '23505' ? 'ID tindakan sudah dipakai dengan data berbeda. Muat ulang sebelum melanjutkan.'
            : 'Tidak dapat menyimpan. Periksa hitungan, waktu nyata, status, dan penugasan akun.');
        return;
      }
      attempt.current = null; router.refresh();
    } catch { setError('Koneksi terputus. Ulangi dengan data yang sama agar tidak terduplikasi.'); }
    finally { setBusy(false); }
  }
  function submit(event: FormEvent<HTMLFormElement>, action: 'start' | 'submit' | 'review') {
    event.preventDefault();
    const data = new FormData(event.currentTarget);
    const note = String(data.get('note') ?? '').trim();
    if (note.length < 3) { setError('Catatan minimal 3 karakter wajib diisi.'); return; }
    if (action === 'review') {
      void invoke('review_vigour', { p_run_id: run.run_id, p_decision: data.get('decision'), p_reason: note }); return;
    }
    const local = String(data.get('actual_time') ?? '');
    const actual = actualEventDate(local);
    if (!actual) { setError('Isi waktu kejadian nyata, bukan waktu rencana atau masa depan.'); return; }
    if (action === 'start') void invoke('start_vigour', { p_item_id: run.item_id, p_started_at: actual.toISOString(), p_conditions_note: note });
    else {
      if (!validCounts) { setError(ret ? 'Isi empat hitungan radikula ≥2 mm, masing-masing 0–100 dari 100 benih.' : 'Setiap ulangan harus berjumlah tepat 100 benih; isi 0 untuk kategori tanpa benih.'); return; }
      if (readyAt && actual < readyAt) { setError(`Pengamatan RET paling cepat ${readyAt.toLocaleString('id-ID')} (72 jam sejak penempatan pada 16°C).`); return; }
      const rows = counts.map(row => ({...Object.fromEntries(fields.map(([key], i) => [key, Number(row[i])])), ...(ret ? {tested:100} : {})}));
      void invoke('submit_vigour', { p_run_id: run.run_id, p_observed_at: actual.toISOString(), p_replicates: rows, p_observation_note: note });
    }
  }
  const summary = run.summary;
  return <details className={styles.vigourPanel}>
    <summary>Vigor · {run.method_name} · {statusLabel(run.status ?? run.item_status)}</summary>
    <p>{run.run_code ?? 'Belum dimulai'}{run.attempt_no && ` · Percobaan ${run.attempt_no}`}</p>
    {run.actual_started_at && <p>Mulai nyata: {dateLabel(run.actual_started_at)}</p>}
    {run.conditions_note && <p>Kondisi/metode: {run.conditions_note}</p>}
    {readyAt && <p>RET · radikula ≥2 mm · 4×100 benih. Pengamatan final paling cepat {readyAt.toLocaleString('id-ID')} (72 jam sejak penempatan pada 16°C).</p>}
    {summary && <>
      <p>Hasil {ret ? 'RET' : 'Vigor'}: <strong>{summary.vigour_percent}%</strong>{!ret && <> · sebelum pembulatan {summary.unrounded_percent}%</>}</p>
      <p>{ret ? `Jumlah radikula memenuhi kriteria / 400 × 100. Toleransi 4 Reps memakai lookup ${summary.tolerance_lookup_percent}%; nilai RET tidak dibulatkan ke persen utuh.` : 'Rata-rata normal per ulangan 100 benih, dibulatkan ke persen utuh mengikuti Excel.'}</p>
      <p>Selisih {summary.gap_pp} poin persentase · batas {summary.limit_pp ?? 'belum tersedia'} · {summary.within_tolerance === true ? 'Dalam toleransi' : summary.within_tolerance === false ? 'Di luar toleransi' : 'Belum dapat dinilai; approval diblokir'}</p>
      <ol>{summary.replicates.map((row, i) => <li key={i}>{ret ? `Radikula ≥2 mm: ${row.radicle_at_least_2mm} / ${row.tested} benih` : `Normal ${row.normal} · Abnormal ${row.abnormal}${row.fresh!==undefined?` · Fresh ${row.fresh}`:''}${row.hard!==undefined?` · Hard ${row.hard}`:''} · Mati ${row.dead}`}</li>)}</ol>
      <p>Pengamatan final nyata: {dateLabel(summary.observed_at)} · {summary.observation_note}</p>
      <ProvisionalResultSnapshot snapshot={summary.uac_quality_reference} />
    </>}
    {run.decision_reason && <p>Catatan QA: {run.decision_reason}</p>}
    {ret&&run.run_code&&run.status&&(analyst||reviewer)&&<RetRequestFormDownload runCode={run.run_code} status={run.status}/>}
    {!ret&&run.run_code&&run.status&&(analyst||reviewer)&&<RequestSeedlingDownload runCode={run.run_code} status={run.status} kind="Vigor"/>}
    {canStart && <form onSubmit={event => submit(event, 'start')} className={styles.form}>
      <fieldset disabled={busy}>
        <legend>{run.status === 'RETEST' ? 'Mulai percobaan ulang baru' : 'Mulai uji nyata'}</legend>
        <label>{ret ? 'Waktu benih ditempatkan pada 16°C' : 'Waktu mulai nyata'}<input name="actual_time" type="datetime-local" step={1} required /></label>
        <label>Kondisi, alat, dan rujukan metode aktual<textarea name="note" minLength={3} maxLength={1000} required /></label>
        <p>Tulis kejadian fisik yang benar-benar dilakukan. Tanggal rencana Excel bukan bukti pelaksanaan.</p>
        <button className="btn btn-primary">{run.status === 'RETEST' ? 'Mulai uji ulang' : 'Mulai Vigor'}</button>
      </fieldset>
    </form>}
    {hostedPilot&&!ret&&run.run_code&&(analyst||reviewer)&&<GerminationDetailsPanel key={run.run_code+run.status} kind="VIGOUR" requestId={run.request_id} runCode={run.run_code} canApprove={summary?.within_tolerance===true} onLoaded={setHasDetails}/>}
    {canSubmit && (ret||!hostedPilot) && <form onSubmit={event => submit(event, 'submit')} className={styles.form}>
      <fieldset disabled={busy}>
        <legend>Pengamatan final · {ret ? 'RET 4 × 100' : '2 × 100'} benih</legend>
        <label>Waktu pengamatan final nyata<input name="actual_time" type="datetime-local" step={1} required /></label>
        {counts.map((row, i) => <fieldset key={i}>
          <legend>Ulangan {i + 1}</legend>
          <div className={styles.vigourCounts}>{fields.map(([key, label], j) => <label key={key}>{label}
            <input aria-label={`${label} ulangan ${i + 1}`} inputMode="numeric" type="number" min={0} max={100} step={1} required value={row[j]}
              onChange={event => setCounts(old => old.map((r, index) => index === i ? r.map((v, col) => col === j ? event.target.value : v) : r))} />
          </label>)}</div>
          <p>{ret ? 'Memenuhi kriteria' : 'Total'} {row.every(v => /^\d+$/.test(v)) ? row.reduce((s, v) => s + Number(v), 0) : '—'} / 100 benih</p>
        </fieldset>)}
        <label>Catatan pengamatan nyata<textarea name="note" minLength={3} maxLength={1000} required /></label>
        <button className="btn btn-primary" disabled={!validCounts}>Kirim hasil Vigor ke QA</button>
      </fieldset>
    </form>}
    {canReview && (ret||!hostedPilot||hasDetails===false) && <form onSubmit={event => submit(event, 'review')} className={styles.form}>
      <fieldset disabled={busy}>
        <legend>Review QA independen</legend>
        <label>Keputusan<select name="decision" required defaultValue="">
          <option value="">Pilih keputusan</option>
          <option value="APPROVE" disabled={summary?.within_tolerance !== true}>Setujui hasil analisis</option>
          <option value="RETEST">Minta uji ulang</option>
        </select></label>
        <label>Hasil pemeriksaan hitungan, waktu, kondisi, dan alasan keputusan<textarea name="note" minLength={3} maxLength={1000} required /></label>
        <p>Persetujuan ini untuk hasil analisis, bukan sertifikasi protokol otomatis atau pelepasan lot.</p>
        <button className="btn btn-primary">Simpan keputusan QA</button>
      </fieldset>
    </form>}
    {!!run.prior_attempts.length && <details><summary>Riwayat percobaan sebelumnya ({run.prior_attempts.length})</summary>
      <ul>{run.prior_attempts.map(prior => <li key={prior.run_code}>{prior.run_code} · percobaan {prior.attempt_no} · {prior.status} · {prior.summary?.vigour_percent ?? '—'}%
       {ret&&(analyst||reviewer)&&<RetRequestFormDownload runCode={prior.run_code} status={prior.status}/>}
       {!ret&&(analyst||reviewer)&&<RequestSeedlingDownload runCode={prior.run_code} status={prior.status} kind="Vigor"/>}
      </li>)}</ul>
    </details>}
    {error && <p role="alert">{error}</p>}
  </details>;
}

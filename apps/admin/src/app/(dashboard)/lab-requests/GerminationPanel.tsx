'use client';

import { useRef, useState, type FormEvent } from 'react';
import { useRouter } from 'next/navigation';
import { createClient } from '@/lib/supabase/client';
import { canonicalWritesEnabled, isolatedApiSchema, hostedPilot } from '@/lib/supabase/config';
import { ProvisionalResultSnapshot, type QualityReference } from './ProvisionalQualityReference';
import { statusLabel } from '@/lib/workflowPresentation';
import {GerminationRequestForms} from './RequestSeedlingForms';
import GerminationDetailsPanel from './GerminationDetailsPanel';

const categories = [
  ['normal', 'Normal'], ['abnormal', 'Abnormal'], ['dead', 'Mati'],
] as const;

type Replicate = { normal: number; abnormal: number; dead: number; fresh?:number; hard?:number; first_normal?:number|null };
export type GerminationRun = {
  request_id: string;
  run_code: string;
  status: string;
  attempt_no?: number;
  is_assigned_analyst?: boolean;
  summary: null | {
    germination_percent: number;
    gap_pp: number;
    limit_pp: number | null;
    within_tolerance: boolean | null;
    replicates: Replicate[];
    uac_quality_reference?: QualityReference | null;
  };
  decision_reason: string | null;
};

export function GerminationPanel({ requestId, status, run, analyst, reviewer, inObservationTab = false }: {
  requestId: string;
  status: string;
  run?: GerminationRun;
  analyst: boolean;
  reviewer: boolean;
  inObservationTab?: boolean;
}) {
  const router = useRouter();
  const [count, setCount] = useState(2);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [hasDetails,setHasDetails]=useState<boolean|null>(null);
  const lock = useRef(false);
  const [confirmedRun, setConfirmedRun] = useState<string|null>(null);
  const sampleAvailable = Boolean(run && confirmedRun === run.run_code);
  const start = analyst && status === 'RECEIVED' && !run;
  const retest = analyst && status === 'RETEST' && run?.status === 'RETEST';
  const submit = analyst && run?.status === 'IN_PROGRESS' && (!hostedPilot || run.is_assigned_analyst === true);
  const review = reviewer && run?.status === 'IN_REVIEW' && Boolean(run.summary) && run.is_assigned_analyst !== true;
  if (!canonicalWritesEnabled || (!run && !start)) return null;

  async function invoke(name: string, args: Record<string, unknown>) {
    if (lock.current) return;
    lock.current = true;
    setBusy(true);
    setError('');
    try {
      const { error } = await createClient().schema(isolatedApiSchema)
        .rpc(name, { ...args, p_request_id: requestId });
      if (error) {
        setError((error.code === '40001' || error.code === 'PT409') || error.code === '55000' ? 'Percobaan atau status berubah. Muat ulang sebelum melanjutkan.' : 'Tidak dapat menyimpan. Periksa data, status, dan hak akses.');
        return;
      }
      router.refresh();
    } catch {
      setError('Koneksi terputus. Coba lagi dengan detail yang sama.');
    } finally {
      lock.current = false;
      setBusy(false);
    }
  }

  function submitCounts(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const data = new FormData(event.currentTarget);
    const rows = Array.from({ length: count }, (_, i) => Object.fromEntries(
      categories.map(([key]) => [key, Number(data.get(key + i))]),
    ) as Replicate);
    const totals = rows.map(row => row.normal + row.abnormal + row.dead);
    if (hostedPilot && (rows.length !== 2 || totals.some(total => total !== 100))) {
      setError('Pengujian baru memerlukan 2 ulangan, masing-masing tepat 100 benih.');
      return;
    }
    if (!totals[0] || totals.some(total => total !== totals[0])) {
      setError('Total benih setiap ulangan harus sama dan lebih dari nol.');
      return;
    }
    void invoke(hostedPilot ? 'submit_germination_attempt' : 'submit_germination', { p_replicates: rows, ...(hostedPilot ? {p_run_code: run?.run_code} : {}) });
  }

  const summary = run?.summary;
  return (
    <details style={{ minWidth: 200 }} open={inObservationTab || undefined}>
      <summary>Germinasi · Pasir 25 °C</summary>
      {run && <p>{run.run_code} · Percobaan {run.attempt_no ?? 1} · <span title={run.status}>{statusLabel(run.status)}</span></p>}
      {!inObservationTab&&run&&(analyst||reviewer)&&<GerminationRequestForms key={requestId+run.run_code} requestId={requestId} runCode={run.run_code} status={run.status}/>}
      {summary && <>
        <p>Hasil Germinasi: <strong>{summary.germination_percent}%</strong></p>
        {hostedPilot && <ProvisionalResultSnapshot snapshot={summary.uac_quality_reference} />}
        <p>Selisih: {summary.gap_pp} poin persentase · batas: {summary.limit_pp ?? 'belum tersedia'}</p>
        <p>{summary.within_tolerance === true ? 'Dalam toleransi'
          : summary.within_tolerance === false ? 'Di luar toleransi' : 'Aturan toleransi belum tersedia'}</p>
        <p>Toleransi membandingkan ulangan, bukan batas spesifikasi mutu atau pelepasan lot.</p>
        <ol>
          {summary.replicates.map((row, index) => <li key={index}>
            Normal {row.normal}, abnormal {row.abnormal}{row.fresh!==undefined&&`, fresh ${row.fresh}`}{row.hard!==undefined&&`, hard ${row.hard}`}, mati {row.dead}{row.first_normal!==undefined&&row.first_normal!==null&&` · first count ${row.first_normal} (terpisah)`}
          </li>)}
        </ol>
        {run?.decision_reason && <p>Catatan QA: {run.decision_reason}</p>}
      </>}
      {start && <button type="button" className="btn btn-primary" disabled={busy}
        onClick={() => void invoke('start_germination', {})}>Mulai uji Germinasi</button>}
      {retest && <form onSubmit={event => {event.preventDefault();if(!sampleAvailable)return;void invoke('start_germination_retest',{p_prior_run_code:run?.run_code,p_sample_available:true});}}>
        <p>QA meminta uji ulang dengan alasan di atas. Percobaan baru memakai sampel yang sama dan hitungan baru 2×100; hasil lama tetap tersimpan. Ini bukan permintaan pengiriman sampel baru.</p>
        <label style={{display:'flex',alignItems:'flex-start',gap:10,paddingBlock:12,cursor:'pointer'}}><input style={{width:18,height:18,flexShrink:0,padding:0,marginTop:2,accentColor:'#059669'}} type="checkbox" checked={sampleAvailable} disabled={busy} onChange={event=>setConfirmedRun(event.target.checked ? run?.run_code ?? null : null)}/> Sampel yang sama masih tersedia di Lab dan uji ulang akan dimulai.</label>
        <button type="submit" className="btn btn-primary" disabled={busy||!sampleAvailable}>Mulai uji ulang Germinasi</button>
      </form>}
      {analyst && run?.status==='IN_PROGRESS' && hostedPilot && run.is_assigned_analyst!==true && <p>Pengamatan diisi oleh Analis yang memulai percobaan ini.</p>}
      {hostedPilot&&run&&(analyst||reviewer)&&<GerminationDetailsPanel key={run.run_code+run.status} requestId={requestId} runCode={run.run_code} canApprove={summary?.within_tolerance===true} onLoaded={setHasDetails}/>}
      {submit && !hostedPilot && <form onSubmit={submitCounts}>
        <fieldset disabled={busy}>
          <legend>Pengamatan final</legend>
          <p>Isi jumlah benih dari pengamatan final yang sudah dilakukan, bukan persentase. Isi 0 jika tidak ada. {hostedPilot ? '2 ulangan × 100 benih. Normal + abnormal + mati = 100 per ulangan.' : 'Total setiap ulangan harus sama.'}</p>
          <label>Jumlah ulangan{' '}
            <select value={count} onChange={event => setCount(Number(event.target.value))}>
              <option value={2}>2</option>{!hostedPilot && <option value={4}>4</option>}
            </select>
          </label>
          {Array.from({ length: count }, (_, index) => <fieldset key={index}>
            <legend>Ulangan {index + 1}</legend>
            {categories.map(([key, label]) => <label key={key}>{label}{' '}
              <input name={key + index} type="number" min={0} max={hostedPilot ? 100 : 9999} step={1} required />
            </label>)}
          </fieldset>)}
          <button className="btn btn-primary" type="submit">Kirim hasil ke QA</button>
        </fieldset>
      </form>}
      {review && (!hostedPilot||hasDetails===false) && <div>
        <button type="button" className="btn btn-primary" disabled={busy || summary?.within_tolerance !== true}
          onClick={() => void invoke(hostedPilot ? 'review_germination_attempt' : 'review_germination', { p_decision: 'APPROVE', ...(hostedPilot ? {p_run_code:run?.run_code} : {}) })}>Setujui hasil</button>
        <form onSubmit={event => {
          event.preventDefault();
          const reason = String(new FormData(event.currentTarget).get('reason') ?? '').trim();
          if (!reason) { setError('Alasan uji ulang wajib diisi.'); return; }
          void invoke(hostedPilot ? 'review_germination_attempt' : 'review_germination', { p_decision: 'RETEST', p_reason: reason, ...(hostedPilot ? {p_run_code:run?.run_code} : {}) });
        }}>
          <label>Alasan uji ulang{' '}<input name="reason" required maxLength={500} disabled={busy} /></label>
          <button type="submit" disabled={busy}>Minta uji ulang</button>
        </form>
      </div>}
      {error && <p role="alert">{error}</p>}
    </details>
  );
}

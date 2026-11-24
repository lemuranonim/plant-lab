import { redirect } from 'next/navigation';
import Link from 'next/link';
import { canUsePreviewVariant, requireCurrentVariantAccess } from '@/lib/accessContext';
import { getAppVariant } from '@/lib/appVariant';
import { createClient } from '@/lib/supabase/server';
import { isolatedApiSchema, canonicalWritesEnabled } from '@/lib/supabase/config';
import { AcceptRequestButton, SubmitRequestForm, type RequestOptions } from './RequestCommands';
import { SampleHandoff, type Handoff } from './SampleHandoff';
import { GerminationPanel, type GerminationRun } from './GerminationPanel';
import styles from '../lab-quality/lab-quality.module.css';
import queueStyles from './queue.module.css';
import { ProvisionalQualityReference, type ConfirmedLabContracts } from './ProvisionalQualityReference';
import { hostedPilot } from '@/lib/supabase/config';
import { HistoricalQualityBrowser } from './HistoricalQualityBrowser';
import { VigourPanel, type VigourRun, type VigourOptions } from './VigourPanel';
import QueueWorkspace from './QueueWorkspace';
import ApprovedRoutineResults from '../lab-routine/ApprovedRoutineResults';
import { nextStep, queueGroup, roleGuide, statusLabel, testLabel } from '@/lib/workflowPresentation';

type CanonicalRequest = {
  request_id: string;
  request_code: string;
  lot_id: string | null;
  lot_code: string | null;
  test_codes: string[];
  status: string;
  requested_at: string | null;
  sampling_instruction: string | null;
};

type RequestLotPair = {
  request_id: string;
  tested_stage_code: 'DSS' | 'DCS';
  dss_lot_code: string;
  dcs_lot_code: string;
};

export default async function CanonicalLabQueue() {
  const variant = getAppVariant();
  const access = await requireCurrentVariantAccess();
  if (!canUsePreviewVariant(access, variant.code)) redirect('/access-denied');

  const supabase = await createClient();
  const api = supabase.schema(isolatedApiSchema);
  const { data, error } = await api.rpc('list_lab_requests', {
    p_module: variant.code,
    p_limit: 50,
  });
  const requests = (data ?? []) as CanonicalRequest[];
  const detailParams = {
    p_request_ids: requests.map(request => request.request_id),
    p_module: variant.code,
  };
  const qualityContracts = hostedPilot ? await api.rpc('get_confirmed_lab_contracts') : null;
  const [options, pairDetails, sampleDetails, germinationDetails, vigourDetails, vigourOptions] = await Promise.all([
    canonicalWritesEnabled && variant.code === 'PLANT' ? api.rpc('get_request_options') : null,
    requests.length ? api.rpc('list_request_lot_pairs', detailParams) : null,
    canonicalWritesEnabled && requests.length ? api.rpc('list_sample_handoffs', detailParams) : null,
    canonicalWritesEnabled && requests.length ? api.rpc(hostedPilot ? 'list_germination_runs_v2' : 'list_germination_runs', detailParams) : null,
    hostedPilot && requests.length ? api.rpc('list_vigour_runs_v2', detailParams) : null,
    hostedPilot ? api.rpc('get_vigour_workflow_options_v2') : null,
  ]);
  const canAccept = canonicalWritesEnabled && variant.code === 'LAB' &&
    access.roles.some(role => role.module_code === 'LAB');
  const lotPairs = new Map(((pairDetails?.data ?? []) as RequestLotPair[])
    .map(pair => [pair.request_id, pair]));
  const handoffs = new Map(((sampleDetails?.data ?? []) as Handoff[])
    .map(handoff => [handoff.request_id, handoff]));
  const germinationRuns = new Map(((germinationDetails?.data ?? []) as GerminationRun[])
    .map(run => [run.request_id, run]));
  const isAnalyst = variant.code === 'LAB' && access.roles.some(role => role.role_code === 'LAB_ANALYST');
  const isReviewer = variant.code === 'LAB' && access.roles.some(role => role.role_code === 'LAB_QA_APPROVER');
  const guide = roleGuide(variant.code, access.roles.filter(role => role.module_code === variant.code).map(role => role.role_code));

  return (
    <div className={styles.container}>
      <header className={styles.header}>
        <div>
          <p className={queueStyles.eyebrow}>{variant.code === 'PLANT' ? 'PLANT / KOORDINASI LAB' : 'LAB / PENGUJIAN BENIH'}</p>
          <h1 className={styles.title}>{variant.code === 'PLANT' ? 'Permintaan & hasil Lab' : 'Antrean pengujian Lab'}</h1>
          <p className={styles.subtitle}>Pantau perjalanan sampel, pengujian, dan hasil dalam satu tempat.</p>
        </div>
        {!hostedPilot && variant.code === 'PLANT' && access.roles.some(role => role.role_code === 'PLANT_SPV' && role.module_code === 'PLANT') && (
          <Link className="btn" href="/lot-pair-reviews">Verifikasi Pasangan Lot</Link>
        )}
      </header>
      <aside className={queueStyles.roleGuide}><span className={queueStyles.guideIcon} aria-hidden="true">{variant.code === 'PLANT' ? 'P' : 'L'}</span><div><h2>{guide.title}</h2><p>{guide.text}</p></div></aside>
      {options?.error && <p role="alert">Pilihan pengajuan belum bisa dimuat.</p>}
      {pairDetails?.error && <p role="alert">Rujukan DSS–DCS belum bisa dimuat.</p>}
      {sampleDetails?.error && <p role="alert">Detail serah terima belum bisa dimuat.</p>}
      {germinationDetails?.error && <p role="alert">Detail Germinasi belum bisa dimuat.</p>}
      {vigourDetails?.error && <p role="alert">Detail Vigor belum bisa dimuat.</p>}
      {vigourOptions?.error && <p role="alert">Pilihan metode Vigor belum bisa dimuat; tidak memakai metode tebakan.</p>}
      {options?.data && <SubmitRequestForm options={options.data as RequestOptions} vigourOptions={vigourOptions?.data as VigourOptions | null} />}
      {hostedPilot && variant.code === 'LAB' && (isAnalyst || isReviewer) && <aside className={queueStyles.roleGuide}><div><h2>Pengujian rutin tanpa request Plant</h2><p>Catat pekerjaan rutin sebagai draft terpisah, periksa kelengkapannya, lalu kirim ke QA. Hasil disetujui tetap bukan pelepasan lot.</p><Link className="btn" href="/lab-routine">Buka catatan uji rutin</Link></div></aside>}
      <QueueWorkspace error={!!error} items={requests.map(request => {
                const pair = lotPairs.get(request.request_id);
                return { id: request.request_id, group: queueGroup(request.status), search: `${request.lot_code ?? ''} ${request.request_code} ${pair?.dss_lot_code ?? ''} ${pair?.dcs_lot_code ?? ''} ${request.test_codes.map(testLabel).join(' ')}`,
                  content: <article className={queueStyles.requestCard} aria-label={`Lot ${request.lot_code ?? 'belum tersedia'}`}>
                    <div className={queueStyles.cardHeading}><div><p className={queueStyles.eyebrow}>LOT DIUJI</p><h3>{request.lot_code ?? 'Belum tersedia'}</h3>
                      <p>{[...new Set(request.test_codes)].map(testLabel).join(' · ') || '—'}{pair && ` · ${pair.tested_stage_code}`}</p></div>
                      <span title={request.status} className={queueStyles.statusBadge} data-status={queueGroup(request.status)}>{statusLabel(request.status)}</span></div>
                    <div className={queueStyles.nextStep}><strong>Langkah berikutnya</strong><p>{nextStep(request.status, variant.code, isReviewer)}</p></div>
                    {germinationRuns.get(request.request_id)?.status === 'APPROVED' && germinationRuns.get(request.request_id)?.summary && <p className={queueStyles.resultPreview}>Germinasi <strong>{germinationRuns.get(request.request_id)!.summary!.germination_percent}%</strong><span>Hasil analisis disetujui QA</span></p>}
                    <details className={queueStyles.requestDetails}><summary>Detail permintaan & pasangan lot</summary>
                      <p>Nomor permintaan: <span className={queueStyles.requestCode}>{request.request_code}</span></p><p>Status sistem: {request.status}</p>
                      {pair && <>
                        <div className={queueStyles.reference}>
                          <small>Rujukan pasangan DSS–DCS</small>
                          <div>{`DSS: ${pair.dss_lot_code}`}</div>
                          <div>{`DCS: ${pair.dcs_lot_code}`}</div>
                        </div>
                      </>}
                    <p>Diajukan: {request.requested_at ? new Intl.DateTimeFormat('id-ID', {
                      dateStyle: 'medium', timeStyle: 'short', timeZone: 'Asia/Jakarta',
                    }).format(new Date(request.requested_at)) : '—'} WIB</p>
                    <p>Instruksi: {request.sampling_instruction || 'Tidak ada instruksi tambahan.'}</p></details>
                    {canonicalWritesEnabled && <div className={queueStyles.cardActions}>
                      {canAccept && request.status === 'REQUESTED' &&
                        <AcceptRequestButton requestId={request.request_id} />}
                      {!sampleDetails?.error && <SampleHandoff requestId={request.request_id} status={request.status}
                        module={variant.code} handoff={handoffs.get(request.request_id)} />}
                      {!germinationDetails?.error && request.test_codes.length === 1 &&
                        request.test_codes[0] === 'GERMINATION' && <GerminationPanel requestId={request.request_id}
                          status={request.status} run={germinationRuns.get(request.request_id)}
                          analyst={isAnalyst} reviewer={isReviewer} />}
                      {!vigourDetails?.error && ((vigourDetails?.data ?? []) as VigourRun[])
                        .filter(run => run.request_id === request.request_id)
                        .map(run => <VigourPanel key={`${run.item_id}:${run.run_id ?? 'new'}`} run={run}
                          requestStatus={request.status} analyst={isAnalyst} reviewer={isReviewer} />)}
                    </div>}
                  </article> };
              })} />
      {hostedPilot && variant.code === 'PLANT' && <ApprovedRoutineResults module="PLANT" />}
      {hostedPilot && <section className={queueStyles.helpSection} aria-label="Referensi dan histori"><h2>Referensi & histori</h2><p>Acuan metode dan arsip Excel tersedia sebagai rujukan, terpisah dari pekerjaan aktif.</p>
        <ProvisionalQualityReference retEnabled={vigourOptions?.data?.ret_enabled === true} vigourEnabled={!vigourOptions?.error && !!vigourOptions?.data} contracts={!qualityContracts?.error ? qualityContracts?.data as ConfirmedLabContracts : null} />
        <HistoricalQualityBrowser key={variant.code} module={variant.code}
          lots={variant.code === 'PLANT' && options?.data ? (options.data as RequestOptions).lots : requests.flatMap(request => request.lot_id && request.lot_code ? [{ id: request.lot_id, lot_code: request.lot_code }] : [])}
          truncated={variant.code === 'PLANT' && !!(options?.data as RequestOptions | null)?.lots_truncated} />
      </section>}
    </div>
  );
}

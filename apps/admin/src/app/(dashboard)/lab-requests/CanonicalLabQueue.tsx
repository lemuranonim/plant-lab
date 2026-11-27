import { redirect } from 'next/navigation';
import Link from 'next/link';
import { canUsePreviewVariant, requireCurrentVariantAccess } from '@/lib/accessContext';
import { getAppVariant } from '@/lib/appVariant';
import { createClient } from '@/lib/supabase/server';
import { isolatedApiSchema, canonicalWritesEnabled } from '@/lib/supabase/config';
import { AcceptRequestButton, SubmitRequestForm, type RequestOptions } from './RequestCommands';
import { SampleHandoff, type Handoff } from './SampleHandoff';
import { GerminationPanel, type GerminationRun } from './GerminationPanel';
import styles from '../shared-lab.module.css';
import queueStyles from './queue.module.css';
import lab from '../lab-surface.module.css';
import { LabHelp } from '../LabUi';
import { ProvisionalQualityReference, type ConfirmedLabContracts } from './ProvisionalQualityReference';
import { hostedPilot } from '@/lib/supabase/config';
import { HistoricalQualityBrowser } from './HistoricalQualityBrowser';
import { VigourPanel, VigourRequestHistory, type VigourRun, type VigourOptions } from './VigourPanel';
import { GerminationRequestHistory, RequestSeedlingDownload } from './RequestSeedlingForms';
import RetRequestFormDownload from './RetRequestFormDownload';
import QueueWorkspace from './QueueWorkspace';
import ApprovedRoutineResults from '../lab-routine/ApprovedRoutineResults';
import { labQueueCue, nextStep, queueGroup, roleGuide, statusLabel, testLabel } from '@/lib/workflowPresentation';

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
  const tabbed = variant.code === 'LAB';
  const isAnalyst = variant.code === 'LAB' && access.roles.some(role => role.role_code === 'LAB_ANALYST');
  const isReviewer = variant.code === 'LAB' && access.roles.some(role => role.role_code === 'LAB_QA_APPROVER');
  const canSeeForms = isAnalyst || isReviewer;
  const guide = roleGuide(variant.code, access.roles.filter(role => role.module_code === variant.code).map(role => role.role_code));

  return (
    <div className={`${styles.container}${variant.code === 'LAB' ? ` ${queueStyles.labQueue}` : ''}`}>
      <header className={`${styles.header}${variant.code === 'LAB' ? ` ${lab.panelHero}` : ''}`}>
        <div>
          <p className={queueStyles.eyebrow}>{variant.code === 'PLANT' ? 'PLANT / KOORDINASI LAB' : 'LAB / PENGUJIAN BENIH'}</p>
          <h1 className={styles.title}>{variant.code === 'PLANT' ? 'Permintaan & hasil Lab' : 'Antrean pengujian Lab'}</h1>
          <p className={styles.subtitle}>Pantau perjalanan sampel, pengujian, dan hasil dalam satu tempat.</p>
        </div>
        {!hostedPilot && variant.code === 'PLANT' && access.roles.some(role => role.role_code === 'PLANT_SPV' && role.module_code === 'PLANT') && (
          <Link className="btn" href="/lot-pair-reviews">Verifikasi Pasangan Lot</Link>
        )}
      </header>
      {variant.code === 'LAB'
        ? <LabHelp label="Bantuan antrean"><p><strong>{guide.title}</strong></p><p>{guide.text}</p></LabHelp>
        : <aside className={queueStyles.roleGuide}><span className={queueStyles.guideIcon} aria-hidden="true">P</span><div><h2>{guide.title}</h2><p>{guide.text}</p></div></aside>}
      {options?.error && <p role="alert">Pilihan pengajuan belum bisa dimuat.</p>}
      {pairDetails?.error && <p role="alert">Rujukan DSS–DCS belum bisa dimuat.</p>}
      {sampleDetails?.error && <p role="alert">Detail serah terima belum bisa dimuat.</p>}
      {germinationDetails?.error && <p role="alert">Detail Germinasi belum bisa dimuat.</p>}
      {vigourDetails?.error && <p role="alert">Detail Vigor belum bisa dimuat.</p>}
      {vigourOptions?.error && <p role="alert">Pilihan metode Vigor belum bisa dimuat; tidak memakai metode tebakan.</p>}
      {options?.data && <SubmitRequestForm options={options.data as RequestOptions} vigourOptions={vigourOptions?.data as VigourOptions | null} />}
      {hostedPilot && variant.code === 'LAB' && (isAnalyst || isReviewer) && <aside className={`${queueStyles.roleGuide} ${queueStyles.routineAction}`}><h2>Uji rutin tanpa request Plant</h2><Link className="btn btn-primary" href="/lab-routine">Buka catatan uji rutin</Link></aside>}
      <QueueWorkspace lab={variant.code === 'LAB'} error={!!error} items={requests.map(request => {
                const pair = lotPairs.get(request.request_id);
                const germination = germinationRuns.get(request.request_id);
                const hasGerminationMethod = !germinationDetails?.error && request.test_codes.length === 1 &&
                  request.test_codes[0] === 'GERMINATION';
                const vigour = vigourDetails?.error ? [] :
                  ((vigourDetails?.data ?? []) as VigourRun[]).filter(run => run.request_id === request.request_id);
                const panels = <>
                  {hasGerminationMethod && <GerminationPanel requestId={request.request_id} status={request.status}
                    run={germination} analyst={isAnalyst} reviewer={isReviewer} inObservationTab={tabbed} />}
                  {vigour.map(run => <VigourPanel key={`${run.item_id}:${run.run_id ?? 'new'}`} run={run}
                    requestStatus={request.status} analyst={isAnalyst} reviewer={isReviewer} inObservationTab={tabbed} />)}
                </>;
                const germinationForm = hasGerminationMethod && canSeeForms ? germination : undefined;
                const vigourForms = canSeeForms ? vigour.flatMap(run =>
                  run.run_code && run.status ? [{ code: run.run_code, status: run.status, ret: run.method_code === 'RET_16C_72H', itemId: run.item_id }] : [],
                ) : [];
                const vigourHistory = vigour.filter(run => run.prior_attempts.length > 0);
                const methodsUnavailable = !!(germinationDetails?.error || vigourDetails?.error);
                const sections = tabbed ? {
                  observations: <section className={queueStyles.detailSection}>
                    <h3>Ulangan & pemeriksaan QA</h3>
                    <p>Pengamatan dan pemeriksaan mengikuti status percobaan serta penugasan akun. Persetujuan analisis bukan pelepasan lot.</p>
                    {!canonicalWritesEnabled
                      ? <p>Rincian pengujian tidak ditampilkan dalam mode hanya-baca ini.</p>
                      : <>
                        {methodsUnavailable && <p role="alert">Sebagian rincian metode belum dapat dimuat. Jangan anggap hasilnya kosong.</p>}
                        {!methodsUnavailable && !vigour.length && !(hasGerminationMethod && (germination || (isAnalyst && request.status === 'RECEIVED'))) &&
                          <p>Belum ada rincian pengujian yang dapat dibuka untuk status dan akses ini.</p>}
                        <div className={queueStyles.cardActions}>{panels}</div>
                      </>}
                  </section>,
                  downloads: <section className={queueStyles.detailSection}>
                    <h3>Unduh hasil per percobaan</h3>
                    <p>Form percobaan lama ada di Riwayat.</p>
                    {canonicalWritesEnabled && methodsUnavailable && <p role="alert">Sebagian rincian belum dimuat. Daftar unduhan mungkin belum lengkap.</p>}
                    {canonicalWritesEnabled && germinationForm && <RequestSeedlingDownload key={germinationForm.run_code} runCode={germinationForm.run_code} status={germinationForm.status} kind="Germinasi" />}
                    {canonicalWritesEnabled && vigourForms.map(run => run.ret
                      ? <RetRequestFormDownload key={`${run.itemId}:${run.code}`} runCode={run.code} status={run.status} />
                      : <RequestSeedlingDownload key={`${run.itemId}:${run.code}`} runCode={run.code} status={run.status} kind="Vigor" />)}
                    {(!canonicalWritesEnabled || (!methodsUnavailable && !germinationForm && !vigourForms.length)) &&
                      <p>Belum ada form percobaan yang bisa diunduh untuk status dan akses ini.</p>}
                  </section>,
                  history: <section className={queueStyles.detailSection}>
                    <h3>Riwayat percobaan permintaan ini</h3>
                    <p>Riwayat pengujian di aplikasi, bukan arsip Histori Excel. Percobaan lama tidak menimpa hasil saat ini.</p>
                    {canonicalWritesEnabled && methodsUnavailable && <p role="alert">Sebagian rincian belum dimuat. Riwayat mungkin belum lengkap.</p>}
                    {canonicalWritesEnabled && germinationForm && <GerminationRequestHistory key={germinationForm.run_code} requestId={request.request_id} runCode={germinationForm.run_code} />}
                    {canonicalWritesEnabled && vigourHistory.map(run => <section key={run.item_id}>
                      <h4>{run.method_name}</h4>
                      <VigourRequestHistory run={run} showForms={canSeeForms} />
                    </section>)}
                    {(!canonicalWritesEnabled || (!methodsUnavailable && !germinationForm && !vigourHistory.length)) &&
                      <p>Belum ada riwayat percobaan yang bisa ditampilkan untuk status dan akses ini.</p>}
                  </section>,
                } : undefined;
                const methods = [...new Set(vigour.map(run => run.method_name).filter(Boolean))];
                const cue = tabbed ? labQueueCue(request.status, canonicalWritesEnabled, isAnalyst, isReviewer) : undefined;
                return { id: request.request_id, group: queueGroup(request.status), search: `${request.lot_code ?? ''} ${request.request_code} ${pair?.dss_lot_code ?? ''} ${pair?.dcs_lot_code ?? ''} ${request.test_codes.map(testLabel).join(' ')}`,
                  lot: request.lot_code ?? 'Belum tersedia', code: request.request_code, status: statusLabel(request.status), rawStatus: request.status,
                  tests: [...new Set(request.test_codes)].map(code => tabbed && code === 'VIGOUR' && methods.length ? methods.join(' · ') : testLabel(code)).join(' · ') || '—',
                  cue,
                  sections,
                  content: <article className={queueStyles.requestCard} aria-label={`Lot ${request.lot_code ?? 'belum tersedia'}`}>
                    {!tabbed && <div className={queueStyles.cardHeading}><div><p className={queueStyles.eyebrow}>LOT DIUJI</p><h3>{request.lot_code ?? 'Belum tersedia'}</h3>
                      <p>{[...new Set(request.test_codes)].map(testLabel).join(' · ') || '—'}{pair && ` · ${pair.tested_stage_code}`}</p></div>
                      <span title={request.status} className={queueStyles.statusBadge} data-status={queueGroup(request.status)} data-raw-status={request.status}>{statusLabel(request.status)}</span></div>}
                    {!cue?.section && <div className={queueStyles.nextStep}><strong>Langkah berikutnya</strong><p>{nextStep(request.status, variant.code, isReviewer)}</p></div>}
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
                      {!tabbed && panels}
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

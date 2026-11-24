import Link from 'next/link';
import { notFound, redirect } from 'next/navigation';
import { requireCurrentVariantAccess } from '@/lib/accessContext';
import { getAppVariant } from '@/lib/appVariant';
import { isolatedApiSchema, isolatedPlantLab, canonicalWritesEnabled } from '@/lib/supabase/config';
import { createClient } from '@/lib/supabase/server';
import { ReviewForm } from './review-form';
import styles from './review.module.css';

type ReviewCase = {
  case_id: string;
  anchor_stage: 'DSS' | 'DCS';
  anchor_code: string;
  site_name: string;
  status: 'PENDING' | 'HELD' | 'CORRECTION_REQUESTED' | 'APPROVED' | 'KEPT_OFFICIAL';
  revision: number;
  official_pair: { dss_code: string | null; dcs_code: string | null } | null;
  candidates: { id: string; dss_code: string; dcs_code: string; hybrid: string; file: string; sheet: string; row: number; has_formula: boolean }[];
  last_decision: { reason: string; evidence: string; decided_at: string } | null;
};

const statuses: Record<ReviewCase['status'], string> = {
  PENDING: 'Menunggu verifikasi Plant', HELD: 'Ditahan', CORRECTION_REQUESTED: 'Menunggu koreksi sumber',
  APPROVED: 'Pasangan ditetapkan', KEPT_OFFICIAL: 'Pasangan resmi dipertahankan',
};

export const revalidate = 0;

export default async function LotPairReviewsPage({ searchParams }: { searchParams: Promise<{ page?: string }> }) {
  if (!isolatedPlantLab) notFound();
  if (getAppVariant().code !== 'PLANT') redirect('/access-denied');
  const access = await requireCurrentVariantAccess();
  if (!access.roles.some(role => role.role_code === 'PLANT_SPV' && role.module_code === 'PLANT')) redirect('/access-denied');
  const rawPage = Number((await searchParams).page ?? 1);
  const page = Number.isSafeInteger(rawPage) && rawPage > 0 && rawPage <= 10000 ? rawPage : 1;
  const supabase = await createClient();
  const { data, error } = await supabase.schema(isolatedApiSchema).rpc('list_lot_pair_reviews', { p_offset: (page - 1) * 20 });
  const cases = (data ?? []) as ReviewCase[];

  return (
    <main className={styles.page}>
      <Link className={styles.back} href="/lab-requests">Kembali ke Antrean Permintaan Lab</Link>
      <header className={styles.heading}>
        <h1>Verifikasi Pasangan Lot</h1>
        <p>Periksa bukti sebelum menetapkan pasangan. Keputusan ini tidak mengubah hasil Lab atau status QA.</p>
        {!canonicalWritesEnabled && <p>Preview read-only: keputusan belum bisa disimpan.</p>}
      </header>
      {error && <p className={styles.case} role="alert">Antrean verifikasi belum bisa dimuat. Muat ulang halaman.</p>}
      {!error && !cases.length && <p className={styles.case}>Tidak ada kasus di halaman ini dalam cakupan Anda.</p>}
      {cases.slice(0, 20).map(item => (
        <section className={styles.case} key={item.case_id} aria-labelledby={`case-${item.case_id}`}>
          <div className={styles.caseHeader}>
            <div>
              <p className={styles.label}>Lot {item.anchor_stage} · {item.site_name}</p>
              <h2 id={`case-${item.case_id}`}>{item.anchor_code}</h2>
            </div>
            <span className={styles.status} data-state={item.status}>{statuses[item.status]}</span>
          </div>
          {item.official_pair && <p className={styles.callout}><strong>Pasangan resmi:</strong>{' '}
            {item.official_pair.dss_code && item.official_pair.dcs_code
              ? `${item.official_pair.dss_code} → ${item.official_pair.dcs_code}` : 'Tercatat, kode di luar cakupan.'}
          </p>}
          <div className={styles.heading}>
            <h3>Kandidat dan bukti sumber</h3>
            <ul className={styles.candidates}>
              {item.candidates.map(candidate => <li className={styles.candidate} key={candidate.id}>
                <dl className={styles.candidateCodes}>
                  <div><dt>DSS</dt><dd>{candidate.dss_code}</dd></div>
                  <div><dt>DCS</dt><dd>{candidate.dcs_code}</dd></div>
                </dl>
                <p className={styles.candidateSource}>
                  {candidate.hybrid} · {candidate.file} / {candidate.sheet}, baris {candidate.row}{candidate.has_formula ? ' · ada rumus di sumber' : ''}
                </p>
              </li>)}
            </ul>
          </div>
          {item.last_decision && <div className={styles.callout}>
            <strong>Catatan terakhir:</strong> {item.last_decision.reason}
            <small>Bukti: {item.last_decision.evidence}</small>
          </div>}
          {canonicalWritesEnabled && item.status !== 'APPROVED' && item.status !== 'KEPT_OFFICIAL' && (
            <ReviewForm key={`${item.case_id}:${item.revision}`} caseId={item.case_id} revision={item.revision}
              hasOfficial={item.official_pair !== null} canKeepOfficial={Boolean(item.official_pair?.dss_code && item.official_pair.dcs_code)}
              candidates={item.candidates.map(candidate => ({
                id: candidate.id, label: `${candidate.dss_code} → ${candidate.dcs_code} (${candidate.sheet}:${candidate.row})`,
              }))} />
          )}
        </section>
      ))}
      {(page > 1 || cases.length > 20) && <nav aria-label="Halaman verifikasi" className={styles.pagination}>
        {page > 1 && <Link href={`/lot-pair-reviews?page=${page - 1}`}>Sebelumnya</Link>}
        {cases.length > 20 && <Link href={`/lot-pair-reviews?page=${page + 1}`}>Berikutnya</Link>}
      </nav>}
    </main>
  );
}

import type { ReactNode } from 'react';
import { countFields, countLabels, observationLabel, wibInput, type RoutineContent, type RoutineSummary } from '@/lib/routineLabDraft';
import styles from './routine-review.module.css';

function Facts({ entries }: { entries: [string, ReactNode][] }) {
  return <dl className={styles.facts}>{entries.map(([label, value]) =>
    <div key={label}><dt>{label}</dt><dd>{value ?? 'Belum dicatat'}</dd></div>
  )}</dl>;
}

export function toleranceLabel(within: boolean | null | undefined) {
  return within === true ? 'Dalam toleransi' : within === false ? 'Di luar toleransi' : 'Batas toleransi belum tersedia';
}

export function RoutineReviewSummary({ summary }: { summary: RoutineSummary }) {
  const value = summary.germination_percent ?? summary.vigour_percent;
  const reference = summary.uac_quality_reference?.minimum_percent;
  return <section className={styles.panel} aria-label="Ringkasan hasil QA">
    <div className={styles.heading}>
      <h4>Ringkasan hasil</h4>
      <span className={styles.tag} data-within={summary.within_tolerance === true}>{toleranceLabel(summary.within_tolerance)}</span>
    </div>
    <Facts entries={[
      ['Hasil analisis', value == null ? null : `${value}%`],
      ['Selisih ulangan', summary.gap_pp == null ? null : `${summary.gap_pp} poin persentase`],
      ['Batas toleransi', summary.limit_pp == null ? 'Belum tersedia' : `${summary.limit_pp} poin persentase`],
    ]} />
    <p className={styles.subtle}>{summary.replicates.length} × 100 benih
      {typeof reference === 'number' ? ` · Acuan minimum ${reference}%` : ' · Acuan mutu belum lengkap'}
      {typeof reference === 'number' && typeof value === 'number' ? value < reference ? ' · Di bawah acuan' : ' · Memenuhi angka acuan' : null}
      {summary.elapsed_hours != null ? ` · RET: ${summary.elapsed_hours} jam sejak penempatan pada 16 °C` : null}
    </p>
    <div className={styles.replicates}>{summary.replicates.map((replicate, index) =>
      <section className={styles.replicate} key={index} aria-label={`Ringkasan ulangan ${index + 1}`}>
        <h5>Ulangan {index + 1}</h5>
        <Facts entries={'radicle_at_least_2mm' in replicate
          ? [['Radikula ≥2 mm', replicate.radicle_at_least_2mm == null ? null : `${replicate.radicle_at_least_2mm}/100`]]
          : [['Normal', replicate.normal], ['Abnormal', replicate.abnormal], ['Fresh', replicate.fresh], ['Hard', replicate.hard], ['Mati', replicate.dead]]} />
      </section>
    )}</div>
    <details><summary>Rujukan hitungan</summary>
      {summary.unrounded_percent != null && <p>Sebelum pembulatan: {summary.unrounded_percent}%</p>}
      <p>{summary.calculation_code} · versi {summary.calculation_version}. Final kumulatif, tidak ditambah first count.</p>
    </details>
  </section>;
}

export function RoutineReviewEvidence({ content, ret }: { content: RoutineContent; ret: boolean }) {
  function date(value: string | null) {
    const time = wibInput(value);
    return time ? `${time.replace('T', ' ')} WIB` : 'Belum dicatat';
  }
  return <section className={styles.panel} aria-label="Bukti sampel dan waktu">
    <h4>Bukti sampel &amp; waktu</h4>
    <Facts entries={[
      ['Label sampel', content.sample_reference || null],
      ['Sampel tersedia', date(content.received_at)],
      [ret ? 'Mulai ditempatkan pada 16 °C' : 'Mulai uji / perlakuan', date(content.started_at)],
      ['Pengamatan final', date(content.final_at)],
    ]} />
    <details><summary>Catatan dan hitungan tercatat</summary>
      {content.note && <p>Catatan kondisi: {content.note}</p>}
      <div className={styles.replicates}>{content.observations.map((row, index) =>
        <section className={styles.replicate} key={index}>
          <h5>{observationLabel(index, ret)}</h5>
          <Facts entries={(ret ? ['radicle_at_least_2mm'] : countFields).map(key => [countLabels[key], row[key]])} />
        </section>
      )}</div>
    </details>
  </section>;
}

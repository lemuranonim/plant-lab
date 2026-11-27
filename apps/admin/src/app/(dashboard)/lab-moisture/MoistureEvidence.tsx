import { moistureNumber, type MoistureContent } from '@/lib/labMoisture';
import { wibInput } from '@/lib/routineLabDraft';
import styles from './moisture.module.css';

export function MoistureMean({ value, entered, preview = false }: { value: number | null; entered?: number; preview?: boolean }) {
  return <div className={styles.mean} aria-live={preview ? 'polite' : undefined}>
    <span>{preview ? 'Pratinjau rata-rata' : 'Rata-rata 3 pembacaan'}{entered !== undefined ? ` · ${entered}/3 terisi` : ''}</span>
    <strong>{value == null ? 'Belum lengkap' : `${moistureNumber(value)}%`}</strong>
  </div>;
}

export function MoistureReadingFacts({ values }: { values: MoistureContent['readings'] }) {
  return <dl className={styles.facts} aria-label="Tiga pembacaan tersimpan">
    {values.map((value, i) => <div key={i}>
      <dt>MC {i + 1}</dt><dd>{value == null ? 'Belum dicatat' : `${moistureNumber(value)}%`}</dd>
    </div>)}
  </dl>;
}

export function MoistureSampleFacts({ content, compact = false }: { content: MoistureContent; compact?: boolean }) {
  const date = (timestamp: string | null) => timestamp ? `${wibInput(timestamp).replace('T',' ')} WIB` : null;
  return <dl className={styles.evidence} aria-label="Identitas dan waktu pengukuran">
    {[
      ['Label sampel', content.sample_reference],
      ['Jenis sampel', content.sample_type],
      ['Pelaksana', content.analyst_name],
      ['Alat', content.instrument],
      ['Metode', content.method],
      ['Waktu ukur', date(content.measured_at)],
      ...(!compact ? [['Sampel tersedia', date(content.received_at)], ['Catatan', content.note]] : []),
    ].map(([label, value]) => <div key={label}><dt>{label}</dt><dd>{value || 'Belum dicatat'}</dd></div>)}
  </dl>;
}

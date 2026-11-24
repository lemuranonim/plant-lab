'use client';
import { fromWibInput, wibInput, type RoutineFormDetails } from '@/lib/routineLabDraft';
import styles from './routine.module.css';

export default function RoutineFormDetailsFields({ value, onChange, germination, retest }: {
  value: RoutineFormDetails; onChange: (value: RoutineFormDetails) => void; germination: boolean; retest: boolean;
}) {
  const set = (key: keyof RoutineFormDetails, text: string | null) => onChange({...value,[key]:text});
  return <details className={styles.workflow}>
    <summary>Rincian form {germination ? 'Germinasi' : 'Vigor'}</summary>
    <p>Isi sesuai pekerjaan nyata. Tanggal tanam berbeda dari mulai perlakuan Vigor. DAP dihitung dari selisih tanggal tanam dan pengamatan dalam WIB.</p>
    <label>Tanaman / spesies pada form<input maxLength={120} value={value.crop_species ?? ''} onChange={e=>set('crop_species',e.target.value || null)}/></label>
    <label>Nama pelaksana / Seed Analyst<input maxLength={120} value={value.analyst_name ?? ''} onChange={e=>set('analyst_name',e.target.value || null)}/></label>
    {germination ? <p>Media dan suhu metode aktif: Pasir 25 °C. Paper BP/TP dan suhu lain belum diaktifkan sebagai metode pengujian.</p>
      : <label>Suhu yang dicatat pada form (°C)<input maxLength={120} placeholder="Sesuai kondisi pengujian, bukan perkiraan" value={value.temperature_text ?? ''} onChange={e=>set('temperature_text',e.target.value || null)}/></label>}
    <label>Tanggal dan jam tanam aktual (WIB)<input type="datetime-local" value={wibInput(value.planted_at)} onChange={e=>set('planted_at',fromWibInput(e.target.value))}/></label>
    <label>Pengamatan first count aktual (WIB)<input type="datetime-local" value={wibInput(value.first_count_at)} onChange={e=>set('first_count_at',fromWibInput(e.target.value))}/></label>
    <p>Jenis uji: {retest ? 'Retest Verification dari keputusan QA' : 'Initial'}. Revalidation 1–3 belum diaktifkan; jangan mengganti label untuk melewati alur QA.</p>
  </details>;
}

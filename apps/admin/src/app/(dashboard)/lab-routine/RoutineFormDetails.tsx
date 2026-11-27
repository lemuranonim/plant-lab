'use client';
import { fromWibInput, wibInput, type RoutineFormDetails } from '@/lib/routineLabDraft';
import styles from './routine.module.css';

export default function RoutineFormDetailsFields({ value, onChange, germination }: {
  value: RoutineFormDetails; onChange: (value: RoutineFormDetails) => void; germination: boolean;
}) {
  const set = (key: keyof RoutineFormDetails, text: string | null) => onChange({...value,[key]:text});
  return <details className={styles.workflow}>
    <summary>Rincian form {germination ? 'Germinasi' : 'Vigor'}</summary>
    <label>Tanaman / spesies pada form<input maxLength={120} value={value.crop_species ?? ''} onChange={e=>set('crop_species',e.target.value || null)}/></label>
    <label>Nama pelaksana / Seed Analyst<input maxLength={120} value={value.analyst_name ?? ''} onChange={e=>set('analyst_name',e.target.value || null)}/></label>
    {germination ? <p>Metode: Pasir 25 °C.</p>
      : <label>Suhu yang dicatat pada form (°C)<input maxLength={120} placeholder="Sesuai kondisi pengujian, bukan perkiraan" value={value.temperature_text ?? ''} onChange={e=>set('temperature_text',e.target.value || null)}/></label>}
    <label>Tanggal dan jam tanam aktual (WIB)<input type="datetime-local" value={wibInput(value.planted_at)} onChange={e=>set('planted_at',fromWibInput(e.target.value))}/></label>
    <label>Pengamatan first count aktual (WIB)<input type="datetime-local" value={wibInput(value.first_count_at)} onChange={e=>set('first_count_at',fromWibInput(e.target.value))}/></label>
  </details>;
}

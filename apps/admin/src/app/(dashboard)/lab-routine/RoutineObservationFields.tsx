import { countFields, countLabels, observationLabel, type RoutineContent } from '@/lib/routineLabDraft';
import styles from './routine.module.css';

export default function RoutineObservationFields({ content, ret, disabled, onChange }: {
  content: RoutineContent;
  ret: boolean;
  disabled: boolean;
  onChange: (patch: Partial<RoutineContent>) => void;
}) {
  const finalKeys = countFields.filter(key => key !== 'first_normal');
  return <div className={styles.observations}>{content.observations.map((row, index) => {
    const input = (key: string) => <label key={key}>{countLabels[key]}
      <input type="number" inputMode="numeric" min={0} max={ret ? 100 : 50} step={1}
        value={row[key] ?? ''} onChange={event => {
          const value = event.target.value;
          onChange({ observations: content.observations.map((observation, i) => i === index
            ? { ...observation, [key]: value === '' ? null : Number(value) } : observation) });
        }} />
    </label>;
    const entered = finalKeys.map(key => row[key]).filter((n): n is number => n !== null && n !== undefined);
    const total = entered.reduce((sum, n) => sum + n, 0);
    const radicles = row.radicle_at_least_2mm;
    return <fieldset key={index} disabled={disabled}>
      <legend>{observationLabel(index, ret)}</legend>
      {ret ? input('radicle_at_least_2mm') : <>
        <div className={styles.firstCount}>{input('first_normal')}</div>
        <p className={styles.finalLabel}>Pengamatan final</p>
        {finalKeys.map(input)}
      </>}
      <p className={styles.countTotal} data-overflow={!ret && total > 50}>
        {ret
          ? radicles == null ? 'Radikula: belum dicatat' : `Radikula: ${radicles}/100 benih`
          : !entered.length ? 'Final: belum dicatat'
          : `Final: ${total}/50 benih · ${entered.length}/5 kategori terisi`}
        {!ret && total > 50 && <span>Jumlah melebihi 50 benih.</span>}
      </p>
      {content.form && (['abnormal_kind', 'remarks'] as const).map(key => <label key={key}>
        {key === 'abnormal_kind' ? 'Jenis abnormal' : 'Catatan subulangan'}
        <textarea rows={1} maxLength={300} value={content.form!.annotations[index]?.[key] ?? ''} onChange={event => {
          const value = event.target.value;
          const details = content.form!;
          onChange({ form: { ...details, annotations: details.annotations.map((item, i) => i === index
            ? { ...item, [key]: value || null } : item) } });
        }} />
      </label>)}
    </fieldset>;
  })}</div>;
}

import { logbookNumber, logbookWib } from '@/lib/labLogbook';
import { labSampleStatusLabels, type SampleRequestRow } from '@/lib/plantSampleRequests';
import shared from '../lab-logbook/logbook.module.css';
import styles from './sample-requests.module.css';

export function SampleLabelFacts({ row }: { row: SampleRequestRow }) {
  return <dl className={styles.facts} aria-label="Label dan berat sampel">
    <div><dt>{row.status === 'RECEIVED' ? 'Label yang dicocokkan' : 'Label kiriman Plant'}</dt><dd>{row.sample_label || 'Belum dicatat'}</dd></div>
    <div><dt>{row.status === 'RECEIVED' ? 'Berat diterima Lab' : 'Berat kiriman Plant'}</dt>
      <dd>{(row.status === 'RECEIVED' ? row.received_grams : row.sent_grams) == null ? 'Belum dicatat'
        : `${logbookNumber((row.status === 'RECEIVED' ? row.received_grams : row.sent_grams)!)} g`}</dd></div>
  </dl>;
}

export default function LabSampleCard({ row, disabled, onReceive, onCancel }: {
  row: SampleRequestRow;
  disabled: boolean;
  onReceive?: () => void;
  onCancel?: () => void;
}) {
  const status = labSampleStatusLabels[row.status] ?? row.status;
  return <article className={shared.entry} data-testid="lab-sample-card">
    <header className={shared.entryHeader}>
      <div><h3>{row.lot_code}</h3><p>{row.hybrid}</p></div>
      <span className={shared.status} data-status={row.status === 'RECEIVED' ? 'VERIFIED_RECORD' : row.status}>{status}</span>
    </header>
    <p>{row.plant_site} → {row.lab_site}</p>
    {row.status === 'REQUESTED' && <p>Plant belum mencatat pengiriman.</p>}
    {(row.status === 'SENT' || row.status === 'RECEIVED') && <SampleLabelFacts row={row} />}
    <details className={shared.entryDetail}>
      <summary>Rincian serah terima</summary>
      <dl>
        <div><dt>Keperluan</dt><dd>{row.purpose}</dd></div>
        <div><dt>Diminta</dt><dd>{logbookWib(row.requested_at)}</dd></div>
        {row.sent_at && <div><dt>Dikirim Plant</dt><dd>{logbookWib(row.sent_at)}</dd></div>}
        {row.sent_note && <div><dt>Kondisi saat dikirim</dt><dd>{row.sent_note}</dd></div>}
        {row.received_at && <div><dt>Diterima Lab</dt><dd>{logbookWib(row.received_at)}</dd></div>}
        {row.received_note && <div><dt>Kondisi saat diterima</dt><dd>{row.received_note}</dd></div>}
        {row.status === 'RECEIVED' && row.sent_grams != null && <div><dt>Berat awal dari Plant</dt><dd>{logbookNumber(row.sent_grams)} g</dd></div>}
        {row.closure_note && <div><dt>Alasan</dt><dd>{row.closure_note}</dd></div>}
      </dl>
    </details>
    {onReceive && <button type="button" className="btn btn-primary" disabled={disabled} onClick={onReceive}>Konfirmasi sampel diterima</button>}
    {onCancel && <button type="button" className="btn" disabled={disabled} onClick={onCancel}>Batalkan permintaan</button>}
  </article>;
}

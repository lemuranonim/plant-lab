import Link from 'next/link';
import { hoursLabel, monitorFocus, workGroups, type MonitorEntry } from '@/lib/labMonitoring';
import { logbookOrigins, logbookStatuses, logbookWib } from '@/lib/labLogbook';
import shared from '../lab-logbook/logbook.module.css';
import styles from './monitoring.module.css';

export default function MonitoringEntryCard({ entry }: { entry: MonitorEntry }) {
  const focus = monitorFocus(entry);
  const status = workGroups[entry.work_group] ?? entry.work_group;
  const rawStatus = logbookStatuses[entry.status] ?? entry.status;
  const ref = [entry.run_code ?? entry.request_code, entry.attempt_no == null ? null : `Percobaan ${entry.attempt_no}`].filter(Boolean).join(' · ');
  const timing = [
    ['Sampel diterima / tersedia', entry.received_at],
    ['Kirim ke QA', entry.submitted_at],
    ['Keputusan QA', entry.decision_at],
  ] as const;
  return <article className={shared.entry} data-testid="monitor-entry">
    <header className={shared.entryHeader}>
      <div><h3>{entry.lot_code}</h3><p>{entry.hybrid} · {entry.method_name}</p></div>
      <span className={shared.status} data-status={entry.status}>{status}</span>
    </header>
    <p className={shared.entryRef}>{[logbookOrigins[entry.entry_kind] ?? entry.entry_kind, ref].filter(Boolean).join(' · ')}</p>
    {focus && <div className={styles.focus} data-warning={focus.warning === true}>
      <p><strong>{focus.label}</strong>{focus.hours !== undefined && <b>{hoursLabel(focus.hours)}</b>}</p>
      {focus.since && <small>Sejak {logbookWib(focus.since)}</small>}
    </div>}
    <details className={shared.entryDetail}>
      <summary>Rincian waktu &amp; catatan</summary>
      <ol className={styles.timeline} aria-label="Waktu yang tercatat">
        {timing.map(([label, value]) => <li key={label} data-known={!!value}>
          <span>{label}</span><strong>{logbookWib(value)}</strong>
        </li>)}
      </ol>
      <dl>
        <div><dt>Status catatan asal</dt><dd>{rawStatus}</dd></div>
        <div><dt>Label sampel</dt><dd>{entry.sample_reference || 'Belum dicatat'}</dd></div>
        <div><dt>Nomor permintaan</dt><dd>{entry.request_code || 'Tidak ada'}</dd></div>
        <div><dt>Nomor uji</dt><dd>{entry.run_code || 'Belum ada'}</dd></div>
        {entry.sample_to_submit_hours !== null && <div><dt>Sampel diterima sampai kirim hasil</dt><dd>{hoursLabel(entry.sample_to_submit_hours)}</dd></div>}
        {entry.qa_tat_hours !== null && <div><dt>Kirim hasil sampai keputusan QA</dt><dd>{hoursLabel(entry.qa_tat_hours)}</dd></div>}
      </dl>
      {entry.receipt_basis === 'RECEIPT_EVENT_TIME' && <p>Waktu penerimaan mengikuti catatan serah terima aplikasi, bukan tanggal tanam atau pengamatan.</p>}
      {entry.clock_issue && <p>Periksa urutan tanggal di catatan asal. Waktu tunggu tidak diberi angka perkiraan.</p>}
      <Link className="btn" href={entry.entry_kind === 'MC_DRAFT' ? '/lab-moisture' : entry.entry_kind === 'ROUTINE' ? '/lab-routine' : '/lab-requests'}>Buka menu pekerjaan asal</Link>
    </details>
  </article>;
}

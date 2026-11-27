'use client';

import Link from 'next/link';
import { useState } from 'react';
import { logbookFormTarget, logbookNumber, logbookOrigins, logbookStatuses, logbookWib, type LogbookEntry } from '@/lib/labLogbook';
import styles from './logbook.module.css';

export default function LogbookEntryCard({ entry, blocked }: { entry: LogbookEntry; blocked: boolean }) {
  const target = logbookFormTarget(entry);
  const [formatBusy, setFormatBusy] = useState<'pdf' | 'xlsx' | null>(null);
  const [error, setError] = useState('');
  const mc = ['DRAFT_MEAN', 'MC_RECORD_MEAN'].includes(entry.result_state);
  const status = logbookStatuses[entry.status] ?? entry.status;
  const origin = logbookOrigins[entry.entry_kind] ?? entry.entry_kind;
  const code = entry.run_code ?? entry.request_code;
  async function download(format: 'pdf' | 'xlsx') {
    if (!target || blocked || formatBusy) return;
    setFormatBusy(format);
    setError('');
    try {
      const { module, id, revision, name } = target;
      const response = await fetch(`/api/${module}/${id}/export?format=${format}&revision=${revision}`, { cache: 'no-store', redirect: 'error' });
      if (!response.ok) {
        const data = await response.json().catch(() => null);
        throw Error(response.status === 409
          ? 'Revisi berubah. Muat ulang hasil sebelum mengunduh.'
          : (typeof data?.message === 'string' ? data.message : 'Form belum bisa diunduh. Coba lagi.'));
      }
      const mime = format === 'pdf' ? 'application/pdf' : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      const file = await response.blob();
      const prefix = new Uint8Array(await file.slice(0, 5).arrayBuffer());
      if (file.size < 5 || file.size > 5 * 1024 * 1024 || response.headers.get('content-type')?.split(';')[0] !== mime
        || (format === 'pdf' ? String.fromCharCode(...prefix) !== '%PDF-' : prefix[0] !== 0x50 || prefix[1] !== 0x4b)) {
        throw Error('File unduhan tidak sesuai. Muat ulang lalu coba lagi.');
      }
      const url = URL.createObjectURL(file);
      const anchor = document.createElement('a');
      anchor.href = url;
      anchor.download = `Form-${name}-${id}-r${revision}.${format}`;
      anchor.click();
      setTimeout(() => URL.revokeObjectURL(url), 1000);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Unduhan belum berhasil.');
    } finally {
      setFormatBusy(null);
    }
  }
  return <article className={styles.entry} data-testid="logbook-entry">
    <header className={styles.entryHeader}>
      <div><h3>{entry.lot_code}</h3><p>{entry.hybrid} · {entry.stage_code}</p></div>
      <span className={styles.status} data-status={entry.status}>{status}</span>
    </header>
    <p>{entry.method_name === origin ? origin : `${entry.method_name} · ${origin}`}</p>
    <p className={styles.entryRef}>{[code, entry.attempt_no == null ? null : `Percobaan ke-${entry.attempt_no}`,
      entry.revision == null ? null : `Revisi ${entry.revision}`].filter(Boolean).join(' · ') || 'Belum ada nomor uji'}</p>
    <div className={styles.result}>
      <span>{mc ? 'Rata-rata 3 pembacaan MC' : 'Hasil analisis'}</span>
      <strong>{entry.result_percent == null ? 'Belum tersedia' : `${logbookNumber(entry.result_percent)}%`}</strong>
    </div>
    <details className={styles.entryDetail}>
      <summary>Rincian catatan{target ? ' & unduhan' : ''}</summary>
      <dl>
        {[
          ['Label sampel', entry.sample_reference || 'Belum dicatat'],
          ['Nomor permintaan', entry.request_code || 'Tidak ada'],
          ['Nomor uji', entry.run_code || 'Belum ada'],
          ['Pertama dicatat', logbookWib(entry.recorded_at)],
          ['Pengamatan final / ukur MC', logbookWib(entry.observed_at)],
          ['Pemeriksaan QA terakhir', logbookWib(entry.reviewed_at)],
        ].map(([label, value]) => <div key={label}><dt>{label}</dt><dd>{value}</dd></div>)}
      </dl>
      <p>{entry.result_state === 'QA_APPROVED' ? 'Persetujuan analisis bukan pelepasan lot.'
        : mc ? 'MC dicatat tanpa penilaian lulus/gagal.' : 'Belum menjadi analisis yang disetujui QA.'}</p>
      {target && <div className={styles.formDownloads}>
        <strong>Form pengujian · revisi {target.revision}</strong>
        <div>
          <button type="button" className="btn" disabled={blocked || !!formatBusy} onClick={() => void download('pdf')}>Unduh form PDF</button>
          <button type="button" className="btn" disabled={blocked || !!formatBusy} onClick={() => void download('xlsx')}>Unduh form Excel</button>
        </div>
        {formatBusy && <p role="status">Menyiapkan form revisi {target.revision}…</p>}
        {error && <p role="alert">{error}</p>}
      </div>}
      {entry.entry_kind === 'PLANT_RUN' && <Link href="/lab-requests">Cari form di Antrean pengujian Lab</Link>}
    </details>
  </article>;
}

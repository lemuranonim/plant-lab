'use client';

import { useRef, useState } from 'react';
import { createClient } from '@/lib/supabase/client';
import { isolatedApiSchema } from '@/lib/supabase/config';
import styles from './history.module.css';

type Lot = { id: string; lot_code: string };
type Fact = { coordinate: string; header: string; header_band: string | null; role: string;
  unit: string; number: number | null; date: string | null; source_value: unknown;
  origin: string; warning: string | null };
type Subunit = { source_row: number; label: string | null; normal: number | null;
  abnormal: number | null; dead: number | null; total: number | null };
type Phase = { key: string; label: string; kind: string; source_method_label: string | null;
  source_stage: string | null; source_planted_date: string | null; source_planted_origin: string | null;
  source_observation_date: string | null; source_observation_origin: string | null;
  source_percent: number | null; diagnostic_percent: number | null; source_comparison: string;
  source_conclusion: string | null; review_codes: string[]; subunits: Subunit[]; values: Fact[] };
type SourceRecord = { id: string; source_type: string; source_file_name: string; sheet: string;
  source_row: number; mapping_version: number; source_testing_type: string | null; phases: Phase[] };
type History = { lot_code: string; history_status: string; total_records: number; records: SourceRecord[] };

const pageSize = 3;
const kinds: Record<string, string> = { FIRST_COUNT: 'Pengamatan awal', FINAL_COUNT: 'Pengamatan final',
  CONTEXT: 'Konteks lot', SOURCE_CYCLE: 'Siklus sumber', LATEST_SUMMARY: 'Ringkasan terbaru sumber' };
const warnings: Record<string, string> = {
  SOURCE_SUMMARY_NOT_QA_APPROVAL: 'Kesimpulan Excel bukan approval QA aplikasi.',
  FIRST_COUNT_NO_MISSING_COUNTS_IMPUTED: 'Komponen kosong pada pengamatan awal tidak diisi dengan nol.',
  GERMINATION_MEDIUM_UNSPECIFIED: 'Media germinasi tidak disebutkan; tidak diasumsikan Sand.',
  OBSERVATION_DATE_CALCULATED_NOT_ACTUAL_EVIDENCE: 'Tanggal hasil rumus, bukan bukti pengamatan aktual.',
  UNEQUAL_OR_ZERO_SUBUNIT_TOTALS: 'Total subunit tidak seimbang atau nol. Perlu tinjauan.',
  OBSERVATION_DATE_MISSING: 'Tanggal pengamatan belum tercatat.',
  START_DATE_MISSING: 'Tanggal mulai belum tercatat.',
  MISSING_OR_INVALID_FINAL_COUNTS: 'Hitungan final belum lengkap atau tidak valid.',
  REPLICATE_LAYOUT_REVIEW: 'Susunan ulangan perlu ditinjau.',
};

function valueText(value: unknown): string {
  if (value === null || value === undefined || value === '') return 'Belum dicatat';
  if (typeof value === 'object') return JSON.stringify(value);
  return String(value);
}
function dateText(value: string | null, origin: string | null) {
  if (!value) return 'Belum dicatat';
  return `${value} · ${origin === 'FORMULA_CACHE' ? 'hasil rumus sumber, bukan bukti aktual' : 'tanggal sumber'}`;
}

function SourcePhase({ phase }: { phase: Phase }) {
  return <details className={styles.phase}>
    <summary>{kinds[phase.kind] ?? phase.kind} · {phase.label}</summary>
    <dl className={styles.facts}>
      <dt>Metode sumber</dt><dd>{phase.source_method_label ?? 'Tidak disebutkan'}</dd>
      <dt>Tahap lot sumber</dt><dd>{phase.source_stage ?? 'Tidak disebutkan'}</dd>
      <dt>Tanggal mulai</dt><dd>{dateText(phase.source_planted_date, phase.source_planted_origin)}</dd>
      <dt>Tanggal pengamatan</dt><dd>{dateText(phase.source_observation_date, phase.source_observation_origin)}</dd>
      <dt>Persentase sumber</dt><dd>{phase.source_percent === null ? 'Belum dicatat' : `${phase.source_percent}%`}</dd>
      <dt>Hitung ulang diagnostik</dt><dd>{phase.diagnostic_percent === null ? 'Tidak dihitung / data tidak cukup' : `${phase.diagnostic_percent}%`}</dd>
      {phase.source_conclusion && <><dt>Keterangan Excel</dt><dd>{phase.source_conclusion} · bukan approval QA aplikasi</dd></>}
    </dl>
    {phase.review_codes.length > 0 && <ul className={styles.notes}>{phase.review_codes.map(code =>
      <li key={code}>{warnings[code] ?? code}</li>)}</ul>}
    {phase.subunits.length > 0 && <div className={styles.scroll} role="region" aria-label="Subunit pengamatan" tabIndex={0}>
      <table><caption>Hitungan asli per subunit · — berarti belum dicatat, bukan nol</caption>
        <thead><tr><th>Subunit / baris</th><th>Normal</th><th>Abnormal</th><th>Mati</th><th>Total</th></tr></thead>
        <tbody>{phase.subunits.map(row => <tr key={row.source_row}>
          <th scope="row">{row.label ?? 'Tanpa label'} / {row.source_row}</th>
          {[row.normal, row.abnormal, row.dead, row.total].map((value, i) => <td key={i}>{value ?? '—'}</td>)}
        </tr>)}</tbody>
      </table>
    </div>}
    <details className={styles.cells}>
      <summary>Nilai sumber & posisi sel ({phase.values.length})</summary>
      <div className={styles.scroll} role="region" aria-label="Nilai sel sumber" tabIndex={0}>
        <table><caption>Nilai/cache dipertahankan. Kesalahan sumber tidak diganti angka.</caption>
          <thead><tr><th>Sel / kolom</th><th>Nilai</th><th>Satuan / asal</th></tr></thead>
          <tbody>{phase.values.map(fact => <tr key={fact.coordinate}>
            <th scope="row">{fact.coordinate} · {fact.header}<small>{fact.header_band}</small></th>
            <td>{fact.date ?? valueText(fact.number ?? fact.source_value)}{fact.warning && <small>{fact.warning}</small>}</td>
            <td>{fact.unit}<small>{fact.origin === 'FORMULA_CACHE' ? 'Cache rumus sumber' : fact.origin}</small></td>
          </tr>)}</tbody>
        </table>
      </div>
    </details>
  </details>;
}

export function HistoricalQualityBrowser({ lots, module, truncated = false }: {
  lots: Lot[]; module: 'PLANT' | 'LAB'; truncated?: boolean;
}) {
  const [query, setQuery] = useState('');
  const [lotId, setLotId] = useState('');
  const [history, setHistory] = useState<History | null>(null);
  const [offset, setOffset] = useState(0);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState('');
  const attempt = useRef(0);
  const unique = Array.from(new Map(lots.map(lot => [lot.id, lot])).values());
  const visible = unique.filter(lot => lot.id === lotId || lot.lot_code.toUpperCase().includes(query.trim().toUpperCase()));

  function selectLot(value: string) {
    attempt.current++;
    setLotId(value); setHistory(null); setOffset(0); setMessage(''); setBusy(false);
  }
  async function load(nextOffset: number) {
    if (!lotId || busy) return;
    const id = ++attempt.current;
    setBusy(true); setHistory(null); setMessage('');
    try {
      const { data, error } = await createClient().schema(isolatedApiSchema).rpc('get_lot_historical_quality', {
        p_lot_id: lotId, p_module: module, p_limit: pageSize, p_offset: nextOffset,
      });
      if (attempt.current !== id) return;
      if (error) throw new Error('History unavailable');
      if (!data) { setMessage('Histori tidak tersedia dalam cakupan akses Anda.'); return; }
      if (data.history_status !== 'SOURCE_HISTORY_NOT_APP_APPROVED' || !Array.isArray(data.records)) throw new Error('Unsupported history');
      setHistory(data as History); setOffset(nextOffset);
    } catch {
      if (attempt.current === id) setMessage('Histori gagal dimuat. Tidak menggunakan data lama. Coba lagi.');
    } finally {
      if (attempt.current === id) setBusy(false);
    }
  }

  return <details className={styles.browser}>
    <summary>Histori Excel · baca-saja</summary>
    <p className={styles.notice}>Arsip sumber, bukan hasil yang disetujui QA aplikasi atau izin pelepasan lot.
      Acuan mutu saat ini tidak diterapkan ulang pada histori.</p>
    <p>{module === 'LAB' ? 'Lab: hanya lot pada permintaan yang berizin. Fase QI tanpa tahap yang jelas tidak ditampilkan.' : 'Plant: lot dalam cakupan site Anda.'}
      {' '}Batch saat ini H59/SWC; tidak semua lot mempunyai histori yang sudah dipetakan.</p>
    {truncated && <p role="status">Daftar pilihan dibatasi API. Lot di luar daftar ini belum dapat dipilih di tampilan ini.</p>}
    {unique.length === 0 ? <p>Belum ada lot yang dapat dipilih dalam cakupan Anda.</p> : <>
      <div className={styles.controls}>
        <label>Cari lot histori<input value={query} onChange={event => setQuery(event.target.value)} placeholder="Kode lot, misalnya DEMO-RR-0002" /></label>
        <label>Lot histori<select aria-label="Lot histori" value={lotId} onChange={event => selectLot(event.target.value)}>
          <option value="">Pilih lot</option>{visible.map(lot => <option key={lot.id} value={lot.id}>{lot.lot_code}</option>)}
        </select></label>
        <button type="button" className="btn" disabled={!lotId || busy} onClick={() => load(0)}>{busy ? 'Memuat histori…' : 'Tampilkan histori'}</button>
      </div>
      <p><small>{visible.length} pilihan ditampilkan dari {unique.length} lot.</small></p>
    </>}
    <div aria-live="polite" aria-busy={busy}>
      {message && <p role="status">{message}</p>}
      {history && <>
        <h2>Histori lot {history.lot_code}</h2>
        {history.total_records === 0 ? <p>Belum ada histori terpetakan yang dapat dibaca untuk lot ini. Ini bukan hasil nol atau gagal uji.</p> : <>
          <p>Rekaman {offset + 1}–{offset + history.records.length} dari {history.total_records}. Satu rekaman sumber dapat memuat beberapa fase, bukan satu pekerjaan baru.</p>
          {history.records.map(record => <details className={styles.record} key={record.id}>
            <summary>{record.source_type === 'QUALITY_INFORMATION_2026' ? 'Quality Information' : 'Germinasi / Vigor'} · {record.sheet} · baris {record.source_row}</summary>
            <p>{record.source_file_name} · mapping v{record.mapping_version}</p>
            {record.source_testing_type && <p>Jenis sumber: {record.source_testing_type}</p>}
            {record.phases.map(phase => <SourcePhase key={phase.key} phase={phase} />)}
          </details>)}
          <nav className={styles.pagination} aria-label="Halaman histori">
            <button type="button" className="btn" disabled={busy || offset === 0} onClick={() => load(Math.max(0, offset - pageSize))}>Sebelumnya</button>
            <button type="button" className="btn" disabled={busy || offset + history.records.length >= history.total_records} onClick={() => load(offset + pageSize)}>Berikutnya</button>
          </nav>
        </>}
      </>}
    </div>
  </details>;
}

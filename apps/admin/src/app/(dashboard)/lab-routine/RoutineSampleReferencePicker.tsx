'use client';

import { useEffect, useRef, useState } from 'react';
import { createClient } from '@/lib/supabase/client';
import { isolatedApiSchema } from '@/lib/supabase/config';
import styles from './routine.module.css';

type Reference = { reference: string; sample_code: string | null; source_kind: 'RECEIVED' | 'DRAFT' };
type ReferencePage = { references: Reference[]; total: number; offset: number; has_more: boolean };

export default function RoutineSampleReferencePicker({ labSiteId, lotId, value, locked, onChange, rpcName='list_routine_sample_references' }: {
  labSiteId: string; lotId: string; value: string; locked: boolean; onChange: (value: string) => void; rpcName?: 'list_routine_sample_references'|'list_mc_sample_references';
}) {
  const [manual, setManual] = useState(!!value);
  const [search, setSearch] = useState('');
  const [page, setPage] = useState<ReferencePage | null>(null);
  const [appliedSearch, setAppliedSearch] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const dialog = useRef<HTMLDialogElement>(null);
  const input = useRef<HTMLInputElement>(null);
  const request = useRef(0);
  useEffect(() => () => { request.current++; }, []);

  async function load(term: string, offset = 0) {
    const version = ++request.current;
    setBusy(true); setError(''); setPage(null);
    try {
      const result = await createClient().schema(isolatedApiSchema).rpc(rpcName, {
        p_lab_site_id: labSiteId, p_lot_id: lotId, p_search: term.trim(), p_offset: offset,
      });
      if (request.current !== version) return;
      if (result.error) throw Error();
      setPage(result.data as ReferencePage); setAppliedSearch(term.trim());
    } catch {
      if (request.current === version) setError('Daftar belum bisa dimuat. Coba lagi atau isi label sebenarnya melalui Isi manual.');
    } finally { if (request.current === version) setBusy(false); }
  }
  function close() { request.current++; setBusy(false); dialog.current?.close(); }
  return <div className={styles.referenceField}>
    <label>Referensi / label sampel<input ref={input} maxLength={120} readOnly={locked || !manual}
      placeholder="Pilih dari daftar atau tekan Isi manual" value={value} onChange={e => onChange(e.target.value)} /></label>
    {!locked && <div className={styles.actions}>
      <button type="button" className="btn" onClick={() => { setSearch(''); dialog.current?.showModal(); void load(''); }}>Pilih label tercatat</button>
      <button type="button" className="btn" onClick={() => { setManual(true); input.current?.focus(); }}>Isi manual</button>
    </div>}
    <small>{locked ? 'Uji ulang memakai referensi sampel semula; tidak dapat diganti.' : 'Pilih label untuk lot ini atau isi sesuai label fisik. Pilihan hanya mengisi referensi, bukan waktu atau hasil uji.'}</small>
    <dialog ref={dialog} className={styles.referenceDialog} aria-labelledby="sample-reference-title" onCancel={close}>
      <h2 id="sample-reference-title">Pilih label sampel</h2>
      <p>Hanya catatan untuk lot dan Lab ini. Cocokkan dengan label sampel fisik; label draft belum diverifikasi.</p>
      <div className={styles.search}>
        <label>Cari nomor atau label sampel<input maxLength={120} value={search} onChange={e => setSearch(e.target.value)}
          onKeyDown={e => { if (e.key === 'Enter') { e.preventDefault(); void load(search); } }} /></label>
        <button type="button" className="btn" disabled={busy} onClick={() => void load(search)}>Cari sampel</button>
      </div>
      <div className={styles.referenceResults} aria-live="polite" aria-busy={busy}>
        {busy && <p>Memuat label sampel…</p>}
        {error && <p role="alert">{error}</p>}
        {page && <p>{page.total} label cocok · maksimal 50 per halaman.</p>}
        {page?.references.map(item => <button type="button" className={styles.lot} key={item.reference} onClick={() => {
          onChange(item.reference); setManual(false); close();
        }}><strong>{item.reference}</strong><small>{item.source_kind === 'RECEIVED' ? 'Sampel sudah diterima Lab' : 'Label dari draft · belum diverifikasi'}{item.sample_code && item.sample_code !== item.reference ? ` · ${item.sample_code}` : ''}</small></button>)}
        {page && !page.references.length && <p>Label belum ditemukan. Periksa pencarian atau isi manual sesuai sampel sebenarnya.</p>}
      </div>
      <div className={styles.actions}>
        <button type="button" className="btn" disabled={busy || !page?.offset} onClick={() => void load(appliedSearch, Math.max(0, (page?.offset ?? 0) - 50))}>Sebelumnya</button>
        <button type="button" className="btn" disabled={busy || !page?.has_more} onClick={() => void load(appliedSearch, (page?.offset ?? 0) + 50)}>Berikutnya</button>
        <button type="button" className="btn" onClick={() => { close(); setManual(true); input.current?.focus(); }}>Tidak ada di daftar · isi manual</button>
        <button type="button" className="btn" onClick={close}>Batal</button>
      </div>
    </dialog>
  </div>;
}

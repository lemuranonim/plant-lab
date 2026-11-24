'use client';

import { useRef, useState, type FormEvent } from 'react';
import { useRouter } from 'next/navigation';
import { createClient } from '@/lib/supabase/client';
import { canonicalWritesEnabled, hostedPilot, isolatedApiSchema } from '@/lib/supabase/config';
import styles from './queue.module.css';
import type { VigourOptions } from './VigourPanel';

export type RequestOptions = {
  lot_count?: number;
  lots_truncated?: boolean;
  lots: { id: string; lot_code: string; canonical_lot_code: string; company_id: number }[];
  lab_sites: { id: string; site_name: string; company_id: number }[];
  test_types: { test_code: string; test_name: string }[];
};

export function SubmitRequestForm({ options, vigourOptions }: { options: RequestOptions; vigourOptions?: VigourOptions | null }) {
  const router = useRouter();
  const [lotId, setLotId] = useState('');
  const [query, setQuery] = useState('');
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState('');
  const [testCode, setTestCode] = useState('');
  const attempt = useRef<{ details: string; id: string } | null>(null);
  const companyId = options.lots.find(lot => lot.id === lotId)?.company_id;
  const visibleLots = options.lots.filter(lot => lot.id === lotId ||
    lot.lot_code.toUpperCase().includes(query.trim().toUpperCase()));

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!canonicalWritesEnabled || busy) return;
    const form = event.currentTarget;
    const fields = new FormData(form);
    const selectedMethods = fields.getAll('vigour_method').map(String).sort();
    const vigour = hostedPilot && testCode === 'VIGOUR';
    if (vigour && selectedMethods.length === 0) { setMessage('Pilih sedikitnya satu metode Vigor yang akan dikerjakan.'); return; }
    const details = {
      p_lot_id: lotId,
      p_target_lab_site_id: String(fields.get('lab')),
      ...(vigour ? { p_method_codes: selectedMethods } : { p_test_code: String(fields.get('test')) }),
      p_sampling_instruction: String(fields.get('instruction') ?? '').trim(),
    };
    const serialized = JSON.stringify(details);
    if (attempt.current?.details !== serialized) {
      attempt.current = { details: serialized, id: crypto.randomUUID() };
    }
    setBusy(true);
    setMessage('');
    try {
      const { data, error } = await createClient().schema(isolatedApiSchema)
        .rpc(vigour ? 'submit_vigour_request' : 'submit_plant_lab_request', { ...details, p_submission_id: attempt.current.id });
      if (error) {
        setMessage(error.code === '23505'
          ? 'Sudah ada permintaan aktif untuk lot dan jenis uji ini.'
          : 'Pengajuan gagal. Periksa pilihan dan akses, lalu coba lagi.');
        return;
      }
      setMessage('Permintaan diajukan: ' + data.request_code);
      form.reset();
      setLotId('');
      setQuery('');
      setTestCode('');
      attempt.current = null;
      router.refresh();
    } catch {
      setMessage('Koneksi terputus. Coba ulang dengan pilihan yang sama.');
    } finally {
      setBusy(false);
    }
  }

  if (!canonicalWritesEnabled) return null;
  if (!options.lots.length) return <p>Belum ada lot yang dapat Anda ajukan.</p>;
  return (
    <details className={styles.newRequest}><summary>+ Ajukan Permintaan Uji</summary><form onSubmit={submit}>
      {hostedPilot && <p>Lot berasal dari Excel asli. Ajukan hanya pekerjaan atau pengujian ulang yang benar-benar akan dilakukan. Germinasi (Sand) dan metode Vigor tersedia.{vigourOptions?.ret_enabled && ' RET memakai radikula ≥2 mm, 4×100 dan pengamatan setelah minimal 72 jam pada 16°C.'}</p>}
      <fieldset disabled={busy} className={styles.form} style={{ border: 0, padding: 0 }}>
        <label>Cari kode lot{' '}
          <input type="search" value={query} autoComplete="off" placeholder="Contoh: DEMO-RR-0002"
            onChange={event => setQuery(event.target.value)} />
        </label>
        <small role="status">{visibleLots.length} pilihan ditampilkan dari {options.lots.length} lot dalam cakupan Anda.</small>
        {options.lots_truncated && <p role="alert">Sebagian lot belum dimuat. Hubungi administrator jika kode yang dicari belum tersedia.</p>}
        {visibleLots.length === 0 && <p>Kode lot tidak ditemukan. Periksa kode atau cakupan site Anda.</p>}
        <label>Lot{' '}
          <select aria-label="Lot" required value={lotId} onChange={event => setLotId(event.target.value)}>
            <option value="">Pilih lot</option>
            {visibleLots.map(lot => <option value={lot.id} key={lot.id}>
              {lot.lot_code}{lot.canonical_lot_code !== lot.lot_code ? ` · ${lot.canonical_lot_code}` : ''}
            </option>)}
          </select>
        </label>
        <label>Lab tujuan{' '}
          <select aria-label="Lab tujuan" required name="lab" key={lotId} defaultValue="">
            <option value="">Pilih Lab</option>
            {options.lab_sites.filter(site => site.company_id === companyId)
              .map(site => <option value={site.id} key={site.id}>{site.site_name}</option>)}
          </select>
        </label>
        <label>Jenis uji{' '}
          <select aria-label="Jenis uji" required name="test" value={testCode} onChange={event => setTestCode(event.target.value)}>
            <option value="">Pilih uji</option>
            {options.test_types.filter(test => !hostedPilot || test.test_code === 'GERMINATION' || (test.test_code === 'VIGOUR' && !!vigourOptions?.methods.length)).map(test => <option key={test.test_code} value={test.test_code}>{test.test_name}</option>)}
          </select>
        </label>
        {hostedPilot && testCode === 'VIGOUR' && <fieldset><legend>Metode Vigor yang diminta</legend>
          <p>Boleh memilih beberapa metode. Masing-masing memiliki pengamatan dan review QA terpisah.</p>
          {vigourOptions?.methods.map(method => <label key={method.method_code} style={{ display: 'flex', gap: 8, alignItems: 'baseline', marginBlock: 10 }}>
            <input type="checkbox" name="vigour_method" value={method.method_code} style={{ width: 'auto' }} /> {method.method_name}
          </label>)}
        </fieldset>}
        <label>Instruksi opsional{' '}<input name="instruction" maxLength={500} /></label>
        <button type="submit" className="btn btn-primary">{busy ? 'Mengajukan…' : 'Ajukan ke Lab'}</button>
      </fieldset>
      {message && <p role="status">{message}</p>}
    </form></details>
  );
}

export function AcceptRequestButton({ requestId }: { requestId: string }) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(false);
  if (!canonicalWritesEnabled) return null;

  async function accept() {
    setBusy(true);
    setError(false);
    try {
      const { error } = await createClient().schema(isolatedApiSchema)
        .rpc('accept_plant_lab_request', { p_request_id: requestId });
      if (error) throw error;
      router.refresh();
    } catch {
      setError(true);
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <button className="btn btn-primary" type="button" disabled={busy} onClick={accept}>
        {busy ? 'Memproses…' : 'Terima permintaan'}
      </button>
      {error && <span role="alert">Tidak dapat menerima. Muat ulang antrean lalu coba lagi.</span>}
    </>
  );
}

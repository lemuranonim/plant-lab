'use client';

import { useState, type FormEvent } from 'react';
import { useRouter } from 'next/navigation';
import { createClient } from '@/lib/supabase/client';
import { canonicalWritesEnabled, isolatedApiSchema } from '@/lib/supabase/config';

export type Handoff = {
  request_id: string;
  sample_code: string;
  dispatch_code: string;
  sent_grams: number;
  dispatch_condition: string;
  receipt_code: string | null;
  received_grams: number | null;
  receipt_condition: string | null;
};

export function SampleHandoff({ requestId, status, module, handoff }: {
  requestId: string;
  status: string;
  module: 'PLANT' | 'LAB';
  handoff?: Handoff;
}) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  if (!canonicalWritesEnabled) return null;
  const action = module === 'PLANT' && status === 'ACCEPTED' ? 'prepare'
    : module === 'PLANT' && status === 'PREPARED' && handoff ? 'send'
      : module === 'LAB' && status === 'SENT' && handoff ? 'receive'
        : null;
  const label = action === 'prepare' ? 'Siapkan sampel'
    : action === 'send' ? 'Tandai dikirim' : 'Terima sampel fisik';

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!action || busy) return;
    const data = new FormData(event.currentTarget);
    const request = { p_request_id: requestId };
    const weight = Number(data.get('weight'));
    const condition = String(data.get('condition') ?? '').trim();
    if (action !== 'send' && (!Number.isFinite(weight) || weight <= 0 || !condition)) {
      setError('Isi berat positif dan kondisi sampel.');
      return;
    }
    setBusy(true);
    setError('');
    try {
      const api = createClient().schema(isolatedApiSchema);
      const result = action === 'prepare'
        ? await api.rpc('prepare_lab_sample', { ...request, p_quantity_grams: weight, p_condition: condition })
        : action === 'send' ? await api.rpc('send_lab_sample', request)
          : await api.rpc('receive_lab_sample', {
            ...request, p_sample_code: String(data.get('sample_code') ?? '').trim(),
            p_received_grams: weight, p_condition: condition,
          });
      if (result.error) {
        setError(result.error.code === '22023' && action === 'receive'
          ? 'Cocokkan kode pada label sampel dan periksa berat serta kondisi.'
          : 'Tidak dapat menyimpan. Periksa detail dan status permintaan.');
      } else {
        router.refresh();
      }
    } catch {
      setError('Koneksi terputus. Coba ulang dengan detail yang sama.');
    } finally {
      setBusy(false);
    }
  }

  if (!action && !handoff) return null;
  return (
    <div style={{ minWidth: 200 }}>
      {handoff && <details><summary>Serah terima sampel · berat & label</summary><div>
        <div>Sampel: <code>{handoff.sample_code}</code></div>
        <div>Pengiriman: <code>{handoff.dispatch_code}</code></div>
        <div>Berat dari Plant: {handoff.sent_grams} g · {handoff.dispatch_condition}</div>
        {handoff.receipt_code && <div>
          Penerimaan: <code>{handoff.receipt_code}</code> · {handoff.received_grams} g · {handoff.receipt_condition}
        </div>}
      </div></details>}
      {action && <details>
        <summary>{label}</summary>
        <form key={action} onSubmit={submit}>
          <fieldset disabled={busy} style={{ border: 0, display: 'grid', gap: 8, padding: 0 }}>
            {action === 'receive' && <label>Kode pada label sampel{' '}
              <input required name="sample_code" maxLength={64} autoComplete="off" />
            </label>}
            {action !== 'send' && <>
              <label>Berat sampel (g){' '}<input required name="weight" type="number" min="0" step="any" /></label>
              <label>Kondisi sampel{' '}<input required name="condition" maxLength={500} /></label>
            </>}
            {action === 'receive' && <p>Gunakan hanya untuk sampel yang layak diterima.</p>}
            <button className="btn btn-primary" type="submit">{busy ? 'Menyimpan…' : label}</button>
          </fieldset>
          {error && <p role="alert">{error}</p>}
        </form>
      </details>}
    </div>
  );
}

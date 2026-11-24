'use client';

import { useRef, useState, type FormEvent } from 'react';
import { useRouter } from 'next/navigation';
import { createClient } from '@/lib/supabase/client';
import { canonicalWritesEnabled, isolatedApiSchema } from '@/lib/supabase/config';
import styles from './review.module.css';

export function ReviewForm({ caseId, revision, hasOfficial, canKeepOfficial, candidates }: {
  caseId: string; revision: number; hasOfficial: boolean; canKeepOfficial: boolean; candidates: { id: string; label: string }[];
}) {
  const router = useRouter();
  const [decision, setDecision] = useState('');
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState('');
  const attempt = useRef<{ input: string; id: string } | null>(null);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!canonicalWritesEnabled || busy) return;
    const form = new FormData(event.currentTarget);
    const details = {
      p_case_id: caseId, p_revision: revision, p_decision: decision,
      p_candidate_id: decision === 'APPROVE' ? String(form.get('candidate') ?? '') : null,
      p_reason: String(form.get('reason') ?? '').trim(), p_evidence: String(form.get('evidence') ?? '').trim(),
    };
    if (!details.p_reason || !details.p_evidence || (decision === 'APPROVE' && !details.p_candidate_id)) {
      setMessage('Isi pilihan, alasan, dan bukti sebelum menyimpan.');
      return;
    }
    const input = JSON.stringify(details);
    if (attempt.current?.input !== input) attempt.current = { input, id: crypto.randomUUID() };
    setBusy(true);
    setMessage('');
    try {
      const { error } = await createClient().schema(isolatedApiSchema)
        .rpc('decide_lot_pair_review', { ...details, p_action_id: attempt.current.id });
      if (error) {
        setMessage(error.code === '55000' || error.code === '23514'
          ? 'Kasus berubah atau masih terkait konflik lain. Muat ulang sebelum memutuskan.'
          : 'Keputusan belum tersimpan. Periksa data dan hak akses.');
        return;
      }
      router.refresh();
    } catch {
      setMessage('Koneksi terputus. Coba lagi dengan keputusan yang sama.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <form onSubmit={submit}>
      <fieldset disabled={busy} className={styles.form}>
        <legend>Keputusan Plant</legend>
        <label className={styles.field}>Keputusan
          <select required value={decision} onChange={event => setDecision(event.target.value)}>
            <option value="">Pilih keputusan</option>
            {canKeepOfficial && <option value="KEEP_OFFICIAL">Pertahankan pasangan resmi</option>}
            {!hasOfficial && <option value="APPROVE">Tetapkan satu pasangan</option>}
            <option value="REQUEST_CORRECTION">Minta koreksi sumber</option>
            <option value="HOLD">Tahan kasus</option>
          </select>
        </label>
        {decision === 'APPROVE' && <label className={styles.field}>Pasangan yang disetujui
          <select name="candidate" required defaultValue="">
            <option value="">Pilih berdasarkan bukti</option>
            {candidates.map(candidate => <option key={candidate.id} value={candidate.id}>{candidate.label}</option>)}
          </select>
        </label>}
        <label className={styles.field}>Alasan keputusan <textarea name="reason" required maxLength={500} rows={2} /></label>
        <label className={styles.field}>Rujukan bukti <input name="evidence" required maxLength={500} placeholder="Contoh: lembar pencatatan proses dan nomor baris" /></label>
        <button type="submit" className={`btn btn-primary ${styles.submit}`}>{busy ? 'Menyimpan…' : 'Simpan keputusan'}</button>
      </fieldset>
      {message && <p role="alert">{message}</p>}
    </form>
  );
}

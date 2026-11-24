'use client';

import { useState } from 'react';
import { createClient } from '@/lib/supabase/client';
import { isolatedApiSchema } from '@/lib/supabase/config';
import { routineDraftHtml, type RoutineDraft } from '@/lib/routineLabDraft';
import { RoutineSummaryView } from './RoutineWorkflowPanel';
import styles from './routine.module.css';

export default function ApprovedRoutineResults({ module }: { module: 'PLANT' | 'LAB' }) {
  const [page, setPage] = useState<{ results: RoutineDraft[]; total: number; offset: number; has_more: boolean } | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  async function load(offset: number) {
    setBusy(true); setError('');
    try {
      const result = await createClient().schema(isolatedApiSchema).rpc('list_approved_routine_lab_results', { p_module: module, p_offset: offset });
      if (result.error) throw Error();
      setPage(result.data);
    } catch { setError('Hasil rutin belum bisa dimuat. Periksa koneksi dan cakupan akun; tidak dianggap kosong.'); }
    finally { setBusy(false); }
  }
  function download(draft: RoutineDraft) {
    const url = URL.createObjectURL(new Blob([routineDraftHtml(draft)], { type: 'text/html;charset=utf-8' }));
    const a = document.createElement('a'); a.href = url; a.download = `Hasil-Lab-${draft.workflow!.run_code}.html`; a.click(); setTimeout(() => URL.revokeObjectURL(url), 1000);
  }
  return <section className={styles.panel} aria-label="Hasil rutin Lab yang disetujui"><h2>Hasil rutin Lab yang disetujui QA</h2>
    <p>Pengujian rutin tidak dihitung sebagai request Plant. Hanya analisis yang sudah disetujui untuk lot dalam cakupan Anda ditampilkan di sini. Bukan pelepasan lot.</p>
    <button className="btn" disabled={busy} onClick={() => void load(page?.offset ?? 0)}>Muat hasil rutin Lab</button>
    {error && <p role="alert">{error}</p>}{page && <p>{page.total} hasil disetujui dalam cakupan akun Anda.</p>}
    {page?.results.map(draft => <article key={draft.id} className={styles.saved}><h3>{draft.lot_code} · {draft.method_name}</h3><p>{draft.hybrid} · {draft.stage_code} · {draft.workflow?.run_code}</p>
      {draft.workflow?.summary && <RoutineSummaryView summary={draft.workflow.summary} />}<p>Catatan QA: {draft.workflow?.review_reason}</p>
      <button className="btn" onClick={() => download(draft)}>Unduh catatan hasil (.html)</button>
    </article>)}
    {page && <div className={styles.actions}><button className="btn" disabled={busy || !page.offset} onClick={() => void load(Math.max(0, page.offset - 50))}>Hasil sebelumnya</button><button className="btn" disabled={busy || !page.has_more} onClick={() => void load(page.offset + 50)}>Hasil berikutnya</button></div>}
  </section>;
}

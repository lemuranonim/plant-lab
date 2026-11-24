import type {RevalidationContext} from './labRevalidation';
export type RoutineMethod = { method_code: string; method_name: string; replicate_count: number; replicate_counts?: number[]; observation_kind: string };
export type RoutineLot = { id: string; lot_code: string; hybrid: string; stage_code: string; plant_site: string };
export type RoutineOptions = {
  draft_only: boolean; can_write: boolean; selected_lab_site_id: string;
  lab_sites: { id: string; site_name: string }[]; methods: RoutineMethod[];
  lots: RoutineLot[]; total: number; offset: number; has_more: boolean;
};
export const countFields = ['first_normal', 'final_normal', 'abnormal', 'fresh', 'hard', 'dead'] as const;
export const countLabels: Record<string, string> = {
  first_normal: 'Normal first count', final_normal: 'Normal final count',
  abnormal: 'Abnormal', fresh: 'Fresh', hard: 'Hard', dead: 'Mati',
  radicle_at_least_2mm: 'Radikula ≥ 2 mm',
};
export type RoutineContent = {
  sample_reference: string | null; received_at: string | null; started_at: string | null;
  final_at: string | null; note: string | null; replicate_count: number;
  observations: Record<string, number | null>[];
  form?: RoutineFormDetails;
};
export type RoutineFormDetails = {
  version: 1; crop_species: string | null; analyst_name: string | null;
  temperature_text: string | null; planted_at: string | null; first_count_at: string | null;
  annotations: { abnormal_kind: string | null; remarks: string | null }[];
};
export function emptyRoutineForm(method: string, rows: number): RoutineFormDetails {
  return { version: 1, crop_species: null, analyst_name: null, temperature_text: method === 'SAND_25C' ? '25' : null,
    planted_at: null, first_count_at: null, annotations: Array.from({length: rows}, () => ({ abnormal_kind: null, remarks: null })) };
}
export type RoutineDraft = {
  id: string; revision: number; status: string; lot_id: string; lot_code: string; hybrid: string;
  stage_code: string; method_code: string; method_name: string; content: RoutineContent;
  can_edit: boolean; updated_at: string; created_by?: string;
  workflow?: RoutineWorkflow | null; retest_of_run_id?: string | null;
  revalidation?:RevalidationContext|null;
};
export type RoutinePurpose='INITIAL'|'RETEST_VERIFICATION'|'REVALIDATION_1'|'REVALIDATION_2'|'REVALIDATION_3';
export function validateRoutinePurpose(r:Pick<RoutineDraft,'revalidation'>&{test_purpose:RoutinePurpose}) {
 const v=r.revalidation;
 if(v ? ![1,2,3].includes(v.stage)||r.test_purpose!==`REVALIDATION_${v.stage}`||!v.authorization_id||!v.source_run_code||!v.authorizer_name||!v.authorized_at||!v.reason||!['RETAINED_LAB','NEW_SAMPLE'].includes(v.sample_plan)||!v.sample_evidence
   : !['INITIAL','RETEST_VERIFICATION'].includes(r.test_purpose))throw Error('FORM_PURPOSE');
}
export function routinePurpose(r:Pick<RoutineDraft,'revalidation'|'retest_of_run_id'>){return r.revalidation?`Revalidation ${r.revalidation.stage}${r.revalidation.is_qa_retest?' (uji ulang QA)':''}`:r.retest_of_run_id?'Retest Verification':'Initial';}
export function routineRevalidationNotes(r:Pick<RoutineDraft,'revalidation'>){const v=r.revalidation;return v?[
 `Revalidation ${v.stage}. Sumber analisis: ${v.source_run_code}. Persetujuan: ${v.authorizer_name}, ${wibInput(v.authorized_at).replace('T',' ')} WIB.`,
 `Alasan: ${v.reason}`,
 `Rencana sampel: ${v.sample_plan==='RETAINED_LAB'?'aliquot dari sampel simpanan Lab':'sampel baru yang dikonfirmasi di Lab'}. Rujukan: ${v.sample_evidence}`,
 `ID persetujuan: ${v.authorization_id}. Root: ${v.root_run_id}.${v.is_qa_retest?' Percobaan ini uji ulang QA, bukan tahap Revalidation berikutnya.':''}`,
 ]:[];}
export type RoutineSummary = {
  germination_percent?: number; vigour_percent?: number; unrounded_percent?: number;
  gap_pp: number; limit_pp: number | null; within_tolerance: boolean | null;
  replicates: Record<string, number | null>[]; calculation_code: string; calculation_version: number;
  uac_quality_reference?: Record<string, unknown> | null; quality_reference_scope?: string;
  elapsed_hours?: number; minimum_radicle_mm?: number;
};
export type RoutineWorkflow = {
  run_id: string; run_code: string; status: string; attempt_no: number; parent_run_id: string | null;
  summary: RoutineSummary | null; analyst_id: string; reviewer_id: string | null;
  review_reason: string | null; reviewed_at: string | null; can_review: boolean; can_retest: boolean;
};
export type RoutineReadiness = {
  revision: number; ready: boolean; blockers: { code: string; message: string }[];
  warnings: string[]; summary: RoutineSummary | null; is_retest: boolean;
};
export function routineStatus(status: string): string {
  return ({ DRAFT: 'Draft', IN_REVIEW: 'Menunggu QA', APPROVED: 'Analisis disetujui', RETEST: 'QA meminta uji ulang' } as Record<string,string>)[status] ?? status;
}
export type RoutinePage = { drafts: RoutineDraft[]; total: number; offset: number; has_more: boolean };
export function emptyRoutineContent(method: RoutineMethod, replicateCount = method.replicate_count): RoutineContent {
  const ret = method.method_code === 'RET_16C_72H';
  const count = replicateCount;
  return { sample_reference: null, received_at: null, started_at: null, final_at: null, note: null,
    replicate_count: count,
    observations: Array.from({ length: ret ? count : count * 2 }, () => Object.fromEntries(
      (ret ? ['radicle_at_least_2mm'] : countFields).map(key => [key, null]),
    )),
  };
}
export function wibInput(iso: string | null): string {
  return iso ? new Date(new Date(iso).getTime() + 7 * 60 * 60 * 1000).toISOString().slice(0, 16) : '';
}
export function fromWibInput(local: string): string | null {
  return local ? new Date(`${local}:00+07:00`).toISOString() : null;
}
export function observationLabel(index: number, ret: boolean): string {
  return ret ? `Ulangan ${index + 1} · 100 benih` : `Ulangan ${Math.floor(index / 2) + 1}${index % 2 ? 'b' : 'a'} · 50 benih`;
}

// User-triggered, static, script-free download. Escape every value from records.
export function routineDraftHtml(draft: RoutineDraft): string {
  const escape = (x: unknown) => String(x ?? 'Belum diisi').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]!);
  const ret = draft.method_code === 'RET_16C_72H';
  const keys = ret ? ['radicle_at_least_2mm'] : [...countFields];
  const date = (iso: string | null) => iso ? `${wibInput(iso).replace('T', ' ')} WIB` : 'Belum diisi';
  const workflow = draft.workflow;
  const summary = workflow?.summary;
  const status = workflow?.status ?? 'DRAFT';
  const heading = status === 'APPROVED' ? 'ANALISIS DISETUJUI QA. Bukan pelepasan lot.' : status === 'IN_REVIEW' ? 'MENUNGGU QA — BELUM DISETUJUI.' : status === 'RETEST' ? 'QA MEMINTA UJI ULANG. Hasil ini belum disetujui.' : 'DRAFT — BELUM DISETUJUI QA. Bukan hasil mutu resmi atau pelepasan lot.';
  const result = summary ? `<p>Hasil analisis: ${escape(summary.germination_percent ?? summary.vigour_percent)}%<br>Hitungan sebelum pembulatan: ${escape(summary.unrounded_percent)}%<br>Selisih antarulangan: ${escape(summary.gap_pp)} poin persentase. Batas: ${escape(summary.limit_pp)}<br>Status toleransi: ${escape(summary.within_tolerance === true ? 'Dalam toleransi' : summary.within_tolerance === false ? 'Di luar toleransi' : 'Aturan belum tersedia')}<br>Perhitungan: ${escape(summary.calculation_code)} v${escape(summary.calculation_version)}</p>` : '';
  const review = workflow ? `<p>Nomor analisis: ${escape(workflow.run_code)} · Percobaan ${escape(workflow.attempt_no)}<br>ID Analis: ${escape(workflow.analyst_id)}<br>ID Pemeriksa QA: ${escape(workflow.reviewer_id)}<br>Waktu pemeriksaan: ${escape(date(workflow.reviewed_at))}<br>Catatan QA: ${escape(workflow.review_reason)}</p>` : '';
  return `<!doctype html><html lang="id"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Draft pengujian rutin</title>
<style>body{font:14px Arial,sans-serif;max-width:1000px;margin:32px auto;padding:0 20px;color:#142c25}h1{font-size:24px}.status{border:2px solid #9a6700;padding:12px;font-weight:bold}.table-wrap{overflow-x:auto}table{border-collapse:collapse;width:100%;min-width:640px;margin:20px 0}th,td{border:1px solid #aebcb7;padding:8px;text-align:left}p{line-height:1.6;white-space:pre-wrap}@page{size:A4 landscape;margin:15mm}@media print{.table-wrap{overflow:visible}table{min-width:0}.screen-note{display:none}}</style>
<h1>Catatan pengujian rutin Lab</h1><p class="status">${escape(heading)}</p>
<p>Jenis pengujian: ${escape(routinePurpose(draft))}</p>${routineRevalidationNotes(draft).map(x=>`<p>${escape(x)}</p>`).join('')}
<p>Lot: ${escape(draft.lot_code)} · Hybrid: ${escape(draft.hybrid)} · Tahap: ${escape(draft.stage_code)}<br>Metode: ${escape(draft.method_name)}<br>Rancangan uji: ${escape(draft.content.replicate_count)} × 100 benih<br>Referensi sampel: ${escape(draft.content.sample_reference)}<br>Sampel tersedia di Lab: ${escape(date(draft.content.received_at))}<br>Mulai uji: ${escape(date(draft.content.started_at))}<br>Pengamatan final: ${escape(date(draft.content.final_at))}</p>
<p class="screen-note">Di layar HP, geser tabel ke samping untuk melihat semua kolom. Untuk mencetak, pilih orientasi mendatar.</p><div class="table-wrap"><table><thead><tr><th>Ulangan</th>${keys.map(k => `<th>${escape(countLabels[k])}</th>`).join('')}</tr></thead><tbody>${draft.content.observations.map((row, i) => `<tr><td>${escape(observationLabel(i, ret))}</td>${keys.map(k => `<td>${escape(row[k])}</td>`).join('')}</tr>`).join('')}</tbody></table></div>
${result}${review}<p>Catatan: ${escape(draft.content.note)}</p><p>Nilai kosong belum dicatat, bukan nol. First count tidak dijumlahkan kembali dengan final count. ${workflow ? 'Status persetujuan di atas berlaku untuk analisis ini, bukan izin pelepasan lot. Salinan dapat diperiksa melalui nomor analisis di aplikasi.' : 'Tidak ada persentase, keputusan toleransi, atau approval yang diterbitkan dari draft ini.'}</p>
<p>Referensi draft: ${escape(draft.id)} · Revisi ${escape(draft.revision)}<br>Disimpan: ${escape(date(draft.updated_at))}. Waktu simpan berbeda dari waktu pekerjaan di atas.</p></html>`;
}

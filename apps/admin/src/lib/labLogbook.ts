export type LogbookFilters={site:string;search:string;from:string;to:string;date_basis:string;origin:string;method:string;status:string};
export const emptyLogbookFilters:LogbookFilters={site:'',search:'',from:'',to:'',date_basis:'RECORDED',origin:'ALL',method:'ALL',status:'ALL'};
export const logbookStatuses:Record<string,string>={DRAFT:'Draft',WAITING_TEST:'Belum mulai uji',ASSIGNED:'Ditugaskan',IN_PROGRESS:'Sedang diuji',SUBMITTED:'Dikirim untuk diperiksa',IN_REVIEW:'Menunggu QA',APPROVED:'Analisis disetujui QA',RETEST:'Perlu uji ulang',REJECTED:'Ditolak QA',CANCELLED:'Dibatalkan',APPROVAL_INCOMPLETE:'Perlu pemeriksaan bukti QA',VERIFIED_RECORD:'Catatan MC diverifikasi QA',RETURNED:'Catatan MC dikembalikan'};
export const logbookOrigins:Record<string,string>={PLANT_RUN:'Permintaan Plant',PLANT_PENDING:'Permintaan Plant · belum mulai',ROUTINE:'Uji rutin Lab',MC_DRAFT:'MC Lab'};
export type LogbookEntry={entry_kind:string;entry_id:string;request_code:string|null;run_code:string|null;lot_code:string;hybrid:string;stage_code:string;method_code:string;method_name:string;status:string;sample_reference:string|null;recorded_at:string;observed_at:string|null;reviewed_at:string|null;result_percent:number|null;result_state:string;revision:number|null;attempt_no:number|null};
export type LogbookPage={selected_lab_site_id:string;lab_sites:{id:string;site_name:string}[];method_options:{method_code:string;method_name:string}[];entries:LogbookEntry[];total:number;offset:number;limit:number;has_more:boolean;summary:{approved:number;draft:number;waiting_qa:number;retest:number;other:number;missing_observation_time:number};as_of:string};
export const logbookWib=(value:string|null)=>value?new Intl.DateTimeFormat('id-ID',{timeZone:'Asia/Jakarta',day:'2-digit',month:'short',year:'numeric',hour:'2-digit',minute:'2-digit',hourCycle:'h23'}).format(new Date(value))+' WIB':'Belum dicatat';
export const logbookNumber=(value:number)=>new Intl.NumberFormat('id-ID',{maximumFractionDigits:6}).format(value);
export function logbookArgs(f:LogbookFilters,offset=0){return {p_lab_site_id:f.site||null,p_search:f.search.trim(),p_from:f.from||null,p_to:f.to||null,p_date_basis:f.date_basis,p_origin:f.origin,p_method:f.method,p_status:f.status,p_offset:offset,p_limit:50};}
export function logbookExportQuery(f:LogbookFilters){return new URLSearchParams(Object.entries(f).filter(([,v])=>v!==''));}

/** A printable record needs its own ID and the revision shown in the logbook. */
export function logbookFormTarget(row: LogbookEntry) {
  if (!/^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i.test(row.entry_id)
    || row.revision == null || !Number.isInteger(row.revision) || row.revision < 1 || row.revision > 999_999_999) return null;
  const target = row.entry_kind === 'MC_DRAFT' && row.method_code === 'MC_LAB'
    ? { module: 'lab-moisture', name: 'MC-Lab' }
    : row.entry_kind === 'ROUTINE' && row.method_code !== 'UNASSIGNED'
      ? row.method_code === 'RET_16C_72H'
        ? { module: 'lab-ret', name: 'RET' }
        : { module: 'lab-routine', name: row.method_code === 'SAND_25C' ? 'Germinasi' : 'Vigor' }
      : null;
  return target && { ...target, id: row.entry_id, revision: row.revision };
}

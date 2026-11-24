import type {TswRaw} from './piTsw';
export type TswForm={form_export_version:1;read_only:true;authorizes_lot_release:false;id:string;test_code:string;lot_code:string;hybrid:string;site_code:string;stage_code:string;test_type:'TSW';numeric_value:number|null;unit_code:'GRAM';tested_at:string;attempt_no:number;revision_of_id:string|null;source_status:'DRAFT'|'SUBMITTED'|'VERIFIED'|'REVISION_REQUIRED';row_version:number;created_by:string;method_reference:string;equipment_reference:string;notes:string;reviewed_at:string|null;reviewed_by:string|null;reviewer_name:null;reviewer_name_recorded:false;review_reason:string|null;basis:'DIRECT_1000'|'EIGHT_100';tsw_raw:TswRaw|null};
export function tswFormState(r:TswForm){return {DRAFT:'DRAFT SUMBER PI - BELUM DIKIRIM',SUBMITTED:'SUMBER PI - MENUNGGU PEMERIKSAAN SPV',VERIFIED:'SUMBER PI DIVERIFIKASI SPV - BUKAN APPROVAL LAB',REVISION_REQUIRED:'SUMBER PI - PERLU REVISI'}[r.source_status];}
export function validateTswForm(r:TswForm){
 if(r.form_export_version!==1||r.read_only!==true||r.authorizes_lot_release!==false||r.test_type!=='TSW'||r.unit_code!=='GRAM'||!tswFormState(r)||!Number.isInteger(r.row_version)||r.row_version<1||r.reviewer_name_recorded!==false||r.reviewer_name!==null)throw Error('TSW_FORM');
 if(r.source_status==='VERIFIED'&&(!r.reviewed_at||!r.reviewed_by))throw Error('TSW_VERIFIER');
 if(r.basis==='EIGHT_100'){
  if(!r.tsw_raw||r.tsw_raw.weights_g.length!==8||r.tsw_raw.tsw_g!==r.numeric_value)throw Error('TSW_RAW');
 }else if(r.basis!=='DIRECT_1000'||r.tsw_raw!==null)throw Error('TSW_BASIS');
}
export const tswFormFilename=(r:TswForm,f:string)=>`Form-TSW-PI-${r.id}-v${r.row_version}.${f}`;

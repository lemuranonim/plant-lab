import ExcelJS from 'exceljs';
import {logbookTemplateBase64} from './labLogbookTemplate';
import {logbookOrigins,logbookStatuses,type LogbookEntry,type LogbookPage} from './labLogbook';
export type LogbookExport=LogbookPage&{export_version:1;read_only:true;history_included:false;authorizes_lot_release:false;lab_name:string;
 filters:{search:string;from:string|null;to:string|null;date_basis:string;origin:string;method:string;status:string}};
const date=(x:string|null)=>x?new Date(Date.parse(x)+7*3600000):null;
export function logbookExportFilename(r:LogbookExport){return `Rekap-Lab-${new Date(r.as_of).toISOString().replace(/[-:]/g,'').replace(/\.\d{3}Z$/,'Z')}.xlsx`;}
export function parseLogbookExportQuery(q:URLSearchParams){
 const known=['site','search','from','to','date_basis','origin','method','status'];
 if([...q.keys()].some(k=>!known.includes(k)||q.getAll(k).length!==1))throw Error('FILTER');
 const f={site:q.get('site')??'',search:q.get('search')??'',from:q.get('from')??'',to:q.get('to')??'',date_basis:q.get('date_basis')??'RECORDED',origin:q.get('origin')??'ALL',method:q.get('method')??'ALL',status:q.get('status')??'ALL'};
 if((f.site&&!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(f.site))||f.search.length>120
  ||[f.from,f.to].some(v=>v&&(!/^\d{4}-\d{2}-\d{2}$/.test(v)||!Number.isFinite(Date.parse(v+'T00:00:00Z'))||new Date(v+'T00:00:00Z').toISOString().slice(0,10)!==v))
  ||(f.from&&f.to&&f.from>f.to)||!['RECORDED','OBSERVED'].includes(f.date_basis)||!['ALL','PLANT','ROUTINE','MC'].includes(f.origin)
  ||!/^[A-Z][A-Z0-9_]{0,79}$/.test(f.method)||!(f.status==='ALL'||Object.hasOwn(logbookStatuses,f.status)))throw Error('FILTER');
 return {p_lab_site_id:f.site||null,p_search:f.search.trim(),p_from:f.from||null,p_to:f.to||null,p_date_basis:f.date_basis,p_origin:f.origin,p_method:f.method,p_status:f.status};
}
export function validateLogbookExport(r:LogbookExport){
 if(r.export_version!==1||r.read_only!==true||r.history_included!==false||r.authorizes_lot_release!==false||r.offset!==0||r.has_more!==false
  ||!Number.isInteger(r.total)||r.total<0||r.total>2000||r.entries.length!==r.total||!Number.isFinite(Date.parse(r.as_of)))throw Error('LOGBOOK_EXPORT');
 const ids=new Set<string>();let approved=0,draft=0,waiting=0,retest=0,other=0,missing=0;
 for(const e of r.entries){const id=e.entry_kind+':'+e.entry_id;if(ids.has(id)||!Object.hasOwn(logbookOrigins,e.entry_kind)||!Object.hasOwn(logbookStatuses,e.status)
   ||!['QA_APPROVED','UNAPPROVED','DRAFT_MEAN','MC_RECORD_MEAN'].includes(e.result_state)
   ||(e.result_percent!==null&&(!Number.isFinite(e.result_percent)||e.result_percent<0||e.result_percent>100))
   ||(e.result_state==='QA_APPROVED'&&e.status!=='APPROVED')||(e.status==='APPROVED'&&e.result_state!=='QA_APPROVED')
   ||(e.entry_kind==='MC_DRAFT'&&!(e.status==='DRAFT'&&e.result_state==='DRAFT_MEAN')&&!(e.result_state==='MC_RECORD_MEAN'&&['IN_REVIEW','RETURNED','VERIFIED_RECORD'].includes(e.status)))
   ||(e.entry_kind!=='MC_DRAFT'&&['MC_RECORD_MEAN','DRAFT_MEAN'].includes(e.result_state))
   ||![e.recorded_at,...[e.observed_at,e.reviewed_at].filter(Boolean)].every(v=>Number.isFinite(Date.parse(v!))))throw Error('LOGBOOK_ENTRY');
  ids.add(id);if(e.result_state==='QA_APPROVED')approved++;else if(!['DRAFT','IN_REVIEW','SUBMITTED','RETEST'].includes(e.status))other++;
  if(e.status==='DRAFT')draft++;if(['IN_REVIEW','SUBMITTED'].includes(e.status))waiting++;if(e.status==='RETEST')retest++;if(e.observed_at===null)missing++;
 }
 const s=r.summary;if(s.approved!==approved||s.draft!==draft||s.waiting_qa!==waiting||s.retest!==retest||s.other!==other||s.missing_observation_time!==missing)throw Error('LOGBOOK_SUMMARY');
}
const resultText=(e:LogbookEntry)=>e.result_state==='DRAFT_MEAN'?'Rata-rata 3 MC, masih draft':e.result_state==='MC_RECORD_MEAN'?'Rata-rata 3 MC; verifikasi catatan saja, bukan lulus/gagal':e.result_state==='QA_APPROVED'?'Analisis disetujui QA, bukan pelepasan lot':'Belum disetujui QA';
export async function logbookExportXlsx(r:LogbookExport){
 validateLogbookExport(r);const wb=new ExcelJS.Workbook();await wb.xlsx.load(Uint8Array.from(Buffer.from(logbookTemplateBase64,'base64')).buffer);
 const ws=wb.getWorksheet('Rekap Lab');if(!ws||wb.worksheets.length!==1)throw Error('LOGBOOK_TEMPLATE');
 const put=(cell:string,value:ExcelJS.CellValue,fmt?:string)=>{const c=ws.getCell(cell);c.style={...c.style};c.value=value;if(fmt)c.numFmt=fmt;};
 put('B3',r.lab_name);put('E3',date(r.as_of),'dd mmm yyyy hh:mm');put('B4',r.filters.date_basis==='OBSERVED'?'Pengamatan final / ukur MC aktual':'Pertama dicatat di aplikasi');
 put('E4',r.filters.from?new Date(r.filters.from+'T00:00:00Z'):null,'dd mmm yyyy');put('H4',r.filters.to?new Date(r.filters.to+'T00:00:00Z'):null,'dd mmm yyyy');
 put('B5',`Cari: ${r.filters.search||'semua'}; Asal: ${r.filters.origin}; Metode: ${r.filters.method}; Status: ${r.filters.status}`);
 for(const [cell,value] of [['B7',r.total],['E7',r.summary.approved],['H7',r.summary.draft],['K7',r.summary.waiting_qa],['N7',r.summary.retest]] as [string,number][])put(cell,value,'0');
 for(let i=0;i<r.entries.length;i++){
  const e=r.entries[i],row=ws.getRow(i+9),values:ExcelJS.CellValue[]=[logbookOrigins[e.entry_kind],e.lot_code,e.hybrid,e.stage_code,e.method_name,logbookStatuses[e.status],e.result_percent,resultText(e),e.sample_reference,e.request_code,e.run_code,e.attempt_no,e.revision,date(e.recorded_at),date(e.observed_at),date(e.reviewed_at),e.method_code,e.status,e.entry_kind,e.entry_id];row.values=values;
  row.height=Math.min(180,Math.max(30,...values.map((v,j)=>typeof v==='string'?Math.ceil(v.length/([25,23,18,10,30,29,13,39,30,26,26,12,10,23,23,23,25,25,20,39][j]||20))*13+8:30)));
  row.eachCell({includeEmpty:true},(c,col)=>{c.style={font:{name:'Arial',size:10,color:{argb:'FF172A3B'}},alignment:{vertical:'top',horizontal:typeof c.value==='number'||c.value instanceof Date?'right':'left',wrapText:true}};
   if([14,15,16].includes(col))c.numFmt='dd mmm yyyy hh:mm';else if(col===7&&typeof c.value==='number'){const n=(c.value.toFixed(6).replace(/0+$/,'').split('.')[1]??'').length;c.numFmt=n?'0.'+'0'.repeat(n):'0';}else if([12,13].includes(col))c.numFmt='0';
  });
 }
 if(!r.total)put('A6','Tidak ada catatan yang cocok dengan filter ini. Tidak ada baris data yang diterbitkan.');
 ws.views=[{state:'frozen',xSplit:2,ySplit:8,showGridLines:false}];ws.autoFilter=`A8:T${Math.max(8,r.total+8)}`;
 ws.pageSetup={paperSize:9,orientation:'landscape',scale:100,printArea:`A1:T${Math.max(8,r.total+8)}`,printTitlesRow:'8:8'};
 wb.creator='Advanta Laboratory';wb.title='Buku pengujian Lab';wb.subject='Salinan seluruh catatan sesuai filter diterapkan, bukan pelepasan lot';
 return new Uint8Array(await wb.xlsx.writeBuffer());
}

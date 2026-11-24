import ExcelJS from 'exceljs';
import {PDFDocument,rgb} from 'pdf-lib';
import fontkit from '@pdf-lib/fontkit';
import {readFile} from 'node:fs/promises';
import path from 'node:path';
import {routinePurpose,routineRevalidationNotes,validateRoutinePurpose,type RoutinePurpose,type RoutineDraft,type RoutineSummary} from './routineLabDraft';
import {retTemplateBase64} from './routineRetFormTemplate';
import {requestRetTemplateBase64} from './requestRetFormTemplate';

type RetSummary=RoutineSummary&{total_tested:number;total_radicle_at_least_2mm:number;ret_percent:number;elapsed_requirement_met:boolean};
export type RetFormRecord=RoutineDraft&{ret_form_version:1;read_only:true;authorizes_lot_release:false;
 export_status:'DRAFT'|'IN_REVIEW'|'APPROVED'|'RETEST'|'APPROVAL_INCOMPLETE';qa_approval_verified:boolean;
 qa_decision:string|null;lab_name:string;crop_category:string;test_purpose:RoutinePurpose;
 operator_names_recorded:false;snapshot_at:string};
export type RetPrintRecord=Omit<RetFormRecord,'revision'|'export_status'>&{revision:number|null;export_status:string;source?:'PLANT_REQUEST';
 request_context?:{request_id:string;request_code:string;plant_site_name:string;sample_code:string;receipt_code:string;dispatch_code:string|null;lab_accession:string|null;observation_note:string|null}};
const statusLabels:Record<string,string>={DRAFT:'DRAFT - BELUM DISETUJUI QA',IN_PROGRESS:'SEDANG DIUJI - BELUM ADA HASIL FINAL',SUBMITTED:'DIKIRIM UNTUK DIPERIKSA - BELUM DISETUJUI',IN_REVIEW:'MENUNGGU QA - BELUM DISETUJUI',
 APPROVED:'ANALISIS DISETUJUI QA - BUKAN PELEPASAN LOT',RETEST:'QA MEMINTA UJI ULANG',
 REJECTED:'ANALISIS DITOLAK QA',CANCELLED:'PENGUJIAN DIBATALKAN',
 APPROVAL_INCOMPLETE:'PERSETUJUAN BELUM LENGKAP - PERLU PEMERIKSAAN QA'};
const localDate=(v:string|null|undefined)=>v?new Date(Date.parse(v)+7*3600000):null;
const dateText=(v:unknown)=>v instanceof Date?v.toISOString().slice(0,16).replace('T',' ')+' WIB':String(v??'');
const numericText=(v:number|null)=>v===null?'':new Intl.NumberFormat('id-ID',{maximumFractionDigits:2}).format(v);
const summary=(r:RetPrintRecord)=>r.workflow?.summary as RetSummary|null|undefined;
const versionLabel=(r:RetPrintRecord)=>r.source==='PLANT_REQUEST'?`percobaan ${r.workflow?.attempt_no}`:`revisi ${r.revision}`;
export const retFormFilename=(r:RetPrintRecord,format:'pdf'|'xlsx')=>r.source==='PLANT_REQUEST'?`Form-RET-Request-${r.id}-${r.export_status}.${format}`:`Form-RET-${r.id}-r${r.revision}.${format}`;
export function validateRetForm(r:RetPrintRecord){
 validateRoutinePurpose(r);
 if(r.ret_form_version!==1||r.read_only!==true||r.authorizes_lot_release!==false||r.operator_names_recorded!==false||r.method_code!=='RET_16C_72H'
  ||!Object.hasOwn(statusLabels,r.export_status)||r.content.replicate_count!==4||r.content.observations.length!==4)throw Error('RET_FORM');
 if(r.source==='PLANT_REQUEST'){
  const q=r.request_context,w=r.workflow;
  if(r.revision!==null||!q?.request_id||!q.request_code||!q.sample_code||!q.receipt_code||!w||!(/^[0-9a-f-]{36}$/i.test(r.id))||w.run_id!==r.id||!/^LT-[A-Z0-9]{1,60}$/.test(w.run_code)
   ||!Number.isInteger(w.attempt_no)||w.attempt_no<1||r.status!==w.status||r.export_status==='DRAFT'
   ||(r.export_status!==r.status&&!(r.status==='APPROVED'&&r.export_status==='APPROVAL_INCOMPLETE')))throw Error('RET_REQUEST_SOURCE');
 }else if(!Number.isInteger(r.revision)||r.revision===null||r.revision<1)throw Error('RET_FORM');
 const counts=r.content.observations.map(o=>o.radicle_at_least_2mm);
 if(r.content.observations.some(o=>Object.keys(o).some(k=>k!=='radicle_at_least_2mm'))
  ||counts.some(v=>v!==null&&(!Number.isInteger(v)||v!<0||v!>100)))throw Error('RET_COUNTS');
 const s=summary(r);
 if(s){
  if(counts.some(v=>v===null)||s.calculation_code!=='RET_RADICLE_4X100_V1'||s.total_tested!==400||s.replicates.length!==4
   ||s.total_radicle_at_least_2mm!==counts.reduce<number>((n,v)=>n+v!,0)||s.ret_percent!==s.total_radicle_at_least_2mm/4
   ||s.vigour_percent!==s.ret_percent||s.replicates.some((rep,i)=>rep.tested!==100||rep.radicle_at_least_2mm!==counts[i]))throw Error('RET_SUMMARY');
 }
 if(r.export_status==='APPROVED'&&(!r.qa_approval_verified||!s?.within_tolerance||!s.elapsed_requirement_met||!r.workflow?.reviewer_id
  ||r.workflow.reviewer_id===r.workflow.analyst_id||!r.workflow.reviewed_at||r.qa_decision!=='APPROVE'
  ||!r.content.started_at||!r.content.final_at||!(Date.parse(r.content.final_at)-Date.parse(r.content.started_at)>=72*3600000)))throw Error('RET_QA');
 if(r.export_status==='DRAFT'&&s)throw Error('RET_DRAFT_RESULT');
}
function fields(r:RetPrintRecord):[number,string,unknown][]{
 const c=r.content,w=r.workflow,s=summary(r);
 const elapsed=c.started_at&&c.final_at?(Date.parse(c.final_at)-Date.parse(c.started_at))/3600000:null;
 const tolerance=!s?'Belum ada analisis tersimpan':s.within_tolerance===true?'Dalam toleransi':s.within_tolerance===false?'Di luar toleransi':'Aturan toleransi belum tersedia';
 const values:[number,string,unknown][]=[[6,'Lot / Tahap',`${r.lot_code} / ${r.stage_code}`],[7,'Hybrid / Jenis',`${r.hybrid} / ${r.crop_category}`],[8,'Laboratorium',r.lab_name],
  [9,'Label sampel',c.sample_reference],[10,r.source==='PLANT_REQUEST'?'Sampel diterima Lab (WIB)':'Sampel tersedia (WIB)',localDate(c.received_at)],[11,'Mulai pada 16 C (WIB)',localDate(c.started_at)],
  [12,'Pengamatan final (WIB)',localDate(c.final_at)],[13,'Lama aktual (jam)',elapsed],[14,'Jenis pengujian',routinePurpose(r)],
  [23,'Total radikula (benih)',s?.total_radicle_at_least_2mm??null],[24,'Hasil RET (%)',s?.ret_percent??null],[25,'Selisih (poin persen)',s?.gap_pp??null],
  [26,'Batas toleransi (pp)',s?.limit_pp??null],[27,'Penilaian toleransi',tolerance],[29,'Analis (ID akun)',w?.analyst_id??r.created_by??null],
  [30,'Pemeriksa QA (ID akun)',w?.reviewer_id??null],[31,'Waktu QA (WIB)',localDate(w?.reviewed_at)],[32,'Catatan QA',w?.review_reason??null],
  [34,'Kondisi / alat / catatan',c.note]];
 if(r.source==='PLANT_REQUEST'&&r.request_context){const q=r.request_context;values.push([15,'Permintaan / Plant',`${q.request_code} / ${q.plant_site_name}`],
  [28,'Pengiriman / penerimaan',[q.dispatch_code,q.receipt_code].filter(Boolean).join(' / ')],[33,'Nomor Lab',q.lab_accession],[35,'Catatan pengamatan',q.observation_note]);}
 return values.sort((a,b)=>a[0]-b[0]);
}
const notes=(r:RetPrintRecord)=>[
 'Kriteria: radikula minimal 2 mm. Rancangan 4 x 100 benih pada 16 C, minimal 72 jam sejak penempatan.',
 'Kosong belum dicatat, bukan nol. Pengamatan radikula bukan hitungan Normal/Abnormal/Mati.',
 r.source==='PLANT_REQUEST'?'Hasil dan toleransi mengambil analisis tersimpan. Uji belum selesai tidak menerbitkan hasil final atau persetujuan.':'Hasil dan toleransi mengambil analisis tersimpan. Draft belum menerbitkan hasil, toleransi atau persetujuan.',
 'Persetujuan analisis bukan izin pelepasan lot. Mengubah unduhan tidak mengubah data aplikasi.',
 'Nama analis/QA belum dicatat pada RET ini. ID akun bukan tanda tangan.',
 `Ref ${r.id} / ${versionLabel(r)} / run ${r.workflow?.run_code??'belum dikirim'}${r.source==='PLANT_REQUEST'?' / asal permintaan Plant':` / percobaan ${r.workflow?.attempt_no??'-'}`}`,
 `Rujukan uji ulang: ${r.retest_of_run_id??'tidak ada'}`,
 `Disimpan ${dateText(localDate(r.updated_at))} / salinan server ${dateText(localDate(r.snapshot_at))}`,
 `Perhitungan: ${summary(r)?.calculation_code??'belum ada analisis tersimpan'} v${summary(r)?.calculation_version??'-'}`,
 'Acuan: konfirmasi tim Plant/Lab, RET 2 mm, 4 x 100, 16 C, 72 jam, toleransi 4 Reps. Format RET terpisah dari Germinasi dan Vigor biasa.',
 ...routineRevalidationNotes(r),
];
export async function routineRetXlsx(r:RetPrintRecord){
 validateRetForm(r);const wb=new ExcelJS.Workbook();await wb.xlsx.load(Uint8Array.from(Buffer.from(r.source==='PLANT_REQUEST'?requestRetTemplateBase64:retTemplateBase64,'base64')).buffer);
 const ws=wb.getWorksheet('RET');if(!ws||wb.worksheets.length!==1)throw Error('RET_TEMPLATE');
 ws.pageSetup={paperSize:9,orientation:'portrait',fitToPage:true,fitToWidth:1,fitToHeight:0,printArea:'A1:H45',margins:{left:.3,right:.3,top:.3,bottom:.3,header:.15,footer:.15}};
 ws.views=[{showGridLines:false}];ws.headerFooter={oddFooter:'RET / Halaman &P dari &N'};
 const rowHeight=(v:unknown,width=42)=>Math.min(409,Math.max(28,String(v??'').split('\n').reduce((n,s)=>n+Math.max(1,Math.ceil(s.length/width)),0)*14+10));
 ws.getCell('A4').value=statusLabels[r.export_status];ws.getRow(4).height=rowHeight(statusLabels[r.export_status],80);
 for(const [row,label,value] of fields(r)){
  const cell=ws.getCell(row,4);cell.style={...cell.style};cell.value=value as ExcelJS.CellValue;cell.alignment={vertical:'top',horizontal:typeof value==='number'||value instanceof Date?'right':'left',wrapText:true};
  ws.getCell(row,1).value=label;ws.getCell(row,1).alignment={vertical:'top',horizontal:'left',wrapText:true};ws.getRow(row).height=rowHeight(value);
  if(value instanceof Date)cell.numFmt='dd mmm yyyy hh:mm';
  if(typeof value==='number')cell.numFmt=[13,24].includes(row)?'0.00':'0';
 }
 for(let i=0;i<4;i++)ws.getCell(17+i,5).value=r.content.observations[i].radicle_at_least_2mm;
 for(const [index,row] of [22,36,37,38,39,41,42,43,44,45].entries()){ws.getCell(row,1).value=notes(r)[index];ws.getRow(row).height=rowHeight(notes(r)[index],85);}
 let last=45;for(const note of notes(r).slice(10)){for(let start=0;start<note.length;start+=350){const part=note.slice(start,start+350);ws.mergeCells(`A${++last}:H${last}`);const c=ws.getCell(last,1);c.value=part;c.font={name:'Arial',size:9};c.alignment={wrapText:true,vertical:'top'};ws.getRow(last).height=rowHeight(part,85);}}
 ws.pageSetup.printArea=`A1:H${last}`;
 wb.creator='Advanta Laboratory';wb.title='Radicle Emergence Test';wb.subject=r.source==='PLANT_REQUEST'?'Salinan satu percobaan RET dari permintaan Plant':'Salinan satu pengujian RET dari revisi tersimpan';
 return new Uint8Array(await wb.xlsx.writeBuffer());
}
export async function routineRetPdf(r:RetPrintRecord){
 validateRetForm(r);const pdf=await PDFDocument.create();pdf.registerFontkit(fontkit);
 const font=await pdf.embedFont(await readFile(path.join(process.cwd(),'public/fonts/NotoSans-Regular.ttf')),{subset:true});
 const bold=await pdf.embedFont(await readFile(path.join(process.cwd(),'public/fonts/NotoSans-Bold.ttf')),{subset:true});
 const glyphs=new Set(font.getCharacterSet());for(const c of JSON.stringify(r)){if(!glyphs.has(c.codePointAt(0)!))throw Error('PDF_CHARACTER');}
 const W=595.28,H=841.89,M=28,CW=W-M*2;let page=pdf.addPage([W,H]),y=M;
 const draw=(t:string,x:number,top:number,size=9,strong=false)=>page.drawText(t,{x,y:H-top-size,size,font:strong?bold:font,color:rgb(.08,.14,.19)});
 function wrap(value:string,width:number,size=9,strong=false){
  const f=strong?bold:font,lines:string[]=[];for(const p of value.replace(/\r/g,'').split('\n')){let line='';
   for(const word of p.split(/\s+/).filter(Boolean)){const candidate=line?line+' '+word:word;if(f.widthOfTextAtSize(candidate,size)<=width){line=candidate;continue;}
    if(line){lines.push(line);line='';}for(const c of word){if(line&&f.widthOfTextAtSize(line+c,size)>width){lines.push(line);line='';}line+=c;}}
   lines.push(line);}return lines;
 }
 function heading(){y=M;for(const [t,size] of [['PT. ADVANTA SEEDS INDONESIA',10],['RADICLE EMERGENCE TEST (RET)',14],[statusLabels[r.export_status],9]] as [string,number][]){for(const line of wrap(t,CW,size,true)){draw(line,M,y,size,true);y+=size+4;}}page.drawLine({start:{x:M,y:H-y},end:{x:W-M,y:H-y},thickness:.5,color:rgb(.4,.5,.55)});y+=10;}
 function ensure(h:number){if(y+h>H-48){page=pdf.addPage([W,H]);heading();}}
 function paragraph(t:string,size=8,strong=false){for(const line of wrap(t,CW,size,strong)){ensure(size+4);draw(line,M,y,size,strong);y+=size+4;}y+=4;}
 function field(label:string,value:unknown){const left=wrap(label,154,9,true),right=wrap(typeof value==='number'?numericText(value):dateText(value),CW-163);
  for(let i=0;i<Math.max(left.length,right.length);i++){ensure(13);if(left[i])draw(left[i],M,y,9,true);if(right[i])draw(right[i],M+163,y);y+=13;}y+=3;}
 heading();for(const [,label,value] of fields(r).filter(x=>x[0]<16))field(label,value);
 ensure(130);const widths=[90,120,CW-210],headers=['Ulangan','Benih diuji','Radikula >= 2 mm (benih)'];
 for(let i=0;i<5;i++){let x=M;const values=i===0?headers:[String(i),'100',numericText(r.content.observations[i-1].radicle_at_least_2mm)];
  for(let j=0;j<3;j++){page.drawRectangle({x,y:H-y-22,width:widths[j],height:22,...(i===0?{color:rgb(.9,.94,.95)}:{}),borderWidth:.4,borderColor:rgb(.6,.7,.74)});draw(values[j],x+5,y+5,9,i===0);x+=widths[j];}y+=22;}
 y+=8;paragraph(notes(r)[0]);for(const [row,label,value] of fields(r).filter(x=>x[0]>=23)){if(row===32||row===34||row===35){paragraph(label,9,true);paragraph(dateText(value),9);}else field(label,value);}
 const closing=[...notes(r).slice(1,5).map(t=>({t,size:8})),...notes(r).slice(6).map(t=>({t,size:7}))];
 // Keep the short explanation/provenance block together instead of orphaning one line.
 ensure(closing.reduce((height,n)=>height+wrap(n.t,CW,n.size).length*(n.size+4)+4,0));
 for(const note of closing)paragraph(note.t,note.size);
 const pages=pdf.getPages();for(let i=0;i<pages.length;i++){page=pages[i];draw(`RET / ${versionLabel(r)} / halaman ${i+1} dari ${pages.length}`,M,H-33,8);draw(`ID ${r.id} / run ${r.workflow?.run_code??'-'} / percobaan ${r.workflow?.attempt_no??'-'}`,M,H-20,7);}
 pdf.setTitle('Radicle Emergence Test');pdf.setAuthor('Advanta Laboratory');return pdf.save();
}

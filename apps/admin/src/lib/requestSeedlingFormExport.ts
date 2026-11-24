import ExcelJS from 'exceljs';
import {PDFDocument,rgb,type PDFFont} from 'pdf-lib';
import fontkit from '@pdf-lib/fontkit';
import {readFile} from 'node:fs/promises';
import path from 'node:path';
import {requestSeedlingTemplateBase64} from './requestSeedlingFormTemplate';
export type SeedlingObservation={replicate_no:number;tested:number|null;normal:number|null;abnormal:number|null;dead:number|null;first_normal:number|null;remarks:string|null;fresh?:number|null;hard?:number|null;abnormal_kind?:string|null};
export type RequestSeedlingRecord={request_form_version:1|2;source:'PLANT_REQUEST';read_only:true;authorizes_lot_release:false;revision:number|null;
 id:string;run_code:string;status:string;export_status:string;qa_approval_verified:boolean;qa_decision:string|null;attempt_no:number;retest_of_run_id:string|null;
 request_id:string;request_code:string;plant_site_name:string;lot_code:string;hybrid:string;stage_code:string;crop_category:string;lab_name:string;
 test_code:'GERMINATION'|'VIGOUR';method_code:string;method_name:string;sample_reference:string;sample_code:string;lab_accession:string|null;receipt_code:string;dispatch_code:string|null;
 received_at:string;source_time_basis:'APPLICATION_EVENT_TIME'|'ANALYST_ACTUAL_INPUT';started_at:string|null;observed_at:string|null;first_count_at:string|null;
 available_at?:string|null;recorded_started_at?:string|null;recorded_final_at?:string|null;treatment_started_at?:string|null;crop_species?:string|null;analyst_name?:string|null;reviewer_name?:string|null;temperature_text?:string|null;detail_submitted?:boolean;
 conditions_note:string|null;observation_note:string|null;observations:SeedlingObservation[];
 summary:null|{replicates:{normal:number;abnormal:number;dead:number;fresh?:number;hard?:number;first_normal?:number|null}[];germination_percent?:number;vigour_percent?:number;unrounded_percent?:number;gap_pp:number;limit_pp:number|null;within_tolerance:boolean|null;calculation_code?:string};
 result_percent:number|null;result_value_matches_summary:boolean;analyst_id:string;reviewer_id:string|null;review_reason:string|null;reviewed_at:string|null;updated_at:string;snapshot_at:string};
export const seedlingStatus:Record<string,string>={IN_PROGRESS:'SEDANG DIUJI - BELUM ADA HASIL FINAL',SUBMITTED:'DIKIRIM UNTUK DIPERIKSA',IN_REVIEW:'MENUNGGU QA - BELUM DISETUJUI',APPROVED:'ANALISIS DISETUJUI QA - BUKAN PELEPASAN LOT',RETEST:'QA MEMINTA UJI ULANG',REJECTED:'ANALISIS DITOLAK QA',CANCELLED:'PENGUJIAN DIBATALKAN',APPROVAL_INCOMPLETE:'BUKTI PERSETUJUAN BELUM LENGKAP - PERLU PEMERIKSAAN QA'};
export const seedlingKind=(r:RequestSeedlingRecord)=>r.test_code==='GERMINATION'?'Germinasi':'Vigor';
const title=(r:RequestSeedlingRecord)=>r.test_code==='GERMINATION'?'GERMINATION TEST FORM':'VIGOUR TEST FORM';
const localDate=(v:string|null)=>v?new Date(Date.parse(v)+7*3600000):null;
const text=(v:unknown)=>v instanceof Date?v.toISOString().slice(0,16).replace('T',' ')+' WIB':v==null?'':typeof v==='number'?new Intl.NumberFormat('id-ID',{maximumFractionDigits:4}).format(v):String(v);
const tolerance=(r:RequestSeedlingRecord)=>!r.summary?'Belum ada hasil final':r.summary.within_tolerance===true?'Dalam toleransi':r.summary.within_tolerance===false?'Di luar toleransi':'Aturan toleransi belum tersedia';
export const requestSeedlingFilename=(r:RequestSeedlingRecord,format:'pdf'|'xlsx')=>`Form-${seedlingKind(r)}-Request-${r.id}-${r.export_status}.${format}`;
export function validateRequestSeedling(r:RequestSeedlingRecord){
 const germ=r.test_code==='GERMINATION',s=r.summary,rich=r.request_form_version===2;
 if(![1,2].includes(r.request_form_version)||r.source!=='PLANT_REQUEST'||r.read_only!==true||r.authorizes_lot_release!==false||(rich?(!Number.isInteger(r.revision)||r.revision!<1):r.revision!==null)
  ||!(/^[0-9a-f-]{36}$/i.test(r.id))||!/^LT-[A-Z0-9]{1,60}$/.test(r.run_code)||!r.request_id||!r.receipt_code||!r.sample_code
  ||!Number.isInteger(r.attempt_no)||r.attempt_no<1||!Object.hasOwn(seedlingStatus,r.export_status)||!Object.hasOwn(seedlingStatus,r.status)||r.status==='APPROVAL_INCOMPLETE'
  ||(r.export_status!==r.status&&!(r.status==='APPROVED'&&r.export_status==='APPROVAL_INCOMPLETE'))
  ||(germ?r.method_code!=='SAND_25C':r.test_code!=='VIGOUR'||!['AAT_42C_72H_RH90','COLD_TEST_5C_24H','SCT_10C7D_25C5D','AAT_EXT_42C_96H_RH90'].includes(r.method_code))
  ||r.source_time_basis!==((germ&&!rich)?'APPLICATION_EVENT_TIME':'ANALYST_ACTUAL_INPUT')
  ||(!rich&&!r.started_at)||(rich&&!germ&&!r.treatment_started_at)||![r.received_at,r.updated_at,r.snapshot_at,...[r.started_at,r.observed_at,r.first_count_at,r.reviewed_at,r.available_at,r.recorded_started_at,r.recorded_final_at,r.treatment_started_at].filter(Boolean)].every(v=>Number.isFinite(Date.parse(v!)))
  ||(rich&&!germ&&r.started_at&&Date.parse(r.started_at)<Date.parse(r.treatment_started_at!))
  ||(r.observed_at&&r.started_at&&Date.parse(r.observed_at)<Date.parse(r.started_at))||!(rich?[2]:[0,2,4]).includes(r.observations.length))throw Error('SEEDLING_SOURCE');
 for(const [i,o] of r.observations.entries()){
  if(o.replicate_no!==i+1||[o.normal,o.abnormal,o.dead,o.first_normal,o.tested,...(rich?[o.fresh??null,o.hard??null]:[])].some(v=>v!==null&&(!Number.isInteger(v)||v<0||v>30000))
   ||(rich&&(!Object.hasOwn(o,'fresh')||!Object.hasOwn(o,'hard')))
   ||(o.tested!==null&&(o.normal===null||o.abnormal===null||o.dead===null||(rich&&(o.fresh==null||o.hard==null))||o.tested!==o.normal+o.abnormal+o.dead+(rich?(o.fresh??0)+(o.hard??0):0)))
   ||(o.first_normal!==null&&o.tested!==null&&o.first_normal>o.tested))throw Error('SEEDLING_COUNTS');
 }
 if(s){
  const rows=r.observations,total=rows.reduce((n,o)=>n+(o.tested??0),0),normal=rows.reduce((n,o)=>n+(o.normal??0),0);
  if(!rows.length||rows.some(o=>o.tested===null||o.tested<=0||o.tested!==rows[0].tested)||s.replicates.length!==rows.length
   ||s.replicates.some((v,i)=>v.normal!==rows[i].normal||v.abnormal!==rows[i].abnormal||v.dead!==rows[i].dead||(rich&&(v.fresh!==rows[i].fresh||v.hard!==rows[i].hard||v.first_normal!==rows[i].first_normal)))
   ||(rich&&(r.detail_submitted!==true||rows.length!==2||rows.some(o=>o.tested!==100)))
   ||!r.result_value_matches_summary||r.result_percent!== (germ?s.germination_percent:s.vigour_percent)
   ||r.result_percent!==(germ?Math.floor((normal*10000+total/2)/total)/100:Math.round(normal/2))
   ||(!germ&&(rows.length!==2||rows.some(o=>o.tested!==100)||s.calculation_code!=='EXCEL_ROUND_AVERAGE_2X100'||s.unrounded_percent!==normal/2))
   ||!Number.isFinite(s.gap_pp)||(s.limit_pp!==null&&(!Number.isFinite(s.limit_pp)||s.limit_pp<0))
   ||s.within_tolerance!==(s.limit_pp===null?null:s.gap_pp<=s.limit_pp))throw Error('SEEDLING_SUMMARY');
 }else if(r.result_percent!==null||r.result_value_matches_summary||(!rich&&r.observed_at!==null))throw Error('SEEDLING_UNSAVED_RESULT');
 if(r.result_percent!==null&&(!Number.isFinite(r.result_percent)||r.result_percent<0||r.result_percent>100))throw Error('SEEDLING_RESULT');
 if(r.export_status==='APPROVED'&&(!s||!r.qa_approval_verified||r.qa_decision!=='APPROVE'||s.within_tolerance!==true||!r.reviewer_id||r.reviewer_id===r.analyst_id||!r.reviewed_at||(rich&&!r.reviewer_name)))throw Error('SEEDLING_QA');
 if([r.conditions_note,r.observation_note,r.review_reason,r.crop_species,r.analyst_name,r.reviewer_name,r.temperature_text,...r.observations.flatMap(o=>[o.remarks,o.abnormal_kind])].some(v=>v&&v.length>10000))throw Error('SEEDLING_NOTE_SIZE');
}
function design(r:RequestSeedlingRecord){const rows=r.observations;if(!rows.length||rows.some(o=>o.tested===null))return 'Pengamatan final belum lengkap';return `${rows.length} x ${rows[0].tested} benih (sumber)`;}
function timing(r:RequestSeedlingRecord){return r.request_form_version===2?`Tanggal tanam/first/final diisi Analis sesuai pekerjaan nyata. Sampel tersedia: ${text(localDate(r.available_at??null))||'belum dicatat'}. ${r.test_code==='VIGOUR'?'Mulai perlakuan dicatat terpisah dari tanggal tanam.':`Mulai dicatat aplikasi: ${text(localDate(r.recorded_started_at??null))}.`} Revisi ${r.revision}.`:r.source_time_basis==='APPLICATION_EVENT_TIME'?'Mulai/final adalah waktu tindakan tercatat di aplikasi, bukan tanggal tanam atau waktu pengamatan fisik yang diisi terpisah.':'Mulai perlakuan dan pengamatan final adalah waktu aktual yang dicatat Analis. Mulai perlakuan tidak otomatis berarti tanggal tanam.';}
function notes(r:RequestSeedlingRecord){return [
 !r.observations.length?'Belum ada pengamatan final. Dua baris kosong mengikuti rancangan acuan 2 x 100; bukan hitungan hasil.':'Satu baris per ulangan sumber. Jumlah benih lama tidak diubah atau dipecah menjadi subulangan baru.',
 r.request_form_version===2?'Sel kosong belum dicatat, bukan nol. Lima kategori final disimpan terpisah. First count tidak dijumlahkan ke final. Subreps tetap kosong: unit sumber100 benih tidak dipecah. DAP tidak dibuat otomatis.':'Sel kosong belum dicatat, bukan nol. Subreps, Fresh/Hard, jenis abnormal, tanaman/spesies, tanggal tanam, DAP serta nama yang belum dicatat tidak dibuat otomatis. First count tidak dijumlahkan ke final.',
 'Persetujuan analisis bukan pelepasan lot atau sertifikasi otomatis pelaksanaan fisik. Salinan nilai tersimpan; mengubah unduhan tidak mengubah data aplikasi.',
 `Ref ${r.id} / ${r.run_code} / percobaan ${r.attempt_no}${r.revision===null?'':` / revisi ${r.revision}`} / sumber permintaan Plant.`,
];}
function metadata(r:RequestSeedlingRecord):[number,string,unknown,string,unknown][]{const germ=r.test_code==='GERMINATION',rich=r.request_form_version===2;return [
 [7,'Hybrid / tahap',`${r.hybrid} / ${r.stage_code}`,'Plant / Lab',`${r.plant_site_name} / ${r.lab_name}`],
 [8,'Lot',r.lot_code,'Permintaan / percobaan',`${r.request_code} / ${r.attempt_no}`],
 [9,'Label sampel',r.sample_reference,'Sampel diterima (WIB)',localDate(r.received_at)],
 [10,'Pengiriman',r.dispatch_code,'Penerimaan / no. Lab',[r.receipt_code,r.lab_accession].filter(Boolean).join(' / ')],
 [11,'Metode',r.method_name,'Ulangan tersimpan',design(r)],
 [12,germ?(rich?'Tanam aktual (WIB)':'Mulai tercatat (WIB)'):'Mulai perlakuan (WIB)',localDate(!germ&&rich?r.treatment_started_at??null:r.started_at),germ&&!rich?'Final tercatat (WIB)':'Pengamatan final (WIB)',localDate(r.observed_at)],
 [13,'Tanaman / spesies',rich?r.crop_species:null,'Tanggal tanam',rich?localDate(r.started_at):null],[14,rich?'First count aktual':'First count tercatat',localDate(r.first_count_at),'DAP',null],
 [15,'Nama analis',rich?r.analyst_name:null,'Nama pemeriksa',rich?r.reviewer_name:null],[16,'Nomor uji',r.run_code,'Jenis pengujian',r.retest_of_run_id?'Retest Verification':'Initial'],
 [25,'Hasil tersimpan (%)',r.result_percent,'Selisih (poin persen)',r.summary?.gap_pp??null],
 [26,'Batas toleransi (pp)',r.summary?.limit_pp??null,'Penilaian toleransi',tolerance(r)],
 [27,'Analis (ID akun)',r.analyst_id,'Pemeriksa (ID akun)',r.reviewer_id],
 [28,'Waktu QA (WIB)',localDate(r.reviewed_at),'Rujukan uji ulang',r.retest_of_run_id],
 [32,'Sumber diperbarui',localDate(r.updated_at),'Salinan server (WIB)',localDate(r.snapshot_at)],
 [33,'Kode hitung tersimpan',r.summary?.calculation_code??null,'Jenis / sumber',`${r.crop_category} / permintaan Plant`],
 ];}
const tableHeads=['Reps','Subreps*','Benih\ndiamati','Normal\n1st count','Normal\nfinal','Abnormal','Fresh*','Hard*','Mati','Jenis abnormal*','Catatan sumber'];
function bodyRows(r:RequestSeedlingRecord){return (r.observations.length?r.observations:Array.from({length:2},(_,i)=>({replicate_no:i+1,tested:null,normal:null,abnormal:null,dead:null,first_normal:null,remarks:null} as SeedlingObservation))).map(o=>[o.replicate_no,null,o.tested,o.first_normal,o.normal,o.abnormal,r.request_form_version===2?o.fresh:null,r.request_form_version===2?o.hard:null,o.dead,r.request_form_version===2?o.abnormal_kind:null,o.remarks]);}
const conditions=(r:RequestSeedlingRecord)=>r.request_form_version===2?[r.temperature_text?`Suhu aktual: ${r.temperature_text} °C`:null,r.conditions_note].filter(Boolean).join('\n')||null:r.conditions_note;
export async function requestSeedlingXlsx(r:RequestSeedlingRecord){
 validateRequestSeedling(r);const wb=new ExcelJS.Workbook();await wb.xlsx.load(Uint8Array.from(Buffer.from(requestSeedlingTemplateBase64,'base64')).buffer);
 const ws=wb.getWorksheet('Pengujian');if(!ws||wb.worksheets.length!==1)throw Error('SEEDLING_TEMPLATE');ws.name=seedlingKind(r);
 const height=(v:unknown,width:number)=>Math.max(26,Math.ceil(String(v??'').length/width)*13+8);
 const put=(row:number,col:number,value:ExcelJS.CellValue)=>{const c=ws.getCell(row,col);c.style={...c.style};c.value=value;c.alignment={vertical:'top',horizontal:typeof value==='number'||(value instanceof Date&&r.request_form_version===1)?'right':'left',wrapText:true};if(value instanceof Date)c.numFmt='dd mmm yyyy hh:mm';if(typeof value==='number')c.numFmt=Number.isInteger(value)?'0':'0.00';};
 put(4,1,title(r));put(5,1,seedlingStatus[r.export_status]);
 for(const [row,l,v,rr,vv] of metadata(r)){put(row,1,l);put(row,3,v as ExcelJS.CellValue);put(row,7,rr);put(row,9,vv as ExcelJS.CellValue);ws.getRow(row).height=Math.max(height(v,43),height(vv,53),36);}
 const full=(row:number,value:string)=>{put(row,1,value);ws.getRow(row).height=height(value,140);};full(17,timing(r));full(18,notes(r)[0]);
 const rows=bodyRows(r),extra:string[]=[];
 for(let i=0;i<4;i++){const row=ws.getRow(20+i);row.hidden=i>=rows.length;if(row.hidden)continue;const values=rows[i].map((v,j)=>{if((j===10||j===9)&&typeof v==='string'&&v.length>140){extra.push(`Ulangan ${i+1}, ${j===9?'jenis abnormal':'catatan'}: ${v}`);return 'Lihat catatan lanjutan di bawah.';}return v;});row.values=values;row.height=Math.max(30,height(values[10],33),height(values[9],20));row.eachCell({includeEmpty:true},(c,col)=>{c.style={font:{name:'Arial',size:10},alignment:{vertical:'top',horizontal:col<=9?'right':'left',wrapText:true}};if(col<=9)c.numFmt='0';});}
 for(const [row,label,value] of [[29,'Catatan QA',r.review_reason],[30,'Kondisi / alat',conditions(r)],[31,'Catatan pengamatan',r.observation_note]] as [number,string,string|null][]){put(row,1,label);put(row,3,value);ws.getRow(row).height=height(value,120);}
 full(34,'Jumlah benih mengikuti catatan sumber, bukan diubah mengikuti rancangan baru.');full(35,notes(r)[1]);full(36,notes(r)[2]);full(37,notes(r)[3]);
 let last=37;for(const note of extra){for(let start=0;start<note.length;start+=400){last+=1;ws.mergeCells(`A${last}:K${last}`);put(last,1,note.slice(start,start+400));ws.getCell(last,1).font={name:'Arial',size:10};ws.getRow(last).height=height(note.slice(start,start+400),145);}}
 ws.views=[{showGridLines:false}];ws.pageSetup={paperSize:9,orientation:'landscape',fitToPage:true,fitToWidth:1,fitToHeight:0,printArea:`A1:K${last}`,printTitlesRow:'19:19',margins:{left:.25,right:.25,top:.25,bottom:.3,header:.1,footer:.1}};ws.headerFooter={oddFooter:`${seedlingKind(r)} / Halaman &P dari &N`};
 wb.creator='Advanta Laboratory';wb.title=title(r);wb.subject='Salinan satu percobaan dari permintaan Plant, sesuai grain sumber';return new Uint8Array(await wb.xlsx.writeBuffer());
}
export async function requestSeedlingPdf(r:RequestSeedlingRecord){
 validateRequestSeedling(r);const pdf=await PDFDocument.create();pdf.registerFontkit(fontkit);
 const font=await pdf.embedFont(await readFile(path.join(process.cwd(),'public/fonts/NotoSans-Regular.ttf')),{subset:true}),bold=await pdf.embedFont(await readFile(path.join(process.cwd(),'public/fonts/NotoSans-Bold.ttf')),{subset:true});
 const glyphs=new Set(font.getCharacterSet());for(const c of JSON.stringify(r)){if(!glyphs.has(c.codePointAt(0)!))throw Error('PDF_CHARACTER');}
 const W=841.89,H=595.28,M=26,CW=W-M*2;let page=pdf.addPage([W,H]),y=M;
 const draw=(t:string,x:number,top:number,size=9,strong=false)=>page.drawText(t,{x,y:H-top-size,size,font:strong?bold:font,color:rgb(.08,.14,.19)});
 function wrap(v:unknown,width:number,size=9,f:PDFFont=font){const lines:string[]=[];for(const p of text(v).replace(/\r/g,'').split('\n')){let line='';for(const word of p.split(/\s+/).filter(Boolean)){if(f.widthOfTextAtSize(line?line+' '+word:word,size)<=width){line=line?line+' '+word:word;continue;}if(line){lines.push(line);line='';}for(const c of word){if(line&&f.widthOfTextAtSize(line+c,size)>width){lines.push(line);line='';}line+=c;}}lines.push(line);}return lines;}
 function heading(){y=M;for(const [t,size] of [['Quality Assurance Laboratory',10],['PT. ADVANTA SEEDS INDONESIA',10],[title(r),13],[seedlingStatus[r.export_status],9]] as [string,number][]){for(const line of wrap(t,CW,size,bold)){draw(line,M,y,size,true);y+=size+3;}}draw(`${r.run_code} / percobaan ${r.attempt_no} / ${r.request_code}`,M,y,8);y+=15;}
 function ensure(h:number){if(y+h>H-40){page=pdf.addPage([W,H]);heading();}}
 function para(v:unknown,size=8,strong=false){for(const line of wrap(v,CW,size,strong?bold:font)){ensure(size+4);draw(line,M,y,size,strong);y+=size+4;}y+=3;}
 function pair(l:string,v:unknown,rr:string,vv:unknown){const parts=[wrap(l,126,9,bold),wrap(v,251),wrap(rr,126,9,bold),wrap(vv,CW-529)];const n=Math.max(...parts.map(p=>p.length));for(let i=0;i<n;i++){ensure(13);for(const [j,x] of [0,134,395,529].entries())if(parts[j][i])draw(parts[j][i],M+x,y,9,j%2===0);y+=13;}y+=3;}
 heading();for(const [,l,v,rr,vv] of metadata(r).filter(x=>x[0]<=16&&(![13,14,15].includes(x[0])||x[2]!==null||x[4]!==null)))pair(l,v,rr,vv);para(timing(r));para(notes(r)[0]);
 const widths=[40,50,69,65,65,65,52,52,52,106,CW-616];
 function tableHeader(){ensure(44);let x=M;for(let i=0;i<11;i++){page.drawRectangle({x,y:H-y-34,width:widths[i],height:34,color:rgb(.9,.94,.95),borderWidth:.4,borderColor:rgb(.55,.65,.7)});for(const [j,line] of wrap(tableHeads[i],widths[i]-8,8,bold).entries())draw(line,x+4,y+3+j*10,8,true);x+=widths[i];}y+=34;}
 tableHeader();for(const values of bodyRows(r)){const lines=values.map((v,j)=>wrap(v,widths[j]-8,9));let lineIndex=0;const max=Math.max(...lines.map(l=>l.length));while(lineIndex<max){if(y+20>H-40){page=pdf.addPage([W,H]);heading();tableHeader();}const count=Math.min(max-lineIndex,Math.floor((H-40-y-6)/12));if(count<1)throw Error('PDF_TABLE_SPACE');const h=count*12+6;let x=M;for(let j=0;j<11;j++){page.drawRectangle({x,y:H-y-h,width:widths[j],height:h,borderWidth:.4,borderColor:rgb(.6,.7,.74)});for(let k=0;k<count;k++){const t=j===0&&k===0&&lineIndex>0?`${values[0]} (lanj.)`:lines[j][lineIndex+k];if(t)for(const [n,line] of wrap(t,widths[j]-8,9).entries())draw(line,x+4,y+3+(k+n)*12);}x+=widths[j];}y+=h;lineIndex+=count;}}
 y+=7;for(const [,l,v,rr,vv] of metadata(r).filter(x=>x[0]>=25))pair(l,v,rr,vv);
 for(const [label,v] of [['Catatan QA',r.review_reason],['Kondisi / alat',conditions(r)],['Catatan pengamatan',r.observation_note]] as [string,string|null][]){if(v){ensure(28);para(label,9,true);para(v,9);}}
 for(const note of notes(r).slice(1))para(note);const pages=pdf.getPages();for(let i=0;i<pages.length;i++){page=pages[i];draw(`${seedlingKind(r)} / ${r.run_code} / percobaan ${r.attempt_no} / halaman ${i+1} dari ${pages.length}`,M,H-26,8);}
 pdf.setTitle(title(r));pdf.setAuthor('Advanta Laboratory');return pdf.save();
}

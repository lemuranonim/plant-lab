import ExcelJS from 'exceljs';
import {PDFDocument,rgb} from 'pdf-lib';
import fontkit from '@pdf-lib/fontkit';
import {readFile} from 'node:fs/promises';
import path from 'node:path';
import {tswTemplateBase64} from './piTswFormTemplate';
import {tswState} from './piTsw';
import {tswFormState,validateTswForm,type TswForm} from './piTswForm';
const date=(v:string|null)=>v?new Date(new Date(v).getTime()+7*3600000):null;
const number=(v:number|null)=>v===null?'':new Intl.NumberFormat('id-ID',{maximumFractionDigits:6}).format(v);
const basis=(r:TswForm)=>r.basis==='EIGHT_100'?'8 x 100 benih - 800 ditimbang, dikonversi per 1.000':'Timbang langsung 1.000 benih';
const calculation=(r:TswForm)=>r.tsw_raw?tswState(r.tsw_raw.calculation_state):'Basis langsung: rata-rata/CV/kernel per ulangan belum dicatat.';
function fields(r:TswForm):[number,string,unknown][]{return [
 [6,'Lot / Stage',`${r.lot_code} / ${r.stage_code}`],[7,'Hybrid',r.hybrid],[8,'Site',r.site_code],
 [9,'Date of Test (WIB)',date(r.tested_at)],[10,'Dasar penimbangan',basis(r)],
 [22,'Metode aktual',r.method_reference],[23,'Alat / timbangan',r.equipment_reference],[24,'Pelaksana (ID akun)',r.created_by],
 [25,'Verificator (ID akun)',r.reviewed_by],[26,'Waktu periksa SPV (WIB)',date(r.reviewed_at)],[27,'Nama pemeriksa','Belum dicatat'],[28,'Catatan SPV',r.review_reason],[29,'Remarks',r.notes],
 ];}
const notes=(r:TswForm)=>[
 r.basis==='EIGHT_100'?'8 x 100: 800 benih ditimbang. TSW adalah konversi per 1.000 benih, bukan timbang langsung 1.000.':'Timbang langsung 1.000 benih. Delapan bacaan, rata-rata, CV dan kernel tidak diisi dengan angka tebakan.',
 'CV mengikuti variance populasi dibagi 8 pada file acuan. Batas 4% bukan spesifikasi mutu baru. Tampilan maksimal 6 desimal; pemeriksaan memakai angka asli.',
 'VERIFIED adalah verifikasi sumber PI, bukan approval hasil Lab atau pelepasan lot.',
 'Snapshot versi tersimpan. Mengubah file unduhan tidak mengubah catatan resmi di aplikasi.',
 `Ref ${r.test_code} / versi sumber ${r.row_version} / percobaan ${r.attempt_no} / versi timbangan ${r.tsw_raw?.source_row_version??'tidak ada'}`,
 `ID ${r.id}${r.revision_of_id?' / revisi dari '+r.revision_of_id:''}`,
 'Acuan format: All Form.xlsx - TSW & Kernel Count. Hitungan: KC Lab, MC,PP,TSW!AJ3:BI3.',
];
export async function tswFormXlsx(r:TswForm){
 validateTswForm(r);
 // The static layout is authored with Artifact Tool; this adapter only fills a saved DB snapshot.
 const wb=new ExcelJS.Workbook();await wb.xlsx.load(Uint8Array.from(Buffer.from(tswTemplateBase64,'base64')).buffer);
 const ws=wb.getWorksheet('TSW');if(!ws||wb.worksheets.length!==1)throw Error('TSW_TEMPLATE');
 ws.pageSetup={paperSize:9,orientation:'portrait',fitToPage:true,fitToWidth:1,fitToHeight:0,printArea:'A1:H38',margins:{left:.3,right:.3,top:.35,bottom:.35,header:.15,footer:.15}};
 ws.views=[{showGridLines:false}];
 const height=(v:unknown,chars:number)=>Math.max(28,String(v??'').split('\n').reduce((n,line)=>n+Math.max(1,Math.ceil(line.length/chars)),0)*14);
 ws.getCell('A4').value=tswFormState(r);ws.getRow(4).height=height(tswFormState(r),80);
 for(const [row,,v] of fields(r)){
  const cell=ws.getCell(row,3);cell.value=v as ExcelJS.CellValue;
  cell.alignment={...cell.alignment,vertical:'top',wrapText:true};
  ws.getCell(row,1).alignment={...ws.getCell(row,1).alignment,vertical:'top',wrapText:true};
  // Merged cells have no reliable auto-fit in Excel. Leave room for wide glyphs.
  ws.getRow(row).height=Math.min(409,Math.max(32,height(v,42)+12));
 }
 for(const row of [9,26])ws.getCell(row,3).numFmt='dd mmm yyyy hh:mm';
 for(let i=0;i<8;i++)ws.getCell(14,i+1).value=r.tsw_raw?.weights_g[i]??null;
 ws.getCell('E16').value=r.tsw_raw?.mean_100_g??null;ws.getCell('E17').value=r.tsw_raw?.cv_percent??null;
 ws.getCell('E18').value=r.numeric_value;ws.getCell('E19').value=r.tsw_raw?.kernel_per_kg??null;
 for(const address of ['A14','B14','C14','D14','E14','F14','G14','H14','E16','E17','E18','E19']){
  const cell=ws.getCell(address),v=cell.value;
  if(typeof v==='number'){
   const decimals=(v.toFixed(6).replace(/0+$/,'').split('.')[1]??'').length;
   cell.numFmt=decimals?'#,##0.'+'0'.repeat(decimals):'#,##0';
  }
 }
 ws.getCell('A20').value=calculation(r);ws.getRow(20).height=height(calculation(r),80);
 for(const [i,row] of [31,32,33,34,36,37,38].entries()){ws.getCell(row,1).value=notes(r)[i];ws.getRow(row).height=height(notes(r)[i],84);}
 wb.creator='Advanta Plant / Lab';wb.title='TSW & Kernel Count - sumber PI';wb.subject='Snapshot satu sumber pada versi tersimpan';
 return new Uint8Array(await wb.xlsx.writeBuffer());
}
export async function tswFormPdf(r:TswForm){
 validateTswForm(r);const pdf=await PDFDocument.create();pdf.registerFontkit(fontkit);
 const font=await pdf.embedFont(await readFile(path.join(process.cwd(),'public/fonts/NotoSans-Regular.ttf')),{subset:true});
 const bold=await pdf.embedFont(await readFile(path.join(process.cwd(),'public/fonts/NotoSans-Bold.ttf')),{subset:true});
 const glyphs=new Set(font.getCharacterSet());for(const c of JSON.stringify(r)){if(!glyphs.has(c.codePointAt(0)!))throw Error('PDF_CHARACTER');}
 const W=595.28,H=841.89,M=28,CW=W-2*M;let page=pdf.addPage([W,H]),y=M;
 function wrap(value:string,width:number,size=9,strong=false){
  const f=strong?bold:font,lines:string[]=[];
  for(const paragraph of value.replace(/\r/g,'').split('\n')){
   let line='';
   for(const word of paragraph.split(/\s+/).filter(Boolean)){
    const candidate=line?line+' '+word:word;
    if(f.widthOfTextAtSize(candidate,size)<=width){line=candidate;continue;}
    if(line){lines.push(line);line='';}
    // Only an individual overlong code/word may be split between characters.
    for(const c of word){if(line&&f.widthOfTextAtSize(line+c,size)>width){lines.push(line);line='';}line+=c;}
   }
   lines.push(line);
  }
  return lines;
 }
 function draw(t:string,x:number,top:number,size=9,strong=false){page.drawText(t,{x,y:H-top-size,font:strong?bold:font,size,color:rgb(.08,.14,.19)});}
 function heading(){y=M;for(const [t,size] of [['PT. ADVANTA SEEDS INDONESIA',11],['TSW & KERNEL COUNT RECORDS',14],[tswFormState(r),9]] as [string,number][]){for(const l of wrap(t,CW,size,true)){draw(l,M,y,size,true);y+=size+5;}}page.drawLine({start:{x:M,y:H-y},end:{x:W-M,y:H-y},thickness:.6,color:rgb(.3,.4,.45)});y+=12;}
 function ensure(h:number){if(y+h>H-55){page=pdf.addPage([W,H]);heading();}}
 function paragraph(value:string,strong=false,size=9){for(const l of wrap(value,CW,size,strong)){ensure(size+4);draw(l,M,y,size,strong);y+=size+4;}y+=6;}
 function field(label:string,value:string){const left=wrap(label,145,9,true),right=wrap(value,CW-155),count=Math.max(left.length,right.length);ensure(count*13+8);for(let i=0;i<count;i++){if(left[i])draw(left[i],M,y,9,true);if(right[i])draw(right[i],M+155,y);y+=13;}y+=6;}
 heading();
 for(const [,label,v] of fields(r).filter(x=>x[0]<=10)){field(label,v instanceof Date?v.toISOString().slice(0,16).replace('T',' ')+' WIB':String(v??''));}
 ensure(90);paragraph('Berat masing-masing 100 benih (g)',true);
 const width=CW/8,values=Array.from({length:8},(_,i)=>number(r.tsw_raw?.weights_g[i]??null));
 const rows=values.map(t=>wrap(t,width-8)),height=Math.max(25,...rows.map(a=>a.length*13+8));
 for(let i=0;i<8;i++){const x=M+i*width;page.drawRectangle({x,y:H-y-21,width,height:21,color:rgb(.9,.94,.95),borderWidth:.5,borderColor:rgb(.55,.65,.7)});draw(`Rep ${i+1}`,x+5,y+4,9,true);page.drawRectangle({x,y:H-y-21-height,width,height,borderWidth:.5,borderColor:rgb(.55,.65,.7)});for(let j=0;j<rows[i].length;j++)draw(rows[i][j],x+4,y+25+j*13);}
 y+=21+height+12;
 for(const [label,value] of [['Rata-rata 100 benih (g)',r.tsw_raw?.mean_100_g??null],['CV populasi (%)',r.tsw_raw?.cv_percent??null],['TSW (g per 1.000 benih)',r.numeric_value],['Kernel/kg (hasil hitung)',r.tsw_raw?.kernel_per_kg??null]] as [string,number|null][])field(label,number(value));
 paragraph(calculation(r));
 for(const [row,label,v] of fields(r).filter(x=>x[0]>=22)){if(row===28||row===29){paragraph(label,true);paragraph(String(v??''));}else field(label,v instanceof Date?v.toISOString().slice(0,16).replace('T',' ')+' WIB':String(v??''));}
 for(const n of notes(r).slice(0,4))paragraph(n,false,8);
 paragraph(notes(r)[6],false,8);
 const pages=pdf.getPages();for(let i=0;i<pages.length;i++){page=pages[i];draw(`${r.test_code} / versi ${r.row_version} / halaman ${i+1} dari ${pages.length}`,M,H-37,8);draw(`ID ${r.id} / percobaan ${r.attempt_no} / timbangan v${r.tsw_raw?.source_row_version??'-'}`,M,H-24,7);}
 return pdf.save();
}

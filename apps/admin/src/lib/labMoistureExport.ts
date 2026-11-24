import ExcelJS from 'exceljs';
import {PDFDocument,rgb} from 'pdf-lib';
import fontkit from '@pdf-lib/fontkit';
import {readFile} from 'node:fs/promises';
import path from 'node:path';
import {wibInput} from './routineLabDraft';
import {moistureStatus,type MoistureDraft} from './labMoisture';
const date=(v:string|null)=>v?wibInput(v).replace('T',' ')+' WIB':'';
const text=(v:unknown)=>v==null?'':String(v);
function validate(r:MoistureDraft){if(!['DRAFT','IN_REVIEW','RETURNED','VERIFIED_RECORD'].includes(r.status)||r.content.version!==1||r.content.readings.length!==3||r.qa_enabled!==false
 ||(r.status!=='DRAFT'&&(!r.submission_id||r.submitted_revision!==r.revision))
 ||(r.status==='VERIFIED_RECORD'&&(r.review?.decision!=='VERIFY_RECORD'||r.review.revision!==r.revision))
 ||(r.status==='RETURNED'&&(r.review?.decision!=='RETURN'||r.review.revision!==r.revision)))throw Error('MC_FORM');}
const title='MOISTURE CONTENT RECORDS';
const state=(r:MoistureDraft)=>`MC LAB - ${moistureStatus(r.status).toUpperCase()}`;
const reviewText=(r:MoistureDraft)=>r.review?`QA: ${r.review.reviewer_name} / ${r.review.decision==='RETURN'?'Dikembalikan':'Catatan diverifikasi'} / revisi ${r.review.revision} / ${date(r.review.reviewed_at)} / ${r.review.note??''}`:'QA: belum ada verifikasi catatan.';
const disclaimer='Verifikasi QA hanya untuk catatan pengukuran. Tidak menilai toleransi/lulus-gagal, tidak menyetujui hasil mutu, dan bukan pelepasan lot.';
const labels=['No.','Hybrid','Lot No.','Type of Sample','Date of Receive','Date of Test','MC1 (%)','MC2 (%)','MC3 (%)','AVG (%)','Remarks'];
function values(r:MoistureDraft){return [1,r.hybrid,r.lot_code,r.content.sample_type,date(r.content.received_at),date(r.content.measured_at),...r.content.readings,r.mean_percent,r.content.note];}
export async function moistureXlsx(r:MoistureDraft){
 validate(r);const wb=new ExcelJS.Workbook(),ws=wb.addWorksheet('MC Lab',{pageSetup:{paperSize:9,orientation:'landscape',fitToPage:true,fitToWidth:1,fitToHeight:0},views:[{showGridLines:false}]});
 ws.columns=[5,16,22,18,25,25,10,10,10,12,35].map(width=>({width}));
 const line=(row:number,value:string)=>{ws.mergeCells(row,1,row,11);ws.getCell(row,1).value=value;ws.getRow(row).height=Math.max(24,Math.ceil(value.length/130)*14);};
 line(2,'PT. ADVANTA SEEDS INDONESIA');line(3,title);line(4,state(r));
 line(6,`Lab: ${r.lab_name} / Stage: ${r.stage_code} / Label: ${r.content.sample_reference??''}`);
 const longNote=(r.content.note?.length??0)>100||/[\r\n]/.test(r.content.note??'');
 const rowValues=values(r);if(longNote)rowValues[10]='Lihat Remarks lengkap di bawah';
 ws.getRow(8).values=labels;ws.getRow(8).height=36;ws.getRow(9).values=rowValues;
 ws.getRow(9).height=Math.max(46,Math.ceil((longNote?30:r.content.note?.length??0)/30)*13);
 line(11,`Pelaksana: ${r.content.analyst_name??''}`);line(12,`Alat: ${r.content.instrument??''}`);line(13,`Metode aktual: ${r.content.method??''}`);
 line(15,'AVG hanya tersedia jika 3 pembacaan lengkap. Angka cetak 2 desimal; bacaan asli tetap tersimpan. Kosong bukan nol.');
 line(16,disclaimer);line(17,reviewText(r));
 line(18,`Ref ${r.id} / revisi ${r.revision} / disimpan ${date(r.updated_at)} / akun pelaksana ${r.created_by}`);
 let last=18;
 if(longNote){line(20,'Remarks lengkap');last=20;for(const paragraph of (r.content.note??'').replace(/\r/g,'').split('\n')){for(let start=0;start<Math.max(1,paragraph.length);start+=125)line(++last,paragraph.slice(start,start+125));}}
 ws.eachRow((row,n)=>row.eachCell({includeEmpty:true},c=>{c.font={name:'Arial',size:n===3?14:n>=15?9:10,bold:[2,3,4,8].includes(n)};c.alignment={vertical:'middle',wrapText:true};if(n===8||n===9)c.border={top:{style:'thin'},bottom:{style:'thin'},left:{style:'thin'},right:{style:'thin'}};if(n===8)c.fill={type:'pattern',pattern:'solid',fgColor:{argb:'FFE2E8E5'}};}));
 for(let col=7;col<=10;col++)ws.getCell(9,col).numFmt='0.00';
 ws.pageSetup.printArea=`A1:K${last}`;return new Uint8Array(await wb.xlsx.writeBuffer());
}
export async function moisturePdf(r:MoistureDraft){
 validate(r);const pdf=await PDFDocument.create();pdf.registerFontkit(fontkit);
 const font=await pdf.embedFont(await readFile(path.join(process.cwd(),'public/fonts/NotoSans-Regular.ttf')),{subset:true});
 const bold=await pdf.embedFont(await readFile(path.join(process.cwd(),'public/fonts/NotoSans-Bold.ttf')),{subset:true});
 const all=JSON.stringify(values(r))+JSON.stringify([r.lab_name,r.content.sample_reference,r.content.analyst_name,r.content.instrument,r.content.method,reviewText(r)]);
 const glyphs=new Set(font.getCharacterSet());for(const c of all){if(!glyphs.has(c.codePointAt(0)!))throw Error('PDF_CHARACTER');}
 const W=841.89,H=595.28,M=28,CW=W-2*M;let page=pdf.addPage([W,H]),y=M;
 const wrap=(value:string,width:number,size=8)=>{const lines:string[]=[];for(const p of value.replace(/\r/g,'').split('\n')){let line='';for(const word of p.split(/\s+/)){if(line&&font.widthOfTextAtSize(line+' '+word,size)>width){lines.push(line);line='';}for(const c of (line?' ':'')+word){if(line&&font.widthOfTextAtSize(line+c,size)>width){lines.push(line);line='';}line+=c;}}lines.push(line);}return lines;};
 function draw(value:string,x:number,top:number,width:number,size=8,strong=false){const lines=wrap(value,width,size);for(let i=0;i<lines.length;i++)page.drawText(lines[i],{x,y:H-top-size-i*(size+3),font:strong?bold:font,size});return lines.length*(size+3);}
 function heading(){y=M;y+=draw('PT. ADVANTA SEEDS INDONESIA',M,y,CW,11,true)+5;y+=draw(title,M,y,CW,14,true)+7;y+=draw(state(r),M,y,CW,10,true)+12;}
 function line(value:string){for(const s of wrap(value,CW)){if(y>H-55){page=pdf.addPage([W,H]);heading();}draw(s,M,y,CW);y+=12;}y+=5;}
 heading();line(`Lab: ${r.lab_name} / Stage: ${r.stage_code} / Label sampel: ${r.content.sample_reference??''}`);
 const widths=[24,70,95,75,100,100,50,50,50,80,92],vals=values(r); // sum786pt
 if(Math.abs(widths.reduce((a,b)=>a+b,0)-CW)>1)throw Error('MC_GRID');
 let x=M;for(let i=0;i<labels.length;i++){page.drawRectangle({x,y:H-y-38,width:widths[i],height:38,color:rgb(.88,.91,.89),borderWidth:.5,borderColor:rgb(.4,.4,.4)});draw(labels[i],x+3,y+4,widths[i]-6,7,true);x+=widths[i];}y+=38;
 // Keep the table readable; long remarks continue below with the same meaning.
 const cells=vals.map((v,i)=>i===10?(v?'Lihat catatan di bawah':''):i>=6&&i<=9&&typeof v==='number'?v.toFixed(2):text(v));
 const height=Math.max(40,...cells.map((v,i)=>wrap(v,widths[i]-6,7).length*10+8));
 x=M;for(let i=0;i<cells.length;i++){page.drawRectangle({x,y:H-y-height,width:widths[i],height,borderWidth:.5,borderColor:rgb(.4,.4,.4)});draw(cells[i],x+3,y+4,widths[i]-6,7);x+=widths[i];}y+=height+14;
 line(`Pelaksana: ${r.content.analyst_name??''}`);line(`Alat: ${r.content.instrument??''}`);line(`Metode aktual: ${r.content.method??''}`);line(`Remarks: ${r.content.note??''}`);
 line('AVG hanya tersedia jika 3 pembacaan lengkap. Angka cetak 2 desimal; bacaan asli tetap tersimpan. Kosong bukan nol.');
 line(reviewText(r));line(disclaimer);
 const pages=pdf.getPages();for(let i=0;i<pages.length;i++){page=pages[i];draw(`Ref ${r.id} / revisi ${r.revision} / halaman ${i+1} dari ${pages.length}`,M,H-31,CW,7);}
 return pdf.save();
}

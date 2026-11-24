// Server-only renderers. Input is a fresh, scoped, saved revision from the RPC.
import ExcelJS from 'exceljs';
import { PDFDocument, rgb, type PDFFont, type PDFPage } from 'pdf-lib';
import fontkit from '@pdf-lib/fontkit';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { wibInput,routinePurpose,routineRevalidationNotes,validateRoutinePurpose,type RoutinePurpose, type RoutineDraft } from './routineLabDraft';

export type FormRecord = RoutineDraft & { form_export_version: 1; lab_name: string; crop_category: string;
  reviewer_name: string | null; test_purpose: RoutinePurpose };
const heads=['Reps','Sub reps','Normal\n1st count','Normal\nFinal count','Abn\nSeed','Fresh\nSeed','Hard\nSeed','Dead\nSeed','Total\nNormal','Total\nAbn','Total\nFresh','Total\nHard','Total\nDead','Kind of Abnormal Seed','Remarks'];
const keys=['first_normal','final_normal','abnormal','fresh','hard','dead'];
const categories=['final_normal','abnormal','fresh','hard','dead'];
const label=(x:unknown)=>x===null||x===undefined?'':String(x);
const date=(x:string|null|undefined)=>x?`${wibInput(x).replace('T',' ')} WIB`:'';
export function formDap(planted:string|null|undefined,observed:string|null|undefined):number|null {
  if(!planted||!observed)return null;
  return Math.round((Date.parse(wibInput(observed).slice(0,10)+'T00:00:00Z')-Date.parse(wibInput(planted).slice(0,10)+'T00:00:00Z'))/86400000);
}
function status(r:FormRecord){return ({DRAFT:'DRAFT - BELUM DISETUJUI QA',IN_REVIEW:'MENUNGGU QA - BELUM DISETUJUI',APPROVED:'ANALISIS DISETUJUI QA - BUKAN PELEPASAN LOT',RETEST:'QA MEMINTA UJI ULANG - REPEATED'} as Record<string,string>)[r.workflow?.status??r.status]??'BELUM DISETUJUI';}
function title(r:FormRecord){return r.method_code==='SAND_25C'?'GERMINATION TEST FORM':'VIGOUR TEST FORM';}
function totals(r:FormRecord,i:number):(number|null)[]{return categories.map(k=>{
  const a=r.content.observations[i]?.[k],b=r.content.observations[i+1]?.[k];
  return a==null||b==null?null:a+b;
});}
function annotation(r:FormRecord,i:number){return r.content.form?.annotations[i]??{abnormal_kind:null,remarks:null};}
function summary(r:FormRecord){
  const s=r.workflow?.summary;
  const mean=s?categories.map((_,i)=>{
    const fields=['normal','abnormal','fresh','hard','dead'];const vals=s.replicates.map(x=>x[fields[i]]);
    return vals.every(v=>typeof v==='number')?(vals as number[]).reduce((a,b)=>a+b,0)/vals.length:null;
  }):[null,null,null,null,null];
  const normals=s?.replicates.map(x=>x.normal).filter((x):x is number=>typeof x==='number')??[];
  return {mean,rounded:s?.germination_percent??s?.vigour_percent??null,max:normals.length?Math.max(...normals):null,min:normals.length?Math.min(...normals):null,
    gap:s?.gap_pp??null,limit:s?.limit_pp??null,conclusion:r.workflow?.status==='APPROVED'?'Accepted (analisis QA)':r.workflow?.status==='RETEST'?'Repeated':r.workflow?.status==='IN_REVIEW'?'Menunggu QA':'Draft'};
}
function metadata(r:FormRecord):[string,string,string,string][]{
  const f=r.content.form;const dap=(observed:string|null|undefined)=>{const d=formDap(f?.planted_at,observed);return d==null?'':` / ${d} DAP`;};
  return [
    ['Crop / Species',label(f?.crop_species),'Date of Planting',date(f?.planted_at)],
    ['Hybrid',r.hybrid,'Reading First Count',date(f?.first_count_at)+dap(f?.first_count_at)],
    ['Lot No.',r.lot_code,'Reading Final Count',date(r.content.final_at)+dap(r.content.final_at)],
    [r.method_code==='SAND_25C'?'Media':'Method',r.method_code==='SAND_25C'?'Sand / Pasir':r.method_name,'Sample label',label(r.content.sample_reference)],
    ['Temperature (°C)',label(f?.temperature_text),'Replications',`${r.content.replicate_count} x 100 benih`],
    ['Stage',r.stage_code,'Type of Test',routinePurpose(r)],
  ];
}
function validate(r:FormRecord){
  if(r.form_export_version!==1||r.method_code==='RET_16C_72H'||![2,4].includes(r.content.replicate_count)||r.content.observations.length!==r.content.replicate_count*2)throw Error('FORM_METHOD');
  validateRoutinePurpose(r);
}
export function formFilename(r:FormRecord,format:'pdf'|'xlsx'){return `Form-${r.method_code==='SAND_25C'?'Germinasi':'Vigor'}-${r.id}-r${r.revision}.${format}`;}

export async function routineFormXlsx(r:FormRecord):Promise<Uint8Array>{
  validate(r);
  const wb=new ExcelJS.Workbook();wb.creator='Advanta Laboratory';wb.title=title(r);
  const ws=wb.addWorksheet(r.method_code==='SAND_25C'?'Germinasi':'Vigor',{views:[{showGridLines:false}],pageSetup:{paperSize:9,orientation:'landscape',fitToPage:true,fitToWidth:1,fitToHeight:0,margins:{left:.25,right:.25,top:.3,bottom:.3,header:.1,footer:.1}}});
  ws.columns=[5,7,8,8,7,7,7,7,8,8,8,8,8,25,27].map(width=>({width}));
  function merge(row:number,left:number,right:number,value:unknown){ws.mergeCells(row,left,row,right);ws.getCell(row,left).value=value==null?null:String(value);}
  for(const [row,text] of [[2,'Quality Assurance Laboratory'],[3,'PT. ADVANTA SEEDS INDONESIA'],[4,title(r)]] as const){merge(row,1,15,text);ws.getRow(row).height=22;ws.getCell(row,1).font={name:'Arial',size:row===4?14:11,bold:true};ws.getCell(row,1).alignment={horizontal:'center',vertical:'middle'};}
  merge(5,1,15,status(r));ws.getRow(5).height=22;ws.getCell(5,1).font={name:'Arial',size:10,bold:true};
  metadata(r).forEach((m,i)=>{const row=7+i;merge(row,1,2,m[0]);merge(row,3,8,m[1]);merge(row,9,12,m[2]);merge(row,13,15,m[3]);ws.getRow(row).height=30;});
  merge(13,1,2,'Conditions / Notes');merge(13,3,15,label(r.content.note));ws.getRow(13).height=Math.max(28,Math.ceil(label(r.content.note).length/115)*13);
  const header=15;ws.getRow(header).values=heads;ws.getRow(header).height=42;
  ws.getRow(header).eachCell(c=>{c.fill={type:'pattern',pattern:'solid',fgColor:{argb:'FFD9D9D9'}};c.font={name:'Arial',size:9,bold:true};c.alignment={vertical:'middle',horizontal:'center',wrapText:true};});
  let row=16;
  for(let i=0;i<r.content.observations.length;i+=2){
    const tt=totals(r,i);
    for(let j=0;j<2;j++){
      const note=annotation(r,i+j),source=r.content.observations[i+j];
      ws.getRow(row+j).values=[j===0?Math.floor(i/2)+1:null,`${Math.floor(i/2)+1}${j?'b':'a'}`,...keys.map(k=>source[k]),...tt.map(x=>j?null:x),note.abnormal_kind,note.remarks];
      ws.getRow(row+j).height=Math.max(23,Math.ceil(Math.max(label(note.abnormal_kind).length/25,label(note.remarks).length/27))*12+6);
    }
    ws.mergeCells(row,1,row+1,1);for(let col=9;col<=13;col++)ws.mergeCells(row,col,row+1,col);row+=2;
  }
  const end=row-1, s=summary(r);
  merge(row,1,8,'Average per ulangan');for(let i=0;i<5;i++)ws.getCell(row,9+i).value=s.mean[i];ws.getCell(row,14).value='Seed Analyst';ws.getCell(row,15).value=r.content.form?.analyst_name??null;
  merge(row+1,1,8,'Round Normal');ws.getCell(row+1,9).value=s.rounded;ws.getCell(row+1,14).value='Checked by';ws.getCell(row+1,15).value=r.reviewer_name;
  merge(row+2,1,8,'Max Normal');ws.getCell(row+2,9).value=s.max;merge(row+2,10,12,'Diff');ws.getCell(row+2,13).value=s.gap;merge(row+2,14,15,'Conclusion');
  merge(row+3,1,8,'Min Normal');ws.getCell(row+3,9).value=s.min;merge(row+3,10,12,'Tolerance');ws.getCell(row+3,13).value=s.limit;merge(row+3,14,15,s.conclusion);
  for(let n=row;n<=row+3;n++)ws.getRow(n).height=28;
  ws.getRow(row).height=Math.max(28,Math.ceil(label(r.content.form?.analyst_name).length/23)*13+6);
  ws.getRow(row+1).height=Math.max(28,Math.ceil(label(r.reviewer_name).length/23)*13+6);
  merge(row+5,1,15,'Sel kosong belum dicatat, bukan nol. First count tidak ditambahkan ke final kumulatif. DAP = selisih tanggal WIB sejak tanam.');
  merge(row+6,1,15,'Persetujuan analisis bukan pelepasan lot. Salinan nilai tersimpan; perubahan file tidak mengubah data aplikasi.');
  merge(row+7,1,15,`Ref ${r.id} / revisi ${r.revision} / run ${r.workflow?.run_code??'belum dikirim'} / ${r.lab_name}`);
  merge(row+8,1,15,`Disimpan ${date(r.updated_at)} / QA ${date(r.workflow?.reviewed_at)} / ID Analis ${r.created_by??r.workflow?.analyst_id??'belum tersedia'} / ID QA ${r.workflow?.reviewer_id??'belum ada'}`);
  if(!r.content.form){merge(row+9,1,15,'Catatan versi lama: rincian form belum dicatat. Tidak diisi atau ditandatangani ulang secara otomatis.');ws.getRow(row+9).height=24;}
  ws.eachRow((rr,n)=>{rr.eachCell({includeEmpty:true},(c,col)=>{
    if(n!==2&&n!==3&&n!==4&&n!==5&&n!==header)c.font={name:'Arial',size:n>row+4?8:10};
    if(n!==header)c.alignment={vertical:'middle',horizontal:n>=16&&n<=end&&col<=13?'center':'left',wrapText:true};
    if(n>=header&&n<=row+3)c.border={top:{style:'thin',color:{argb:'FF707070'}},left:{style:'thin',color:{argb:'FF707070'}},bottom:{style:'thin',color:{argb:'FF707070'}},right:{style:'thin',color:{argb:'FF707070'}}};
    if(n>=16&&n<=end&&col>=3&&col<=13)c.numFmt='0';
    if(n===row&&col>=9&&col<=13)c.numFmt='0.##';
  });});
  for(let n=row+5;n<=row+9;n++)if(ws.getRow(n).hasValues)ws.getRow(n).height=26;
  let finalRow=row+(r.content.form?8:9);
  for(const note of routineRevalidationNotes(r)){for(let start=0;start<note.length;start+=350){const part=note.slice(start,start+350);merge(++finalRow,1,15,part);ws.getCell(finalRow,1).font={name:'Arial',size:8};ws.getCell(finalRow,1).alignment={wrapText:true,vertical:'top'};ws.getRow(finalRow).height=Math.max(25,Math.ceil(part.length/135)*13+8);}}
  ws.pageSetup.printArea=`A1:O${finalRow}`;
  ws.pageSetup.printTitlesRow='15:15';ws.headerFooter.oddFooter='Halaman &P dari &N';
  const bytes=await wb.xlsx.writeBuffer();return new Uint8Array(bytes);
}

export async function routineFormPdf(r:FormRecord):Promise<Uint8Array>{
  validate(r);const pdf=await PDFDocument.create();pdf.registerFontkit(fontkit);
  const font=await pdf.embedFont(await readFile(path.join(process.cwd(),'public/fonts/NotoSans-Regular.ttf')),{subset:true});
  const bold=await pdf.embedFont(await readFile(path.join(process.cwd(),'public/fonts/NotoSans-Bold.ttf')),{subset:true});
  const glyphs=new Set(font.getCharacterSet());
  const allText=[...metadata(r).flat(),...routineRevalidationNotes(r),label(r.content.note),r.content.form?.analyst_name,r.reviewer_name,...r.content.observations.flatMap((_,i)=>Object.values(annotation(r,i)))].join('');
  for(const char of allText){if(!/[\n\r\t]/.test(char)&&!glyphs.has(char.codePointAt(0)!))throw Error('PDF_CHARACTER');}
  pdf.setTitle(title(r));pdf.setAuthor('Advanta Laboratory');
  const W=841.89,H=595.28,M=24,CW=W-2*M;let page:PDFPage;let y=0;
  const border=rgb(.38,.38,.38),gray=rgb(.86,.86,.86);
  function lines(text:string,width:number,size:number,face:PDFFont=font){
    const out:string[]=[];for(const paragraph of text.replace(/\r/g,'').split('\n')){
      let current='';for(const word of paragraph.split(/\s+/)){
        const joined=current?current+' '+word:word;
        if(current&&face.widthOfTextAtSize(joined,size)>width){out.push(current);current='';}
        if(face.widthOfTextAtSize(word,size)>width){
          for(const char of word){if(current&&face.widthOfTextAtSize(current+char,size)>width){out.push(current);current='';}current+=char;}
        }else current=current?current+' '+word:word;
      }out.push(current);
    }return out;
  }
  function text(textValue:string,x:number,top:number,width:number,size=8,face:PDFFont=font){
    const ll=lines(textValue,width,size,face);for(let i=0;i<ll.length;i++)page.drawText(ll[i],{x,y:H-top-size-i*(size+2),size,font:face});return ll.length*(size+2);
  }
  function rect(x:number,top:number,w:number,h:number,fill?:ReturnType<typeof rgb>){page.drawRectangle({x,y:H-top-h,width:w,height:h,borderWidth:.45,borderColor:border,...(fill?{color:fill}:{})});}
  function newPage(continuation=false){page=pdf.addPage([W,H]);y=M;text('Quality Assurance Laboratory',M,y,CW,10,bold);y+=16;text('PT. ADVANTA SEEDS INDONESIA',M,y,CW,10,bold);y+=16;text(title(r)+(continuation?' - lanjutan':''),M,y,CW,13,bold);y+=23;text(status(r),M,y,CW,9,bold);y+=19;}
  function need(height:number){if(y+height>H-54)newPage(true);}
  newPage();
  for(const m of metadata(r)){
    const left=`${m[0]}: ${m[1]}`,right=`${m[2]}: ${m[3]}`;
    const height=Math.max(lines(left,CW*.60-10,8).length,lines(right,CW*.40,8).length)*10+4;
    text(left,M,y,CW*.60-10);text(right,M+CW*.60,y,CW*.40);y+=height;
  }
  const condition=`Conditions / Notes: ${label(r.content.note)}`;
  for(const line of lines(condition,CW,8)){need(12);text(line,M,y,CW);y+=11;}
  y+=8;
  const widths=[24,30,36,36,30,30,30,30,35,35,35,35,35,(CW-421)/2,(CW-421)/2];
  // The first thirteen columns total421pt; the remaining width holds row notes.
  const sum=widths.reduce((a,b)=>a+b,0);if(Math.abs(sum-CW)>.1)throw Error('PDF_GRID');
  function header(){let x=M;for(let i=0;i<heads.length;i++){rect(x,y,widths[i],34,gray);text(heads[i],x+3,y+3,widths[i]-6,6.6,bold);x+=widths[i];}y+=34;}
  header();
  for(let i=0;i<r.content.observations.length;i+=2){
    const pairRows=[0,1].map(j=>[j?'':String(i/2+1),`${i/2+1}${j?'b':'a'}`,...keys.map(k=>label(r.content.observations[i+j][k])),...totals(r,i).map(v=>j?'':label(v)),label(annotation(r,i+j).abnormal_kind),label(annotation(r,i+j).remarks)]);
    const height=Math.max(17,...pairRows.flatMap(rr=>rr.map((v,col)=>lines(v,widths[col]-6,7).length*9+6)));
    if(y+height*2>H-54){newPage(true);header();}
    for(let j=0;j<2;j++){let x=M;for(let col=0;col<15;col++){
      if(col===0||(col>=8&&col<=12)){if(j===0){rect(x,y,widths[col],height*2);text(pairRows[0][col],x+3,y+4,widths[col]-6,7);}}
      else {rect(x,y,widths[col],height);text(pairRows[j][col],x+3,y+4,widths[col]-6,7);}
      x+=widths[col];}y+=height;}
  }
  const s=summary(r);need(86);y+=9;
  const summaries=[`Average per ulangan: Normal ${label(s.mean[0])}; Abnormal ${label(s.mean[1])}; Fresh ${label(s.mean[2])}; Hard ${label(s.mean[3])}; Dead ${label(s.mean[4])}`,
    `Round Normal: ${label(s.rounded)}    Max: ${label(s.max)}    Min: ${label(s.min)}    Diff: ${label(s.gap)}    Tolerance: ${label(s.limit)}    Conclusion: ${s.conclusion}`,
    `Seed Analyst: ${label(r.content.form?.analyst_name)}    Checked by: ${label(r.reviewer_name)}    QA: ${date(r.workflow?.reviewed_at)}`,
    'Sel kosong belum dicatat, bukan nol. First count tidak ditambahkan ke final kumulatif. DAP dihitung dari tanggal tanam dalam WIB.',
    'Persetujuan analisis bukan pelepasan lot. Salinan nilai tersimpan; perubahan file tidak mengubah data aplikasi.'];
  if(!r.content.form)summaries.push('Catatan versi lama: rincian form belum dicatat. Tidak diisi atau ditandatangani ulang secara otomatis.');
  summaries.push(...routineRevalidationNotes(r));
  for(const s of summaries)for(const line of lines(s,CW,8)){need(12);text(line,M,y,CW,8);y+=12;}
  const pages=pdf.getPages();for(let i=0;i<pages.length;i++){page=pages[i];text(`Ref ${r.id} / revisi ${r.revision} / ${r.workflow?.run_code??'belum dikirim'} / halaman ${i+1} dari ${pages.length}`,M,H-31,CW,7);}
  return pdf.save();
}

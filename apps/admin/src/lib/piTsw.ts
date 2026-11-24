export type TswRaw={weights_g:(number|null)[];entered_count:number;mean_100_g:number|null;cv_percent:number|null;tsw_g:number|null;kernel_per_kg:number|null;calculation_state:string;source_row_version?:number};
export const tswNumber=(v:number|null)=>v===null?'Belum tersedia':new Intl.NumberFormat('id-ID',{maximumFractionDigits:6}).format(v);
export const tswState=(s:string)=>({INCOMPLETE:'Lengkapi 8 timbangan',ZERO_MEAN:'Periksa bacaan nol',WITHIN_WORKBOOK_REFERENCE:'CV dalam acuan file (maksimal 4%)',RECOUNT_WORKBOOK_REFERENCE:'Perlu hitung/timbang ulang menurut acuan file (CV >4%)'}[s]??s);
export function previewTsw(w:(number|null)[]):TswRaw{
 const n=w.filter(x=>x!==null).length,empty={weights_g:w,entered_count:n,mean_100_g:null,cv_percent:null,tsw_g:null,kernel_per_kg:null};
 if(w.length!==8||n!==8||w.some(x=>x===null||!Number.isFinite(x)||x<0||x>100000))return {...empty,calculation_state:'INCOMPLETE'};
 const a=w as number[],mean=a.reduce((x,y)=>x+y,0)/8,variance=a.reduce((s,x)=>s+(x-mean)**2,0)/8;
 if(mean<=0)return {...empty,mean_100_g:mean,calculation_state:'ZERO_MEAN'};
 const cv=Math.sqrt(variance)/mean*100,within=variance<=mean*mean*.0016+mean*mean*1e-14;
 return {...empty,mean_100_g:mean,cv_percent:cv,tsw_g:within?mean*10:null,kernel_per_kg:within?100000/(mean):null,calculation_state:within?'WITHIN_WORKBOOK_REFERENCE':'RECOUNT_WORKBOOK_REFERENCE'};
}

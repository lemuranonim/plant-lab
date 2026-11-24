export type SampleSite={id:string;site_name:string};
export type SampleRequestRow={id:string;status:string;lot_code:string;hybrid:string;plant_site:string;lab_site:string;purpose:string;requested_at:string;sample_label:string|null;sent_grams:number|null;sent_note:string|null;sent_at:string|null;received_grams:number|null;received_note:string|null;received_at:string|null;closure_note:string|null};
export type SamplePage={version:1;selected_site_id:string;sites:SampleSite[];can_write:boolean;rows:SampleRequestRow[];total:number;offset:number;limit:number;has_more:boolean};

export function parseSamplePage(p:SamplePage,offset:number,site:string|null){
 if(p?.version!==1||typeof p.selected_site_id!=='string'||!Array.isArray(p.rows)||!Array.isArray(p.sites)||p.offset!==offset||(site&&p.selected_site_id!==site)
   ||!p.sites.some(s=>s.id===p.selected_site_id)||typeof p.can_write!=='boolean'||p.limit!==30||p.rows.length>p.limit
   ||!Number.isInteger(p.total)||p.total<0||p.has_more!==(p.total>offset+p.limit))throw Error('SAMPLE_SCOPE');
 return p;
}

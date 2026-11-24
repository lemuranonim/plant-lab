import {redirect} from 'next/navigation';
import {requireCurrentVariantAccess} from '@/lib/accessContext';
import {getAppVariant} from '@/lib/appVariant';
import {hostedPilot,isolatedApiSchema} from '@/lib/supabase/config';
import {createClient} from '@/lib/supabase/server';
import type {RoutineOptions} from '@/lib/routineLabDraft';
import type {MoisturePage} from '@/lib/labMoisture';
import MoistureWorkspace from './MoistureWorkspace';
export const revalidate=0;
export default async function MoisturePageView(){
 const access=await requireCurrentVariantAccess();
 if(!hostedPilot||getAppVariant().code!=='LAB'||!access.roles.some(r=>r.module_code==='LAB'&&['LAB_ANALYST','LAB_QA_APPROVER'].includes(r.role_code)))redirect('/access-denied');
 const api=(await createClient()).schema(isolatedApiSchema),options=await api.rpc('get_routine_lab_options');
 if(options.error||!options.data)return <section role="alert" className="card"><h1>MC Lab</h1><p>Data belum dimuat. Periksa koneksi dan penugasan, lalu muat ulang.</p></section>;
 const records=await api.rpc('list_lab_moisture_drafts',{p_lab_site_id:options.data.selected_lab_site_id});
 return <MoistureWorkspace initialOptions={options.data as RoutineOptions} initialPage={records.error?null:records.data as MoisturePage}/>;
}

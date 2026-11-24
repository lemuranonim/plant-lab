import {redirect} from 'next/navigation';
import {requireCurrentVariantAccess} from '@/lib/accessContext';
import {getAppVariant} from '@/lib/appVariant';
import {hostedPilot,isolatedApiSchema} from '@/lib/supabase/config';
import {createClient} from '@/lib/supabase/server';
import {validateMonitorPage} from '@/lib/labMonitoring';
import LabMonitoring from './LabMonitoring';
export const revalidate=0;
export default async function LabMonitoringPage(){
 const access=await requireCurrentVariantAccess();
 if(!hostedPilot||getAppVariant().code!=='LAB'||!access.roles.some(r=>r.module_code==='LAB'&&['LAB_ANALYST','LAB_QA_APPROVER'].includes(r.role_code)))redirect('/access-denied');
 const response=await (await createClient()).schema(isolatedApiSchema).rpc('get_lab_work_monitoring');
 let page=null;try{if(!response.error)page=validateMonitorPage(response.data);}catch{}
 return <LabMonitoring initialPage={page}/>;
}

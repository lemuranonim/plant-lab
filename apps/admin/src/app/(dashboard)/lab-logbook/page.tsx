import {redirect} from 'next/navigation';
import {requireCurrentVariantAccess} from '@/lib/accessContext';
import {getAppVariant} from '@/lib/appVariant';
import {hostedPilot,isolatedApiSchema} from '@/lib/supabase/config';
import {createClient} from '@/lib/supabase/server';
import type {LogbookPage} from '@/lib/labLogbook';
import LabLogbookWorkspace from './LabLogbookWorkspace';
export const revalidate=0;
export default async function LabLogbook(){
 const access=await requireCurrentVariantAccess();
 if(!hostedPilot||getAppVariant().code!=='LAB'||!access.roles.some(r=>r.module_code==='LAB'&&['LAB_ANALYST','LAB_QA_APPROVER'].includes(r.role_code)))redirect('/access-denied');
 const result=await (await createClient()).schema(isolatedApiSchema).rpc('get_lab_logbook');
 return <LabLogbookWorkspace initialPage={result.error?null:result.data as LogbookPage}/>;
}

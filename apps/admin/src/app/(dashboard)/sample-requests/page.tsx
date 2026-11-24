import {redirect} from 'next/navigation';
import {requireCurrentVariantAccess} from '@/lib/accessContext';
import {getAppVariant} from '@/lib/appVariant';
import {canonicalWritesEnabled,isolatedApiSchema,plantSampleRequestsEnabled} from '@/lib/supabase/config';
import {createClient} from '@/lib/supabase/server';
import {parseSamplePage,type SamplePage} from '@/lib/plantSampleRequests';
import SampleRequests from './SampleRequests';

export default async function Page(){
 const access=await requireCurrentVariantAccess();
 const variant=getAppVariant().code;
 const roles=variant==='PLANT'?['PLANT_OPERATOR','PLANT_SPV']:['LAB_ANALYST','LAB_QA_APPROVER'];
 if(!plantSampleRequestsEnabled||!access.roles.some(r=>r.module_code===variant&&roles.includes(r.role_code)))redirect('/access-denied');
 let initialPage:SamplePage|null=null;
 try{
  const {data,error}=await (await createClient()).schema(isolatedApiSchema).rpc('list_plant_sample_requests',{p_module:variant,p_status:'ACTIVE'});
  if(!error)initialPage=parseSamplePage(data,0,null);
 }catch{}
 return <SampleRequests module={variant} writesEnabled={canonicalWritesEnabled} initialPage={initialPage}/>;
}

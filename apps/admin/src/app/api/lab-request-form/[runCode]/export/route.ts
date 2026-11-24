import {createClient as bearerClient} from '@supabase/supabase-js';
import {createClient} from '@/lib/supabase/server';
import {hostedPilot,supabaseClientConfig} from '@/lib/supabase/config';
import {requestSeedlingFilename,requestSeedlingPdf,requestSeedlingXlsx,type RequestSeedlingRecord} from '@/lib/requestSeedlingFormExport';
export const runtime='nodejs';export const dynamic='force-dynamic';
const headers={'Cache-Control':'private, no-store','X-Content-Type-Options':'nosniff'};
const fail=(message:string,status:number)=>Response.json({message},{status,headers});
export async function GET(request:Request,context:{params:Promise<{runCode:string}>}){
 if(!hostedPilot||process.env.PLANT_LAB_APP_VARIANT!=='LAB')return fail('Tidak tersedia.',404);
 const {runCode}=await context.params,q=new URL(request.url).searchParams,format=q.get('format'),state=q.get('status'),revision=q.get('revision');
 if(!/^LT-[A-Z0-9]{1,60}$/.test(runCode)||!['pdf','xlsx'].includes(format??'')
  ||!['IN_PROGRESS','SUBMITTED','IN_REVIEW','APPROVED','RETEST','REJECTED','CANCELLED'].includes(state??'')
  ||(revision!==null&&!/^[1-9][0-9]{0,8}$/.test(revision))
  ||[...q.keys()].some(k=>!['format','status','revision'].includes(k)||q.getAll(k).length!==1))return fail('Pilihan unduhan tidak benar.',400);
 try{
  const authorization=request.headers.get('authorization');if(authorization&&!/^Bearer [A-Za-z0-9._-]{20,8192}$/.test(authorization))return fail('Silakan login kembali.',401);
  const config=supabaseClientConfig(),client=authorization?bearerClient(config.url,config.key,{auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false},global:{headers:{Authorization:authorization}}}):await createClient();
  const auth=await client.auth.getUser(authorization?.slice(7));if(auth.error||!auth.data.user)return fail('Silakan login kembali.',401);
  const api=client.schema('plantlab_api'),access=await api.rpc('get_current_access_context');if(access.error||access.data?.can_access_lab!==true)return fail('Akun tidak sesuai aplikasi Lab.',403);
  const result=await api.rpc('get_request_seedling_form_export_v2',{p_run_code:runCode,p_expected_status:state,p_expected_revision:revision===null?null:Number(revision)});
  if(result.error)return fail((result.error.code==='40001' || result.error.code==='PT409')?'Status atau revisi pengujian berubah. Muat ulang sebelum mengunduh.':result.error.code==='22023'?'Pilihan ini memerlukan percobaan Germinasi atau Vigor biasa dari permintaan Plant.':'Catatan tidak tersedia dalam cakupan akun Anda.',(result.error.code==='40001' || result.error.code==='PT409')?409:result.error.code==='22023'?422:403);
  const record=result.data as RequestSeedlingRecord;if(record.source!=='PLANT_REQUEST'||record.run_code!==runCode||record.status!==state||(revision!==null&&record.revision!==Number(revision)))return fail('Sumber cetakan tidak sesuai.',409);
  const bytes=format==='pdf'?await requestSeedlingPdf(record):await requestSeedlingXlsx(record);if(bytes.length>5*1024*1024)return fail('File terlalu besar.',422);
  return new Response(Buffer.from(bytes),{headers:{...headers,'Content-Type':format==='pdf'?'application/pdf':'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
   'Content-Disposition':`attachment; filename="${requestSeedlingFilename(record,format as 'pdf'|'xlsx')}"`}});
 }catch(e){return fail(e instanceof Error&&e.message==='PDF_CHARACTER'?'Ada karakter yang belum didukung PDF. Gunakan Excel.':'Unduhan belum berhasil. Coba kembali.',500);}
}

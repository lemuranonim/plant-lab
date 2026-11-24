import {createClient as bearerClient} from '@supabase/supabase-js';
import {createClient} from '@/lib/supabase/server';
import {hostedPilot,supabaseClientConfig} from '@/lib/supabase/config';
import {retFormFilename,routineRetPdf,routineRetXlsx,type RetPrintRecord} from '@/lib/routineRetFormExport';
export const runtime='nodejs';export const dynamic='force-dynamic';
const headers={'Cache-Control':'private, no-store','X-Content-Type-Options':'nosniff'};
const fail=(message:string,status:number)=>Response.json({message},{status,headers});
export async function GET(request:Request,context:{params:Promise<{runCode:string}>}){
 if(!hostedPilot||process.env.PLANT_LAB_APP_VARIANT!=='LAB')return fail('Tidak tersedia.',404);
 const {runCode}=await context.params,q=new URL(request.url).searchParams,format=q.get('format'),state=q.get('status');
 if(!/^LT-[A-Z0-9]{1,60}$/.test(runCode)||!['pdf','xlsx'].includes(format??'')
  ||!['IN_PROGRESS','SUBMITTED','IN_REVIEW','APPROVED','RETEST','REJECTED','CANCELLED'].includes(state??'')
  ||[...q.keys()].some(k=>!['format','status'].includes(k)||q.getAll(k).length!==1))return fail('Pilihan unduhan tidak benar.',400);
 try{
  const authorization=request.headers.get('authorization');if(authorization&&!/^Bearer [A-Za-z0-9._-]{20,8192}$/.test(authorization))return fail('Silakan login kembali.',401);
  const config=supabaseClientConfig(),client=authorization?bearerClient(config.url,config.key,{auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false},global:{headers:{Authorization:authorization}}}):await createClient();
  const auth=await client.auth.getUser(authorization?.slice(7));if(auth.error||!auth.data.user)return fail('Silakan login kembali.',401);
  const api=client.schema('plantlab_api'),access=await api.rpc('get_current_access_context');if(access.error||access.data?.can_access_lab!==true)return fail('Akun tidak sesuai aplikasi Lab.',403);
  const result=await api.rpc('get_request_ret_form_export',{p_run_code:runCode,p_expected_status:state});
  if(result.error)return fail((result.error.code==='40001' || result.error.code==='PT409')?'Status pengujian berubah. Muat ulang sebelum mengunduh.':result.error.code==='22023'?'Pilihan ini memerlukan percobaan RET dari permintaan Plant.':'Catatan tidak tersedia dalam cakupan akun Anda.',(result.error.code==='40001' || result.error.code==='PT409')?409:result.error.code==='22023'?422:403);
  const record=result.data as RetPrintRecord;if(record.source!=='PLANT_REQUEST'||record.workflow?.run_code!==runCode||record.status!==state)return fail('Sumber cetakan tidak sesuai.',409);
  const bytes=format==='pdf'?await routineRetPdf(record):await routineRetXlsx(record);if(bytes.length>5*1024*1024)return fail('File terlalu besar.',422);
  return new Response(Buffer.from(bytes),{headers:{...headers,'Content-Type':format==='pdf'?'application/pdf':'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
   'Content-Disposition':`attachment; filename="${retFormFilename(record,format as 'pdf'|'xlsx')}"`}});
 }catch(e){return fail(e instanceof Error&&e.message==='PDF_CHARACTER'?'Ada karakter yang belum didukung PDF. Gunakan Excel.':'Unduhan belum berhasil. Coba kembali.',500);}
}

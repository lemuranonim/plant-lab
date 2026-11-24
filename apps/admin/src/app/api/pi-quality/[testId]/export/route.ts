import {createClient as bearerClient} from '@supabase/supabase-js';
import {createClient} from '@/lib/supabase/server';
import {hostedPilot,supabaseClientConfig} from '@/lib/supabase/config';
import {tswFormPdf,tswFormXlsx} from '@/lib/piTswFormExport';
import {tswFormFilename,type TswForm} from '@/lib/piTswForm';
export const runtime='nodejs';export const dynamic='force-dynamic';
const headers={'Cache-Control':'private, no-store','X-Content-Type-Options':'nosniff'};
const fail=(message:string,status:number)=>Response.json({message},{status,headers});
export async function GET(request:Request,context:{params:Promise<{testId:string}>}){
 const variant=process.env.PLANT_LAB_APP_VARIANT;
 if(!hostedPilot||!['PLANT','LAB'].includes(variant??''))return fail('Tidak tersedia.',404);
 const {testId}=await context.params,q=new URL(request.url).searchParams,format=q.get('format'),revision=q.get('revision');
 if(!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(testId)||!['pdf','xlsx'].includes(format??'')||!/^[1-9][0-9]{0,8}$/.test(revision??''))return fail('Pilihan unduhan tidak benar.',400);
 try{
  const authorization=request.headers.get('authorization');if(authorization&&!/^Bearer [A-Za-z0-9._-]{20,8192}$/.test(authorization))return fail('Silakan login kembali.',401);
  const config=supabaseClientConfig(),client=authorization?bearerClient(config.url,config.key,{auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false},global:{headers:{Authorization:authorization}}}):await createClient();
  const auth=await client.auth.getUser(authorization?.slice(7));if(auth.error||!auth.data.user)return fail('Silakan login kembali.',401);
  const api=client.schema('plantlab_api'),access=await api.rpc('get_current_access_context');
  if(access.error||access.data?.[variant==='PLANT'?'can_access_plant':'can_access_lab']!==true)return fail('Akun tidak sesuai aplikasi ini.',403);
  const result=await api.rpc('get_pi_tsw_form_export',{p_test_id:testId,p_expected_version:Number(revision)});
  if(result.error)return fail(result.error.code==='40001'?'Versi berubah. Muat ulang sebelum mengunduh.':'Sumber TSW tidak tersedia dalam cakupan akun Anda.',result.error.code==='40001'?409:result.error.code==='22023'?422:403);
  const r=result.data as TswForm,bytes=format==='pdf'?await tswFormPdf(r):await tswFormXlsx(r);
  if(bytes.length>5*1024*1024)return fail('File terlalu besar.',422);
  return new Response(Buffer.from(bytes),{headers:{...headers,'Content-Type':format==='pdf'?'application/pdf':'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet','Content-Disposition':`attachment; filename="${tswFormFilename(r,format!)}"`}});
 }catch(e){return fail(e instanceof Error&&e.message==='PDF_CHARACTER'?'Ada karakter yang belum didukung PDF. Gunakan Excel.':'Unduhan belum berhasil. Coba kembali.',500);}
}

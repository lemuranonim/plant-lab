import {createClient as bearerClient} from '@supabase/supabase-js';
import {createClient} from '@/lib/supabase/server';
import {hostedPilot,supabaseClientConfig} from '@/lib/supabase/config';
import {logbookExportFilename,logbookExportXlsx,parseLogbookExportQuery,type LogbookExport} from '@/lib/labLogbookExport';
export const runtime='nodejs';export const dynamic='force-dynamic';
const headers={'Cache-Control':'private, no-store','X-Content-Type-Options':'nosniff'};
const fail=(message:string,status:number)=>Response.json({message},{status,headers});
export async function GET(request:Request){
 if(!hostedPilot||process.env.PLANT_LAB_APP_VARIANT!=='LAB')return fail('Tidak tersedia.',404);
 let args;try{args=parseLogbookExportQuery(new URL(request.url).searchParams);}catch{return fail('Filter unduhan tidak benar. Terapkan ulang filter.',400);}
 try{
  const authorization=request.headers.get('authorization');if(authorization&&!/^Bearer [A-Za-z0-9._-]{20,8192}$/.test(authorization))return fail('Silakan login kembali.',401);
  const config=supabaseClientConfig(),client=authorization?bearerClient(config.url,config.key,{auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false},global:{headers:{Authorization:authorization}}}):await createClient();
  const auth=await client.auth.getUser(authorization?.slice(7));if(auth.error||!auth.data.user)return fail('Silakan login kembali.',401);
  const api=client.schema('plantlab_api'),access=await api.rpc('get_current_access_context');if(access.error||access.data?.can_access_lab!==true)return fail('Akun tidak sesuai aplikasi Lab.',403);
  const result=await api.rpc('get_lab_logbook_export',args);
  if(result.error)return fail(result.error.code==='54000'?'Lebih dari 2000 catatan cocok. Persempit tanggal atau filter; tidak ada file sebagian yang diterbitkan.':(result.error.code==='40001' || result.error.code==='PT409')?'Catatan berubah. Muat ulang sebelum mengunduh.':result.error.code==='22023'?'Filter belum benar. Terapkan ulang filter.':'Rekap tidak tersedia dalam cakupan akun Anda.',result.error.code==='54000'||result.error.code==='22023'?422:(result.error.code==='40001' || result.error.code==='PT409')?409:403);
  const record=result.data as LogbookExport,bytes=await logbookExportXlsx(record);if(bytes.length>5*1024*1024)return fail('File terlalu besar. Persempit filter.',422);
  return new Response(Buffer.from(bytes),{headers:{...headers,'Content-Type':'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet','Content-Disposition':`attachment; filename="${logbookExportFilename(record)}"`}});
 }catch{return fail('Unduhan belum berhasil. Periksa koneksi lalu coba lagi.',500);}
}

import { createClient as createBearerClient } from '@supabase/supabase-js';
import { createClient } from '@/lib/supabase/server';
import { hostedPilot, supabaseClientConfig } from '@/lib/supabase/config';
import { formFilename, routineFormPdf, routineFormXlsx, type FormRecord } from '@/lib/routineLabFormExport';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';
const headers = { 'Cache-Control': 'private, no-store', 'X-Content-Type-Options': 'nosniff' };
const fail = (message: string, status: number) => Response.json({ message }, { status, headers });

export async function GET(request: Request, context: { params: Promise<{ draftId: string }> }) {
  if (!hostedPilot || process.env.PLANT_LAB_APP_VARIANT !== 'LAB') return fail('Tidak tersedia.', 404);
  const { draftId } = await context.params;
  const query = new URL(request.url).searchParams;
  const format = query.get('format'), revision = query.get('revision');
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(draftId) ||
    !['pdf', 'xlsx'].includes(format ?? '') || !/^[1-9][0-9]{0,8}$/.test(revision ?? '')) return fail('Pilihan unduhan tidak benar.', 400);
  try {
    const authorization = request.headers.get('authorization');
    if (authorization && !/^Bearer [A-Za-z0-9._-]{20,8192}$/.test(authorization)) return fail('Silakan login kembali.', 401);
    const config = supabaseClientConfig();
    const client = authorization ? createBearerClient(config.url, config.key, {
      auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
      global: { headers: { Authorization: authorization } },
    }) : await createClient();
    const auth = await client.auth.getUser(authorization?.slice(7));
    if (auth.error || !auth.data.user) return fail('Silakan login kembali.', 401);
    const result = await client.schema('plantlab_api').rpc('get_routine_lab_form_export', {
      p_draft_id: draftId, p_expected_revision: Number(revision),
    });
    if (result.error) return fail((result.error.code === '40001' || result.error.code === 'PT409') ? 'Revisi berubah. Muat ulang sebelum mengunduh.' :
      result.error.code === '22023' ? 'Form metode ini belum tersedia.' : 'Catatan tidak tersedia dalam akses akun Anda.',
      (result.error.code === '40001' || result.error.code === 'PT409') ? 409 : result.error.code === '22023' ? 422 : 403);
    const record = result.data as FormRecord;
    const bytes = format === 'pdf' ? await routineFormPdf(record) : await routineFormXlsx(record);
    if (bytes.length > 5 * 1024 * 1024) return fail('File terlalu besar. Hubungi pengelola.', 422);
    return new Response(Buffer.from(bytes), { headers: { ...headers,
      'Content-Type': format === 'pdf' ? 'application/pdf' : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'Content-Disposition': `attachment; filename="${formFilename(record, format as 'pdf'|'xlsx')}"`,
    } });
  } catch (error) {
    return fail(error instanceof Error && error.message === 'PDF_CHARACTER'
      ? 'Ada karakter yang belum didukung PDF. Gunakan Excel atau periksa catatan.' : 'Unduhan belum berhasil. Coba kembali atau hubungi pengelola.', 500);
  }
}

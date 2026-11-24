import { redirect } from 'next/navigation';
import { requireCurrentVariantAccess } from '@/lib/accessContext';
import { getAppVariant } from '@/lib/appVariant';
import { createClient } from '@/lib/supabase/server';
import { hostedPilot, isolatedApiSchema } from '@/lib/supabase/config';
import type { RoutineOptions, RoutinePage } from '@/lib/routineLabDraft';
import RoutineLabWorkspace from './RoutineLabWorkspace';

export const revalidate = 0;
export default async function RoutineLabPage() {
  const access = await requireCurrentVariantAccess();
  if (!hostedPilot || getAppVariant().code !== 'LAB' || !access.roles.some(r =>
    r.module_code === 'LAB' && ['LAB_ANALYST', 'LAB_QA_APPROVER'].includes(r.role_code))) redirect('/access-denied');
  const api = (await createClient()).schema(isolatedApiSchema);
  const options = await api.rpc('get_routine_lab_options');
  if (options.error || !options.data) return <section className="card" role="alert"><h1>Catatan uji rutin</h1><p>Catatan rutin belum bisa dimuat. Periksa koneksi dan penugasan Lab, lalu muat ulang. Antrean request Plant tetap tersedia.</p></section>;
  const catalog = options.data as RoutineOptions;
  const records = await api.rpc('list_routine_lab_drafts', { p_lab_site_id: catalog.selected_lab_site_id });
  return <RoutineLabWorkspace initialOptions={catalog} initialPage={records.error ? null : records.data as RoutinePage} />;
}

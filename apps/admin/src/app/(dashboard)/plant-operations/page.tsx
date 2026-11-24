import { redirect } from 'next/navigation';
import { requireVariantAccess } from '@/lib/accessContext';
import { hostedPilot } from '@/lib/supabase/config';
import PlantOperations from './PlantOperations';

export const revalidate = 0;

export default async function PlantOperationsPage() {
  if (!hostedPilot) redirect('/lab-requests');
  const access = await requireVariantAccess('PLANT');
  return <PlantOperations userId={access.user_id}
    reviewer={access.roles.some(role => role.module_code === 'PLANT' && role.role_code === 'PLANT_SPV')} />;
}

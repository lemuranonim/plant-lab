import { redirect } from 'next/navigation';
import { requireCurrentVariantAccess } from '@/lib/accessContext';
import { getAppVariant } from '@/lib/appVariant';
import { hostedPilot } from '@/lib/supabase/config';
import PiQuality from './PiQuality';

export const revalidate = 0;

export default async function PiQualityPage() {
  if (!hostedPilot) redirect('/lab-requests');
  await requireCurrentVariantAccess();
  return <PiQuality variant={getAppVariant().code === 'LAB' ? 'LAB' : 'PLANT'} />;
}

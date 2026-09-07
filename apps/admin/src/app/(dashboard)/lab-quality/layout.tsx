import { requireVariantAccess } from '@/lib/accessContext';

export default async function LabQualityLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  await requireVariantAccess('LAB');
  return children;
}

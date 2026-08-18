import { requireAccess } from '@/lib/accessContext';

export default async function LabQualityLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  await requireAccess('can_access_lab');
  return children;
}

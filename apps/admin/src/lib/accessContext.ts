import { cache } from 'react';
import { redirect } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';
import { getAppVariant, type AppVariantCode } from '@/lib/appVariant';

export type AccessSite = {
  id: string;
  site_code: string;
  site_name: string;
  site_type: string;
  company_id: number;
};

export type AccessRole = {
  module_code: string;
  role_code: string;
  role_name: string;
  site_id: string | null;
  company_id: number | null;
};

export type AccessContext = {
  user_id: string;
  primary_role_name: string;
  modules: string[];
  roles: AccessRole[];
  sites: AccessSite[];
  can_access_plant: boolean;
  can_access_lab: boolean;
  can_manage_users: boolean;
};

export type AccessCapability =
  | 'can_access_plant'
  | 'can_access_lab'
  | 'can_manage_users';

function isAccessContext(value: unknown): value is AccessContext {
  if (!value || typeof value !== 'object') return false;

  const context = value as Partial<AccessContext>;
  return (
    typeof context.user_id === 'string' &&
    typeof context.primary_role_name === 'string' &&
    Array.isArray(context.modules) &&
    Array.isArray(context.roles) &&
    Array.isArray(context.sites) &&
    typeof context.can_access_plant === 'boolean' &&
    typeof context.can_access_lab === 'boolean' &&
    typeof context.can_manage_users === 'boolean'
  );
}

export const getCurrentAccessContext = cache(async () => {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc('pl_get_current_access_context');

  if (error || !isAccessContext(data)) {
    return null;
  }

  return data;
});

export async function requireAccess(capability: AccessCapability) {
  const context = await getCurrentAccessContext();

  if (!context?.[capability]) {
    redirect('/access-denied');
  }

  return context;
}

export async function requireCurrentVariantAccess() {
  const variant = getAppVariant();
  return requireAccess(variant.accessCapability);
}

export async function requireVariantAccess(expectedVariant: AppVariantCode) {
  const variant = getAppVariant();

  if (variant.code !== expectedVariant) {
    redirect('/access-denied');
  }

  return requireAccess(variant.accessCapability);
}

export const standalonePreview =
  process.env.NEXT_PUBLIC_PLANT_LAB_LOCAL_PREVIEW === 'true';

export const hostedPilot = process.env.NEXT_PUBLIC_PLANT_LAB_HOSTED_PILOT === 'true';
export const plantSampleRequestsEnabled = hostedPilot &&
  process.env.NEXT_PUBLIC_PLANT_LAB_SAMPLE_REQUESTS === 'true';
export const isolatedPlantLab = standalonePreview || hostedPilot;
export const isolatedApiSchema = hostedPilot ? 'plantlab_api' : 'plant_lab_api';

export const standaloneWritePreview = standalonePreview &&
  process.env.NODE_ENV === 'development' &&
  process.env.NEXT_PUBLIC_PLANT_LAB_LOCAL_WRITE_PREVIEW === 'true';

// Canonical-only opt-in. Never enables the legacy operational writes.
export const canonicalWritesEnabled = standaloneWritePreview ||
  (hostedPilot && !standalonePreview &&
    process.env.NEXT_PUBLIC_PLANT_LAB_HOSTED_WRITES_ENABLED === 'true');

export function supabaseClientConfig() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = hostedPilot
    ? process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY
    : process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (hostedPilot && (standalonePreview ||
    url !== 'https://bstxdyyglxrrfqgohllz.supabase.co' ||
    !/^sb_publishable_[A-Za-z0-9_-]+$/.test(key ?? ''))) {
    throw new Error('Pilot hosted memerlukan URL Advanta-CC dan publishable key.');
  }
  if (standalonePreview && (
    process.env.NODE_ENV !== 'development' ||
    url !== 'http://127.0.0.1:54521' ||
    !key?.trim()
  )) {
    throw new Error('Preview Plant/Lab requires Next dev and the local Supabase API on port 54521.');
  }
  return { url: url!, key: key! };
}

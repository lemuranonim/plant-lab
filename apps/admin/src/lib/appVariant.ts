import 'server-only';

export type AppVariantCode = 'PLANT' | 'LAB';

export type AppVariantConfig = {
  code: AppVariantCode;
  appName: string;
  moduleName: string;
  tagline: string;
  logoPath: string;
  accessCapability: 'can_access_plant' | 'can_access_lab';
};

const variants: Record<AppVariantCode, AppVariantConfig> = {
  PLANT: {
    code: 'PLANT',
    appName: 'Advanta Plant',
    moduleName: 'Plant',
    tagline: 'Plant Quality Operations',
    logoPath: '/logo_plant.png',
    accessCapability: 'can_access_plant',
  },
  LAB: {
    code: 'LAB',
    appName: 'Advanta Lab',
    moduleName: 'Lab',
    tagline: 'Laboratory Quality Operations',
    logoPath: '/logo_lab.png',
    accessCapability: 'can_access_lab',
  },
};

export function getAppVariant(): AppVariantConfig {
  const configuredVariant = process.env.PLANT_LAB_APP_VARIANT
    ?.trim()
    .toUpperCase();

  if (configuredVariant === 'PLANT' || configuredVariant === 'LAB') {
    return variants[configuredVariant];
  }

  throw new Error(
    'PLANT_LAB_APP_VARIANT must be set to PLANT or LAB for this deployment.',
  );
}

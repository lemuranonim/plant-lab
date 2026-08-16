import 'server-only';

export const operationalWritesEnabled =
  process.env.PLANT_LAB_WRITES_ENABLED === 'true';

import 'server-only';
import { isolatedPlantLab } from '@/lib/supabase/config';

export const operationalWritesEnabled =
  !isolatedPlantLab && process.env.PLANT_LAB_WRITES_ENABLED === 'true';

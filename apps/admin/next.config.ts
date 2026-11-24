import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  outputFileTracingIncludes: { '/api/lab-routine/*/export': ['./public/fonts/*.ttf'], '/api/lab-moisture/*/export': ['./public/fonts/*.ttf'], '/api/pi-quality/*/export': ['./public/fonts/*.ttf'], '/api/lab-ret/*/export': ['./public/fonts/*.ttf'] },
  distDir: process.env.PLANT_LAB_SEPARATE_BUILD_OUTPUT === 'true'
    ? (process.env.PLANT_LAB_APP_VARIANT === 'LAB' ? 'build/hosted-pilot-lab' : 'build/hosted-pilot-plant')
    : '.next',
  async redirects() {
    const localPreview = process.env.NEXT_PUBLIC_PLANT_LAB_LOCAL_PREVIEW === 'true';
    const hostedPilot = process.env.NEXT_PUBLIC_PLANT_LAB_HOSTED_PILOT === 'true';
    if (hostedPilot && (localPreview ||
      process.env.NEXT_PUBLIC_SUPABASE_URL !== 'https://bstxdyyglxrrfqgohllz.supabase.co' ||
      !/^sb_publishable_[A-Za-z0-9_-]+$/.test(process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ?? '') ||
      !['PLANT', 'LAB'].includes(process.env.PLANT_LAB_APP_VARIANT ?? ''))) {
      throw new Error('Configure the Advanta-CC publishable key and PLANT/LAB variant for hosted pilot.');
    }
    if (!localPreview && !hostedPilot) return [];
    if (localPreview && process.env.NODE_ENV !== 'development') {
      throw new Error('Plant/Lab standalone preview is only supported by Next dev.');
    }
    // Redirect before any legacy Server Component starts querying its tables.
    return ['/', '/dashboard', '/inspections', '/receiving', '/lab-quality', '/reports', '/users']
      .map(source => ({ source, destination: '/lab-requests', permanent: false }));
  },
};

export default nextConfig;

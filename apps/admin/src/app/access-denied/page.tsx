import LogoutButton from '@/app/(dashboard)/LogoutButton';
import { getAppVariant } from '@/lib/appVariant';
import Image from 'next/image';

export default function AccessDeniedPage() {
  const variant = getAppVariant();

  return (
    <main
      style={{
        minHeight: '100vh',
        display: 'grid',
        placeItems: 'center',
        padding: '2rem',
        background: 'var(--background)',
      }}
    >
      <section className="card" style={{ maxWidth: '520px', padding: '2rem' }}>
        <Image
          src={variant.logoPath}
          alt={`Logo ${variant.appName}`}
          width={72}
          height={72}
          style={{ width: '72px', height: '72px', objectFit: 'contain', marginBottom: '1rem' }}
        />
        <p style={{ color: 'var(--warning)', fontWeight: 700, marginBottom: '0.75rem' }}>
          Akses dibatasi
        </p>
        <h1 style={{ fontSize: '1.75rem', marginBottom: '0.75rem' }}>
          Akun tidak memiliki akses {variant.appName}
        </h1>
        <p style={{ color: 'var(--text-secondary)', marginBottom: '1.5rem' }}>
          Akses mengikuti assignment module, company, dan site yang aktif untuk
          akun Anda. Keluar lalu gunakan akun {variant.moduleName} yang sesuai.
        </p>
        <LogoutButton />
      </section>
    </main>
  );
}

import { redirect } from 'next/navigation';
import Image from 'next/image';
import { createClient } from '@/lib/supabase/server';
import styles from './dashboard-layout.module.css';
import lab from './lab-surface.module.css';
import LogoutButton from './LogoutButton';
import ThemeToggle from '@/components/ThemeToggle';
import ScopedNav from './ScopedNav';
import { canUsePreviewVariant, getCurrentAccessContext } from '@/lib/accessContext';
import { getAppVariant } from '@/lib/appVariant';
import { hostedPilot, isolatedPlantLab, canonicalWritesEnabled } from '@/lib/supabase/config';

export default async function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect('/login');
  }

  const access = await getCurrentAccessContext();
  const variant = getAppVariant();

  if (!access || !access[variant.accessCapability] ||
    (isolatedPlantLab && !canUsePreviewVariant(access, variant.code))) {
    redirect('/access-denied');
  }

  const roleName = access.primary_role_name;
  const displayEmail = user.email;
  const scopedSites = access.sites.filter(
    (site) => site.site_type.toUpperCase() === variant.code,
  );

  if (hostedPilot && variant.code === 'LAB') {
    const sites = scopedSites.map(site => site.site_name).join(', ');
    const roles = access.roles.filter(role => role.module_code === 'LAB').map(role => role.role_code);
    const supportNumber = process.env.LAB_SUPPORT_WHATSAPP?.trim();
    const reportWhatsAppNumber = supportNumber && /^[1-9]\d{7,14}$/.test(supportNumber) && roles.length ? supportNumber : undefined;
    const mode = canonicalWritesEnabled ? 'Pilot operasional · Online' : 'Pilot internal · Hanya-baca';
    return <div className={lab.shell} data-lab-workspace="">
      <a className={styles.skipLink} href="#main-content">Lewati menu, ke isi halaman</a>
      <header className={`${styles.header} ${lab.head}`}>
        <div className={styles.scopedBrand}>
          <Image src={variant.logoPath} alt="" width={36} height={36} style={{ objectFit: 'contain' }} />
          <div><strong>{variant.appName}</strong><div className={styles.scopeCaption}>{roleName} · {sites || 'Site belum tersedia'}</div></div>
        </div>
        <span className={`${lab.mode} ${lab.headBadge}`} data-readonly={!canonicalWritesEnabled || undefined}>{mode}</span>
        <div className={styles.scopedAccount}><ThemeToggle /><details><summary>Akun</summary><div className={styles.accountPanel}><strong>{roleName}</strong><p>{displayEmail}</p><LogoutButton /></div></details></div>
      </header>
      <div role="status" className={lab.modeNote}>
        <p className={lab.modeDetail}>{canonicalWritesEnabled ? 'Data asli · Catat hanya pekerjaan yang benar-benar dilakukan.' : 'Hanya antrean Plant/Lab mandiri.'}</p>
      </div>
      <div className={lab.body}>
        <ScopedNav plant={false} supervisor={false} roles={roles} sites={sites} reportWhatsAppNumber={reportWhatsAppNumber} />
        <main id="main-content" tabIndex={-1} className={`${styles.mainContent} ${lab.main}`}>{children}</main>
      </div>
    </div>;
  }

  // All deployments now use isolated Plant or Lab mode.
  // The ScopedNav provides navigation for both hosted pilot and local preview.
  return (
    <div className={styles.mainWrapper}>
      <header className={styles.header}>
        <div className={styles.scopedBrand}>
          <Image src={variant.logoPath} alt={`Logo ${variant.appName}`} width={36} height={36} style={{ objectFit: 'contain' }} />
          <div><strong>{variant.appName}</strong>
            <div className={styles.scopeCaption}>{roleName} · {scopedSites.map(site => site.site_name).join(', ') || 'Site belum tersedia'}</div></div>
        </div>
        <div className={styles.scopedAccount}><ThemeToggle /><details><summary>Akun</summary><div className={styles.accountPanel}><strong>{roleName}</strong><p>{displayEmail}</p><LogoutButton /></div></details></div>
      </header>
      <a className={styles.skipLink} href="#main-content">Lewati menu, ke isi halaman</a>
      <div className={styles.readOnlyBanner} role="status">
        <strong>{hostedPilot ? (canonicalWritesEnabled ? 'Pilot operasional · Online' : 'Pilot internal · Hanya-baca') : canonicalWritesEnabled ? 'Preview lokal · Uji pengajuan' : 'Preview lokal · Read-only'}</strong>
        <span>{canonicalWritesEnabled ? 'Data asli · Catat hanya pekerjaan yang benar-benar dilakukan.' : 'Hanya antrean Plant/Lab mandiri.'}</span>
      </div>
      <ScopedNav plant={variant.code === 'PLANT'} supervisor={access.roles.some(role => role.module_code === 'PLANT' && role.role_code === 'PLANT_SPV')} roles={access.roles.filter(role => role.module_code === variant.code).map(role => role.role_code)} sites={scopedSites.map(site => site.site_name).join(', ')} />
      <main id="main-content" tabIndex={-1} className={styles.mainContent}>{children}</main>
    </div>
  );
}

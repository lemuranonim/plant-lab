import { redirect } from 'next/navigation';
import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';
import styles from './dashboard-layout.module.css';
import LogoutButton from './LogoutButton';
import ThemeToggle from '@/components/ThemeToggle';

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

  const isSuperAdmin = user.email === 'admin@advantaindonesia.com';
  const roleName = isSuperAdmin ? 'Superadmin' : 'Staff Admin';
  const displayEmail = user.email;

  return (
    <div className={styles.container}>
      <aside className={styles.sidebar}>
        <div className={styles.logo}>
          <div className={styles.logoIcon} style={{ background: 'none', width: '36px', height: '36px' }}>
            <img src="/logo_plant_lab.png" alt="Plant+Lab Logo" style={{ width: '36px', height: '36px', objectFit: 'contain' }} />
          </div>
          <div className={styles.logoText}>
            <span className={styles.logoTitle}>Plant+Lab</span>
            <span className={styles.logoSub}>Advanta Quality</span>
          </div>
        </div>

        <div className={styles.companyBadge}>
          <span className={styles.companyDot}></span>
          <span className={styles.companyName}>PT Advanta Seeds ID</span>
        </div>

        <nav className={styles.nav}>
          <div className={styles.navSection}>Main Menu</div>

          <Link href="/dashboard" className={styles.navItem}>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className={styles.icon}>
              <path d="m3 9 9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"></path>
              <polyline points="9 22 9 12 15 12 15 22"></polyline>
            </svg>
            Dashboard
          </Link>

          <Link href="/receiving" className={styles.navItem}>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className={styles.icon}>
              <path d="M14 18V6a2 2 0 0 0-2-2H4a2 2 0 0 0-2 2v11a1 1 0 0 0 1 1h2"></path>
              <path d="M15 18H9"></path>
              <path d="M19 18h2a1 1 0 0 0 1-1v-3.65a1 1 0 0 0-.22-.62l-3.24-4.04a1 1 0 0 0-.78-.36H15v8z"></path>
              <circle cx="7" cy="18" r="2"></circle>
              <circle cx="17" cy="18" r="2"></circle>
            </svg>
            Receiving Harvest
          </Link>

          <Link href="/inspections" className={styles.navItem}>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className={styles.icon}>
              <path d="M9 11l3 3L22 4"></path>
              <path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"></path>
            </svg>
            Plant Process Inspections
          </Link>

          <Link href="/lab-requests" className={styles.navItem}>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className={styles.icon}>
              <path d="M10 2v7.527a2 2 0 0 1-.211.896L4.72 20.55a1 1 0 0 0 .9 1.45h12.76a1 1 0 0 0 .9-1.45l-5.069-10.127A2 2 0 0 1 14 9.527V2"></path>
              <path d="M8.5 2h7"></path>
              <path d="M7 16h10"></path>
            </svg>
            Lab Sample Tracking
          </Link>

          <Link href="/lab-quality" className={styles.navItem}>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className={styles.icon}>
              <path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"></path>
              <polyline points="3.27 6.96 12 12.01 20.73 6.96"></polyline>
              <line x1="12" y1="22.08" x2="12" y2="12"></line>
            </svg>
            Lab Quality Data
          </Link>

          <Link href="/reports" className={styles.navItem}>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className={styles.icon}>
              <line x1="18" y1="20" x2="18" y2="10"></line>
              <line x1="12" y1="20" x2="12" y2="4"></line>
              <line x1="6" y1="20" x2="6" y2="14"></line>
            </svg>
            Reports & Analytics
          </Link>

          <div className={styles.navSection}>Administration</div>

          <Link href="/users" className={styles.navItem}>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className={styles.icon}>
              <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path>
              <circle cx="9" cy="7" r="4"></circle>
              <path d="M23 21v-2a4 4 0 0 0-3-3.87"></path>
              <path d="M16 3.13a4 4 0 0 1 0 7.75"></path>
            </svg>
            Users & Roles
          </Link>
        </nav>
      </aside>

      <div className={styles.mainWrapper}>
        <header className={styles.header}>
          <div className={styles.headerLeft}>
            <select className={styles.siteSelect} defaultValue="PLANT-PASURUAN">
              <option value="PLANT-PASURUAN">Plant Pasuruan (Jawa Timur)</option>
              <option value="LAB-PASURUAN">Lab / SPL Pasuruan</option>
              <option value="WH-PASURUAN">Gudang Pasuruan</option>
            </select>
          </div>

          <div className={styles.userMenu}>
            <ThemeToggle />

            <div className={styles.userInfo}>
              <span className={styles.userEmail}>{displayEmail}</span>
              <span className={styles.userRole}>
                {isSuperAdmin ? (
                  <span className="badge badge-gold" style={{ padding: '2px 6px', fontSize: '10px' }}>★ SUPERADMIN</span>
                ) : (
                  <span>{roleName}</span>
                )}
              </span>
            </div>

            <LogoutButton />
          </div>
        </header>

        <main className={styles.mainContent}>{children}</main>
      </div>
    </div>
  );
}
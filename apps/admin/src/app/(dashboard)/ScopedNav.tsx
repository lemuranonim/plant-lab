'use client';

import Link from 'next/link';
import { useState, useSyncExternalStore } from 'react';
import { usePathname } from 'next/navigation';
import styles from './dashboard-layout.module.css';
import lab from './lab-surface.module.css';
import SoftLaunchGuide from './SoftLaunchGuide';
import {plantSampleRequestsEnabled} from '@/lib/supabase/config';

const icons: Record<string, string> = {
  '/lab-requests': 'M9 3h6m-5 0v6l-5 9a2 2 0 0 0 2 3h10a2 2 0 0 0 2-3l-5-9V3M8 15h8',
  '/lab-routine': 'M7 3h10v18H5V3zm2 5h6m-6 4h6m-6 4h3',
  '/lab-moisture': 'M12 2C9 7 6 10 6 14a6 6 0 0 0 12 0c0-4-3-7-6-12zm-3 12a3 3 0 0 0 3 3',
  '/lab-logbook': 'M5 3h14v18H5zm3 5h8m-8 4h8m-8 4h5',
  '/lab-monitoring': 'M4 4v16h16M8 16v-4m4 4V8m4 8v-6m4 6V5',
  '/sample-requests': 'M4 7l8-4 8 4v10l-8 4-8-4zm0 0l8 4 8-4m-8 4v10',
  '/pi-quality': 'M5 4h14v16H5zm4 8 2 2 4-5',
};
function NavIcon({ path }: { path: string }) {
  return <svg aria-hidden="true" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.65" strokeLinecap="round" strokeLinejoin="round"><path d={path} /></svg>;
}
const narrowMedia = '(max-width: 760px)';
function subscribeWidth(callback: () => void) {
  const query = window.matchMedia(narrowMedia);
  query.addEventListener('change', callback);
  return () => query.removeEventListener('change', callback);
}

export default function ScopedNav({ plant, supervisor, roles, sites, reportWhatsAppNumber }: { plant: boolean; supervisor: boolean; roles: string[]; sites: string; reportWhatsAppNumber?: string }) {
  const pathname = usePathname();
  const narrow = useSyncExternalStore(subscribeWidth, () => window.matchMedia(narrowMedia).matches, () => false);
  const [menuOpen, setMenuOpen] = useState<boolean | null>(null);
  const expanded = menuOpen ?? !narrow;
  const items = [
    { href: '/lab-requests', label: plant ? 'Permintaan & hasil Lab' : 'Antrean & hasil uji', icon: '01' },
    ...(plant ? [{ href: '/plant-operations', label: 'Input Harian Plant', icon: '02' }] : []),
    ...(!plant ? [{ href: '/lab-routine', label: 'Catatan uji rutin', icon: '02' }] : []),
    ...(!plant ? [{ href: '/lab-moisture', label: 'MC Lab', icon: '03' }] : []),
    ...(!plant ? [{ href: '/lab-logbook', label: 'Buku pengujian Lab', icon: '04' }] : []),
    ...(!plant ? [{ href: '/lab-monitoring', label: 'Pemantauan kerja Lab', icon: '05' }] : []),
    ...(plantSampleRequestsEnabled && roles.some(r => (plant ? ['PLANT_OPERATOR','PLANT_SPV'] : ['LAB_ANALYST','LAB_QA_APPROVER']).includes(r)) ? [{href:'/sample-requests',label:plant?'Permintaan sampel dari Lab':'Permintaan sampel ke Plant',icon:plant?'05':'06'}] : []),
    { href: '/pi-quality', label: plant ? 'Mutu PI' : 'Sumber Mutu Plant', icon: plant ? '03' : '02' },
    ...(plant && supervisor ? [{ href: '/lot-pair-reviews', label: 'Verifikasi pasangan lot', icon: '04' }] : []),
  ];
  if (!plant) return <aside className={lab.aside} data-collapsed={!expanded || undefined}>
    <nav aria-label="Menu Lab" className={lab.rail}>
      <div className={lab.railHeading}>
        <span className={lab.railCaption}>Ruang kerja Lab</span>
        <button className={lab.menuToggle} type="button" aria-controls="lab-navigation-items" aria-expanded={expanded} aria-label={expanded ? 'Ciutkan menu Lab' : 'Buka menu Lab'} onClick={() => setMenuOpen(!expanded)}>
          <NavIcon path="M3 5h18v14H3zm6 0v14m3-9h6m-6 4h6" />
        </button>
      </div>
      <div id="lab-navigation-items" className={lab.menuItems}>
        {items.map(item => <Link className={lab.menuLink} key={item.href} href={item.href} aria-label={item.label} title={item.label}
          aria-current={pathname === item.href ? 'page' : undefined} onClick={() => { if (narrow) setMenuOpen(false); }}>
          <NavIcon path={icons[item.href]} /><span className={lab.menuLabel}>{item.label}</span>
        </Link>)}
        <div className={lab.guide}><SoftLaunchGuide plant={plant} roles={roles} sites={sites} reportWhatsAppNumber={reportWhatsAppNumber} /></div>
      </div>
    </nav>
  </aside>;
  return <nav aria-label={`Menu ${plant ? 'Plant' : 'Lab'}`} className={styles.scopedNav}>
    {items.map(item => <Link key={item.href} href={item.href} aria-current={pathname === item.href ? 'page' : undefined}>
      <span aria-hidden="true">{item.icon}</span>{item.label}
    </Link>)}
    <SoftLaunchGuide plant={plant} roles={roles} sites={sites} />
  </nav>;
}

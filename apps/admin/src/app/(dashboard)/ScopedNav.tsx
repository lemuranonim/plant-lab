'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import styles from './dashboard-layout.module.css';
import SoftLaunchGuide from './SoftLaunchGuide';
import {plantSampleRequestsEnabled} from '@/lib/supabase/config';

export default function ScopedNav({ plant, supervisor, roles, sites }: { plant: boolean; supervisor: boolean; roles: string[]; sites: string }) {
  const pathname = usePathname();
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
  return <nav aria-label={`Menu ${plant ? 'Plant' : 'Lab'}`} className={styles.scopedNav}>
    {items.map(item => <Link key={item.href} href={item.href} aria-current={pathname === item.href ? 'page' : undefined}>
      <span aria-hidden="true">{item.icon}</span>{item.label}
    </Link>)}
    <SoftLaunchGuide plant={plant} roles={roles} sites={sites} />
  </nav>;
}

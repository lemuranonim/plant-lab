'use client';

import type { ReactNode } from 'react';
import styles from './lab-surface.module.css';

export function LabSkeleton({ label }: { label: string }) {
  return <div role="status"><p>{label}</p><div aria-hidden="true" className={styles.skeleton}><span /><span /></div></div>;
}

export function LabFormSections({ sections }: { sections: { id: string; label: string }[] }) {
  return <nav aria-label="Lompat ke bagian isian" className={styles.formSections}>
    {sections.map(({ id, label }) => <button type="button" className="btn" key={id} onClick={() => {
      const section = document.getElementById(id);
      section?.focus({ preventScroll: true });
      section?.scrollIntoView({ block: 'start' });
    }}>{label}</button>)}
  </nav>;
}

export function LabHelp({ children, label = 'Bantuan singkat' }: { children: ReactNode; label?: string }) {
  return <details className={styles.help}><summary>{label}</summary><div>{children}</div></details>;
}

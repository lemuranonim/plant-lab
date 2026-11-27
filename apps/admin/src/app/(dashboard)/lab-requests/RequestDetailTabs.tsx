'use client';

import { useId, useRef, useState, type KeyboardEvent, type ReactNode } from 'react';
import styles from './queue.module.css';

const tabs = [
  { key: 'summary', label: 'Ringkasan' },
  { key: 'observations', label: 'Ulangan' },
  { key: 'downloads', label: 'Unduh' },
  { key: 'history', label: 'Riwayat' },
] as const;
type TabKey = (typeof tabs)[number]['key'];
export type RequestDetailSections = Record<Exclude<TabKey, 'summary'>, ReactNode>;

export default function RequestDetailTabs({ summary, sections, cue }: {
  summary: ReactNode;
  sections: RequestDetailSections;
  cue?: string;
}) {
  const id = useId();
  const [active, setActive] = useState<TabKey>('summary');
  const buttons = useRef<Partial<Record<TabKey, HTMLButtonElement>>>({});

  function navigate(event: KeyboardEvent<HTMLButtonElement>, index: number) {
    let target: number;
    switch (event.key) {
      case 'ArrowRight': target = (index + 1) % tabs.length; break;
      case 'ArrowLeft': target = (index + tabs.length - 1) % tabs.length; break;
      case 'Home': target = 0; break;
      case 'End': target = tabs.length - 1; break;
      default: return;
    }
    event.preventDefault();
    const key = tabs[target].key;
    setActive(key);
    buttons.current[key]?.focus();
  }

  return <>
    <div className={styles.detailTabs} role="tablist" aria-label="Bagian detail permintaan">
      {tabs.map(({ key, label }, index) => <button
        key={key}
        ref={node => {
          if (node) buttons.current[key] = node;
          else delete buttons.current[key];
        }}
        type="button"
        role="tab"
        id={`${id}-tab-${key}`}
        aria-selected={active === key}
        aria-controls={`${id}-panel-${key}`}
        tabIndex={active === key ? 0 : -1}
        onClick={() => setActive(key)}
        onKeyDown={event => navigate(event, index)}
      >{label}</button>)}
    </div>
    {tabs.map(({ key }) => <div
      key={key}
      id={`${id}-panel-${key}`}
      role="tabpanel"
      aria-labelledby={`${id}-tab-${key}`}
      className={styles.detailTabPanel}
      // Preserve active editors and in-flight requests when changing panels.
      hidden={active !== key}
      tabIndex={0}
    >{key === 'summary' ? <>
      {cue && <button type="button" className={`btn btn-primary ${styles.quickObservation}`} onClick={() => {
        setActive('observations');
        buttons.current.observations?.focus();
      }}>{cue} →</button>}
      {summary}
    </> : sections[key]}</div>)}
  </>;
}

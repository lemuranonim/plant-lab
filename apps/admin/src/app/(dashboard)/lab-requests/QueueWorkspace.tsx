'use client';

import { useId, useRef, useState, type ReactNode } from 'react';
import { useRouter } from 'next/navigation';
import styles from './queue.module.css';
import RequestDetailTabs, { type RequestDetailSections } from './RequestDetailTabs';

type Item = {
  id: string; search: string; group: string; content: ReactNode;
  lot: string; code: string; tests: string; rawStatus: string; status: string;
  sections?: RequestDetailSections;
  cue?: { label: string; section?: 'observations' };
};
function LabQueueRow({ item }: { item: Item }) {
  const drawer = useRef<HTMLDialogElement>(null);
  const title = useId();
  return <tr className={styles.overviewRow}>
    <th scope="row"><strong className={styles.queueLot}>{item.lot}</strong><small className={styles.requestCode}>{item.code}</small></th>
    <td data-column="Jenis uji">{item.tests}</td>
    <td data-column="Status"><span className={styles.statusBadge} data-status={item.group} data-raw-status={item.rawStatus}>{item.status}</span></td>
    <td className={styles.rowCue} data-column="Langkah berikutnya">{item.cue?.label}</td>
    <td className={styles.openColumn}>
      <button type="button" className="btn btn-outline" aria-haspopup="dialog" aria-label={`Buka detail ${item.code}`} onClick={() => drawer.current?.showModal()}>Buka detail</button>
      <dialog ref={drawer} aria-labelledby={`${title} ${title}-request`} className={styles.detailDrawer}>
        <div className={styles.drawerHeading}>
          <div className={styles.drawerIdentity}>
            <p className={styles.eyebrow}>LOT DIUJI</p>
            <h2 id={title}>{item.lot}</h2>
            <p id={`${title}-request`} className={styles.requestCode}>{item.code}</p>
          </div>
          <button type="button" className={`btn btn-outline ${styles.closeDetail}`} aria-label="Tutup detail" onClick={() => drawer.current?.close()}>×</button>
          <div className={styles.drawerMeta}>
            <span>{item.tests}</span>
            <span className={styles.statusBadge} data-status={item.group} data-raw-status={item.rawStatus}>{item.status}</span>
          </div>
        </div>
        <div className={styles.drawerBody} data-testid="lab-drawer-body">
          {item.sections ? <RequestDetailTabs summary={item.content} sections={item.sections} cue={item.cue?.section ? item.cue.label : undefined} /> : item.content}
        </div>
      </dialog>
    </td>
  </tr>;
}
export default function QueueWorkspace({ items, error, lab = false }: { items: Item[]; error: boolean; lab?: boolean }) {
  const [query, setQuery] = useState('');
  const [filter, setFilter] = useState('all');
  const router = useRouter();
  const visible = items.filter(item => (filter === 'all' || item.group === filter) && item.search.toLocaleLowerCase('id-ID').includes(query.trim().toLocaleLowerCase('id-ID')));
  return <section aria-label="Daftar permintaan" className={styles.workspace}>
    <div className={styles.sectionHeading}><div><h2>Permintaan & hasil pengujian</h2><p>Menampilkan maksimal 50 permintaan terbaru dalam cakupan akun Anda.</p></div>
      <button type="button" className={lab ? 'btn btn-outline' : 'btn'} onClick={() => router.refresh()}>Muat ulang</button></div>
    {!error && <div className={styles.metrics}>
      {[['active', 'Dalam proses'], ['review', 'Menunggu QA'], ['approved', 'Hasil disetujui']].map(([group, label]) => <div key={group} data-queue-metric={lab ? group : undefined}><strong>{items.filter(item => item.group === group).length}</strong><span>{label}</span></div>)}
    </div>}
    <div className={styles.toolbar}><label>Cari permintaan<input type="search" placeholder="Kode lot atau nomor permintaan" value={query} onChange={e => setQuery(e.target.value)} /></label>
      <label>Tampilkan<select aria-label="Tampilkan" value={filter} onChange={e => setFilter(e.target.value)}>
        <option value="all">Semua status</option><option value="active">Dalam proses</option><option value="review">Menunggu QA</option><option value="approved">Hasil disetujui</option><option value="closed">Ditutup / dibatalkan</option>
      </select></label></div>
    {error ? <p role="alert" className={styles.empty}>Antrean gagal dimuat. Periksa koneksi, lalu pilih Muat ulang. Jumlah permintaan belum dapat dipastikan.</p>
      : <><p role="status" className={styles.resultCount}>{visible.length} dari {items.length} permintaan ditampilkan</p>
        {visible.length ? lab
          ? <table className={styles.overviewTable} aria-label="Antrean permintaan uji Lab">
              <thead><tr><th scope="col">Lot dan permintaan</th><th scope="col">Jenis uji</th><th scope="col">Status</th><th scope="col">Langkah berikutnya</th><th scope="col">Detail</th></tr></thead>
              <tbody>{visible.map(item => <LabQueueRow key={item.id} item={item} />)}</tbody>
            </table>
          : <div className={styles.requestList}>{visible.map(item => <div key={item.id}>{item.content}</div>)}</div>
          : <div className={styles.empty}><h3>{items.length ? 'Tidak ada hasil yang cocok' : 'Belum ada permintaan'}</h3><p>{items.length ? 'Periksa kode lot atau ubah filter status.' : 'Permintaan yang masuk ke site dan role Anda akan tampil di sini. Tidak perlu membuat permintaan ulang hanya untuk mengisi antrean.'}</p>
            {!!items.length && <button type="button" className="btn" onClick={() => { setQuery(''); setFilter('all'); }}>Hapus pencarian & filter</button>}</div>}</>}
  </section>;
}

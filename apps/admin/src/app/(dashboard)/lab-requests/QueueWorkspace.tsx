'use client';

import { useState, type ReactNode } from 'react';
import { useRouter } from 'next/navigation';
import styles from './queue.module.css';

type Item = { id: string; search: string; group: string; content: ReactNode };
export default function QueueWorkspace({ items, error }: { items: Item[]; error: boolean }) {
  const [query, setQuery] = useState('');
  const [filter, setFilter] = useState('all');
  const router = useRouter();
  const visible = items.filter(item => (filter === 'all' || item.group === filter) && item.search.toLocaleLowerCase('id-ID').includes(query.trim().toLocaleLowerCase('id-ID')));
  return <section aria-label="Daftar permintaan" className={styles.workspace}>
    <div className={styles.sectionHeading}><div><h2>Permintaan & hasil pengujian</h2><p>Menampilkan maksimal 50 permintaan terbaru dalam cakupan akun Anda.</p></div>
      <button type="button" className="btn" onClick={() => router.refresh()}>Muat ulang</button></div>
    {!error && <div className={styles.metrics}>
      {[['active', 'Dalam proses'], ['review', 'Menunggu QA'], ['approved', 'Hasil disetujui']].map(([group, label]) => <div key={group}><strong>{items.filter(item => item.group === group).length}</strong><span>{label}</span></div>)}
    </div>}
    <div className={styles.toolbar}><label>Cari permintaan<input type="search" placeholder="Kode lot atau nomor permintaan" value={query} onChange={e => setQuery(e.target.value)} /></label>
      <label>Tampilkan<select aria-label="Tampilkan" value={filter} onChange={e => setFilter(e.target.value)}>
        <option value="all">Semua status</option><option value="active">Dalam proses</option><option value="review">Menunggu QA</option><option value="approved">Hasil disetujui</option><option value="closed">Ditutup / dibatalkan</option>
      </select></label></div>
    {error ? <p role="alert" className={styles.empty}>Antrean gagal dimuat. Periksa koneksi, lalu pilih Muat ulang. Jumlah permintaan belum dapat dipastikan.</p>
      : <><p role="status" className={styles.resultCount}>{visible.length} dari {items.length} permintaan ditampilkan</p>
        {visible.length ? <div className={styles.requestList}>{visible.map(item => <div key={item.id}>{item.content}</div>)}</div>
          : <div className={styles.empty}><h3>{items.length ? 'Tidak ada hasil yang cocok' : 'Belum ada permintaan'}</h3><p>{items.length ? 'Periksa kode lot atau ubah filter status.' : 'Permintaan yang masuk ke site dan role Anda akan tampil di sini. Tidak perlu membuat permintaan ulang hanya untuk mengisi antrean.'}</p>
            {!!items.length && <button type="button" className="btn" onClick={() => { setQuery(''); setFilter('all'); }}>Hapus pencarian & filter</button>}</div>}</>}
  </section>;
}

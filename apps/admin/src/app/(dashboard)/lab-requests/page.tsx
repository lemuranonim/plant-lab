import { createClient } from '@/lib/supabase/server';
import styles from '../lab-quality/lab-quality.module.css';

export const revalidate = 0;

export default async function LabRequestsPage() {
  const supabase = await createClient();
  const { data: requests, error } = await supabase
    .from('pl_lab_requests')
    .select('*')
    .order('requested_at', { ascending: false });

  const getStatusBadge = (status: string) => {
    const s = status?.toUpperCase();
    if (s === 'APPROVED') return 'badge-emerald';
    if (s === 'IN_TESTING' || s === 'RECEIVED') return 'badge-gold';
    if (s === 'SENT' || s === 'PREPARED') return 'badge-cyan';
    if (s === 'REJECTED') return 'badge-rose';
    return 'badge-gray';
  };

  return (
    <div className={styles.container}>
      <header className={styles.pageHeader}>
        <div>
          <h1 className={styles.pageTitle}>🔬 Lab Requests & Sample Tracking</h1>
          <p className={styles.pageSubtitle}>
            Pelacakan sampel benih dari Kebun/Plant ke Lab Analyst (Alur Status 6 Stage Stepper)
          </p>
        </div>
        <div className="badge badge-gold" style={{ fontSize: '12px', padding: '6px 12px' }}>
          {requests?.length || 0} Total Requests
        </div>
      </header>

      {error ? (
        <div className="card" style={{ padding: '24px', borderColor: 'var(--danger)' }}>
          <p style={{ color: 'var(--danger)', fontWeight: 'bold' }}>Error loading lab requests: {error.message}</p>
        </div>
      ) : (
        <div className="card" style={{ padding: '0', overflow: 'hidden' }}>
          <div style={{ overflowX: 'auto' }}>
            <table className={styles.table}>
              <thead>
                <tr>
                  <th>No. Request</th>
                  <th>Lot ID Raw</th>
                  <th>Jenis Pengujian</th>
                  <th>Berat Sampel</th>
                  <th>Status Tracking</th>
                  <th>Pengambil Sampel</th>
                  <th>Waktu Request</th>
                  <th>Notes</th>
                </tr>
              </thead>
              <tbody>
                {requests && requests.length > 0 ? (
                  requests.map((item: any) => (
                    <tr key={item.id}>
                      <td style={{ fontWeight: 'bold', fontFamily: 'monospace', color: 'var(--accent-light)' }}>
                        {item.request_no}
                      </td>
                      <td style={{ fontWeight: 'bold' }}>{item.lot_id_raw}</td>
                      <td>
                        <span className="badge badge-emerald">{item.test_type}</span>
                      </td>
                      <td style={{ fontWeight: '600' }}>{item.sample_qty_grams ? `${item.sample_qty_grams} g` : '500 g'}</td>
                      <td>
                        <span className={`badge ${getStatusBadge(item.status)}`}>{item.status}</span>
                      </td>
                      <td style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>
                        {item.sampler_name || item.sampler_email || 'Inspector'}
                      </td>
                      <td style={{ fontSize: '13px', color: 'var(--text-muted)' }}>
                        {item.requested_at ? new Date(item.requested_at).toLocaleDateString('id-ID') : '-'}
                      </td>
                      <td style={{ color: 'var(--text-muted)', fontSize: '13px' }}>{item.notes || '-'}</td>
                    </tr>
                  ))
                ) : (
                  <tr>
                    <td colSpan={8} style={{ textAlign: 'center', padding: '32px', color: 'var(--text-muted)' }}>
                      Belum ada permintaan pengujian sampel lab tersimpan.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
}

import { createClient } from '@/lib/supabase/server';
import styles from '../lab-quality/lab-quality.module.css';
import { requireVariantAccess } from '@/lib/accessContext';

export const revalidate = 0;

type ReceivingHarvestRow = {
  id: string | number;
  lot_id_raw: string | null;
  hybrid_code: string | null;
  shelling_qty_kg: number | null;
  incoming_date: string | null;
  field_status: string | null;
  remarks: string | null;
  notes: string | null;
};

export default async function ReceivingPage() {
  await requireVariantAccess('PLANT');
  const supabase = await createClient();
  const { data: harvests, error } = await supabase
    .from('pl_receiving_harvest')
    .select('*')
    .order('created_at', { ascending: false });

  return (
    <div className={styles.container}>
      <header className={styles.pageHeader}>
        <div>
          <h1 className={styles.pageTitle}>🚜 Receiving Harvest Management</h1>
          <p className={styles.pageSubtitle}>
            Data penerimaan hasil panen jagung (gleondong) dari kebun mitra & grower
          </p>
        </div>
        <div className="badge badge-gold" style={{ fontSize: '12px', padding: '6px 12px' }}>
          {harvests?.length || 0} Total Harvest Records
        </div>
      </header>

      {error ? (
        <div className="card" style={{ padding: '24px', borderColor: 'var(--danger)' }}>
          <p style={{ color: 'var(--danger)', fontWeight: 'bold' }}>Error loading receiving data: {error.message}</p>
        </div>
      ) : (
        <div className="card" style={{ padding: '0', overflow: 'hidden' }}>
          <div style={{ overflowX: 'auto' }}>
            <table className={styles.table}>
              <thead>
                <tr>
                  <th>No. Lot / Batch</th>
                  <th>Varietas Hybrid</th>
                  <th>Jumlah Shelling (Kg)</th>
                  <th>Tanggal Masuk</th>
                  <th>Status Lapangan</th>
                  <th>Remarks</th>
                </tr>
              </thead>
              <tbody>
                {harvests && harvests.length > 0 ? (
                  harvests.map((item: ReceivingHarvestRow) => (
                    <tr key={item.id}>
                      <td style={{ fontWeight: 'bold', color: 'var(--accent-light)' }}>
                        {item.lot_id_raw || 'Unknown Lot'}
                      </td>
                      <td>
                        <span className="badge badge-emerald">{item.hybrid_code || '-'}</span>
                      </td>
                      <td style={{ fontWeight: '600' }}>
                        {item.shelling_qty_kg ? `${item.shelling_qty_kg.toLocaleString()} kg` : '0 kg'}
                      </td>
                      <td>{item.incoming_date ? new Date(item.incoming_date).toLocaleDateString('id-ID') : '-'}</td>
                      <td>
                        <span
                          className={`badge ${
                            item.field_status === 'ACCEPTED' || item.field_status === 'APPROVED'
                              ? 'badge-emerald'
                              : 'badge-amber'
                          }`}
                        >
                          {item.field_status || 'DRAFT'}
                        </span>
                      </td>
                      <td style={{ color: 'var(--text-muted)', fontSize: '13px' }}>
                        {item.remarks || item.notes || 'Normal delivery'}
                      </td>
                    </tr>
                  ))
                ) : (
                  <tr>
                    <td colSpan={6} style={{ textAlign: 'center', padding: '32px', color: 'var(--text-muted)' }}>
                      Belum ada data receiving harvest.
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

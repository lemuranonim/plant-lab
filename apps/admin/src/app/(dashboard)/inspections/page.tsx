import { createClient } from '@/lib/supabase/server';
import styles from '../lab-quality/lab-quality.module.css';
import { requireAccess } from '@/lib/accessContext';

export const revalidate = 0;

type InspectionRow = {
  id: string;
  inspection_no: string | null;
  process_type: string | null;
  is_oos: boolean | null;
  notes: string | null;
  created_at: string | null;
  submitted_at: string | null;
};

export default async function InspectionsPage() {
  await requireAccess('can_access_plant');
  const supabase = await createClient();
  const { data: inspections, error } = await supabase
    .from('pl_inspections')
    .select('*')
    .order('created_at', { ascending: false });

  const oosCount = inspections?.filter((i) => i.is_oos === true).length || 0;
  const passedCount = (inspections?.length || 0) - oosCount;

  return (
    <div className={styles.container}>
      <header className={styles.pageHeader}>
        <div>
          <h1 className={styles.pageTitle}>📋 Plant Process Inspections</h1>
          <p className={styles.pageSubtitle}>
            Hasil pengawasan kualitas 6 proses pengolahan benih (Intake, Drier, Shelling, Cleaning, Treatment, Packing)
          </p>
        </div>
        <div style={{ display: 'flex', gap: '8px' }}>
          <span className="badge badge-emerald" style={{ padding: '6px 12px', fontSize: '12px' }}>
            ✓ {passedCount} PASSED
          </span>
          <span className="badge badge-rose" style={{ padding: '6px 12px', fontSize: '12px' }}>
            ⚠️ {oosCount} OUT OF SPEC
          </span>
        </div>
      </header>

      {error ? (
        <div className="card" style={{ padding: '24px', borderColor: 'var(--danger)' }}>
          <p style={{ color: 'var(--danger)', fontWeight: 'bold' }}>Error loading inspections data: {error.message}</p>
        </div>
      ) : (
        <div className="card" style={{ padding: '0', overflow: 'hidden' }}>
          <div style={{ overflowX: 'auto' }}>
            <table className={styles.table}>
              <thead>
                <tr>
                  <th>No. Inspeksi</th>
                  <th>Proses Pengolahan</th>
                  <th>Status Kualitas</th>
                  <th>Inspektur</th>
                  <th>Waktu Inspeksi</th>
                  <th>Catatan / Parameters</th>
                </tr>
              </thead>
              <tbody>
                {inspections && inspections.length > 0 ? (
                  inspections.map((item: InspectionRow) => {
                    const isOos = item.is_oos === true;
                    const dateStr = item.created_at || item.submitted_at;
                    const dateFormatted = dateStr ? new Date(dateStr).toLocaleString('id-ID') : '-';

                    return (
                      <tr key={item.id}>
                        <td style={{ fontWeight: 'bold', fontFamily: 'monospace', color: 'var(--accent-light)' }}>
                          {item.inspection_no || `INS-${item.id.substring(0, 6)}`}
                        </td>
                        <td>
                          <span
                            className="badge"
                            style={{
                              backgroundColor: 'rgba(16, 185, 129, 0.15)',
                              color: 'var(--accent-light)',
                              fontWeight: 'bold',
                            }}
                          >
                            {item.process_type || 'UNKNOWN'}
                          </span>
                        </td>
                        <td>
                          <span className={`badge ${isOos ? 'badge-rose' : 'badge-emerald'}`}>
                            {isOos ? '⚠️ OUT OF SPEC' : '✓ PASSED'}
                          </span>
                        </td>
                        <td style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>
                          {item.notes?.includes('email:') ? item.notes.split('email:')[1] : 'Inspector'}
                        </td>
                        <td style={{ fontSize: '13px', color: 'var(--text-muted)' }}>{dateFormatted}</td>
                        <td style={{ color: 'var(--text-secondary)', fontSize: '13px' }}>
                          {item.notes || 'Pengawasan parameter proses standar'}
                        </td>
                      </tr>
                    );
                  })
                ) : (
                  <tr>
                    <td colSpan={6} style={{ textAlign: 'center', padding: '32px', color: 'var(--text-muted)' }}>
                      Belum ada data hasil inspeksi plant tersimpan.
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

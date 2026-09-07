import { createClient } from '@/lib/supabase/server';
import styles from './reports.module.css';
import { requireVariantAccess } from '@/lib/accessContext';

export default async function ReportsPage() {
  await requireVariantAccess('LAB');
  const supabase = await createClient();

  // Fetch summary by hybrid for report presentation from pl_germ_results
  const { data: hybridStats } = await supabase
    .from('pl_germ_results')
    .select('hybrid_code, germ_normal_pct, soak_normal_pct, germ_conclusion');

  // Group stats by hybrid
  const hybridMap: Record<string, { total: number; accepted: number; avgGerm: number; sumGerm: number }> = {};

  if (hybridStats) {
    hybridStats.forEach((row) => {
      const h = row.hybrid_code || 'UNKNOWN';
      if (!hybridMap[h]) {
        hybridMap[h] = { total: 0, accepted: 0, avgGerm: 0, sumGerm: 0 };
      }
      hybridMap[h].total += 1;
      if (row.germ_conclusion === 'ACCEPTED' || row.germ_conclusion === 'GF') {
        hybridMap[h].accepted += 1;
      }
      if (row.germ_normal_pct) {
        hybridMap[h].sumGerm += Number(row.germ_normal_pct);
      }
    });

    Object.keys(hybridMap).forEach((h) => {
      hybridMap[h].avgGerm = Math.round((hybridMap[h].sumGerm / (hybridMap[h].total || 1)) * 10) / 10;
    });
  }

  return (
    <div className={styles.container}>
      {/* Header */}
      <div className={styles.header}>
        <h1 className={styles.title}>Quality & Operations Analytics</h1>
        <p className={styles.subtitle}>Executive reporting on seed germination rates, hybrid yield, and processing metrics</p>
      </div>

      {/* Reports Grid */}
      <div className={styles.statsGrid}>
        <div className={`card ${styles.statCard} ${styles.statCardEmerald}`}>
          <div className={styles.cardHeader}>
            <span className={styles.cardLabel}>Lab Germination</span>
            <span className="badge badge-success">Live Report</span>
          </div>
          <h3 className={styles.cardTitle}>Germination Summary</h3>
          <p className={styles.cardDesc}>Aggregated germination and vigor observations across CY2026 batches.</p>
        </div>

        <div className={`card ${styles.statCard} ${styles.statCardAmber}`}>
          <div className={styles.cardHeader}>
            <span className={styles.cardLabel}>Receiving Harvest</span>
            <span className="badge badge-gold">Active</span>
          </div>
          <h3 className={styles.cardTitle}>Harvest Intake Volume</h3>
          <p className={styles.cardDesc}>Daily FC & SWC receiving volume from Prasad and grower fields.</p>
        </div>

        <div className={`card ${styles.statCard} ${styles.statCardBlue}`}>
          <div className={styles.cardHeader}>
            <span className={styles.cardLabel}>Plant Processing</span>
            <span className="badge badge-warning">Monitoring</span>
          </div>
          <h3 className={styles.cardTitle}>Shelling & Drying OOS</h3>
          <p className={styles.cardDesc}>Out-of-spec frequency tracking for BIN temperatures & moisture content.</p>
        </div>

        <div className={`card ${styles.statCard} ${styles.statCardPurple}`}>
          <div className={styles.cardHeader}>
            <span className={styles.cardLabel}>Lab Logistics</span>
            <span className="badge badge-success">On Schedule</span>
          </div>
          <h3 className={styles.cardTitle}>Testing SLA & TAT</h3>
          <p className={styles.cardDesc}>Turnaround time from sample delivery to final certificate issuance.</p>
        </div>
      </div>

      {/* Hybrid Quality Breakdown Table */}
      <div className={`card ${styles.tableCard}`}>
        <div className={styles.tableHeader}>
          <div>
            <h2 className={styles.tableTitle}>Hybrid Seed Performance Breakdown</h2>
            <p className={styles.tableDesc}>Pass rate & average germination per hybrid variety</p>
          </div>
          <button className="btn btn-outline text-xs">
            Export CSV
          </button>
        </div>

        <div className={styles.tableWrapper}>
          <table className={styles.table}>
            <thead>
              <tr>
                <th>Hybrid Code</th>
                <th>Total Tested Lots</th>
                <th>Accepted Lots</th>
                <th>Pass Rate (%)</th>
                <th>Average Germination</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {Object.entries(hybridMap).map(([hybrid, data]) => {
                const passRate = Math.round((data.accepted / (data.total || 1)) * 100);
                return (
                  <tr key={hybrid}>
                    <td className="font-bold text-text-primary">
                      <span className="badge badge-gold">{hybrid}</span>
                    </td>
                    <td className="font-semibold">{data.total}</td>
                    <td className="text-success font-semibold">{data.accepted}</td>
                    <td>
                      <div className={styles.progressBarContainer}>
                        <div className={styles.progressBarTrack}>
                          <div
                            className={`${styles.progressBarFill} ${passRate >= 80 ? styles.fillSuccess : styles.fillWarning}`}
                            style={{ width: `${passRate}%` }}
                          ></div>
                        </div>
                        <span className="font-bold text-xs">{passRate}%</span>
                      </div>
                    </td>
                    <td>
                      <span className={data.avgGerm >= 80 ? 'text-success font-bold' : 'text-danger font-bold'}>
                        {data.avgGerm}%
                      </span>
                    </td>
                    <td>
                      {passRate >= 80 ? (
                        <span className="badge badge-success">High Performing</span>
                      ) : (
                        <span className="badge badge-warning">Needs Review</span>
                      )}
                    </td>
                  </tr>
                );
              })}
              {Object.keys(hybridMap).length === 0 && (
                <tr>
                  <td colSpan={6} className="text-center py-12 text-text-muted">
                    No report data available.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}

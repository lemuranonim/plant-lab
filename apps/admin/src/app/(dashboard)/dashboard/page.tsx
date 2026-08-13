import { createClient } from '@/lib/supabase/server';
import styles from './dashboard.module.css';
import Link from 'next/link';

export default async function DashboardPage() {
  const supabase = await createClient();

  // Fetch summary stats using custom RPC
  const { data: statsData, error: statsError } = await supabase.rpc('pl_get_germ_dashboard_stats', {
    p_season: '2026',
  });

  // Fetch recent quality evaluations from pl_germ_results to show actual lab data
  const { data: recentLots } = await supabase
    .from('pl_germ_results')
    .select('lot_id_raw, hybrid_code, test_category, germ_normal_pct, soak_normal_pct, germ_conclusion, germ_date')
    .order('germ_date', { ascending: false })
    .limit(8);

  const stats = statsData || {
    total_lots: 0,
    accepted: 0,
    rejected: 0,
    avg_germ_pct: 0,
    avg_vigor_ct_pct: 0,
    below_80_pct: 0,
  };

  return (
    <div className={styles.container}>
      <div className={styles.header}>
        <div>
          <h1 className={styles.title}>Plant+Lab Quality Dashboard</h1>
          <p className={styles.subtitle}>Real-time seed quality analytics & germination performance (CY2026)</p>
        </div>
        <div className="flex gap-2">
          <Link href="/lab-quality" className="btn btn-outline text-sm">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" style={{ width: '16px', height: '16px', marginRight: '0.25rem' }}>
              <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path>
              <polyline points="14 2 14 8 20 8"></polyline>
            </svg>
            View All Lab Records
          </Link>
        </div>
      </div>

      {statsError && (
        <div className="bg-red-500/10 border border-red-500/30 text-red-500 p-4 rounded-xl mb-6 flex items-center gap-3">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" style={{ width: '20px', height: '20px' }}>
            <path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"></path>
            <line x1="12" y1="9" x2="12" y2="13"></line>
            <line x1="12" y1="17" x2="12.01" y2="17"></line>
          </svg>
          <span>Error connecting to Supabase: {statsError.message}</span>
        </div>
      )}

      {/* KPI Cards Grid */}
      <div className={styles.statsGrid}>
        {/* Card 1: Total Lots Tested */}
        <div className={`${styles.statCard} card`}>
          <div className={styles.statIconWrapper}>
            {/* Corn / Batch Icon */}
            <svg viewBox="0 0 24 24" fill="none" stroke="var(--accent)" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" style={{ width: '24px', height: '24px' }}>
              <path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"></path>
              <polyline points="3.27 6.96 12 12.01 20.73 6.96"></polyline>
              <line x1="12" y1="22.08" x2="12" y2="12"></line>
            </svg>
          </div>
          <div className={styles.statContent}>
            <div className={styles.statLabel}>Total Seed Lots</div>
            <div className={styles.statValue}>{stats.total_lots}</div>
          </div>
        </div>

        {/* Card 2: Average Germination Rate */}
        <div className={`${styles.statCard} card`}>
          <div className={styles.statIconWrapper}>
            {/* Seedling Sprout Icon */}
            <svg viewBox="0 0 24 24" fill="none" stroke="var(--accent)" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" style={{ width: '24px', height: '24px' }}>
              <path d="M7 20h10"></path>
              <path d="M10 20c0-3.5 1-6.5 2-10"></path>
              <path d="M12 10s-3-2-5-1.5S3 12 3 14s4 2 6-1"></path>
              <path d="M12 7s3-2 5-1.5S21 9 21 11s-4 2-6-1"></path>
            </svg>
          </div>
          <div className={styles.statContent}>
            <div className={styles.statLabel}>Avg Germination</div>
            <div className={styles.statValue}>{stats.avg_germ_pct ?? '-'}%</div>
          </div>
        </div>

        {/* Card 3: Average Vigor CT */}
        <div className={`${styles.statCard} card`}>
          <div className={styles.statIconWrapper}>
            {/* Golden Sun / Vigor Icon */}
            <svg viewBox="0 0 24 24" fill="none" stroke="var(--accent-gold)" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" style={{ width: '24px', height: '24px' }}>
              <circle cx="12" cy="12" r="5"></circle>
              <line x1="12" y1="1" x2="12" y2="3"></line>
              <line x1="12" y1="21" x2="12" y2="23"></line>
              <line x1="4.22" y1="4.22" x2="5.64" y2="5.64"></line>
              <line x1="18.36" y1="18.36" x2="19.78" y2="19.78"></line>
              <line x1="1" y1="12" x2="3" y2="12"></line>
              <line x1="21" y1="12" x2="23" y2="12"></line>
            </svg>
          </div>
          <div className={styles.statContent}>
            <div className={styles.statLabel}>Avg Vigor (CT)</div>
            <div className={styles.statValue}>{stats.avg_vigor_ct_pct ?? '-'}%</div>
          </div>
        </div>

        {/* Card 4: Below Standard Alert */}
        <div className={`${styles.statCard} card`}>
          <div className={styles.statIconWrapper}>
            {/* Warning Alert Icon */}
            <svg viewBox="0 0 24 24" fill="none" stroke="var(--danger)" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" style={{ width: '24px', height: '24px' }}>
              <path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"></path>
              <line x1="12" y1="9" x2="12" y2="13"></line>
              <line x1="12" y1="17" x2="12.01" y2="17"></line>
            </svg>
          </div>
          <div className={styles.statContent}>
            <div className={styles.statLabel}>Below 80% Standard</div>
            <div className={styles.statValue}>{stats.below_80_pct}</div>
          </div>
        </div>
      </div>

      {/* Main Content Grid */}
      <div className={styles.contentGrid}>
        <div className={`${styles.mainPanel} card`}>
          <div className={styles.panelHeader}>
            <div>
              <h2 className="text-xl font-bold">Recent Quality Evaluations</h2>
              <p className="text-xs text-text-muted mt-0.5">Live seed germination and vigor testing records</p>
            </div>
            <Link href="/lab-quality" className="btn btn-ghost text-xs">
              View All Data →
            </Link>
          </div>

          <div className={styles.tableWrapper}>
            <table className={styles.table}>
              <thead>
                <tr>
                  <th>Lot ID</th>
                  <th>Hybrid Code</th>
                  <th>Category</th>
                  <th>Germination (%)</th>
                  <th>Vigor Soak (%)</th>
                  <th>Conclusion</th>
                  <th>Result Date</th>
                </tr>
              </thead>
              <tbody>
                {recentLots?.map((lot, i) => (
                  <tr key={i}>
                    <td className="font-semibold text-text-primary">
                      {lot.lot_id_raw || 'N/A'}
                    </td>
                    <td>
                      <span className="badge badge-gold">{lot.hybrid_code}</span>
                    </td>
                    <td className="font-medium">{lot.test_category}</td>
                    <td>
                      <span className={lot.germ_normal_pct >= 80 ? 'text-success font-semibold' : 'text-danger font-semibold'}>
                        {lot.germ_normal_pct ? `${lot.germ_normal_pct}%` : <span className="text-border">-</span>}
                      </span>
                    </td>
                    <td>{lot.soak_normal_pct ? `${lot.soak_normal_pct}%` : <span className="text-border">-</span>}</td>
                    <td>
                      {lot.germ_conclusion === 'ACCEPTED' || lot.germ_conclusion === 'GF' ? (
                        <span className="badge badge-success">✓ {lot.germ_conclusion === 'GF' ? 'Passed (GF)' : 'Accepted'}</span>
                      ) : lot.germ_conclusion === 'REJECTED' || lot.germ_conclusion === 'RF' ? (
                        <span className="badge badge-danger">✕ {lot.germ_conclusion === 'RF' ? 'Rejected (RF)' : 'Rejected'}</span>
                      ) : lot.germ_conclusion === 'YF' ? (
                        <span className="badge badge-warning">⚠ Marginal (YF)</span>
                      ) : (
                        <span className="badge badge-neutral">{lot.germ_conclusion || 'Pending'}</span>
                      )}
                    </td>
                    <td className="text-text-muted">{lot.germ_date}</td>
                  </tr>
                ))}
                {(!recentLots || recentLots.length === 0) && (
                  <tr>
                    <td colSpan={8} className="text-center py-8 text-text-muted">
                      No recent seed quality data found.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  );
}
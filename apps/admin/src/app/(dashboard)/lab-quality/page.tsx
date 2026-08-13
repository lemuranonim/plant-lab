'use client';

import { useEffect, useState } from 'react';
import { createClient } from '@/lib/supabase/client';
import styles from './lab-quality.module.css';

type GermResult = {
  id: number;
  lot_id_raw: string;
  hybrid_code: string;
  test_category: string;
  germ_normal_pct: number;
  soak_normal_pct: number;
  germ_conclusion: string;
  germ_date: string;
};

export default function LabQualityPage() {
  const [items, setItems] = useState<GermResult[]>([]);
  const [loading, setLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState<'ALL' | 'ACCEPTED' | 'REJECTED'>('ALL');
  const [categoryFilter, setCategoryFilter] = useState<string>('ALL');
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedItem, setSelectedItem] = useState<GermResult | null>(null);

  useEffect(() => {
    async function fetchData() {
      const supabase = createClient();
      let query = supabase
        .from('pl_germ_results')
        .select('*')
        .order('germ_date', { ascending: false })
        .limit(150);

      if (statusFilter !== 'ALL') {
        query = query.eq('germ_conclusion', statusFilter);
      }

      if (categoryFilter !== 'ALL') {
        query = query.eq('test_category', categoryFilter);
      }

      const { data, error } = await query;

      if (!error && data) {
        setItems(data as GermResult[]);
      } else {
        console.error('Error fetching quality info:', error);
      }
      setLoading(false);
    }

    setLoading(true);
    fetchData();
  }, [statusFilter, categoryFilter]);

  // Client-side search filter
  const filteredItems = items.filter((item) => {
    if (!searchQuery.trim()) return true;
    const q = searchQuery.toLowerCase();
    return (
      (item.lot_id_raw && item.lot_id_raw.toLowerCase().includes(q)) ||
      (item.hybrid_code && item.hybrid_code.toLowerCase().includes(q)) ||
      (item.test_category && item.test_category.toLowerCase().includes(q))
    );
  });

  const categories = ['ALL', 'FC', 'SWC', 'FG_FC', 'FG_SWC', 'PS', 'PREBASIC', 'VEGE'];

  return (
    <div className={styles.container}>
      {/* Header */}
      <div className={styles.header}>
        <div>
          <h1 className={styles.title}>Lab Quality Database</h1>
          <p className={styles.subtitle}>Comprehensive germination & vigor testing data across CY2026 lots</p>
        </div>
      </div>

      {/* Unified Filter Toolbar */}
      <div className={styles.filterBar}>
        {/* Live Search */}
        <div className={styles.searchBox}>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" style={{ width: '16px', height: '16px', color: 'var(--text-muted)' }}>
            <circle cx="11" cy="11" r="8"></circle>
            <line x1="21" y1="21" x2="16.65" y2="16.65"></line>
          </svg>
          <input
            type="text"
            placeholder="Search Lot ID, Hybrid (AX09)..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className={styles.searchInput}
          />
          {searchQuery && (
            <button onClick={() => setSearchQuery('')} className="text-xs text-text-muted hover:text-text-primary mr-2">
              ✕
            </button>
          )}
        </div>

        <div className="flex items-center gap-3">
          <div className="flex items-center gap-2">
            <span className="text-xs font-semibold text-text-muted uppercase tracking-wide">Category:</span>
            <select 
              className={styles.filterSelect}
              value={categoryFilter}
              onChange={(e) => setCategoryFilter(e.target.value)}
            >
              <option value="ALL">All Crops</option>
              <option value="FC">FC (Field Corn)</option>
              <option value="SWC">SWC (Sweet Corn)</option>
              <option value="FG_FC">FG_FC</option>
              <option value="FG_SWC">FG_SWC</option>
              <option value="PS">PS</option>
              <option value="PREBASIC">PREBASIC</option>
              <option value="VEGE">VEGE</option>
            </select>
          </div>

          <div className="flex items-center gap-2">
            <span className="text-xs font-semibold text-text-muted uppercase tracking-wide">Status:</span>
            <select 
              className={styles.filterSelect}
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value as any)}
            >
              <option value="ALL">All Records</option>
              <option value="ACCEPTED">✓ Accepted</option>
              <option value="REJECTED">✕ Rejected</option>
            </select>
          </div>
        </div>
      </div>

      {/* Main Table Card */}
      <div className={`${styles.tableCard} card`}>
        {loading ? (
          <div className={styles.loadingState}>
            <div className={styles.spinner}></div>
            <p>Loading seed quality records from Supabase...</p>
          </div>
        ) : (
          <div className={styles.tableWrapper}>
            <table className={styles.table}>
              <thead>
                <tr>
                  <th>Lot ID</th>
                  <th>Hybrid</th>
                  <th>Category</th>
                  <th>Germination (%)</th>
                  <th>Vigor Soak (%)</th>
                  <th>Conclusion</th>
                  <th>Date</th>
                </tr>
              </thead>
              <tbody>
                {filteredItems.length === 0 ? (
                  <tr>
                    <td colSpan={7} className="text-center py-12 text-text-muted">
                      No seed quality records found matching your filters.
                    </td>
                  </tr>
                ) : (
                  filteredItems.map((item) => (
                    <tr key={item.id} onClick={() => setSelectedItem(item)} title="Click to view full seed detail">
                      <td className="font-bold text-text-primary">{item.lot_id_raw || '-'}</td>
                      <td>
                        <span className="badge badge-gold">{item.hybrid_code}</span>
                      </td>
                      <td className="font-medium text-text-secondary">{item.test_category}</td>
                      <td>
                        <span className={item.germ_normal_pct >= 80 ? 'text-success font-semibold' : 'text-danger font-semibold'}>
                          {item.germ_normal_pct ? `${item.germ_normal_pct}%` : <span className="text-border">-</span>}
                        </span>
                      </td>
                      <td>{item.soak_normal_pct ? `${item.soak_normal_pct}%` : <span className="text-border">-</span>}</td>
                      <td>
                        {item.germ_conclusion === 'ACCEPTED' || item.germ_conclusion === 'GF' ? (
                          <span className="badge badge-success">✓ {item.germ_conclusion === 'GF' ? 'Passed (GF)' : 'Accepted'}</span>
                        ) : item.germ_conclusion === 'REJECTED' || item.germ_conclusion === 'RF' ? (
                          <span className="badge badge-danger">✕ {item.germ_conclusion === 'RF' ? 'Rejected (RF)' : 'Rejected'}</span>
                        ) : item.germ_conclusion === 'YF' ? (
                          <span className="badge badge-warning">⚠ Marginal (YF)</span>
                        ) : (
                          <span className="badge badge-neutral">{item.germ_conclusion || 'Pending'}</span>
                        )}
                      </td>
                      <td className="text-text-muted">{item.germ_date}</td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Detail Modal Drawer */}
      {selectedItem && (
        <div className={styles.modalOverlay} onClick={() => setSelectedItem(null)}>
          <div className={styles.modal} onClick={(e) => e.stopPropagation()}>
            <div className={styles.modalHeader}>
              <div>
                <h3 className={styles.modalTitle}>Seed Quality Details</h3>
                <p className="text-xs text-text-muted">Lot ID: {selectedItem.lot_id_raw || 'N/A'}</p>
              </div>
              <button className={styles.modalClose} onClick={() => setSelectedItem(null)}>
                ✕
              </button>
            </div>

            <div className={styles.modalGrid}>
              <div className={styles.modalField}>
                <span className={styles.modalLabel}>Hybrid Code</span>
                <span className={styles.modalValue}>
                  <span className="badge badge-gold">{selectedItem.hybrid_code}</span>
                </span>
              </div>

              <div className={styles.modalField}>
                <span className={styles.modalLabel}>Category / Crop</span>
                <span className={styles.modalValue}>{selectedItem.test_category}</span>
              </div>

              <div className={styles.modalField}>
                <span className={styles.modalLabel}>Germination Rate</span>
                <span className={`text-xl font-bold ${selectedItem.germ_normal_pct >= 80 ? 'text-success' : 'text-danger'}`}>
                  {selectedItem.germ_normal_pct ? `${selectedItem.germ_normal_pct}%` : 'N/A'}
                </span>
              </div>

              <div className={styles.modalField}>
                <span className={styles.modalLabel}>Vigor (Soak)</span>
                <span className="text-xl font-bold text-amber-500">
                  {selectedItem.soak_normal_pct ? `${selectedItem.soak_normal_pct}%` : 'N/A'}
                </span>
              </div>

              <div className={styles.modalField}>
                <span className={styles.modalLabel}>Result Date</span>
                <span className={styles.modalValue}>{selectedItem.germ_date || 'N/A'}</span>
              </div>

              <div className={styles.modalField}>
                <span className={styles.modalLabel}>Evaluation Status</span>
                <span className={styles.modalValue}>
                  {selectedItem.germ_conclusion === 'ACCEPTED' || selectedItem.germ_conclusion === 'GF' ? (
                    <span className="badge badge-success">✓ {selectedItem.germ_conclusion === 'GF' ? 'Passed (GF)' : 'Accepted'}</span>
                  ) : selectedItem.germ_conclusion === 'REJECTED' || selectedItem.germ_conclusion === 'RF' ? (
                    <span className="badge badge-danger">✕ {selectedItem.germ_conclusion === 'RF' ? 'Rejected (RF)' : 'Rejected'}</span>
                  ) : selectedItem.germ_conclusion === 'YF' ? (
                    <span className="badge badge-warning">⚠ Marginal (YF)</span>
                  ) : (
                    <span className="badge badge-neutral">{selectedItem.germ_conclusion || 'Pending'}</span>
                  )}
                </span>
              </div>
            </div>

            <div className="flex justify-end pt-3 border-t border-border">
              <button className="btn btn-primary" onClick={() => setSelectedItem(null)}>
                Close Details
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
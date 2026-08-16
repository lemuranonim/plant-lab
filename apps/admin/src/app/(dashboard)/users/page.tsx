import { operationalWritesEnabled } from '@/lib/operationalMode';

export default function UsersPage() {
  return (
    <div style={{ animation: 'fadeIn 0.5s ease-out' }}>
      <h1 style={{ fontSize: '1.875rem', fontWeight: 600, marginBottom: '0.5rem' }}>User & Role Assignments</h1>
      <p style={{ color: 'var(--text-secondary)', marginBottom: '2rem' }}>Manage user access across PLATFORM, PLANT, and LAB modules.</p>

      <div className="card">
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.5rem' }}>
          <h2 style={{ fontSize: '1.25rem', fontWeight: 600 }}>Role Definitions</h2>
          <button
            className="btn btn-primary"
            disabled={!operationalWritesEnabled}
            title={
              operationalWritesEnabled
                ? 'Assign role'
                : 'Disabled while Plant/Lab is in read-only mode'
            }
          >
            {operationalWritesEnabled ? '+ Assign Role' : 'Read-only'}
          </button>
        </div>

        <div style={{ overflowX: 'auto' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left', fontSize: '0.875rem' }}>
            <thead>
              <tr style={{ borderBottom: '1px solid var(--border)', color: 'var(--text-muted)' }}>
                <th style={{ padding: '0.75rem 1rem' }}>Module</th>
                <th style={{ padding: '0.75rem 1rem' }}>Role Code</th>
                <th style={{ padding: '0.75rem 1rem' }}>Role Name</th>
                <th style={{ padding: '0.75rem 1rem' }}>Scope</th>
              </tr>
            </thead>
            <tbody>
              <tr style={{ borderBottom: '1px solid var(--border)' }}>
                <td style={{ padding: '0.75rem 1rem' }}><span className="badge badge-success">PLATFORM</span></td>
                <td style={{ padding: '0.75rem 1rem', fontFamily: 'monospace' }}>PLATFORM_ADMIN</td>
                <td style={{ padding: '0.75rem 1rem' }}>Platform Administrator</td>
                <td style={{ padding: '0.75rem 1rem', color: 'var(--text-secondary)' }}>Global</td>
              </tr>
              <tr style={{ borderBottom: '1px solid var(--border)' }}>
                <td style={{ padding: '0.75rem 1rem' }}><span className="badge badge-warning">LAB</span></td>
                <td style={{ padding: '0.75rem 1rem', fontFamily: 'monospace' }}>LAB_QA_APPROVER</td>
                <td style={{ padding: '0.75rem 1rem' }}>Lab QA Approver</td>
                <td style={{ padding: '0.75rem 1rem', color: 'var(--text-secondary)' }}>Company / Lab Site</td>
              </tr>
              <tr style={{ borderBottom: '1px solid var(--border)' }}>
                <td style={{ padding: '0.75rem 1rem' }}><span className="badge badge-warning">PLANT</span></td>
                <td style={{ padding: '0.75rem 1rem', fontFamily: 'monospace' }}>PLANT_SPV</td>
                <td style={{ padding: '0.75rem 1rem' }}>Plant Supervisor</td>
                <td style={{ padding: '0.75rem 1rem', color: 'var(--text-secondary)' }}>Company / Plant Site</td>
              </tr>
              <tr>
                <td style={{ padding: '0.75rem 1rem' }}><span className="badge badge-warning">PLANT</span></td>
                <td style={{ padding: '0.75rem 1rem', fontFamily: 'monospace' }}>PLANT_OPERATOR</td>
                <td style={{ padding: '0.75rem 1rem' }}>Plant Operator</td>
                <td style={{ padding: '0.75rem 1rem', color: 'var(--text-secondary)' }}>Plant Site</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}

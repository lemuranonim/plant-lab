import Link from 'next/link';

export default function AccessDeniedPage() {
  return (
    <main
      style={{
        minHeight: '100vh',
        display: 'grid',
        placeItems: 'center',
        padding: '2rem',
        background: 'var(--background)',
      }}
    >
      <section className="card" style={{ maxWidth: '520px', padding: '2rem' }}>
        <p style={{ color: 'var(--warning)', fontWeight: 700, marginBottom: '0.75rem' }}>
          Access restricted
        </p>
        <h1 style={{ fontSize: '1.75rem', marginBottom: '0.75rem' }}>
          Your role cannot open this page
        </h1>
        <p style={{ color: 'var(--text-secondary)', marginBottom: '1.5rem' }}>
          Plant/Lab access follows the active module, company, and site assignment
          registered for your account.
        </p>
        <Link href="/dashboard" className="btn btn-primary">
          Return to dashboard
        </Link>
      </section>
    </main>
  );
}

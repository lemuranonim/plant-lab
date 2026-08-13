import Link from 'next/link';
import './globals.css';

export default function NotFound() {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', height: '100vh', gap: '1rem', textAlign: 'center' }}>
      <h1 style={{ fontSize: '4rem', fontWeight: 'bold', color: 'var(--accent)' }}>404</h1>
      <h2 style={{ fontSize: '1.5rem' }}>Page Not Found</h2>
      <p style={{ color: 'var(--text-secondary)' }}>The page you are looking for does not exist.</p>
      <Link href="/" className="btn btn-primary" style={{ marginTop: '1rem' }}>
        Return Home
      </Link>
    </div>
  );
}
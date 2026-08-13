'use client';

import { useEffect } from 'react';
import './globals.css';

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    console.error(error);
  }, [error]);

  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', height: '100vh', gap: '1rem', textAlign: 'center' }}>
      <h1 style={{ fontSize: '4rem', fontWeight: 'bold', color: 'var(--danger)' }}>500</h1>
      <h2 style={{ fontSize: '1.5rem' }}>Something went wrong!</h2>
      <p style={{ color: 'var(--text-secondary)' }}>An unexpected error occurred.</p>
      <button onClick={() => reset()} className="btn btn-primary" style={{ marginTop: '1rem' }}>
        Try again
      </button>
    </div>
  );
}
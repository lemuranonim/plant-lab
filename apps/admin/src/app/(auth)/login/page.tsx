'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { createClient } from '@/lib/supabase/client';
import styles from './login.module.css';

export default function LoginPage() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const router = useRouter();
  const supabase = createClient();

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError(null);

    const { error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    if (error) {
      setError(error.message);
      setLoading(false);
    } else {
      router.push('/dashboard');
      router.refresh();
    }
  };

  return (
    <div className={styles.container}>
      <div className={styles.brandPanel}>
        <div className={styles.glowCircle1}></div>
        <div className={styles.glowCircle2}></div>
        <div className={styles.brandContent}>
          <img src="/logo_plant_lab.png" alt="Plant+Lab Logo" style={{ width: '80px', height: '80px', marginBottom: '16px', objectFit: 'contain' }} />
          <h1 className={styles.brandTitle}>Plant+Lab</h1>
          <p className={styles.brandTagline}>Advanta Quality Management Platform</p>
        </div>
      </div>
      <div className={styles.formPanel}>
        <div className={styles.formCard}>
          <h2 className={styles.formTitle}>Welcome Back</h2>
          <p className={styles.formSubtitle}>Sign in to your account to continue</p>
          
          {error && <div className={styles.errorBanner}>{error}</div>}
          
          <form onSubmit={handleLogin} className={styles.form}>
            <div className={styles.inputGroup}>
              <input
                type="email"
                id="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder=" "
                required
                className={styles.input}
              />
              <label htmlFor="email" className={styles.label}>Email Address</label>
            </div>
            
            <div className={styles.inputGroup}>
              <input
                type="password"
                id="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder=" "
                required
                className={styles.input}
              />
              <label htmlFor="password" className={styles.label}>Password</label>
            </div>
            
            <button type="submit" className={`btn btn-primary ${styles.submitBtn}`} disabled={loading}>
              {loading ? 'Signing in...' : 'Sign In'}
            </button>
          </form>
        </div>
      </div>
    </div>
  );
}
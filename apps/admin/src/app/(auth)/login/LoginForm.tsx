'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import Image from 'next/image';
import { createClient } from '@/lib/supabase/client';
import styles from './login.module.css';

type LoginBrand = {
  appName: string;
  tagline: string;
  logoPath: string;
};

function friendlyAuthError(message: string) {
  const normalized = message.toLowerCase();

  if (normalized.includes('invalid login credentials')) {
    return 'Email atau password tidak sesuai.';
  }
  if (normalized.includes('email not confirmed')) {
    return 'Email belum dikonfirmasi oleh administrator.';
  }
  if (normalized.includes('rate limit') || normalized.includes('too many')) {
    return 'Terlalu banyak percobaan login. Tunggu sebentar lalu coba lagi.';
  }

  return `Login gagal: ${message}`;
}

export default function LoginForm({ brand }: { brand: LoginBrand }) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const router = useRouter();
  const supabase = createClient();

  const handleLogin = async (event: React.FormEvent) => {
    event.preventDefault();
    setLoading(true);
    setError(null);

    const { error: loginError } = await supabase.auth.signInWithPassword({
      email: email.trim(),
      password,
    });

    if (loginError) {
      setError(friendlyAuthError(loginError.message));
      setLoading(false);
      return;
    }

    router.replace('/dashboard');
    router.refresh();
  };

  return (
    <div className={styles.container}>
      <div className={styles.brandPanel}>
        <div className={styles.glowCircle1}></div>
        <div className={styles.glowCircle2}></div>
        <div className={styles.brandContent}>
          <Image
            src={brand.logoPath}
            alt={`Logo ${brand.appName}`}
            width={116}
            height={116}
            loading="eager"
            className={styles.brandLogo}
          />
          <h1 className={styles.brandTitle}>{brand.appName}</h1>
          <p className={styles.brandTagline}>{brand.tagline}</p>
          <p className={styles.brandCompany}>Advanta Seeds Indonesia</p>
        </div>
      </div>

      <div className={styles.formPanel}>
        <div className={styles.formCard}>
          <div className={styles.mobileBrand}>
            <Image
              src={brand.logoPath}
              alt=""
              aria-hidden="true"
              width={48}
              height={48}
              loading="eager"
              className={styles.mobileLogo}
            />
            <span>{brand.appName}</span>
          </div>
          <h2 className={styles.formTitle}>Selamat datang</h2>
          <p className={styles.formSubtitle}>
            Masuk menggunakan akun {brand.appName} Anda.
          </p>

          {error && (
            <div className={styles.errorBanner} role="alert">
              {error}
            </div>
          )}

          <form onSubmit={handleLogin} className={styles.form}>
            <div className={styles.inputGroup}>
              <input
                type="email"
                id="email"
                value={email}
                onChange={(event) => setEmail(event.target.value)}
                placeholder=" "
                autoComplete="email"
                required
                className={styles.input}
              />
              <label htmlFor="email" className={styles.label}>
                Email
              </label>
            </div>

            <div className={styles.inputGroup}>
              <input
                type={showPassword ? 'text' : 'password'}
                id="password"
                value={password}
                onChange={(event) => setPassword(event.target.value)}
                placeholder=" "
                autoComplete="current-password"
                required
                className={`${styles.input} ${styles.passwordInput}`}
              />
              <label htmlFor="password" className={styles.label}>
                Password
              </label>
              <button
                type="button"
                className={styles.passwordToggle}
                onClick={() => setShowPassword((current) => !current)}
                aria-label={
                  showPassword ? 'Sembunyikan password' : 'Tampilkan password'
                }
                title={
                  showPassword ? 'Sembunyikan password' : 'Tampilkan password'
                }
              >
                {showPassword ? (
                  <svg viewBox="0 0 24 24" aria-hidden="true">
                    <path d="M3 3l18 18M10.6 10.7a2 2 0 0 0 2.7 2.7M9.9 4.2A10.9 10.9 0 0 1 12 4c5.5 0 9.5 5.2 9.5 5.2a15.6 15.6 0 0 1-3.1 3.8M6.6 6.6a16.6 16.6 0 0 0-4.1 5.6S6.5 17.4 12 17.4c1.2 0 2.3-.2 3.3-.6" />
                  </svg>
                ) : (
                  <svg viewBox="0 0 24 24" aria-hidden="true">
                    <path d="M2.5 12s4-5.2 9.5-5.2 9.5 5.2 9.5 5.2-4 5.2-9.5 5.2S2.5 12 2.5 12Z" />
                    <circle cx="12" cy="12" r="2.6" />
                  </svg>
                )}
              </button>
            </div>

            <button
              type="submit"
              className={`btn btn-primary ${styles.submitBtn}`}
              disabled={loading}
            >
              {loading ? 'Memproses...' : 'Masuk'}
            </button>
          </form>
        </div>
      </div>
    </div>
  );
}

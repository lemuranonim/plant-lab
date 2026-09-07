import { getAppVariant } from '@/lib/appVariant';
import LoginForm from './LoginForm';

export default function LoginPage() {
  const variant = getAppVariant();

  return (
    <LoginForm
      brand={{
        appName: variant.appName,
        tagline: variant.tagline,
        logoPath: variant.logoPath,
      }}
    />
  );
}

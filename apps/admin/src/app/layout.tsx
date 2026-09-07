import type { Metadata } from 'next'
import { getAppVariant } from '@/lib/appVariant'
import './globals.css'

export function generateMetadata(): Metadata {
  const variant = getAppVariant()

  return {
    title: `${variant.appName} | Advanta Quality Platform`,
    description: `${variant.tagline} for Advanta Seeds Indonesia`,
    icons: {
      icon: variant.logoPath,
      apple: variant.logoPath,
    },
  }
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  const variant = getAppVariant()

  return (
    <html lang="id">
      <body data-app-variant={variant.code.toLowerCase()}>{children}</body>
    </html>
  )
}

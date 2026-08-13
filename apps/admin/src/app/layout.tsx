import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'Plant+Lab Admin | Advanta Quality Platform',
  description: 'Premium Plant+Lab Quality Management Admin Portal',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  )
}
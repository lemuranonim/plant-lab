import { NextResponse, type NextRequest } from 'next/server'
import { updateSession } from '@/lib/supabase/middleware'
import { hostedPilot, isolatedPlantLab } from '@/lib/supabase/config'

export async function proxy(request: NextRequest) {
  // This single read-only endpoint authenticates cookies or the APK bearer itself.
  if (hostedPilot && (request.nextUrl.pathname === '/api/lab-logbook/export' || /^\/api\/(?:lab-ret-request|lab-request-form)\/LT-[A-Z0-9]{1,60}\/export$/.test(request.nextUrl.pathname) || /^\/api\/(?:lab-routine|lab-moisture|pi-quality|lab-ret)\/[0-9a-f-]{36}\/export$/i.test(request.nextUrl.pathname))) {
    return NextResponse.next()
  }
  // Preserve the routing behavior of the current non-pilot deployment.
  return isolatedPlantLab ? updateSession(request) : NextResponse.next()
}

export const config = {
  matcher: [
    '/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)',
  ],
}

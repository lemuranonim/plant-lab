import { createServerClient } from '@supabase/ssr'
import { NextResponse, type NextRequest } from 'next/server'
import { hostedPilot, isolatedPlantLab, supabaseClientConfig } from './config'

export async function updateSession(request: NextRequest) {
  let supabaseResponse = NextResponse.next({
    request,
  })

  const { url: supabaseUrl, key } = supabaseClientConfig()
  const supabase = createServerClient(
    supabaseUrl,
    key,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll()
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value))
          supabaseResponse = NextResponse.next({
            request,
          })
          cookiesToSet.forEach(({ name, value, options }) =>
            supabaseResponse.cookies.set(name, value, options)
          )
        },
      },
    }
  )

  const {
    data: { user },
  } = await supabase.auth.getUser()

  if (isolatedPlantLab) {
    const { pathname } = request.nextUrl
    const allowed = ['/login', '/access-denied', '/lab-requests']
    allowed.push('/lot-pair-reviews')
    if (hostedPilot) allowed.push('/plant-operations', '/pi-quality', '/lab-routine', '/lab-moisture', '/lab-logbook', '/lab-monitoring', '/sample-requests')
    const destination = !user && pathname !== '/login'
      ? '/login'
      : user && !allowed.includes(pathname)
        ? '/lab-requests'
        : null
    if (destination) {
      const url = request.nextUrl.clone()
      url.pathname = destination
      url.search = ''
      const response = NextResponse.redirect(url)
      for (const cookie of supabaseResponse.cookies.getAll()) {
        response.cookies.set(cookie)
      }
      return response
    }
    return supabaseResponse
  }

  if (!user && !request.nextUrl.pathname.startsWith('/login') && !request.nextUrl.pathname.startsWith('/auth')) {
    const url = request.nextUrl.clone()
    url.pathname = '/login'
    return NextResponse.redirect(url)
  }

  if (user && request.nextUrl.pathname === '/') {
    const url = request.nextUrl.clone()
    url.pathname = '/dashboard'
    return NextResponse.redirect(url)
  }

  return supabaseResponse
}

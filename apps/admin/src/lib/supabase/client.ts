import { createBrowserClient } from '@supabase/ssr'
import { supabaseClientConfig } from './config'

export function createClient() {
  const { url, key } = supabaseClientConfig()
  return createBrowserClient(url, key)
}

import { createClient, type SupabaseClient } from '@supabase/supabase-js'

let browserClient: SupabaseClient | null = null
let pendingClient: Promise<SupabaseClient> | null = null

async function resolveConfig() {
  const publicUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || ''
  const publicKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY || ''
  if (publicUrl && publicKey) return { url: publicUrl, key: publicKey }

  const response = await fetch('/api/supabase-config', { cache: 'no-store' })
  const payload = await response.json().catch(() => ({}))
  if (!response.ok || !payload?.url || !payload?.key) {
    throw new Error('Konfigurasi Supabase tidak ditemukan pada deployment.')
  }
  return { url: String(payload.url), key: String(payload.key) }
}

export async function getSupabase(): Promise<SupabaseClient> {
  if (browserClient) return browserClient
  if (typeof window === 'undefined') throw new Error('Supabase browser client hanya tersedia di browser.')
  if (!pendingClient) {
    pendingClient = resolveConfig().then(({ url, key }) => {
      browserClient = createClient(url, key, {
        auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true }
      })
      return browserClient
    }).catch((error) => {
      pendingClient = null
      throw error
    })
  }
  return pendingClient
}

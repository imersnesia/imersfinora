import { NextResponse } from 'next/server'

export const dynamic = 'force-dynamic'
export const runtime = 'nodejs'

export async function GET() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL || process.env.SUPABASE_URL || ''
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY || process.env.SUPABASE_ANON_KEY || process.env.SUPABASE_PUBLISHABLE_KEY || ''
  if (!url || !key) {
    return NextResponse.json({ ok: false, error: 'SUPABASE_CONFIG_MISSING' }, { status: 503, headers: { 'Cache-Control': 'no-store' } })
  }
  return NextResponse.json({ ok: true, url, key }, { headers: { 'Cache-Control': 'no-store' } })
}

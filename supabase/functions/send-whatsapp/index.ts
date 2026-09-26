import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  try {
    const body = await req.json()
    const { family_id, to, message, file, provider } = body
    if (!family_id || !to || !message) throw new Error('family_id, to and message are required')
    const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)
    const { data: settings, error } = await supabase.from('wa_gateway_settings').select('*').eq('family_id', family_id).single()
    if (error || !settings?.enabled) throw new Error('WhatsApp gateway is not enabled')
    let url = settings.endpoint || (settings.provider === 'starsender' ? 'https://api.starsender.online/api/send' : 'https://api.fonnte.com/send')
    let response: Response
    if (settings.provider === 'fonnte') {
      response = await fetch(url, { method: 'POST', headers: { Authorization: settings.api_key_encrypted, 'Content-Type': 'application/json' }, body: JSON.stringify({ target: to, message, url: file || undefined }) })
    } else {
      response = await fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: settings.api_key_encrypted }, body: JSON.stringify({ messageType: file ? 'image' : 'text', to, body: file || message, file: file || undefined }) })
    }
    const result = await response.text()
    if (!response.ok) throw new Error(result)
    return new Response(JSON.stringify({ ok: true, provider: settings.provider, result }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  }
})

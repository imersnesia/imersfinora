import { corsHeaders } from '../_shared/cors.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  try {
    const { family_id, chat_id, message, photo_url } = await req.json()
    if (!family_id || !chat_id || !message) throw new Error('family_id, chat_id and message are required')
    const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)
    const { data: settings, error } = await supabase.from('telegram_settings').select('*').eq('family_id', family_id).single()
    if (error || !settings?.enabled || !settings.bot_token_encrypted) throw new Error('Telegram bot is not enabled')
    const method = photo_url ? 'sendPhoto' : 'sendMessage'
    const payload = photo_url ? { chat_id, photo: photo_url, caption: message } : { chat_id, text: message }
    const response = await fetch(`https://api.telegram.org/bot${settings.bot_token_encrypted}/${method}`, { method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify(payload) })
    const result = await response.json()
    if (!response.ok || !result.ok) throw new Error(JSON.stringify(result))
    return new Response(JSON.stringify({ ok:true, result }), { headers:{...corsHeaders,'Content-Type':'application/json'} })
  } catch(e) {
    return new Response(JSON.stringify({ ok:false,error:String(e) }), { status:400, headers:{...corsHeaders,'Content-Type':'application/json'} })
  }
})

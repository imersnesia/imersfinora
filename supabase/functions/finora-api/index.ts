import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: { ...corsHeaders, 'Content-Type': 'application/json' },
})

const cleanPhone = (value: unknown) => {
  let phone = String(value ?? '').replace(/[^0-9]/g, '')
  if (phone.startsWith('0')) phone = `62${phone.slice(1)}`
  return phone
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return json({ ok: false, error: 'METHOD_NOT_ALLOWED' }, 405)

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) return json({ ok: false, error: 'UNAUTHORIZED' }, 401)

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const authClient = createClient(supabaseUrl, anonKey, { global: { headers: { Authorization: authHeader } } })
    const admin = createClient(supabaseUrl, serviceRoleKey)

    const { data: { user }, error: userError } = await authClient.auth.getUser()
    if (userError || !user) return json({ ok: false, error: 'UNAUTHORIZED' }, 401)

    const body = await req.json()
    const action = String(body.action ?? '')
    const familyId = String(body.family_id ?? '')
    if (!action || !familyId) return json({ ok: false, error: 'ACTION_AND_FAMILY_ID_REQUIRED' }, 400)

    const { data: membership } = await admin
      .from('family_members')
      .select('role,status')
      .eq('family_id', familyId)
      .eq('user_id', user.id)
      .maybeSingle()

    if (!membership || membership.status !== 'active') return json({ ok: false, error: 'FORBIDDEN' }, 403)

    const requireAdmin = () => {
      if (!['owner', 'admin'].includes(String(membership.role))) throw new Error('ADMIN_REQUIRED')
    }

    if (action === 'save_whatsapp_settings') {
      requireAdmin()
      const provider = String(body.provider ?? 'fonnte').toLowerCase()
      if (!['fonnte', 'starsender'].includes(provider)) throw new Error('PROVIDER_NOT_SUPPORTED')
      const apiKey = String(body.api_key ?? '').trim()
      if (!apiKey) throw new Error('API_KEY_REQUIRED')
      const endpoint = provider === 'starsender'
        ? 'https://api.starsender.online/api/send'
        : 'https://api.fonnte.com/send'
      const { error } = await admin.from('wa_gateway_settings').upsert({
        family_id: familyId,
        provider,
        enabled: body.enabled !== false,
        endpoint,
        api_key_encrypted: apiKey,
        sender_label: body.sender_label ? String(body.sender_label) : null,
      }, { onConflict: 'family_id' })
      if (error) throw error
      return json({ ok: true, action, provider })
    }

    if (action === 'save_telegram_settings') {
      requireAdmin()
      const token = String(body.bot_token ?? '').trim()
      if (!token) throw new Error('BOT_TOKEN_REQUIRED')
      const { error } = await admin.from('telegram_settings').upsert({
        family_id: familyId,
        enabled: body.enabled !== false,
        bot_username: body.bot_username ? String(body.bot_username) : null,
        bot_token_encrypted: token,
      }, { onConflict: 'family_id' })
      if (error) throw error
      return json({ ok: true, action })
    }

    if (action === 'send_whatsapp' || action === 'test_whatsapp') {
      const to = cleanPhone(body.to)
      const message = String(body.message ?? (action === 'test_whatsapp' ? 'Test WhatsApp iMersFinora berhasil.' : '')).trim()
      if (!to || !message) throw new Error('TARGET_AND_MESSAGE_REQUIRED')

      const { data: settings, error } = await admin.from('wa_gateway_settings').select('*').eq('family_id', familyId).single()
      if (error || !settings?.enabled || !settings?.api_key_encrypted) throw new Error('WHATSAPP_NOT_CONFIGURED')

      const provider = String(settings.provider).toLowerCase()
      let response: Response
      if (provider === 'starsender') {
        response = await fetch('https://api.starsender.online/api/send', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', Authorization: settings.api_key_encrypted },
          body: JSON.stringify({ messageType: 'text', to, body: message }),
        })
      } else if (provider === 'fonnte') {
        const form = new FormData()
        form.append('target', to)
        form.append('message', message)
        response = await fetch('https://api.fonnte.com/send', {
          method: 'POST',
          headers: { Authorization: settings.api_key_encrypted },
          body: form,
        })
      } else {
        throw new Error('PROVIDER_NOT_SUPPORTED')
      }

      const providerBody = await response.text()
      if (!response.ok) throw new Error(`PROVIDER_ERROR_${response.status}: ${providerBody}`)
      return json({ ok: true, action, provider, status_code: response.status, provider_response: providerBody })
    }

    if (action === 'send_telegram' || action === 'test_telegram') {
      const chatId = String(body.chat_id ?? '').trim()
      const message = String(body.message ?? (action === 'test_telegram' ? 'Test Telegram iMersFinora berhasil.' : '')).trim()
      const photoUrl = String(body.photo_url ?? '').trim()
      if (!chatId || !message) throw new Error('CHAT_ID_AND_MESSAGE_REQUIRED')

      const { data: settings, error } = await admin.from('telegram_settings').select('*').eq('family_id', familyId).single()
      if (error || !settings?.enabled || !settings?.bot_token_encrypted) throw new Error('TELEGRAM_NOT_CONFIGURED')

      const method = photoUrl ? 'sendPhoto' : 'sendMessage'
      const payload = photoUrl
        ? { chat_id: chatId, photo: photoUrl, caption: message }
        : { chat_id: chatId, text: message }
      const response = await fetch(`https://api.telegram.org/bot${settings.bot_token_encrypted}/${method}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      })
      const result = await response.json()
      if (!response.ok || !result?.ok) throw new Error(`TELEGRAM_ERROR: ${JSON.stringify(result)}`)
      return json({ ok: true, action, provider: 'telegram', result })
    }

    return json({ ok: false, error: 'UNKNOWN_ACTION' }, 400)
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error)
    const status = message === 'ADMIN_REQUIRED' ? 403 : 400
    return json({ ok: false, error: message }, status)
  }
})

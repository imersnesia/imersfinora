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
    const url = new URL(req.url)
    const hook = url.searchParams.get('hook')
    if (hook === 'whatsapp' || hook === 'telegram') {
      const familyId = url.searchParams.get('family') || ''
      const secret = url.searchParams.get('secret') || ''
      if (!familyId || !secret) return json({ok:false,error:'INVALID_WEBHOOK'},401)
      const supabaseUrl = Deno.env.get('SUPABASE_URL')!
      const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
      const admin = createClient(supabaseUrl, serviceRoleKey)
      const table = hook === 'telegram' ? 'telegram_settings' : 'wa_gateway_settings'
      const {data:cfg} = await admin.from(table).select('*').eq('family_id',familyId).maybeSingle()
      if (!cfg?.bot_enabled || cfg.webhook_secret !== secret) return json({ok:false,error:'BOT_DISABLED_OR_SECRET_INVALID'},403)
      const payload:any = await req.json()
      let sender='', textMsg='', mediaUrl=''
      if (hook === 'telegram') {
        const m=payload?.message||payload?.edited_message||{}
        sender=String(m?.chat?.id||''); textMsg=String(m?.text||m?.caption||'').trim()
        const photos=m?.photo||[]
        if(photos.length&&cfg.bot_token_encrypted){const fileId=photos[photos.length-1]?.file_id;const fr=await fetch(`https://api.telegram.org/bot${cfg.bot_token_encrypted}/getFile?file_id=${fileId}`);const fj=await fr.json();if(fj?.result?.file_path)mediaUrl=`https://api.telegram.org/file/bot${cfg.bot_token_encrypted}/${fj.result.file_path}`}
      } else {
        sender=cleanPhone(payload?.sender||payload?.from||payload?.phone||payload?.data?.sender||payload?.data?.from)
        textMsg=String(payload?.message||payload?.text||payload?.caption||payload?.data?.message||'').trim()
        mediaUrl=String(payload?.url||payload?.file||payload?.media||payload?.data?.url||'').trim()
      }
      if(!sender) return json({ok:true,ignored:'NO_SENDER'})
      let q=admin.from('notification_recipients').select('user_id,phone,telegram_chat_id').eq('family_id',familyId)
      q=hook==='telegram'?q.eq('telegram_chat_id',sender):q.eq('phone',sender)
      const {data:recipient}=await q.maybeSingle()
      if(!recipient?.user_id) return json({ok:true,ignored:'SENDER_NOT_LINKED'})
      let storedMedia:string|null=null
      if(mediaUrl){try{const mr=await fetch(mediaUrl);if(mr.ok){const blob=await mr.blob();const ext=(blob.type.split('/')[1]||'jpg').replace('jpeg','jpg');const path=`${familyId}/${recipient.user_id}/bot-${Date.now()}.${ext}`;const up=await admin.storage.from('finora-receipts').upload(path,blob,{contentType:blob.type||'image/jpeg'});if(!up.error)storedMedia=path}}catch(_){storedMedia=mediaUrl}}
      const {data:inbox}=await admin.from('bot_inbox').insert({family_id:familyId,user_id:recipient.user_id,channel:hook,external_sender:sender,message_text:textMsg||null,media_url:storedMedia,raw_payload:payload,status:'received'}).select('id').single()
      const lower=textMsg.toLowerCase(); const nums=(lower.match(/[0-9][0-9.,]*/g)||[]); let amount=0
      if(nums.length){let raw=nums[0].replace(/\./g,'').replace(/,/g,'');amount=Number(raw);if(/\b(jt|juta)\b/.test(lower))amount*=1000000;else if(/\b(rb|ribu|k)\b/.test(lower))amount*=1000}
      const type=/\b(gaji|masuk|income|pemasukan|terima)\b/.test(lower)?'income':'expense'
      const {data:accounts}=await admin.from('accounts').select('id,name,current_balance').eq('family_id',familyId).eq('is_active',true).order('created_at')
      const account=(accounts||[]).find((a:any)=>lower.includes(String(a.name).toLowerCase()))||(accounts||[])[0]
      const reply=async(message:string)=>{if(hook==='telegram'&&cfg.bot_token_encrypted)await fetch(`https://api.telegram.org/bot${cfg.bot_token_encrypted}/sendMessage`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({chat_id:sender,text:message})});if(hook==='whatsapp'&&cfg.api_key_encrypted){if(cfg.provider==='fonnte'){const f=new FormData();f.append('target',sender);f.append('message',message);await fetch('https://api.fonnte.com/send',{method:'POST',headers:{Authorization:cfg.api_key_encrypted},body:f})}else await fetch('https://api.starsender.online/api/send',{method:'POST',headers:{'Content-Type':'application/json',Authorization:cfg.api_key_encrypted},body:JSON.stringify({messageType:'text',to:sender,body:message})})}}
      if(/^saldo\b/.test(lower)){const total=(accounts||[]).reduce((n:number,a:any)=>n+Number(a.current_balance||0),0);await reply(`💰 Total saldo: Rp${Math.round(total).toLocaleString('id-ID')}`);if(inbox)await admin.from('bot_inbox').update({status:'processed'}).eq('id',inbox.id);return json({ok:true,action:'balance'})}
      if(!amount||!account){if(inbox)await admin.from('bot_inbox').update({status:'pending_amount'}).eq('id',inbox.id);await reply(storedMedia?'📷 Foto diterima. Tambahkan nominal/keterangan pada caption, contoh: "75rb makan cash".':'Ketik contoh: "75rb makan cash", "gaji 8jt BCA", atau "saldo".');return json({ok:true,pending:true})}
      const {data:txId,error:txErr}=await admin.rpc('bot_post_transaction',{p_family_id:familyId,p_user_id:recipient.user_id,p_account_id:account.id,p_type:type,p_amount:amount,p_description:textMsg||'Transaksi via bot',p_receipt_url:storedMedia,p_metadata:{source:hook,bot_inbox_id:inbox?.id}})
      if(txErr)throw txErr
      if(inbox)await admin.from('bot_inbox').update({status:'processed',transaction_id:txId}).eq('id',inbox.id)
      await reply(`✅ ${type==='income'?'Pemasukan':'Pengeluaran'} Rp${Math.round(amount).toLocaleString('id-ID')} tercatat ke ${account.name}.`)
      return json({ok:true,transaction_id:txId})
    }

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
      .select('role')
      .eq('family_id', familyId)
      .eq('user_id', user.id)
      .maybeSingle()

    if (!membership) return json({ ok: false, error: 'FORBIDDEN' }, 403)

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

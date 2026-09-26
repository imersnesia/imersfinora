import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

Deno.serve(async (req) => {
  const secret = req.headers.get('x-cron-secret')
  if (!secret || secret !== Deno.env.get('REMINDER_CRON_SECRET')) return new Response('Unauthorized', { status:401 })
  const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)
  // Reminder engine foundation: notifications are queued here; provider delivery is intentionally isolated in send-whatsapp/send-telegram.
  // Future reminder rules can be added without exposing service-role credentials to the client.
  const { data, error } = await supabase.from('notifications').select('id').eq('status','queued').limit(50)
  if (error) return new Response(JSON.stringify({ok:false,error:error.message}),{status:500})
  return new Response(JSON.stringify({ok:true,queued:data?.length ?? 0}))
})

# iMersFinora v1.4.0

- Fixed Vercel/Next.js prerender failure: `supabaseKey is required`.
- Supabase browser client is now lazy-created only at browser runtime, never at module import or render/prerender time.
- Existing v1.3 database requires no SQL migration for this release.
- Fresh clients still use the single full fresh installer SQL.
- PWA files, single `finora-api` Edge Function, Fonnte, StarSender and Telegram integration remain included.

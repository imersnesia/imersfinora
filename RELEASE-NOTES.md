# v1.3
- Replaced placeholder login with real Supabase email/password authentication.
- Added automatic first-login workspace bootstrap for existing/manual Auth users.
- Root now redirects to login or app; removed developer placeholder homepage.
- Added session persistence and logout.
- Added functional starter dashboard reading real Supabase family/accounts.
- Added installable PWA: manifest, icons, service worker, registration, standalone metadata, offline fallback.
- Kept a single `finora-api` Edge Function and excluded Supabase Deno source from Vercel build.
- Added v1.2 -> v1.3 upgrade SQL; fresh SQL includes bootstrap function.

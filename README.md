# iMersFinora FINAL CLEAN INSTALLER v1.3
Fresh installer Next.js + Supabase + installable PWA.

## Existing v1.2 database
Run only `supabase/upgrade/UPGRADE_v1.2_TO_v1.3.sql` once. Do NOT rerun the fresh installer.

## Fresh client
Run `supabase/install/00_FULL_FRESH_INSTALL_IMERSFINORA.sql` once.

## Vercel ENV
Set `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY`.

## Authentication
Create user in Supabase Authentication. On first successful login the app calls `bootstrap_my_workspace()`, creates the missing profile/workspace, assigns that user as `owner` of their workspace, creates Main Wallet and integration settings.

## PWA
Manifest, 192/512 icons, service worker registration, standalone display and offline fallback are included.

## Edge Function
Only `supabase/functions/finora-api/index.ts` is used: Fonnte, StarSender, Telegram.

## v1.4 deployment fix
Supabase client initialization is lazy and browser-runtime only. This prevents Vercel static prerender from constructing a Supabase client during `next build`.
Existing v1.3 installations do not need a database migration for v1.4.

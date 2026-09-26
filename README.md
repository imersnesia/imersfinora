# iMersFinora FINAL CLEAN INSTALLER v1.6
Premium personal/family finance PWA, Next.js + Supabase.

## Existing v1.5 install
Replace source with v1.6 and redeploy. No SQL upgrade required.

## Fresh client
Run only `supabase/install/00_FULL_FRESH_INSTALL_IMERSFINORA.sql`, configure Vercel public Supabase environment variables, deploy `supabase/functions/finora-api/index.ts`, then deploy the Next.js project.

## PWA
Manifest, 192/512 icons, service worker, standalone mode and offline page are included.

## Themes
10 presets + custom primary color. Theme preference is stored in the user's Supabase profile and cached locally for fast PWA startup.

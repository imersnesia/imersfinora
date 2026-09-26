# iMersFinora v1.14
Single-family personal finance PWA built with Next.js + Supabase.

## Product model
One installation = one family. The first authenticated user becomes owner automatically. Family context is internal and requires no workspace setup. A Cash / Tunai financial account is created automatically when needed.

## Upgrade from v1.13
Run `supabase/upgrade/UPGRADE_v1.13_TO_v1.14.sql` in Supabase SQL Editor, then deploy the v1.14 frontend. WhatsApp/Telegram bots are optional; web/PWA transaction entry works without them.

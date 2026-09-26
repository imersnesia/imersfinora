# iMersFinora — FINAL CLEAN INSTALLER v1.0

Fresh installer for a new client / new Supabase project.

## Included
- Next.js PWA-ready application shell
- Supabase database schema, RLS and finance RPC foundation
- Profiles, families, accounts, categories, transactions and ledger
- Theme preference fields for 10-theme engine + custom colors
- WhatsApp settings (Fonnte / StarSender)
- Telegram Bot settings
- Separated Edge Functions: send-whatsapp, send-telegram, process-reminders
- No client gateway token hardcoded

## Fresh Installation
1. Create a new Supabase project.
2. Run `supabase/install/00_FULL_FRESH_INSTALL_IMERSFINORA.sql`.
3. Run `supabase/install/01_VERIFY_INSTALLATION.sql`.
4. Deploy each Edge Function folder separately.
5. Copy `.env.example` to `.env.local` and fill Supabase URL/key.
6. Run `npm install`, `npm run build`, then deploy to Vercel.
7. Configure WhatsApp/Telegram from the application web Settings.

Do not run old experimental iMersFinora SQL on a fresh installation.

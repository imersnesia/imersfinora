# iMersFinora FINAL CLEAN INSTALLER v1.5

Fresh client: run `supabase/install/00_FULL_FRESH_INSTALL_IMERSFINORA.sql` once.
Existing v1.3/v1.4 database: no SQL migration is required for v1.5.

Supabase configuration accepts either the current publishable-key naming or legacy anon-key naming. See `.env.example`.

Edge Functions remain a single function: `supabase/functions/finora-api/index.ts`.

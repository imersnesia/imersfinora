# iMersFinora v1.2.0

- FIX: Next.js/Vercel no longer type-checks Supabase Edge Functions (Deno runtime).
- `supabase/functions/**/*` excluded from frontend TypeScript compilation.
- Edge Function remains a single `finora-api/index.ts`.
- Supported gateways: Fonnte, StarSender, Telegram.
- WAPlus and XSender are not enabled in this release.
- Fresh-install SQL remains compatible with v1.0/v1.1; no SQL rerun is required for existing v1.0 database.

# iMersFinora v1.0 — Fresh Installation Guide

## Supabase
Run `00_FULL_FRESH_INSTALL_IMERSFINORA.sql` once on a NEW project, then run `01_VERIFY_INSTALLATION.sql`.

## Edge Functions
Create/deploy each function independently using the included folder and its own `index.ts`:
- `send-whatsapp`
- `send-telegram`
- `process-reminders`

`_shared` contains common helpers.

## Web/PWA
Copy `.env.example` to `.env.local`, set the public Supabase URL and anon/publishable key, install dependencies and build. The manifest is already included and the UI is mobile-first/PWA-ready.

## Integration Credentials
WhatsApp API token/endpoint and Telegram bot token/chat configuration are intended to be entered from the web Settings UI. Do not hardcode client credentials in source code. Edge Functions consume server-side configuration.

## Important
This package is the MASTER CLEAN fresh installer. Existing installations should use migrations/hotfixes rather than re-running the full installer.

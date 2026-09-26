# iMersFinora v1.11 — Functional Core

Premium Personal & Family Finance PWA.

## Existing v1.6 installation
Run once: `supabase/upgrade/UPGRADE_v1.6_TO_v1.11.sql`, then replace the web source and redeploy.

## New client / fresh installation
Run only: `supabase/install/00_FULL_FRESH_INSTALL_IMERSFINORA.sql`.
Do not run historical upgrade SQL files on a fresh install.

## Core active in v1.11
- Supabase Auth + automatic workspace bootstrap
- Family/Workspace + owner/admin/partner/member/child/viewer roles
- Invite/add family member by email
- Accounts/wallets with opening balance
- Income, expense, and account-to-account transfer via ledger RPC
- Default finance categories
- Transaction history
- Premium PWA shell + installable manifest/service worker
- 10 themes/custom appearance foundation
- One Edge Function: `finora-api` (Fonnte, StarSender, Telegram)

# iMersFinora v1.13

- Fixed Accounts page that could remain forever on “Memuat akun…”.
- Account loading now always exits into data, empty state, or a visible retryable error state.
- Automatically creates `Cash / Tunai` when an existing workspace has no active financial account.
- Added clear explanation that Accounts are financial sources (cash, bank, e-wallet), not login users.
- Account creation remains available to workspace owner/admin.
- Bot integrations remain optional; web/PWA transaction entry remains fully supported.
- Upgrade SQL: `supabase/upgrade/UPGRADE_v1.12_TO_v1.13.sql`.

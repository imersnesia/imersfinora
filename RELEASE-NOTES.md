# iMersFinora v1.20

## Critical SQL migration fix
- Fix PostgreSQL error `42P13: cannot change return type of existing function` on `invite_family_member(uuid,text,app_role)`.
- Migration now drops the exact old function signature before recreating it with JSONB return type.
- v1.19 -> v1.20 migration is idempotent/recovery-safe for a failed or partially executed v1.19 migration.
- Fresh installer master SQL is corrected with the same return-type transition fix.

## Install rules
### Client baru
Run ONE file only: `supabase/install/00_FULL_FRESH_INSTALL_IMERSFINORA.sql`.

### Existing v1.19 / failed v1.19 migration
Run: `supabase/upgrade/UPGRADE_v1.19_TO_v1.20.sql`.

### Edge Function
No redeploy required for this SQL-only correction.

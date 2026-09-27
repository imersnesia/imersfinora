# iMersFinora v1.20

## CLIENT BARU / FRESH INSTALL
Jalankan SATU SQL saja:
`supabase/install/00_FULL_FRESH_INSTALL_IMERSFINORA.sql`

## UPDATE / RECOVERY v1.19 -> v1.20
Jalankan:
`supabase/upgrade/UPGRADE_v1.19_TO_v1.20.sql`

Patch v1.20 memperbaiki error PostgreSQL `42P13 cannot change return type of existing function` pada fungsi Family Invite. Migration dibuat aman untuk kondisi v1.19 yang sebelumnya gagal/berhenti sebagian.

## EDGE FUNCTION
Tidak perlu redeploy untuk patch SQL v1.20 ini.

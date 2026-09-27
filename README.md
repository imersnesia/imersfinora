# iMersFinora v1.22

## CLIENT BARU / FRESH INSTALL
Jalankan SATU SQL saja:
`supabase/install/00_FULL_FRESH_INSTALL_IMERSFINORA.sql`

## UPDATE / RECOVERY v1.19 -> v1.22
Jalankan:
`supabase/upgrade/UPGRADE_v1.19_TO_v1.22.sql`

Patch v1.22 memperbaiki error PostgreSQL `42P13 cannot change return type of existing function` pada fungsi Family Invite. Migration dibuat aman untuk kondisi v1.19 yang sebelumnya gagal/berhenti sebagian.

## EDGE FUNCTION
Tidak perlu redeploy untuk patch SQL v1.22 ini.


## v1.22
Dynamic Categories (income/expense/both) with CRUD and active status. Flexible Reports support presets/custom date range, account/category/type/member filters, summary and browser-native A4 PDF export.

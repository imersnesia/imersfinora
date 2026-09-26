# iMersFinora v1.16

- Fixed `permission denied for table families` on authenticated PostgREST requests.
- Added the missing authenticated table privileges while keeping RLS active.
- Family context remains automatic/internal; user never creates a workspace manually.
- Accounts continues to mean financial sources: Cash, bank accounts, and e-wallets.
- Fresh installer includes the same permission fix.

## v1.16
- Fix akar masalah Accounts: frontend tidak lagi SELECT langsung ke families/family_members/accounts untuk bootstrap halaman Akun.
- Tambah RPC SECURITY DEFINER get_my_context, get_my_accounts, add_my_account.
- Menghindari ketergantungan permission PostgREST tabel pada flow awal.

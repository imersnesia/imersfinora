# iMersFinora v1.15

- Fixed `permission denied for table families` on authenticated PostgREST requests.
- Added the missing authenticated table privileges while keeping RLS active.
- Family context remains automatic/internal; user never creates a workspace manually.
- Accounts continues to mean financial sources: Cash, bank accounts, and e-wallets.
- Fresh installer includes the same permission fix.

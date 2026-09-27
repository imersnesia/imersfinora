# iMersFinora v1.22

- Dynamic category CRUD in Settings.
- Separate income/expense/both category types; transaction form already filters by transaction type.
- Flexible financial reports: today/week/month/year/custom dates + account/category/type/member filters.
- A4 print/PDF report with income, expense, net cashflow, category summary and transaction detail.
- Transfers excluded from income/expense/net cashflow totals.
- Existing install: run `supabase/upgrade/UPGRADE_v1.20_TO_v1.22.sql`.
- Fresh install: run only `supabase/install/00_FULL_FRESH_INSTALL_IMERSFINORA.sql`.

## v1.22
- Fixed PWA branding upload that could show a success message while Media Library remained empty.
- Upload is now explicit: choose image -> preview -> Upload to Media Library -> Apply as PWA Icon.
- Branding DB read/write now uses protected SECURITY DEFINER RPCs and surfaces real Storage/DB errors.

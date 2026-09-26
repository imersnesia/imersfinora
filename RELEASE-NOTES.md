# iMersFinora v1.5.0

- Fixed runtime Supabase configuration handling.
- Supports Supabase publishable-key and legacy anon-key environment variable names.
- Added runtime `/api/supabase-config` fallback so configuration is not tied to prerender/import time.
- Fixed `/` client-side exception when configuration cannot be resolved.
- Login now initializes Supabase at browser runtime and reports real auth/bootstrap errors.
- Existing database from v1.3/v1.4 requires no SQL migration for this release.
- PWA assets, manifest and service worker retained.
- Single `finora-api` Edge Function retained.

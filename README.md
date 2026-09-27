# iMersFinora v1.17

## CLIENT BARU / FRESH INSTALL
1. Jalankan `supabase/install/00_FULL_FRESH_INSTALL_IMERSFINORA.sql`
2. Jalankan `supabase/install/01_VERIFY_INSTALLATION.sql`
3. Deploy Edge Function `finora-api`
4. Isi ENV Supabase di Vercel lalu deploy frontend.

## CLIENT LAMA v1.16 -> v1.17
Jalankan `supabase/upgrade/UPGRADE_v1.16_TO_v1.17.sql`, lalu deploy frontend v1.17.
Edge Function: tidak perlu redeploy untuk fitur branding ini.

## Branding PWA
Settings -> Icon & Logo PWA. Rekomendasi 512x512 px, PNG/WebP, maks 2 MB. Media Library menyimpan gambar yang sudah pernah di-upload dan mencegah duplikasi file identik.

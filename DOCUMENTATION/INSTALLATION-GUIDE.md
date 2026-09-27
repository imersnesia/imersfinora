# iMersFinora v1.18 — Installation Guide

## Fresh install / client baru
1. Buat project Supabase baru.
2. Buka SQL Editor.
3. Jalankan **hanya** `supabase/install/00_FULL_FRESH_INSTALL_IMERSFINORA.sql`.
4. Pastikan query selesai tanpa error. Self-verification otomatis berjalan di akhir file.
5. Deploy Edge Function `finora-api`.
6. Isi environment Supabase di Vercel lalu deploy frontend.

> Jangan jalankan file `supabase/upgrade/*` pada fresh install.

## Existing install
Gunakan hanya file upgrade yang sesuai versi asal dan tujuan. Untuk v1.17 -> v1.18, **tidak perlu SQL update**.

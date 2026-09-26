# iMersFinora v1.12

- Bot WhatsApp/Telegram sekarang **opsional**. Tanpa bot, pencatatan transaksi via web/PWA tetap penuh.
- Incoming webhook bot untuk chat transaksi sederhana (`75rb makan cash`, `gaji 8jt BCA`, `saldo`).
- Foto/struk dari bot disimpan ke bucket private `finora-receipts`; caption bernominal dapat langsung dicatat.
- Form transaksi web/PWA mendukung upload/foto struk opsional.
- Halaman Akun tidak lagi blank: workspace tanpa akun akan membuat `Cash / Tunai` default.
- Integrasi menyimpan binding nomor WA / Telegram Chat ID per member.

## Upgrade dari v1.11
WAJIB jalankan `supabase/upgrade/UPGRADE_v1.11_TO_v1.12.sql`, lalu deploy ulang Edge Function `finora-api` dan frontend.

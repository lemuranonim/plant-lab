# Advanta Plant & Lab — snapshot rilis pilot

Rilis fitur 21 November 2026. APK Plant dan Lab: **1.0.29+30**.

- `apps/admin`: source web Plant dan Lab. Satu codebase, dua varian.
- `apps/plant_lab`: source APK Plant dan Lab. Entrypoint
  `lib/main_plant.dart` dan `lib/main_lab.dart`.
- `supabase/migrations`: migrasi khusus pilot terisolasi, mulai
  `20261107000100_plantlab_isolated_hosted.sql` sampai
  `20261118000300_lab_sample_requests.sql`. Migrasi ini melengkapi source
  rilis; jangan menjalankan ulang ke database aktif atau menjalankannya
  otomatis hanya karena ada push. Uji pangkalan data dan migrasi di
  lingkungan terpisah sebelum rilis berikutnya.

Snapshot mencakup input harian dan mutu PI di Plant, antrean dan dua arah
serah-terima sampel, uji rutin Lab, Germinasi/Vigor/RET/MC, review QA dan
Revalidation, unduhan per form, buku pengujian, serta pemantauan kerja.
Persetujuan analisis QA bukan pelepasan lot.

Setup aplikasi ada di [README web](apps/admin/README.md) dan
[README APK](apps/plant_lab/README.md). Untuk APK rilis ini gunakan
`--build-name=1.0.29 --build-number=30` dan penandatanganan resmi tim.

Pilot memakai `plantlab_api`. Fitur permintaan sampel ke Plant memerlukan
`NEXT_PUBLIC_PLANT_LAB_SAMPLE_REQUESTS=true` di web dan
`--dart-define=PLANT_LAB_SAMPLE_REQUESTS=true` di Flutter, selain flag
pilot. Flag tulis hanya untuk lingkungan yang sudah disetujui.

File konfigurasi lokal, signing, data operasional dan hasil ekspor,
Excel sumber, screenshot, serta berkas distribusi tidak disimpan di Git.

# Rekapan Warung — Warung Lupi

Aplikasi mobile **Warung Lupi** (versi Flutter) untuk pencatatan bon/kuitansi,
pelanggan, item, dan cetak struk thermal via printer Bluetooth.

Client Flutter dari aplikasi web Laravel + React (sumber: `C:\laragon\www\Rekapan_Warung`).
Lihat [`docs/AUDIT.md`](docs/AUDIT.md) untuk pemetaan fitur lengkap dari web ke Flutter.

## Teknologi

- **Flutter** 3.47.5 (channel stable)
- **State management:** Provider
- **Networking:** Dio (REST JSON ke backend Laravel)
- **Bahasa/UI:** Bahasa Indonesia, format mata uang `id-ID`

## Fitur (per audit)

- **Dashboard** — kartu statistik (bon hari ini, total, lunas, masih hutang) + 10 bon terbaru
- **Buat / Edit Bon** — simpan header terlebih dahulu, lalu tambah item; promo otomatis:
  nama item mengandung `gorengan` → tiap 3 pcs = Rp5.000, nama mengandung
  `donat`/`nagasari`/`lemper`/`jajanan` → tiap 2 pcs = Rp5.000;
  urutan item bisa diatur ulang (drag reorder)
- **Riwayat Bon** — pencarian, filter rentang tanggal, pagination
- **Detail Bon** — preview struk + cetak Bluetooth / export PDF / download PNG / copy struk / RawBT intent
- **Pelanggan** — daftar, tambah, edit; klik nama → riwayat bon per pelanggan
- **Item & Kategori** — daftar item, kategori dengan tambah/edit inline
- **Pengaturan** — pair/ganti printer Bluetooth, tes cetak, ukuran kertas (58mm / 80mm)

## Struktur proyek

```
lib/
├── core/
│   ├── api/          # ApiConfig + Dio client
│   ├── storage/      # SharedPreferences helpers
│   ├── theme/        # AppTheme
│   └── navigation.dart
├── models/           # Model + fromJson/toJson
├── providers/        # Provider state + repositories
├── screens/
│   ├── bon/          # buat / edit / detail / riwayat bon
│   ├── customers/    # pelanggan
│   ├── products/     # item & kategori
│   └── settings/     # pengaturan printer
├── services/         # printer_service (Bluetooth thermal)
├── utils/            # format harga, promo
└── widgets/          # thermal_receipt, widgets umum
```

## Backend / API

Server: `https://warunglupi.tplp004.com` (default produksi).
Lihat `lib/core/api/api_client.dart` (class `ApiConfig`).

## Pengembangan

```bash
flutter pub get
flutter analyze --no-fatal-infos
flutter test
flutter build apk --release
```

> Tes live (butuh koneksi server) **dilewati** secara default.
> Jalankan dengan `--dart-define=RUN_LIVE_TESTS=true` bila diperlukan.

## Build

APK rilis: `build/app/outputs/flutter-apk/app-release.apk`

## CI/CD

GitHub Actions (`.github/workflows/flutter-ci.yml`):
`pub get` → `analyze --no-fatal-infos` → `test` → `build apk --release`,
artifact `app-release-apk`. Dijalankan pada setiap push ke `main`.

import 'dart:io';

/// Konfigurasi bersama untuk tes integrasi LIVE (memanggil server produksi).
///
/// Tes ini MEMBUAT dan MENGHAPUS data bon sungguhan di database produksi,
/// jadi sengaja tidak berjalan pada `flutter test` biasa.
///
/// Jalankan secara eksplisit:
///   flutter test --dart-define=RUN_LIVE_TESTS=true test/live_api_test.dart
const bool runLiveTests = bool.fromEnvironment('RUN_LIVE_TESTS');

/// `flutter test` memasang HttpOverrides palsu lewat TestWidgetsFlutterBinding
/// sehingga SEMUA request HTTP dipaksa balas 400 tanpa menyentuh jaringan.
/// Tes live harus mematikannya agar benar-benar menghubungi server.
void enableRealNetwork() => HttpOverrides.global = null;

/// Pesan yang ditampilkan saat tes live dilewati.
const String skipReason =
    'Tes live dimatikan. Jalankan dengan --dart-define=RUN_LIVE_TESTS=true';
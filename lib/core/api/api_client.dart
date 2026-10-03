import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// ApiConfig — sumber base URL tunggal untuk semua request API.
///
/// Flutter adalah **client** backend Laravel Warung Lupi. Satu-satunya sumber
/// data adalah database produksi di belakang
/// `https://warunglupi.tplp004.com` (sama dengan aplikasi web).
///
/// Prioritas base URL:
/// 1. `--dart-define=API_BASE_URL=...` → untuk development lokal.
/// 2. Web (`kIsWeb`) → `''` (relative `/api`, same-origin seperti
///    `resources/js/api/client.js` yang memakai `baseURL: '/api'`).
/// 3. Default (Android/iOS/desktop) → [productionBaseUrl] (HTTPS).
///
/// ⚠️ JANGAN mengembalikan alamat emulator (`http://10.0.2.2:8000`) sebagai
/// default. Alamat itu hanya valid di dalam emulator Android; pada HP fisik
/// `10.0.2.2` tidak routable sehingga seluruh request menggantung sampai
/// timeout (gejala: "Memuat..." tanpa henti & "Koneksi ke server timeout").
///
/// Untuk menjalankan mode dev secara sadar, gunakan:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
///   flutter run --dart-define=API_BASE_URL=http://IP-LAN-ANDA:8000
class ApiConfig {
  ApiConfig._();

  static const _envBase = String.fromEnvironment('API_BASE_URL');

  /// Backend Laravel produksi Warung Lupi (database production yang sama
  /// dengan aplikasi web). Wajib HTTPS.
  static const String productionBaseUrl = 'https://warunglupi.tplp004.com';

  /// Origin efektif yang dipakai runtime. Diisi dari [Prefs] saat app start
  /// agar alamat server bisa diubah tanpa build ulang; kosong = pakai default.
  static String runtimeOverride = '';

  static bool get isWeb => kIsWeb;

  /// Origin server efektif (tanpa `/api`).
  static String get baseUrl {
    if (runtimeOverride.trim().isNotEmpty) {
      return _trimTrailingSlash(runtimeOverride.trim());
    }
    final env = _envBase.trim();
    if (env.isNotEmpty) return _trimTrailingSlash(env);
    if (isWeb) return ''; // relative → meniru web Laravel
    return productionBaseUrl;
  }

  /// Root endpoint API (`<origin>/api`).
  static String get apiBaseUrl => '$baseUrl/api';

  /// Nama host untuk pesan error yang mudah di-debug.
  ///
  /// Diambil dari base URL Dio yang **sedang aktif**, bukan dari konfigurasi
  /// statis — supaya pesan error tidak menyesatkan ketika alamat server
  /// diubah saat runtime (Pengaturan / `--dart-define`).
  static String get hostLabel {
    final live = ApiClient.instance.dio.options.baseUrl;
    final uri = Uri.tryParse(live);
    if (uri != null && uri.host.isNotEmpty) return uri.host;
    final fallbackUri = Uri.tryParse(apiBaseUrl);
    if (fallbackUri != null && fallbackUri.host.isNotEmpty) {
      return fallbackUri.host;
    }
    return apiBaseUrl;
  }

  static String _trimTrailingSlash(String v) =>
      v.endsWith('/') ? v.substring(0, v.length - 1) : v;
}

/// ApiClient — klien HTTP (Dio) untuk backend Laravel Warung Lupi.
///
/// Meniru `resources/js/api/client.js`:
/// - `baseURL: '/api'` → di Flutter di-absolut-kan lewat [ApiConfig]
/// - header: Content-Type/Accept json, X-Requested-With XMLHttpRequest,
///   ngrok-skip-browser-warning (kompatibilitas)
class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  late final Dio dio = _createDio();

  /// Base URL efektif yang sedang dipakai (setelah override `--dart-define`
  /// / Pengaturan). Berguna untuk ditampilkan di Pengaturan & pesan error.
  static String get activeBaseUrl => ApiConfig.baseUrl;

  static const String productionBaseUrl = ApiConfig.productionBaseUrl;

  /// Ganti server API saat runtime (mis. untuk dev di HP tanpa build ulang).
  /// Semua request berikutnya langsung memakai alamat baru.
  void setBaseUrl(String url) {
    final v = url.trim();
    final origin = v.endsWith('/') ? v.substring(0, v.length - 1) : v;
    dio.options.baseUrl =
        '${origin.isEmpty ? ApiConfig.productionBaseUrl : origin}/api';
  }

  Dio _createDio() {
    final options = BaseOptions(
      baseUrl: ApiConfig.apiBaseUrl,
      // Timeout sengaja ketat: endpoint produksi terukur ~0.15–0.4s.
      // Nilai besar hanya membuat UI "loading" lama saat server tak terjangkau.
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-Requested-With': 'XMLHttpRequest',
        // Kompatibel dengan backend (dipakai juga di web client Laravel).
        'ngrok-skip-browser-warning': 'true',
      },
    );
    return Dio(options);
  }

  /// Uji konektivitas ke `GET /api/dashboard`. Mengembalikan null bila OK,
  /// atau pesan error yang siap ditampilkan.
  static Future<String?> ping() async {
    try {
      await ApiClient.instance.dio.get(
        '/dashboard',
        options: Options(receiveTimeout: const Duration(seconds: 15)),
      );
      return null;
    } catch (e) {
      return errorMessage(e, fallback: 'Server tidak merespons.');
    }
  }

  /// Helper: ambil pesan error user-friendly dari DioException.
  ///
  /// Pesan selalu menyertakan host server agar kegagalan koneksi bisa
  /// langsung dikenali tanpa membuka log.
  static String errorMessage(
    Object? error, {
    String fallback = 'Terjadi kesalahan. Silakan coba lagi.',
  }) {
    if (error is DioException) {
      // Pesan dari Laravel (mis. 422 "masih memiliki riwayat bon") selalu
      // diprioritaskan di atas pesan generik.
      final data = error.response?.data;
      if (data is Map) {
        final msg = data['message'];
        if (msg is String && msg.isNotEmpty) return msg;
      }

      final host = ApiConfig.hostLabel;

      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.transformTimeout:
          return 'Koneksi ke server ($host) timeout. Periksa koneksi internet Anda.';
        case DioExceptionType.badCertificate:
          return 'Sertifikat HTTPS server ($host) tidak valid.';
        case DioExceptionType.connectionError:
        case DioExceptionType.unknown:
          return 'Tidak dapat terhubung ke server ($host). '
              'Periksa koneksi internet / alamat server.';
        case DioExceptionType.cancel:
          return 'Permintaan dibatalkan.';
        case DioExceptionType.badResponse:
          final code = error.response?.statusCode;
          if (code == 401) return 'Sesi berakhir. Silakan masuk kembali.';
          if (code == 403) return 'Anda tidak memiliki akses.';
          if (code == 404) return 'Data tidak ditemukan.';
          if (code == 422) return 'Data yang dikirim tidak valid.';
          if (code != null && code >= 500) {
            return 'Server sedang bermasalah. Coba lagi beberapa saat.';
          }
          return 'Server menolak permintaan ($code).';
      }
    }
    return fallback;
  }

  /// Helper: ambil map `errors` dari response validasi Laravel (422).
  /// Format: `{ errors: { field: [msg] } }` → `{ field: msg }` (ambil yang pertama).
  static Map<String, String> fieldErrors(Object? error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['errors'] is Map) {
        final raw = data['errors'] as Map;
        final result = <String, String>{};
        raw.forEach((k, v) {
          if (v is List && v.isNotEmpty) {
            result[k.toString()] = v.first.toString();
          } else if (v is String) {
            result[k.toString()] = v;
          }
        });
        return result;
      }
    }
    return {};
  }
}

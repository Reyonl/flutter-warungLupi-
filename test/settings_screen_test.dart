// Smoke test layar Pengaturan: memastikan kartu "SERVER API" baru benar-benar
// ter-render dengan alamat produksi (layar ini ditulis ulang, jadi perlu bukti
// bahwa ia dibangun tanpa exception).
//
// Jalankan: flutter test test/settings_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rekapan_warung/core/api/api_client.dart';
import 'package:rekapan_warung/screens/settings/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Pengaturan menampilkan SERVER API + alamat produksi',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SettingsScreen())),
    );
    // Selesaikan Future prefs di initState.
    await tester.pumpAndSettle();

    expect(find.text('Pengaturan'), findsOneWidget);
    expect(find.text('SERVER API'), findsOneWidget);

    // Alamat produksi harus terlihat (default saat prefs kosong).
    expect(find.text(ApiClient.productionBaseUrl), findsWidgets);
    expect(ApiClient.productionBaseUrl, 'https://warunglupi.tplp004.com');

    // Label status "Produksi" → membuktikan app memakai server produksi.
    expect(find.text('Produksi'), findsOneWidget);

    // Kontrol yang diharapkan ada.
    expect(find.text('Simpan Alamat'), findsOneWidget);
    expect(find.text('Tes Koneksi'), findsOneWidget);
    expect(find.text('PRINTER THERMAL'), findsOneWidget);
    expect(find.text('UKURAN KERTAS DEFAULT'), findsOneWidget);
  });

  testWidgets('Pengaturan menampilkan server kustom bila prefs diisi',
      (tester) async {
    SharedPreferences.setMockInitialValues({'apiBaseUrl': 'http://192.168.1.9:8000'});
    ApiConfig.runtimeOverride = 'http://192.168.1.9:8000';
    ApiClient.instance.setBaseUrl('http://192.168.1.9:8000');

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SettingsScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.text('http://192.168.1.9:8000'), findsWidgets);
    expect(find.text('Kustom'), findsOneWidget);

    // Kembalikan ke produksi agar tidak bocor ke tes lain.
    ApiConfig.runtimeOverride = '';
    ApiClient.instance.setBaseUrl('');
  });
}
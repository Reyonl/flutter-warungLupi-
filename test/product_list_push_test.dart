// Regresi: chip "Tambah Item" di Dashboard meng-push ProductListScreen
// LANGSUNG lewat Navigator (bukan lewat drawer HomeShell). Sebelum fix,
// layar itu tidak punya Scaffold sendiri → TextField kehilangan ancestor
// Material → "No Material widget found" + overflow 199202px.
//
// Adapter Dio distub kosong supaya initState (loadCategories + load)
// selesai tanpa jaringan dan tanpa timer pending di lingkungan test.
//
// Jalankan: flutter test test/product_list_push_test.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:rekapan_warung/core/api/api_client.dart';
import 'package:rekapan_warung/core/theme/app_theme.dart';
import 'package:rekapan_warung/providers/providers.dart';
import 'package:rekapan_warung/providers/repositories.dart';
import 'package:rekapan_warung/screens/products/product_list_screen.dart';

class _EmptyListAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '[]',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  setUp(() {
    ApiClient.instance.dio.httpClientAdapter = _EmptyListAdapter();
  });

  testWidgets('di-push tanpa Scaffold di atasnya → tetap punya Material', (
    tester,
  ) async {
    // Sengaja TIDAK dibungkus Scaffold: inilah jalur Navigator.push dari
    // dashboard. Widget harus membungkus dirinya sendiri (embedded=false).
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => ProductProvider(ProductRepository()),
            ),
          ],
          child: const ProductListScreen(),
        ),
      ),
    );
    // Jalankan post-frame (loadCategories + load) lalu majukan clock FakeAsync
    // agar timer internal Dio (zero-duration) selesai — tanpa ini binding
    // melaporkan "Timer is still pending" saat teardown.
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      tester.takeException(),
      isNull,
      reason: 'ProductListScreen tidak boleh crash saat di-push',
    );
    expect(
      find.byType(TextField),
      findsWidgets,
      reason: 'baris cari item harus ter-render',
    );
    expect(
      find.byType(AppBar),
      findsOneWidget,
      reason: 'mode push → punya AppBar sendiri',
    );
  });

  testWidgets('embedded → TIDAK menambah Scaffold kedua (tetap 1)', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => ProductProvider(ProductRepository()),
            ),
          ],
          child: const Scaffold(body: ProductListScreen(embedded: true)),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
    expect(
      find.byType(Scaffold),
      findsOneWidget,
      reason: 'mode embedded = body HomeShell; Scaffold ganda menumpuk AppBar',
    );
    expect(find.byType(AppBar), findsNothing);
  });
}

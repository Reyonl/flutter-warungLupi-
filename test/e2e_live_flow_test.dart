// E2E LIVE — Phase 2 End-to-End Verification (2026-10-02).
//
// Mengemudi BonCreateScreen ASLI dengan provider ASLI (CustomerProvider /
// ProductProvider / BonDraftProvider → Dio → https://warunglupi.tplp004.com)
// sehingga teks di dropdown terbukti data API produksi, bukan dummy.
// Interceptor mencatat SETIAP request (method, path, durasi) untuk audit
// duplikat/full-reload + pengukuran latensi payment status.
//
// Catatan teknis: request yang DIPILOTPROVIDER dari zona FakeAsync terbukti
// jalan dengan loop settleUntil (runAsync + pump(Duration)); pemanggilan
// repo langsung lewat tester.runAsync justru kena receive-timeout — jadi
// semua re-read backend di sini lewat helper `live()` (zona tes + polling).
//
// Menulis ke database produksi → HANYA jalan dengan flag eksplisit, dan
// selalu menghapus bon uji di tearDownAll:
//   flutter test --dart-define=RUN_LIVE_TESTS=true test/e2e_live_flow_test.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'live_test_config.dart';

import 'package:rekapan_warung/core/api/api_client.dart';
import 'package:rekapan_warung/core/theme/app_theme.dart';
import 'package:rekapan_warung/models/models.dart';
import 'package:rekapan_warung/providers/providers.dart';
import 'package:rekapan_warung/providers/repositories.dart';
import 'package:rekapan_warung/screens/bon/bon_create_screen.dart';
import 'package:rekapan_warung/utils/promo.dart' show formatPriceDisplay;

class LogEntry {
  final String method;
  final String url;
  final DateTime start;
  DateTime? end;
  int? status;
  LogEntry(this.method, this.url, this.start);
  int get ms => end == null ? -1 : end!.difference(start).inMilliseconds;
  String get path => Uri.parse(url).path;
}

class NetLog {
  final List<LogEntry> entries = [];
  List<LogEntry> of(String method, String pathContains) => entries
      .where((e) => e.method == method && e.path.contains(pathContains))
      .toList();
  int count(String method, String pathContains) => of(method, pathContains).length;
  int mark() => entries.length;
  bool allDone([int from = 0]) => !entries.skip(from).any((e) => e.end == null);
  void clear() => entries.clear();
}

final NetLog net = NetLog();

class _NetInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    net.entries
        .add(LogEntry(options.method, options.uri.toString(), DateTime.now()));
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    for (final e in net.entries.reversed) {
      if (e.end == null) {
        e
          ..end = DateTime.now()
          ..status = response.statusCode;
        break;
      }
    }
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    for (final e in net.entries.reversed) {
      if (e.end == null) {
        e
          ..end = DateTime.now()
          ..status = err.response?.statusCode;
        break;
      }
    }
    super.onError(err, handler);
  }
}

/// Jalankan event loop NYATA 200ms lalu majukan jam FakeAsync, berulang,
/// sampai [condition] terpenuhi. pump() TANPA durasi tidak memajukan jam
/// fake → callback provider tak pernah jalan (penyebab timeout pertama).
Future<bool> settleUntil(WidgetTester tester, bool Function() condition,
    {int maxSeconds = 45, String? label}) async {
  final deadline = DateTime.now().add(Duration(seconds: maxSeconds));
  while (DateTime.now().isBefore(deadline)) {
    if (condition()) return true;
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump(const Duration(milliseconds: 250));
  }
  // ignore: avoid_print
  print('⏱ settleUntil TIMEOUT menunggu: $label');
  return condition();
}

/// Tunggu sampai SEMUA request yang tercatat selesai (status terisi).
Future<void> settleNet(WidgetTester tester) async {
  final ok =
      await settleUntil(tester, () => net.allDone(), maxSeconds: 30, label: 'net selesai');
  expect(ok, isTrue, reason: 'semua request harus selesai tercatat');
}

/// Jalankan pemanggilan repo di ZONA TES (bukan runAsync — lihat header)
/// dan poll sampai selesai. Retry 1x untuk stall koneksi sementara
/// (connect/receive timeout) — kegagalan persist tetap menggagalkan test.
Future<T> live<T>(WidgetTester tester, Future<T> Function() body,
    {String label = 'repo call', int attempts = 2}) async {
  Object? lastError;
  for (var a = 0; a < attempts; a++) {
    Object? result;
    Object? error;
    bool done = false;
    // Future dibuat di zona fake — sama seperti load() provider yang terbukti jalan.
    body().then((v) {
      result = v;
      done = true;
    }, onError: (Object e) {
      error = e;
      done = true;
    });
    final ok = await settleUntil(tester, () => done, maxSeconds: 45, label: label);
    if (!ok) throw StateError('live() timeout: $label');
    if (error == null) return result as T;
    lastError = error;
    // ignore: avoid_print
    print('↻ live($label) error ke-${a + 1}: $error');
  }
  throw lastError!;
}

Future<void> idle(WidgetTester tester, {int frames = 6}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Akhiri testWidgets: majukan jam fake melewati jendela idle keepAlive
/// socket (dart:_http membuat Timer 3s di zona fake saat koneksi HTTP
/// dilepas; invariant flutter_test melarang timer pending saat test selesai).
Future<void> drainKeepAlive(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
}

Finder fieldByHint(String hintText) => find.byWidgetPredicate(
    (w) => w is TextField && (w.decoration?.hintText ?? '') == hintText);

Finder fieldWithControllerText(String text) => find.byWidgetPredicate(
    (w) => w is TextField && (w.controller?.text ?? '') == text);

String head(String s, int n) => s.substring(0, s.length < n ? s.length : n);

void main() {
  enableRealNetwork();

  if (!runLiveTests) {
    test('E2E LIVE DILEWATI', () {}, skip: skipReason);
    return;
  }

  ApiClient.instance.dio.interceptors.add(_NetInterceptor());

  final customers = CustomerRepository();
  final products = ProductRepository();
  final txRepo = TransactionRepository();

  late CustomerProvider custProv;
  late ProductProvider prodProv;
  late BonDraftProvider draftProv;

  late Customer liveCustomer;
  late Customer otherCustomer;
  late List<Customer> allActiveCustomers;
  late Product liveProductA;
  late Product liveProductB;

  int? testTxId;
  final findings = <String>[];

  setUp(() {
    enableRealNetwork(); // binding memasang ulang mock setelah main()
    custProv = CustomerProvider(customers);
    prodProv = ProductProvider(products);
    draftProv = BonDraftProvider(txRepo);
  });

  Future<void> pumpCreate(WidgetTester tester, {int? editId, BonDraftProvider? draft}) async {
    final usedDraft = draft ?? draftProv;
    final size = tester.view.physicalSize;
    final dpr = tester.view.devicePixelRatio;
    addTearDown(() {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = dpr;
    });
    tester.view.physicalSize = const Size(1100, 2300);
    tester.view.devicePixelRatio = 1.0;

    // Bongkar tree yang masih terpasang dulu: pumpWidget kedua dengan tipe
    // sama akan MEMAKAI ULANG State lama (initState tidak jalan) — padahal
    // buka ulang layar di app nyata = State baru. Tanpa ini _init tidak pernah
    // memanggil loadExisting untuk provider yang baru.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: custProv),
          ChangeNotifierProvider.value(value: prodProv),
          ChangeNotifierProvider.value(value: usedDraft),
        ],
        child: BonCreateScreen(editTransactionId: editId),
      ),
    ));

    var ok = await settleUntil(
        tester,
        () => custProv.customers.isNotEmpty &&
            prodProv.products.isNotEmpty &&
            !custProv.loading &&
            !prodProv.loading &&
            net.allDone(),
        maxSeconds: 60,
        label: 'referensi termuat dari API');
    if (!ok && (custProv.error != null || prodProv.error != null)) {
      // Satu retry untuk koneksi flaky (bukan menyembunyikan bug API:
      // error tetap membuat test gagal kalau retry pun gagal).
      // ignore: avoid_print
      print('↻ load referensi gagal (${custProv.error ?? prodProv.error}) → retry 1x');
      custProv.error = null;
      prodProv.error = null;
      custProv.load(); // fire-and-settle: await langsung deadlock di zona fake
      prodProv.load();
      ok = await settleUntil(
          tester,
          () => custProv.customers.isNotEmpty &&
              prodProv.products.isNotEmpty &&
              !custProv.loading &&
              !prodProv.loading &&
              net.allDone(),
          maxSeconds: 60,
          label: 'referensi retry');
    }
    if (!ok) {
      // ignore: avoid_print
      print('DIAG custErr=${custProv.error} prodErr=${prodProv.error} '
          'loading=${custProv.loading}/${prodProv.loading} '
          'counts=${custProv.customers.length}/${prodProv.products.length} '
          'reqs=[${net.entries.map((e) => "${e.method} ${e.path}→${e.status}").join("; ")}]');
    }
    expect(ok, isTrue, reason: 'data referensi harus datang dari API produksi');
    expect(custProv.error, isNull, reason: 'load customer: ${custProv.error}');
    expect(prodProv.error, isNull, reason: 'load produk: ${prodProv.error}');
    await idle(tester);
  }

  Future<void> selectCustomer(WidgetTester tester, String name) async {
    final f = fieldByHint('Cari pelanggan (ketik nama/hp)...');
    await tester.tap(f);
    await idle(tester, frames: 3);
    await tester.enterText(f, name);
    await idle(tester, frames: 3);
    await tester.tap(find.text(name).last);
    await idle(tester, frames: 5); // timer 200ms penutup dropdown
  }

  test('0. Prasyarat: data nyata tersedia di API produksi', () async {
    allActiveCustomers = await customers.index(isActive: true);
    final ps = await products.index(isActive: true);
    liveCustomer = allActiveCustomers.first;
    otherCustomer = allActiveCustomers.firstWhere((c) => c.id != liveCustomer.id);
    liveProductA = ps[0];
    liveProductB = ps[1];
    // ignore: avoid_print
    print('LIVE DATA: cust=${liveCustomer.id}:${liveCustomer.name} | '
        'A=${liveProductA.id}:${liveProductA.name}@${liveProductA.defaultPrice} | '
        'B=${liveProductB.id}:${liveProductB.name}@${liveProductB.defaultPrice}');
    expect(allActiveCustomers.length, greaterThan(1));
    expect(ps.length, greaterThan(1));
  });

  test('0b. Latensi mentah backend (zona nyata, tanpa FakeAsync/polling)',
      () async {
    // Plain test() = timer & event loop NYATA (sama seperti live_api_test).
    // Angka ini yang menjadi patokan waktu request sesungguhnya; angka di
    // testWidgets terdistorsi granularitas polling settleUntil (200ms/cycle).
    final sw = Stopwatch();
    final r = <String, int>{};

    sw..reset()..start();
    await customers.index(isActive: true); // koneksi pertama: TLS handshake
    sw.stop();
    r['GET customers (cold TLS)'] = sw.elapsedMilliseconds;

    final t = await txRepo.store(
        customerId: liveCustomer.id,
        transactionDate: '2026-10-02',
        notes: 'LATPROBE-FLUTTER');
    try {
      for (final label in ['paid', 'unpaid', 'paid', 'unpaid']) {
        sw..reset()..start();
        await txRepo.update(t.id, paymentStatus: label);
        sw.stop();
        r['PUT payment → $label'] = sw.elapsedMilliseconds;
      }
      sw..reset()..start();
      await txRepo.show(t.id);
      sw.stop();
      r['GET show (warm)'] = sw.elapsedMilliseconds;
    } finally {
      await txRepo.destroy(t.id);
    }
    // ignore: avoid_print
    print('RAW LATENCY (flutter client → produksi):\n  '
        '${r.entries.map((e) => "${e.key}: ${e.value}ms").join("\n  ")}');
    findings.add('Latensi mentah via klien Flutter: '
        '${r.entries.map((e) => "${e.key} ${e.value}ms").join(", ")}');
    // Sanity: backend harus di bawah timeout ketat app (20s).
    expect(r.values.every((ms) => ms < 5000), isTrue,
        reason: 'semua request < 5s — server sehat: $r');
  });

  testWidgets('1. Customer Search: hasil = data API, 0 request/karakter, ganti & clear',
      (tester) async {
    net.clear();
    await pumpCreate(tester);

    findings.add('Load awal: ${net.count('GET', '/api/customers')} GET customers, '
        '${net.count('GET', '/api/products')} GET products, '
        '${net.count('GET', '/api/categories')} GET categories');

    final custField = fieldByHint('Cari pelanggan (ketik nama/hp)...');
    expect(custField, findsOneWidget);
    expect(tester.widget<TextField>(custField).enabled, isTrue,
        reason: 'field siap keyboard saat header belum disimpan');

    final before = net.count('GET', '/api/customers');
    await tester.tap(custField);
    await idle(tester, frames: 3);
    await tester.enterText(custField, head(liveCustomer.name, 2));
    await idle(tester, frames: 3);
    expect(net.count('GET', '/api/customers'), before,
        reason: 'satu ketukan huruf ≠ satu request API');
    expect(find.text(liveCustomer.name), findsWidgets,
        reason: 'hasil berasal dari data customer API nyata');

    await tester.enterText(custField, 'zzqxx-tidak-ada');
    await idle(tester, frames: 3);
    expect(find.text('Tidak ada pelanggan ditemukan'), findsOneWidget);

    await selectCustomer(tester, liveCustomer.name);
    expect(find.byIcon(Icons.clear), findsOneWidget, reason: 'tombol clear tampil');
    await tester.tap(find.byIcon(Icons.clear));
    await idle(tester, frames: 3);
    await selectCustomer(tester, otherCustomer.name);
    await selectCustomer(tester, liveCustomer.name);
    expect(net.count('GET', '/api/customers'), before,
        reason: 'ganti-ganti customer tetap 0 request tambahan');
    findings.add('Customer search: filter lokal, 0 request/karakter, '
        'clear+ganti OK, empty state OK');
    await drainKeepAlive(tester);
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('2-3. Product Search + Save: 2 item + keterangan → TERBUKTI di backend',
      (tester) async {
    net.clear();
    await pumpCreate(tester);
    await selectCustomer(tester, liveCustomer.name);

    net.clear();
    await tester.tap(find.text('Mulai Input Catatan'));
    final headerOk = await settleUntil(
        tester, () => draftProv.headerSaved && draftProv.transactionId != null,
        label: 'POST header');
    expect(headerOk, isTrue, reason: 'header harus tersimpan (err=${draftProv.error})');
    await settleNet(tester);
    testTxId = draftProv.transactionId!;
    final postH = net.of('POST', '/api/transactions');
    expect(postH.length, 1, reason: 'tepat 1 POST header — tanpa duplikat');
    expect((postH.first.status ?? 0) < 300, isTrue,
        reason: 'header dibalas 2xx (${postH.first.status})');
    findings.add('Simpan header: HTTP ${postH.first.ms}ms (id=$testTxId, '
        'no=${draftProv.transactionNumber})');

    expect(
        tester.widget<TextField>(fieldByHint('Cari pelanggan (ketik nama/hp)...')).enabled,
        isFalse,
        reason: 'pelanggan terkunci setelah header tersimpan');
    expect(find.text('Mulai Input Catatan'), findsNothing);

    // ---- Product search ----
    final prodField = fieldByHint('Cari item...');
    expect(prodField, findsOneWidget, reason: 'form item muncul setelah header');
    final pBefore = net.count('GET', '/api/products');
    await tester.tap(prodField);
    await idle(tester, frames: 3);
    await tester.enterText(prodField, head(liveProductA.name, 3));
    await idle(tester, frames: 3);
    expect(net.count('GET', '/api/products'), pBefore,
        reason: 'product search = filter lokal, 0 request/karakter');
    expect(find.text(liveProductA.name), findsOneWidget,
        reason: 'hasil item = data produk API nyata');

    await tester.enterText(prodField, 'zzqxx');
    await idle(tester, frames: 3);
    expect(find.text('Tidak ada item ditemukan'), findsOneWidget);

    await tester.enterText(prodField, liveProductA.name);
    await idle(tester, frames: 3);
    await tester.tap(find.text(liveProductA.name).last);
    await idle(tester, frames: 4);
    expect(
        fieldWithControllerText(formatPriceDisplay(liveProductA.defaultPrice.toString())),
        findsOneWidget,
        reason: 'harga default ${liveProductA.defaultPrice} terisi otomatis');

    net.clear();
    await tester.tap(find.text('+ Tambah'));
    var added = await settleUntil(tester, () => draftProv.items.length == 1,
        label: 'POST item A');
    expect(added, isTrue);
    await settleNet(tester);
    final postA = net.of('POST', '/items');
    expect(postA.length, 1, reason: '1 POST item');
    expect(net.count('GET', '/api/transactions/'), 1,
        reason: 'tepat 1 GET refresh — tanpa full reload ganda');
    findings.add('Item A: POST ${postA.first.ms}ms + refresh GET '
        '${net.of('GET', '/api/transactions/').first.ms}ms');

    // Item KEDUA (B): A tidak boleh hilang; isi keterangan + qty 2.
    await tester.tap(prodField);
    await idle(tester, frames: 3);
    await tester.enterText(prodField, liveProductB.name);
    await idle(tester, frames: 3);
    await tester.tap(find.text(liveProductB.name).last);
    await idle(tester, frames: 4);

    await tester.enterText(fieldByHint('Contoh: Tegar'), 'E2E-KETERANGAN');
    await idle(tester, frames: 2);
    await tester.enterText(fieldWithControllerText('1'), '2'); // qty
    await idle(tester, frames: 2);

    net.clear();
    await tester.tap(find.text('+ Tambah'));
    added = await settleUntil(tester, () => draftProv.items.length == 2, label: 'POST item B');
    expect(added, isTrue);
    await settleNet(tester);
    expect(draftProv.items.first.productName, liveProductA.name,
        reason: 'item pertama tidak hilang saat menambah item kedua');

    // ---- Bukti di BACKEND ----
    final fresh = await live(tester, () => txRepo.show(testTxId!), label: 're-read show');
    expect(fresh.customerId, liveCustomer.id, reason: 'customer tersimpan di DB');
    expect(fresh.items.length, 2, reason: '2 item tersimpan di DB produksi');
    expect(fresh.items.map((i) => i.productName).toSet(),
        {liveProductA.name, liveProductB.name});
    final b = fresh.items.firstWhere((i) => i.productName == liveProductB.name);
    expect(b.quantity, 2, reason: 'qty terkirim benar');
    expect(b.description, 'E2E-KETERANGAN', reason: 'catatan item tersimpan di DB');
    expect(b.unitPrice, liveProductB.defaultPrice, reason: 'harga tersimpan di DB');
    expect(fresh.totalAmount, fresh.items.fold<int>(0, (s, i) => s + i.subtotal),
        reason: 'total backend = Σ subtotal (server yang menghitung)');
    expect(draftProv.totalAmount, fresh.totalAmount, reason: 'total UI = backend');
    findings.add('Save terbukti di DB: customer=${fresh.customerId}, items=2, '
        'qty B=2, desc B OK, total=${fresh.totalAmount} (UI==backend)');
    await drainKeepAlive(tester);
  }, timeout: const Timeout(Duration(minutes: 4)));

  testWidgets('4. Edit Transaksi + Payment Status: qty/ket/hapus, latensi, persist',
      (tester) async {
    expect(testTxId, isNotNull, reason: 'memakai bon dari tes 2-3');
    net.clear();
    await pumpCreate(tester, editId: testTxId);

    final editLoaded = await settleUntil(
        tester, () => draftProv.headerSaved && draftProv.items.length == 2,
        label: 'loadExisting edit mode');
    expect(editLoaded, isTrue, reason: 'mode edit memuat 2 item (err=${draftProv.error})');
    expect(draftProv.paymentStatus, 'unpaid');
    expect(
        tester.widget<TextField>(fieldByHint('Cari pelanggan (ketik nama/hp)...')).enabled,
        isFalse,
        reason: 'mode edit: pelanggan terkunci (sama dgn website)');
    findings.add('Ganti customer on-screen: terkunci by design setelah header '
        'identik website; endpoint PUT customer_id tetap tersedia di repo');

    // Edit item B: qty 2→4 + keterangan diubah.
    final itemB = draftProv.orderedItems.firstWhere((i) => i.productName == liveProductB.name);
    final bIndex = draftProv.orderedItems.indexWhere((i) => i.id == itemB.id);
    await tester.tap(find.text('Edit').at(bIndex));
    await idle(tester, frames: 4);
    expect(find.text('Edit Item'), findsOneWidget, reason: 'form masuk mode edit item');
    expect(fieldWithControllerText('E2E-KETERANGAN'), findsOneWidget,
        reason: 'keterangan lama ikut termuat di form edit');

    await tester.enterText(fieldWithControllerText('2'), '4');
    await idle(tester, frames: 2);
    await tester.enterText(fieldByHint('Contoh: Tegar'), 'E2E-KETERANGAN-EDIT');
    await idle(tester, frames: 2);

    net.clear();
    await tester.tap(find.text('✓ Update'));
    final upd = await settleUntil(
        tester, () => draftProv.items.any((i) => i.id == itemB.id && i.quantity == 4),
        label: 'PUT item');
    expect(upd, isTrue, reason: 'qty 4 masuk state dari respons server');
    await settleNet(tester);
    expect(net.count('PUT', '/api/transaction-items'), 1, reason: 'tepat 1 PUT item');
    expect(net.count('GET', '/api/transactions/'), 1, reason: '1 refresh GET');

    // Hapus item A.
    final aIndex = draftProv.orderedItems.indexWhere((i) => i.id != itemB.id);
    await tester.tap(find.text('Hapus').at(aIndex));
    final removed =
        await settleUntil(tester, () => draftProv.items.length == 1, label: 'DELETE item');
    expect(removed, isTrue);
    await settleNet(tester);
    expect(net.count('DELETE', '/api/transaction-items'), 1);
    expect(draftProv.items.first.id, itemB.id, reason: 'item B yang tersisa');

    // ---- Payment status: UKUR, jangan ubah logic ----
    // Provider SUDAH optimistic (set state → PUT → rollback bila error),
    // jadi "UI berubah" instan; angka penting = durasi HTTP PUT + GET
    // tambahan (indikator unnecessary reload).
    net.clear();
    await tester.tap(find.text('Sudah Dibayar'));
    final paidUi =
        await settleUntil(tester, () => draftProv.paymentStatus == 'paid', label: 'paid');
    expect(paidUi, isTrue);
    // Existence dulu — allDone() atas list KOSONG bernilai true (race).
    await settleUntil(
        tester,
        () => net.of('PUT', '/api/transactions').length == 1 && net.allDone(),
        maxSeconds: 30,
        label: 'PUT paid tercatat & selesai');
    final paidReq = net.of('PUT', '/api/transactions');
    expect(paidReq.length, 1, reason: 'tepat 1 PUT status — tanpa duplikat');
    expect((paidReq.first.status ?? 0) < 300, isTrue);
    findings.add('Payment → paid: HTTP ${paidReq.first.ms}ms (status='
        '${paidReq.first.status}); GET tambahan setelah update: '
        '${net.count('GET', '/api/transactions')} (0 = tidak ada reload); '
        'UI instan (optimistic + rollback, provider lama)');

    final db1 = await live(tester, () => txRepo.show(testTxId!), label: 'check paid');
    expect(db1.paymentStatus, 'paid', reason: 'paid tersimpan di DB (source of truth)');

    net.clear();
    await tester.tap(find.text('Berhutang'));
    final unpaidUi =
        await settleUntil(tester, () => draftProv.paymentStatus == 'unpaid', label: 'unpaid');
    expect(unpaidUi, isTrue);
    await settleUntil(
        tester,
        () => net.of('PUT', '/api/transactions').length == 1 && net.allDone(),
        maxSeconds: 30,
        label: 'PUT unpaid tercatat & selesai');
    final unpaidReq = net.of('PUT', '/api/transactions');
    expect(unpaidReq.length, 1);
    findings.add('Payment → unpaid: HTTP ${unpaidReq.first.ms}ms; GET tambahan: '
        '${net.count('GET', '/api/transactions')}');
    final db2 = await live(tester, () => txRepo.show(testTxId!), label: 'check unpaid');
    expect(db2.paymentStatus, 'unpaid');

    // ---- Keluar dari halaman → buka ulang (layar baru + provider draft baru) ----
    final reopened = BonDraftProvider(txRepo);
    net.clear();
    await pumpCreate(tester, editId: testTxId, draft: reopened);
    final reloadOk = await settleUntil(
        tester,
        () => (reopened.headerSaved &&
                reopened.items.isNotEmpty &&
                !reopened.loading &&
                net.allDone()) ||
            reopened.error != null,
        maxSeconds: 60,
        label: 'buka ulang');
    if (!reloadOk || reopened.error != null) {
      // ignore: avoid_print
      print('DIAG reopen error=${reopened.error} loading=${reopened.loading} '
          'headerSaved=${reopened.headerSaved} items=${reopened.items.length} '
          'reqs=[${net.entries.map((e) => "${e.method} ${e.path}→${e.status ?? "open"} ${e.ms}ms").join("; ")}]');
    }
    expect(reopened.error, isNull, reason: 'loadExisting tidak boleh error');
    expect(reloadOk, isTrue);
    await settleNet(tester);
    expect(reopened.items.length, 1, reason: 'item A tetap terhapus setelah buka ulang');
    expect(reopened.items.first.quantity, 4, reason: 'qty hasil edit persist di DB');
    expect(reopened.items.first.description, 'E2E-KETERANGAN-EDIT',
        reason: 'catatan hasil edit persist di DB');
    expect(reopened.paymentStatus, 'unpaid');
    expect(net.count('GET', '/api/transactions'), 1,
        reason: 'buka ulang = 1 GET transaksi (tanpa fetch list penuh)');
    findings.add('Persist pasca-buka-ulang via UI: 1 item, qty=4, '
        'keterangan diedit, unpaid; reopen = 1 GET');
    await drainKeepAlive(tester);
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('6. Regresi: kontrak daftar & riwayat customer tetap normal',
      (tester) async {
    // testWidgets (bukan test biasa): setelah testWidgets lain, koneksi
    // keepAlive tersimpan Dio terikat zona fake yang sudah mati → pemanggilan
    // repo langsung mati timeout. Zona live() yang di-poll tetap jalan.
    expect(testTxId, isNotNull);
    final t = await live(tester, () => txRepo.show(testTxId!), label: 'regresi show');
    expect(t.transactionNumber, startsWith('INV-'));
    var page =
        await live(tester, () => txRepo.index(search: t.transactionNumber), label: 'index');
    var found = page.data.any((x) => x.id == testTxId);
    if (!found) {
      page = await live(tester, () => txRepo.index(page: 1, perPage: 100), label: 'index fallback');
      found = page.data.any((x) => x.id == testTxId);
    }
    expect(found, isTrue, reason: 'bon E2E terlihat di daftar (Riwayat Bon)');
    final hist = await live(tester, () => customers.transactions(t.customerId!),
        label: 'riwayat customer');
    expect(hist.any((x) => x.id == testTxId), isTrue,
        reason: 'bon terlihat di riwayat customer (layar Customer)');
    findings.add('Regresi GET /transactions & riwayat customer: normal');
    await drainKeepAlive(tester);
  }, timeout: const Timeout(Duration(minutes: 2)));

  tearDownAll(() async {
    if (testTxId != null) {
      try {
        await txRepo.destroy(testTxId!);
        // ignore: avoid_print
        print('🧹 CLEANUP: bon uji $testTxId dihapus dari DB produksi');
      } catch (e) {
        // ignore: avoid_print
        print('⚠ CLEANUP GAGAL (hapus manual id=$testTxId): $e');
      }
    }
    // ignore: avoid_print
    print('\n===== E2E FINDINGS =====\n- ${findings.join('\n- ')}\n');
  });
}

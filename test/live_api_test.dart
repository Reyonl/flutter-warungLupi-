// LIVE integration test — Flutter repositories → https://warunglupi.tplp004.com
// → Laravel → database produksi.
//
// Dijalankan dengan:
//   flutter test --dart-define=RUN_LIVE_TESTS=true test/live_api_test.dart
// Bukan bagian dari unit test biasa (butuh jaringan). Tujuannya membuktikan
// jalur request Flutter (Dio + ApiConfig + repositories) benar-benar bekerja
// terhadap backend produksi yang sama dengan aplikasi web.
import 'package:flutter_test/flutter_test.dart';

import 'live_test_config.dart';
import 'package:rekapan_warung/core/api/api_client.dart';
import 'package:rekapan_warung/providers/repositories.dart';

void main() {
  enableRealNetwork();

  // Menulis ke database produksi → hanya berjalan bila diminta eksplisit.
  if (!runLiveTests) {
    test('LIVE TEST DILEWATI', () {}, skip: skipReason);
    return;
  }

  final customers = CustomerRepository();
  final products = ProductRepository();
  final tx = TransactionRepository();
  final dashboard = DashboardRepository();

  int? createdTxId;
  int? createdItemId;

  test('1. base URL memakai server produksi (bukan emulator)', () {
    // ignore: avoid_print
    print('ACTIVE BASE URL: ${ApiConfig.apiBaseUrl}');
    expect(ApiConfig.apiBaseUrl, 'https://warunglupi.tplp004.com/api');
    expect(ApiConfig.apiBaseUrl.contains('10.0.2.2'), isFalse);
    expect(ApiConfig.apiBaseUrl.contains('localhost'), isFalse);
    expect(ApiConfig.apiBaseUrl.startsWith('https://'), isTrue);
  });

  test('2. koneksi ke server produksi (errorMessage/ping)', () async {
    final err = await ApiClient.ping();
    // ignore: avoid_print
    print('PING ERROR: $err');
    expect(err, isNull);
  });

  test('3. dashboard terisi dari server', () async {
    final d = await dashboard.index();
    // ignore: avoid_print
    print('DASHBOARD: bon=${d.bonHariIni} total=${d.totalHariIni} '
        'hutang=${d.masihHutang} pelanggan=${d.totalPelanggan} '
        'recent=${d.recent.length}');
    expect(d.totalPelanggan, greaterThan(0));
  });

  test('4. daftar customer muncul', () async {
    final list = await customers.index();
    // ignore: avoid_print
    print('CUSTOMERS: ${list.length} → ${list.take(3).map((c) => "${c.id}:${c.name}").join(", ")}');
    expect(list, isNotEmpty);
    expect(list.first.name, isNotEmpty);
  });

  test('5. daftar item/produk muncul', () async {
    final list = await products.index();
    // ignore: avoid_print
    print('PRODUCTS: ${list.length} → ${list.take(3).map((p) => "${p.id}:${p.name}@${p.defaultPrice}").join(", ")}');
    expect(list, isNotEmpty);
  });

  test('6. buat bon (POST /api/transactions) + item + hitung total', () async {
    final cust = (await customers.index()).first;
    final prod = (await products.index()).first;

    // Header bon
    final created = await tx.store(
      customerId: cust.id,
      transactionDate: DateTime.now().toIso8601String().substring(0, 10),
      notes: 'TES INTEGRASI FLUTTER',
    );
    createdTxId = created.id;
    // ignore: avoid_print
    print('CREATED TX: id=${created.id} no=${created.transactionNumber} '
        'status=${created.status} payment=${created.paymentStatus}');

    expect(created.id, greaterThan(0));
    expect(created.transactionNumber, startsWith('INV-'));
    expect(created.status, 'draft');
    expect(created.paymentStatus, 'unpaid');

    // Tambah item (subtotal dihitung server: qty * unit_price)
    final item = await tx.addItem(
      created.id,
      productId: prod.id,
      productName: prod.name,
      quantity: 3,
      unit: prod.unit,
      unitPrice: prod.defaultPrice,
    );
    createdItemId = item.id;
    // ignore: avoid_print
    print('CREATED ITEM: id=${item.id} qty=${item.quantity} '
        'price=${item.unitPrice} subtotal=${item.subtotal}');

    expect(item.quantity, 3);
    expect(item.subtotal, prod.defaultPrice * 3);

    // Baca ulang dari server (bukti tersimpan di DB produksi, bukan lokal)
    final fresh = await tx.show(created.id);
    // ignore: avoid_print
    print('RE-READ TX: total=${fresh.totalAmount} items=${fresh.items.length}');
    expect(fresh.items.length, 1);
    expect(fresh.id, created.id);
  });

  test('7. update quantity → subtotal & total ikut berubah', () async {
    expect(createdTxId, isNotNull);
    expect(createdItemId, isNotNull);
    final prod = (await products.index()).first;

    final updated = await tx.updateItem(createdItemId!, quantity: 5);
    // ignore: avoid_print
    print('UPDATED ITEM: qty=${updated.quantity} subtotal=${updated.subtotal}');
    expect(updated.quantity, 5);
    expect(updated.subtotal, prod.defaultPrice * 5);

    // total_amount bon dihitung oleh backend (recalculateTotal)
    final fresh = await tx.show(createdTxId!);
    // ignore: avoid_print
    print('TX TOTAL AFTER QTY UPDATE: ${fresh.totalAmount}');
    expect(fresh.totalAmount, prod.defaultPrice * 5);
  });

  test('8. status pembayaran (hutang → lunas) lewat backend', () async {
    expect(createdTxId, isNotNull);
    final paid = await tx.update(createdTxId!, paymentStatus: 'paid');
    // ignore: avoid_print
    print('PAYMENT STATUS: ${paid.paymentStatus}');
    expect(paid.paymentStatus, 'paid');

    final unpaid = await tx.update(createdTxId!, paymentStatus: 'unpaid');
    expect(unpaid.paymentStatus, 'unpaid');
  });

  test('9. bon muncul di daftar transaksi (dibaca web juga)', () async {
    expect(createdTxId, isNotNull);
    final page = await tx.index(search: 'TES INTEGRASI FLUTTER');
    // ignore: avoid_print
    print('INDEX SEARCH HITS: ${page.data.length}');
    final found = page.data.any((t) => t.id == createdTxId);
    if (!found) {
      final p2 = await tx.index(page: 1, perPage: 50);
      // ignore: avoid_print
      print('FALLBACK INDEX (first 50): contains=${p2.data.any((t) => t.id == createdTxId!)}');
    }
    final all = await tx.index(page: 1, perPage: 100);
    expect(all.data.any((t) => t.id == createdTxId), isTrue,
        reason: 'Bon yang dibuat Flutter harus terlihat di daftar transaksi');
  });

  test('10. riwayat bon per customer (dipakai layar customer)', () async {
    expect(createdTxId, isNotNull);
    final cust = (await tx.show(createdTxId!)).customerId;
    expect(cust, isNotNull);
    final hist = await customers.transactions(cust!);
    // ignore: avoid_print
    print('CUSTOMER $cust HISTORY: ${hist.length} bon');
    expect(hist.any((t) => t.id == createdTxId), isTrue);
  });

  test('11. hapus item (DELETE /api/transaction-items/{id})', () async {
    expect(createdItemId, isNotNull);
    await tx.deleteItem(createdItemId!);
    final fresh = await tx.show(createdTxId!);
    // ignore: avoid_print
    print('ITEMS AFTER DELETE: ${fresh.items.length} total=${fresh.totalAmount}');
    expect(fresh.items.length, 0);
  });

  test('12. cleanup — hapus bon uji dari database produksi', () async {
    expect(createdTxId, isNotNull);
    await tx.destroy(createdTxId!);
    Object? err;
    try {
      await tx.show(createdTxId!);
    } catch (e) {
      err = e;
    }
    // ignore: avoid_print
    print('AFTER DESTROY, show() error: ${ApiClient.errorMessage(err)}');
    expect(err, isNotNull, reason: 'Bon uji harus sudah terhapus');
  });
}
// Membuktikan arah WEB → FLUTTER:
//  1. Bon yang dibuat lewat aplikasi web dibaca oleh Flutter.
//  2. Flutter mengedit bon tersebut (ubah quantity) → total ikut berubah.
//  3. Hasil edit dibaca ulang dari server (dan tampil juga di web).
//
// Jalankan: flutter test test/web_to_flutter_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'live_test_config.dart';
import 'package:rekapan_warung/providers/repositories.dart';

void main() {
  enableRealNetwork();

  // Menulis ke database produksi → hanya berjalan bila diminta eksplisit.
  if (!runLiveTests) {
    test('LIVE TEST DILEWATI', () {}, skip: skipReason);
    return;
  }

  final tx = TransactionRepository();

  // Bon yang dibuat lewat aplikasi web (lihat langkah verifikasi web).
  const webBonId = 79;

  test('bon buatan WEB terbaca di FLUTTER', () async {
    final t = await tx.show(webBonId);

    // ignore: avoid_print
    print('FLUTTER BACA BON WEB → id=${t.id} no=${t.transactionNumber} '
        'pelanggan=${t.customer?.name} tanggal=${t.transactionDate} '
        'status=${t.status} payment=${t.paymentStatus} total=${t.totalAmount}');
    for (final it in t.items) {
      // ignore: avoid_print
      print('  item: ${it.productName} qty=${it.quantity} '
          'x ${it.unitPrice} = ${it.subtotal}');
    }

    expect(t.id, webBonId);
    expect(t.customer?.name, 'Untung',
        reason: 'Pelanggan yang dipilih di web harus terlihat di Flutter');
    expect(t.items, isNotEmpty,
        reason: 'Item yang ditambahkan di web harus terlihat di Flutter');
    expect(t.items.first.productName, 'Aqua B');
    expect(t.totalAmount, 7000,
        reason: 'Total dari web harus sama persis di Flutter');
  });

  test('FLUTTER mengedit bon buatan WEB (quantity) → total berubah', () async {
    final before = await tx.show(webBonId);
    final item = before.items.first;

    // Ubah qty 1 → 4 (harga satuan 7000 → subtotal 28000)
    final updated = await tx.updateItem(item.id, quantity: 4);
    // ignore: avoid_print
    print('FLUTTER EDIT QTY: ${updated.quantity} × ${updated.unitPrice} '
        '= ${updated.subtotal}');
    expect(updated.quantity, 4);
    expect(updated.subtotal, 28000);

    // Backend yang menghitung ulang total bon (source of truth)
    final after = await tx.show(webBonId);
    // ignore: avoid_print
    print('TOTAL BON SETELAH EDIT FLUTTER: ${after.totalAmount}');
    expect(after.totalAmount, 28000);

    // Kembalikan ke kondisi semula (qty 1) agar data web tetap rapi.
    await tx.updateItem(item.id, quantity: 1);
    final restored = await tx.show(webBonId);
    // ignore: avoid_print
    print('DIKEMBALIKAN: qty=1 total=${restored.totalAmount}');
    expect(restored.totalAmount, 7000);
  });

  test('bon buatan WEB muncul di daftar transaksi Flutter', () async {
    final page = await tx.index(page: 1, perPage: 50);
    final found = page.data.any((t) => t.id == webBonId);
    // ignore: avoid_print
    print('BON WEB ADA DI DAFTAR FLUTTER: $found (total ${page.total})');
    expect(found, isTrue);
  });
}
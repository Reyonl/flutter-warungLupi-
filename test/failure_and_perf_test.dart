// Tes perilaku saat server GAGAL + ukur performa buat bon.
//
// Membuktikan:
//  - server tak terjangkau → error jelas & cepat (BUKAN "Memuat..." tanpa henti)
//  - proses buat bon (header + item + ubah status) berapa milidetik
//
// Jalankan: flutter test test/failure_and_perf_test.dart
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

  test('server tidak terjangkau → error jelas, bukan loading tanpa henti',
      () async {
    // Arahkan ke host yang tidak routable (mensimulasikan HP tanpa akses).
    ApiClient.instance.setBaseUrl('https://192.0.2.1');

    final sw = Stopwatch()..start();
    final err = await ApiClient.ping();
    sw.stop();

    // ignore: avoid_print
    print('UNREACHABLE PING: ${sw.elapsedMilliseconds} ms → $err');
    expect(err, isNotNull, reason: 'harus mengembalikan pesan error');
    expect(err!.contains('192.0.2.1'), isTrue,
        reason: 'pesan error harus menyebut host agar mudah di-debug');

    // Harus gagal jauh sebelum user merasa "stuck".
    expect(sw.elapsedMilliseconds, lessThan(20000),
        reason: 'harus timeout cepat, tidak menggantung lama');

    ApiClient.instance.setBaseUrl(ApiConfig.productionBaseUrl);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('performa: buat bon lengkap ke server produksi', () async {
    final customers = CustomerRepository();
    final products = ProductRepository();
    final tx = TransactionRepository();

    final sw0 = Stopwatch()..start();
    final custList = await customers.index();
    final prodList = await products.index();
    sw0.stop();
    // ignore: avoid_print
    print('PERF muat referensi (pelanggan+item paralel-ish): '
        '${sw0.elapsedMilliseconds} ms');

    final cust = custList.first;
    final prod = prodList.first;
    final today = DateTime.now().toIso8601String().substring(0, 10);

    // --- Ukur setiap langkah buat bon ---
    final sw1 = Stopwatch()..start();
    final created = await tx.store(
      customerId: cust.id,
      transactionDate: today,
      notes: 'TES PERFORMA',
    );
    sw1.stop();

    final sw2 = Stopwatch()..start();
    await tx.addItem(
      created.id,
      productId: prod.id,
      productName: prod.name,
      quantity: 2,
      unit: prod.unit,
      unitPrice: prod.defaultPrice,
    );
    sw2.stop();

    final sw3 = Stopwatch()..start();
    final done = await tx.update(created.id, status: 'completed');
    sw3.stop();

    // ignore: avoid_print
    print('PERF header bon (POST /transactions): ${sw1.elapsedMilliseconds} ms');
    // ignore: avoid_print
    print('PERF tambah item (POST /items): ${sw2.elapsedMilliseconds} ms');
    // ignore: avoid_print
    print('PERF finalize (PUT /transactions): ${sw3.elapsedMilliseconds} ms');
    // ignore: avoid_print
    print('PERF TOTAL buat bon: '
        '${sw1.elapsedMilliseconds + sw2.elapsedMilliseconds + sw3.elapsedMilliseconds} ms');

    expect(done.status, 'completed');

    // Bersihkan
    await tx.destroy(created.id);
    // ignore: avoid_print
    print('PERF cleanup: bon uji ${created.id} dihapus');
  }, timeout: const Timeout(Duration(seconds: 120)));
}
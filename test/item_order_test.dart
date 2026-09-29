// Verifikasi urutan item manual (drag & drop) pada semua jalur:
//  - Transaction.withItemOrder: murni model (dipakai BonDetailScreen untuk
//    preview, cetak thermal, PDF, PNG, copy, RawBT).
//  - BonDraftProvider reorder: moveItem/orderedItems/itemOrderIds/reset.
//
// Jalankan: flutter test test/item_order_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:rekapan_warung/models/models.dart';
import 'package:rekapan_warung/providers/providers.dart';
import 'package:rekapan_warung/providers/repositories.dart';

TransactionItem item(int id) => TransactionItem(
  id: id,
  transactionId: 1,
  productId: id,
  productName: 'Barang $id',
  quantity: 1,
  unit: 'pcs',
  unitPrice: 1000,
  subtotal: 1000,
);

Transaction txn(List<int> ids) => Transaction(
  id: 1,
  transactionNumber: 'BON-001',
  transactionDate: '2026-09-30',
  totalAmount: 1000 * ids.length,
  status: 'completed',
  paymentStatus: 'paid',
  items: ids.map(item).toList(),
);

void main() {
  group('Transaction.withItemOrder', () {
    test('order kosong => urutan server tidak berubah', () {
      final t = txn([10, 20, 30]);
      expect(t.withItemOrder(const []).items.map((e) => e.id).toList(), [
        10,
        20,
        30,
      ]);
      expect(txn([]).withItemOrder([30, 10]).items, isEmpty);
    });

    test('order lengkap => item diurut sesuai customOrder', () {
      final t = txn([10, 20, 30]);
      final o = t.withItemOrder([30, 10, 20]);
      expect(o.items.map((e) => e.id).toList(), [30, 10, 20]);
    });

    test('order sebagian => item tanpa urutan di akhir (urutan server)', () {
      final t = txn([10, 20, 30, 40]);
      final o = t.withItemOrder([30, 20]);
      expect(o.items.map((e) => e.id).toList(), [30, 20, 10, 40]);
    });

    test('id asing dibuang, tidak crash', () {
      final t = txn([10, 20]);
      final o = t.withItemOrder([999, 20, 10]);
      expect(o.items.map((e) => e.id).toList(), [20, 10]);
    });

    test('order berisi duplikat => item tetap muncul sekali', () {
      final t = txn([10, 20, 30]);
      final o = t.withItemOrder([20, 20, 10]);
      expect(o.items.map((e) => e.id).toList(), [20, 10, 30]);
    });

    test('field lain (total, status, nomor) tidak berubah', () {
      final t = txn([10, 20]);
      final o = t.withItemOrder([20, 10]);
      expect(o.totalAmount, t.totalAmount);
      expect(o.status, t.status);
      expect(o.paymentStatus, t.paymentStatus);
      expect(o.id, t.id);
      expect(o.transactionNumber, t.transactionNumber);
    });
  });

  group('BonDraftProvider reorder (tanpa jaringan)', () {
    BonDraftProvider makeProvider() => BonDraftProvider(TransactionRepository());

    test('moveItem mengurutkan orderedItems sesuai drag', () {
      final prov = makeProvider();
      prov.items = [item(10), item(20), item(30)];
      prov.setItemOrder([10, 20, 30]);
      expect(prov.itemOrderIds, [10, 20, 30]);
      expect(prov.orderedItems.map((e) => e.id).toList(), [10, 20, 30]);

      // Pindah item ketiga (id 30) ke paling depan.
      prov.moveItem(2, 0);
      expect(prov.itemOrderIds, [30, 10, 20]);
      expect(prov.orderedItems.map((e) => e.id).toList(), [30, 10, 20]);

      // Geser id 30 dari depan ke akhir (konvensi ReorderableListView:
      // newIndex dihitung setelah item asal dilepas).
      prov.moveItem(0, 3);
      expect(prov.orderedItems.map((e) => e.id).toList(), [10, 20, 30]);
    });

    test('orderedItems: id hilang dibuang, item baru di akhir', () {
      final prov = makeProvider();
      prov.items = [item(10), item(20), item(30)];
      prov.setItemOrder([30, 10, 20]);

      // Item id 10 dihapus → urutan manual tidak boleh crash / duplikat.
      prov.items = [item(20), item(30)];
      expect(prov.orderedItems.map((e) => e.id).toList(), [30, 20]);

      // Item baru (id 40) belum punya urutan manual → ditaruh di akhir.
      prov.items = [item(20), item(30), item(40)];
      expect(prov.orderedItems.map((e) => e.id).toList(), [30, 20, 40]);
    });

    test('reset membuang urutan manual', () {
      final prov = makeProvider();
      prov.items = [item(10), item(20)];
      prov.setItemOrder([20, 10]);
      expect(prov.itemOrderIds.length, 2);

      prov.reset();
      expect(prov.itemOrderIds, isEmpty);
      expect(prov.items, isEmpty);
    });

    test('clearItemOrder kembali ke urutan server', () {
      final prov = makeProvider();
      prov.items = [item(10), item(20)];
      prov.setItemOrder([20, 10]);
      prov.clearItemOrder();
      expect(prov.itemOrderIds, isEmpty);
      expect(prov.orderedItems.map((e) => e.id).toList(), [10, 20]);
    });
  });
}
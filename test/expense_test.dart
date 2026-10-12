// Tes parsing model Pengeluaran (padanan GET /api/expenses)
// dan pemisahan item bon (penambahan vs pengurangan).
//
// Data hard-code dari contoh respons `ExpenseController` — sengaja TIDAK
// menyentuh jaringan sesuai aturan test widget network-free.
import 'package:flutter_test/flutter_test.dart';

import 'package:rekapan_warung/models/models.dart';
import 'package:rekapan_warung/providers/repositories.dart';

void main() {
  group('Expense.fromJson', () {
    test('pengeluaran manual — amount DECIMAL datang sebagai String', () {
      final e = Expense.fromJson({
        'id': 3,
        'expense_date': '2026-10-12',
        'title': 'Beli ayam',
        'category': 'Dapur',
        'amount': '188000',
        'source': 'manual',
        'notes': 'utk masakan',
      });

      expect(e.id, 3);
      expect(e.expenseDate, '2026-10-12');
      expect(e.title, 'Beli ayam');
      expect(e.category, 'Dapur');
      expect(e.amount, 188000);
      expect(e.source, 'manual');
      expect(e.isFromBon, isFalse);
      expect(e.transactionId, isNull);
      expect(e.notes, 'utk masakan');
    });

    test('pengeluaran dari bon — membawa relasi transaction', () {
      final e = Expense.fromJson({
        'id': 7,
        'expense_date': '2026-10-12 00:00:00',
        'title': 'ayam',
        'category': null,
        'amount': '-9000',
        'source': 'bon',
        'transaction': {
          'id': 96,
          'transaction_number': 'INV-20261012-007',
        },
      });

      expect(e.isFromBon, isTrue);
      expect(e.amount, -9000);
      expect(e.transactionId, 96);
      expect(e.transactionNumber, 'INV-20261012-007');
      // expense_date datetime string → substring(0,10) di UI.
      expect(e.expenseDate, '2026-10-12');
    });

    test('respons kosong / null aman', () {
      final e = Expense.fromJson({});
      expect(e.id, 0);
      expect(e.expenseDate, '');
      expect(e.title, '');
      expect(e.amount, 0);
      expect(e.source, 'manual');
      expect(e.isFromBon, isFalse);
    });
  });

  group('ExpensePage.fromJson', () {
    test('membaca data paginated + summary', () {
      final p = ExpensePage.fromJson({
        'data': [
          {
            'id': 8,
            'expense_date': '2026-10-12',
            'title': 'ambil daun',
            'category': null,
            'amount': '50000',
            'source': 'bon',
          },
          {
            'id': 9,
            'expense_date': '2026-10-12',
            'title': 'Bensin',
            'category': 'Transport',
            'amount': '20000',
            'source': 'manual',
          },
        ],
        'current_page': 1,
        'last_page': 1,
        'total': 2,
        'summary': {
          'total_amount': '70000',
          'count': 2,
          'by_source': {'manual': '20000', 'bon': '50000'},
        },
      });

      expect(p.data.length, 2);
      expect(p.currentPage, 1);
      expect(p.lastPage, 1);
      expect(p.total, 2);
      expect(p.summary.totalAmount, 70000);
      expect(p.summary.count, 2);
      expect(p.summary.manualAmount, 20000);
      expect(p.summary.bonAmount, 50000);
    });

    test('respons kosong → halaman kosong, summary empty, tidak melempar', () {
      final p = ExpensePage.fromJson({});
      expect(p.data, isEmpty);
      expect(p.currentPage, 1);
      expect(p.lastPage, 1);
      expect(p.total, 0);
      expect(p.summary.totalAmount, 0);
      expect(p.summary.manualAmount, 0);
      expect(p.summary.bonAmount, 0);
    });
  });

  group('splitItems — pemisahan tambahan vs potongan', () {
    TransactionItem item(
      int id,
      String name,
      int subtotal, {
      int qty = 1,
      int unitPrice = 0,
    }) =>
        TransactionItem(
          id: id,
          productName: name,
          quantity: qty,
          unit: 'pcs',
          unitPrice: unitPrice == 0 ? subtotal : unitPrice,
          subtotal: subtotal,
        );

    test('item minus jadi deductions, sisanya adds', () {
      final split = splitItems([
        item(1, 'Nasi Uduk', 5000),
        item(2, 'Gorengan', -5000),
        item(3, 'Aqua', 7000),
      ]);

      expect(split.adds.map((i) => i.productName), ['Nasi Uduk', 'Aqua']);
      expect(split.deductions.single.productName, 'Gorengan');
      expect(split.totalBefore, 12000);
      expect(split.totalDeduct, 5000);
      expect(split.finalTotal, 7000);
      expect(split.hasDeductions, isTrue);
    });

    test('tanpa potongan → totalBefore = finalTotal', () {
      final split = splitItems([item(1, 'Aqua', 7000)]);
      expect(split.hasDeductions, isFalse);
      expect(split.totalBefore, 7000);
      expect(split.totalDeduct, 0);
      expect(split.finalTotal, 7000);
    });

    test('totalDeduct memakai nilai absolut subtotal', () {
      final split = splitItems([item(1, 'Potongan A', -9000)]);
      expect(split.totalDeduct, 9000);
      expect(split.finalTotal, -9000);
    });

    test('list kosong aman', () {
      final split = splitItems([]);
      expect(split.adds, isEmpty);
      expect(split.deductions, isEmpty);
      expect(split.totalBefore, 0);
      expect(split.totalDeduct, 0);
      expect(split.finalTotal, 0);
      expect(split.hasDeductions, isFalse);
    });
  });

  group('DashboardData field pengeluaran', () {
    test('default 0 — konstruktor lama tidak wajib isi pengeluaran', () {
      // DashboardData dibuat di DashboardRepository.index(); test ini menjaga
      // kompatibilitas mundur: kunci `pengeluaran_*` absen → default 0.
      const data = DashboardData(
        bonHariIni: 4,
        totalHariIni: 120000,
        lunasHariIni: 30000,
        lunasTotal: 30000,
        masihHutang: 90000,
        totalPelanggan: 40,
        recent: [],
      );

      expect(data.pengeluaranHariIni, 0);
      expect(data.pengeluaranTotal, 0);
      expect(data.bonHariIni, 4);
    });

    test('membaca pengeluaran dari stats (DECIMAL sebagai String)', () {
      // SUM() DECIMAL MySQL = string JSON → numFrom menanganinya.
      final stats = <String, dynamic>{
        'pengeluaran_hari_ini': '188000',
        'pengeluaran_total': '238000',
        'masih_hutang': '743000',
      };

      expect(numFrom(stats['pengeluaran_hari_ini']), 188000);
      expect(numFrom(stats['pengeluaran_total']), 238000);
      expect(numFrom(stats['masih_hutang']), 743000);
      expect(numFrom(stats['tidak_ada']), 0);
    });
  });
}
// Tes parsing model Laporan Rokok (padanan GET /api/reports/cigarettes
// dan GET /api/transactions/{id}/cigarettes).
//
// Semua data hard-code dari contoh respons `CigaretteReportService` —
// sengaja TIDAK menyentuh jaringan sesuai aturan test widget network-free.
import 'package:flutter_test/flutter_test.dart';

import 'package:rekapan_warung/models/models.dart';

void main() {
  group('CigaretteReport.fromJson', () {
    test('membaca summary, items, bon paginated, dan daftar produk', () {
      final r = CigaretteReport.fromJson({
        'summary': {
          // SUM() DECIMAL dari MySQL bisa datang sebagai String.
          'cigarette_quantity': 12,
          'cigarette_sales': '96000',
          'bon_count': 2,
          'paid_sales': '60000',
          'unpaid_sales': '36000',
        },
        'items': [
          {
            'product_name': 'Rokok Gudang Garam',
            'total_quantity': 8,
            'total_sales': '64000',
          },
          {
            'product_name': 'roket',
            'total_quantity': 4,
            'total_sales': '32000',
          },
        ],
        'transactions': {
          'data': [
            {
              'id': 80,
              'transaction_number': 'TRX-20261003-001',
              'transaction_date': '2026-10-03 00:00:00',
              'customer_name': 'Untung',
              'payment_status': 'unpaid',
              'cigarette_quantity': 4,
              'cigarette_total': '32000',
            },
          ],
          'total': 21,
          'per_page': 20,
          'current_page': 2,
          'last_page': 2,
        },
        'products': ['Rokok Gudang Garam', 'roket'],
      });

      expect(r.summary.cigaretteSales, 96000);
      expect(r.summary.paidSales, 60000);
      expect(r.summary.unpaidSales, 36000);
      expect(r.items.length, 2);
      expect(r.items.first.productName, 'Rokok Gudang Garam');
      expect(r.bons.single.customerName, 'Untung');
      // transaction_date datang sebagai datetime string — substring di UI.
      expect(r.bons.single.transactionDate, contains('2026-10-03'));
      expect(r.bonTotal, 21);
      expect(r.currentPage, 2);
      expect(r.lastPage, 2);
      expect(r.products, ['Rokok Gudang Garam', 'roket']);
    });

    test('respons kosong tidak melempar', () {
      final r = CigaretteReport.fromJson({});
      expect(r.summary.cigaretteSales, 0);
      expect(r.items, isEmpty);
      expect(r.bons, isEmpty);
      expect(r.lastPage, 1);
    });
  });

  group('BonCigaretteSummary.fromJson', () {
    test('memakai key quantity/subtotal/unit_price (bukan total_*)', () {
      final s = BonCigaretteSummary.fromJson({
        'items': [
          {
            'id': 5,
            'product_name': 'Rokok Surya',
            'quantity': 3,
            'unit': 'pack',
            'unit_price': '14000',
            'subtotal': '42000',
          },
        ],
        'total_quantity': 3,
        'total_amount': '42000',
      });
      expect(s.totalQuantity, 3);
      expect(s.totalAmount, 42000);
      expect(s.items.single.unitPrice, 14000);
      expect(s.items.single.totalSales, 42000);
      expect(s.items.single.totalQuantity, 3);
    });

    test('items kosong → nol aman', () {
      final s = BonCigaretteSummary.fromJson({});
      expect(s.items, isEmpty);
      expect(s.totalQuantity, 0);
    });
  });
}

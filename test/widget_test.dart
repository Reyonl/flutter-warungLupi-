// Smoke test tanpa network: widget test murni + unit test logika promo.
//
// CATATAN: jangan pump seluruh app (RekapanWarungApp) di sini — DashboardScreen
// memicu request network via dio, dan di lingkungan testWidgets (FakeAsync)
// request tersebut tidak pernah selesai sehingga timer Dio tetap pending.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rekapan_warung/core/theme/app_theme.dart';
import 'package:rekapan_warung/utils/promo.dart';
import 'package:rekapan_warung/widgets/widgets.dart';

void main() {
  group('AppFormField', () {
    testWidgets('renders label with required marker', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: AppFormField(
              label: 'Nama Item',
              required: true,
              child: const TextField(),
            ),
          ),
        ),
      );

      expect(find.text('Nama Item'), findsOneWidget);
      expect(find.text('*'), findsOneWidget);
    });
  });

  group('StatusBadge', () {
    testWidgets('renders Aktif for active customer', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: StatusBadge.active(isActive: true)),
        ),
      );

      expect(find.text('Aktif'), findsOneWidget);
    });

    testWidgets('renders Nonaktif for inactive customer', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: StatusBadge.active(isActive: false)),
        ),
      );

      expect(find.text('Nonaktif'), findsOneWidget);
    });
  });

  group('calculatePromoSubtotal', () {
    test('gorengan: tiap 3 pcs = Rp5.000, sisa × harga', () {
      // 5 pcs @2000 → promoQty 1 (5000) + sisa 2 (4000) = 9000
      expect(calculatePromoSubtotal('Gorengan Tahu', 5, 2000), 9000);
      // 3 pcs → 5000
      expect(calculatePromoSubtotal('Gorengan Pisang', 3, 2000), 5000);
      // 1 pcs → 2000
      expect(calculatePromoSubtotal('Gorengan', 1, 2000), 2000);
    });

    test('donat/nagasari/lemper/jajanan: tiap 2 pcs = Rp5.000', () {
      // 5 pcs @1500 → promoQty 2 (10000) + sisa 1 (1500) = 11500
      expect(calculatePromoSubtotal('Donat Coklat', 5, 1500), 11500);
      expect(calculatePromoSubtotal('nagasari', 4, 1500), 10000);
      expect(calculatePromoSubtotal('lemper ayam', 2, 1500), 5000);
      expect(calculatePromoSubtotal('Jajanan pasar', 1, 1500), 1500);
    });

    test('item lain: qty × harga', () {
      expect(calculatePromoSubtotal('Es Teh', 3, 5000), 15000);
    });
  });

  group('formatPriceDisplay', () {
    test('memformat angka ribuan id-ID', () {
      expect(formatPriceDisplay(1234567), '1.234.567');
      expect(formatPriceDisplay(-5000), '-5.000');
      expect(formatPriceDisplay(''), '');
    });
  });
}

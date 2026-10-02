// Smoke test tanpa network untuk dua field pencarian baru di form Bon:
// CustomerSearchField & ProductSearchField — pola sama (provider di-inject,
// data diisi langsung, tidak ada request HTTP karena load() tidak dipanggil).
//
// Plus unit test sanitizePriceInput (harga minus / POTONGAN) yang dipakai
// _handlePriceChange di bon_create_screen.dart.
//
// Jalankan: flutter test test/search_field_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:rekapan_warung/core/theme/app_theme.dart';
import 'package:rekapan_warung/models/models.dart';
import 'package:rekapan_warung/providers/providers.dart';
import 'package:rekapan_warung/providers/repositories.dart';
import 'package:rekapan_warung/utils/promo.dart';
import 'package:rekapan_warung/widgets/widgets.dart';

/// Provider berisi data jadi — `load()` tidak dipanggil sehingga tidak ada
/// network; repository hanya dipakai di dalam method yang tidak kita uji di sini.
CustomerProvider customerProviderWith(List<Customer> list) =>
    CustomerProvider(CustomerRepository())
      ..customers = list;

ProductProvider productProviderWith(List<Product> list) =>
    ProductProvider(ProductRepository())..products = list;

Widget wrap(Widget child, {CustomerProvider? cust, ProductProvider? prod}) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: MultiProvider(
        providers: [
          if (cust != null) ChangeNotifierProvider.value(value: cust),
          if (prod != null) ChangeNotifierProvider.value(value: prod),
        ],
        child: child,
      ),
    ),
  );
}

final List<Customer> _customers = [
  const Customer(id: 1, name: 'Budi', phone: '0812-3333', isActive: true),
  const Customer(id: 2, name: 'Siti', isActive: true),
  const Customer(id: 3, name: 'Mati', isActive: false), // nonaktif
];

final List<Product> _products = [
  const Product(
      id: 10, name: 'Donat Coklat', defaultPrice: 1500, unit: 'pcs', isActive: true),
  const Product(
      id: 11, name: 'Gorengan Tahu', defaultPrice: 2000, unit: 'pcs', isActive: true),
  const Product(
      id: 12, name: 'Es Teh Manis', defaultPrice: 3000, unit: 'gelas', isActive: true),
];

void main() {
  group('CustomerSearchField', () {
    testWidgets('menampilkan hint saat kosong', (tester) async {
      await tester.pumpWidget(wrap(
        CustomerSearchField(
          onSelected: (_) {},
        ),
        cust: customerProviderWith(_customers),
      ));

      expect(find.text('Cari pelanggan (ketik nama/hp)...'), findsOneWidget);
    });

    testWidgets('filter real-time berdasarkan nama (contains)', (tester) async {
      await tester.pumpWidget(wrap(
        CustomerSearchField(
          onSelected: (_) {},
        ),
        cust: customerProviderWith(_customers),
      ));

      await tester.enterText(find.byType(TextField), 'udi');
      await tester.pump();

      expect(find.text('Budi'), findsOneWidget); // cuma dia yang cocok
      expect(find.text('Siti'), findsNothing);
    });

    testWidgets('cocok lewat nomor HP juga', (tester) async {
      await tester.pumpWidget(wrap(
        CustomerSearchField(
          onSelected: (_) {},
        ),
        cust: customerProviderWith(_customers),
      ));

      await tester.enterText(find.byType(TextField), '3333');
      await tester.pump();

      expect(find.text('Budi'), findsOneWidget);
      expect(find.textContaining('0812-3333'), findsWidgets); // list tampil + phone
    });

    testWidgets('kecuali pelanggan terkunci, yang nonaktif disembunyikan',
        (tester) async {
      await tester.pumpWidget(wrap(
        CustomerSearchField(
          onSelected: (_) {},
        ),
        cust: customerProviderWith(_customers),
      ));

      await tester.tap(find.byType(TextField)); // buka dropdown tanpa query
      await tester.pump();

      expect(find.text('Budi'), findsOneWidget);
      expect(find.text('Siti'), findsOneWidget);
      expect(find.text('Mati'), findsNothing);
    });

    testWidgets('pelanggan terpilih (initialCustomerId) tetap tampil walau nonaktif',
        (tester) async {
      // Header terkunci mode edit: pelanggan nonaktif harus bisa ditampilkan
      // sebagai teks, seperti perilaku website.
      await tester.pumpWidget(wrap(
        CustomerSearchField(
          initialCustomerId: 3,
          initialCustomerName: 'Mati',
          onSelected: (_) {},
        ),
        cust: customerProviderWith(_customers),
      ));

      await tester.tap(find.byType(TextField));
      await tester.pump();

      expect(find.text('Mati'), findsWidgets); // input + list
    });

    testWidgets('tap hasil → onSelected(id) dan dropdown tertutup', (tester) async {
      int? selected;
      await tester.pumpWidget(wrap(
        CustomerSearchField(
          onSelected: (id) => selected = id,
        ),
        cust: customerProviderWith(_customers),
      ));

      await tester.enterText(find.byType(TextField), 'si');
      await tester.pump();
      await tester.tap(find.text('Siti'));
      // Future.delayed(200ms) penutup dropdown setelah unfocus harus tuntas.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(selected, 2);
      expect(find.text('Siti'), findsOneWidget); // hanya isi input, list hilang
    });

    testWidgets('tidak ada hasil → pesan kosong', (tester) async {
      await tester.pumpWidget(wrap(
        CustomerSearchField(
          onSelected: (_) {},
        ),
        cust: customerProviderWith(_customers),
      ));

      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pump();

      expect(find.text('Tidak ada pelanggan ditemukan'), findsOneWidget);
    });

    testWidgets('tombol clear → onSelected(null) + onClear', (tester) async {
      final calls = <int?>[];
      var cleared = 0;
      await tester.pumpWidget(wrap(
        CustomerSearchField(
          onSelected: (id) => calls.add(id),
          onClear: () => cleared++,
        ),
        cust: customerProviderWith(_customers),
      ));

      await tester.enterText(find.byType(TextField), 'Budi');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      expect(calls, [null]);
      expect(cleared, 1);
      expect(find.text('Budi'), findsNothing);
    });

    testWidgets('enabled: false → input terkunci (header tersimpan)', (tester) async {
      await tester.pumpWidget(wrap(
        CustomerSearchField(
          initialCustomerName: 'Budi',
          onSelected: (_) {},
          enabled: false,
        ),
        cust: customerProviderWith(_customers),
      ));

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.enabled, isFalse);
      // Tombol clear tidak boleh muncul saat terkunci.
      expect(find.byIcon(Icons.clear), findsNothing);
    });

    testWidgets('initialCustomerName berubah → teks ikut di-sync', (tester) async {
      final field = CustomerSearchField(
        initialCustomerName: 'Awal',
        onSelected: (_) {},
      );
      await tester.pumpWidget(wrap(field, cust: customerProviderWith(_customers)));
      expect(find.text('Awal'), findsOneWidget);

      await tester.pumpWidget(wrap(
        CustomerSearchField(
          initialCustomerName: 'Budi',
          onSelected: (_) {},
        ),
        cust: customerProviderWith(_customers),
      ));
      await tester.pump();

      expect(find.text('Budi'), findsOneWidget);
      expect(find.text('Awal'), findsNothing);
    });
  });

  group('ProductSearchField', () {
    testWidgets('menampilkan hint dan opsi input manual saat dibuka',
        (tester) async {
      await tester.pumpWidget(wrap(
        ProductSearchField(onSelected: (_) {}),
        prod: productProviderWith(_products),
      ));

      expect(find.text('Cari item...'), findsOneWidget);

      await tester.tap(find.byType(TextField));
      await tester.pump();

      expect(find.text('Input Manual / Item Lain'), findsOneWidget);
      expect(find.text('Donat Coklat'), findsOneWidget);
    });

    testWidgets('filter real-time + pilih item → onSelected(Product)', (tester) async {
      Product? picked;
      await tester.pumpWidget(wrap(
        ProductSearchField(onSelected: (p) => picked = p),
        prod: productProviderWith(_products),
      ));

      await tester.enterText(find.byType(TextField), 'donat');
      await tester.pump();

      expect(find.text('Gorengan Tahu'), findsNothing);
      await tester.tap(find.text('Donat Coklat'));
      await tester.pumpAndSettle();

      expect(picked?.id, 10);
      expect(picked?.defaultPrice, 1500);
      // Setelah dipilih, field kosong siap untuk item berikutnya.
      expect(find.text('Cari item...'), findsOneWidget);
    });

    testWidgets('opsi manual → onSelectManual', (tester) async {
      var manual = 0;
      await tester.pumpWidget(wrap(
        ProductSearchField(
          onSelected: (_) {},
          onSelectManual: () => manual++,
        ),
        prod: productProviderWith(_products),
      ));

      await tester.enterText(find.byType(TextField), 'xyz');
      await tester.pump();
      await tester.tap(find.text('Input Manual / Item Lain'));
      await tester.pumpAndSettle();

      expect(manual, 1);
      expect(find.text('Tidak ada item ditemukan'), findsNothing); // dropdown tutup
    });

    testWidgets('tidak ada hasil → pesan kosong', (tester) async {
      await tester.pumpWidget(wrap(
        ProductSearchField(onSelected: (_) {}),
        prod: productProviderWith(_products),
      ));

      await tester.enterText(find.byType(TextField), 'kviii');
      await tester.pump();

      expect(find.text('Tidak ada item ditemukan'), findsOneWidget);
    });

    testWidgets('hasil dibatasi maksimal 10', (tester) async {
      final many = List.generate(
        25,
        (i) => Product(
            id: i, name: 'Item $i', defaultPrice: 100, unit: 'pcs', isActive: true),
      );
      await tester.pumpWidget(wrap(
        ProductSearchField(onSelected: (_) {}),
        prod: productProviderWith(many),
      ));

      await tester.tap(find.byType(TextField));
      await tester.pump();

      // ListView.builder bersifat lazy: item di luar viewport (max 280px)
      // belum di-build, jadi cek jumlah child dari delegate-nya langsung:
      // 10 hasil (take(10)) + 1 opsi manual = 11.
      final sliver = tester.widget<SliverList>(find.byType(SliverList).first);
      final delegate = sliver.delegate as SliverChildBuilderDelegate;
      expect(delegate.childCount, 11);

      // Scroll ke dasar daftar: item terakhir yang boleh ada adalah Item 9,
      // Item 10 (ke-11) harus tidak pernah masuk list.
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(find.text('Item 9'), findsOneWidget);
      expect(find.text('Item 10'), findsNothing);
    });
  });

  group('sanitizePriceInput (harga minus / POTONGAN)', () {
    test('minus di awal dipertahankan', () {
      expect(sanitizePriceInput('-9000'), '-9000');
    });

    test('minus di tengah dibuang semua', () {
      expect(sanitizePriceInput('9-0-00'), '9000');
    });

    test('non-digit dibuang', () {
      expect(sanitizePriceInput('abc12x'), '12');
      expect(sanitizePriceInput('Rp. 5.000'), '5.000'.replaceAll('.', ''));
    });

    test('leading nol dihapus, minus dan nol tunggal utuh', () {
      expect(sanitizePriceInput('09000'), '9000');
      expect(sanitizePriceInput('-09000'), '-9000');
      expect(sanitizePriceInput('0'), '0');
      expect(sanitizePriceInput('-'), '-');
    });

    test('harga minus menghasilkan subtotal minus untuk item non-promo', () {
      expect(calculatePromoSubtotal('Potongan', 1, -5000), -5000);
      expect(calculatePromoSubtotal('', 2, -1000), -2000);
    });
  });
}

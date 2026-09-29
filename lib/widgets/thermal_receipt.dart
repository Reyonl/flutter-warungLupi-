import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/theme/app_theme.dart';
import '../models/models.dart';
import '../utils/format.dart';

/// Nilai QRIS dari struk — hardcoded SAMA PERSIS dengan TransactionDetail.jsx (Laravel).
abstract final class ThermalReceiptData {
  static const qrisValue =
      '00020101021126610014COM.GO-JEK.WWW01189360091431908993800210G1908993800303UMI51440014ID.CO.QRIS.WWW0215ID10253695702010303UMI5204549953033605802ID5923WARUNG LUPI, Pagedangan6009TANGERANG61051533062070703A0163044C4B';
}

/// ThermalReceipt — widget preview struk thermal.
/// Meniru komponen `ThermalReceipt` di TransactionDetail.jsx:
/// header WARUNG LUPI + tagline, No/Tgl/Plg, item (wrap, tebal), TOTAL,
/// catatan, QRIS, footer. Font Courier, warna hitam di atas putih.
class ThermalReceipt extends StatelessWidget {
  final Transaction transaction;
  final String size; // '58mm' | '80mm'
  final bool preview; // true = preview layar (300/400px), false = versi print

  const ThermalReceipt({
    super.key,
    required this.transaction,
    this.size = '58mm',
    this.preview = true,
  });

  double get _width => size == '58mm' ? 300 : 400;

  @override
  Widget build(BuildContext context) {
    final items = transaction.items;
    final dateStr = formatDateShort(transaction.transactionDate);
    final font = 'Courier';

    const divider = Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Divider(color: Colors.black, height: 1),
    );

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(fontFamily: font, fontSize: 13, color: Colors.black)),
              Text(value, style: TextStyle(fontFamily: font, fontSize: 13, color: Colors.black)),
            ],
          ),
        );

    return Container(
      width: preview ? _width : null,
      padding: const EdgeInsets.all(24),
      decoration: preview
          ? BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(color: Color(0x10000000), blurRadius: 4, offset: Offset(0, 2)),
              ],
            )
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Text(
            'WARUNG LUPI',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: font,
              fontSize: preview ? 20 : 17,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              color: Colors.black,
            ),
          ),
          Text(
            'Ke pasar membeli semangka',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: font, fontSize: preview ? 13 : 11, color: Colors.black),
          ),
          Text(
            'Jangan lupa mampir ke Lupi',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: font, fontSize: preview ? 13 : 11, color: Colors.black),
          ),
          divider,
          // Info
          row('No.', transaction.transactionNumber),
          row('Tanggal', dateStr),
          row('Pelanggan', transaction.customer?.name ?? 'Umum'),
          divider,
          // Items
          ...items.map((item) {
            final name = (item.description != null && item.description!.isNotEmpty)
                ? '${item.productName} - ${item.description}'
                : item.productName;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontFamily: font,
                      fontSize: preview ? 14 : 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${item.quantity} x ${formatNumber(item.unitPrice)}',
                        style: TextStyle(fontFamily: font, fontSize: preview ? 14 : 12, color: Colors.black),
                      ),
                      Text(
                        formatNumber(item.subtotal),
                        style: TextStyle(fontFamily: font, fontSize: preview ? 14 : 12, color: Colors.black),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          divider,
          // Total
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TOTAL',
                  style: TextStyle(
                    fontFamily: font,
                    fontSize: preview ? 18 : 15,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
                Text(
                  formatNumber(transaction.totalAmount),
                  style: TextStyle(
                    fontFamily: font,
                    fontSize: preview ? 18 : 15,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          if (transaction.notes != null && transaction.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Catatan: ${transaction.notes}',
              style: TextStyle(fontFamily: font, fontSize: preview ? 13 : 11, color: Colors.black),
            ),
          ],
          // QR & footer
          const SizedBox(height: 20),
          Center(
            child: QrImageView(
              data: ThermalReceiptData.qrisValue,
              size: preview ? 140 : 100,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Terima kasih sudah belanja',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: font,
              fontSize: preview ? 13 : 11,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          Text(
            'Semoga puas di hati',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: font, fontSize: preview ? 13 : 11, color: Colors.black),
          ),
        ],
      ),
    );
  }
}
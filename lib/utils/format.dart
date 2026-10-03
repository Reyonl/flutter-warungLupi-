/// Padanan dari `resources/js/utils/format.js` (Rekapan Warung).
///
/// Mempertahankan format persis aplikasi Laravel:
/// - Rupiah: `Rp1.234.567` (pemisah ribuan titik, gaya id-ID)
/// - Angka: `1.234.567`
/// - Tanggal: `23 Sep 2026` (dd Mon yyyy)
/// - Tanggal pendek: `23/09/2026`
library;

const List<String> _monthShort = [
  '',
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

/// formatRupiah(value) -> 'Rp1.234'
String formatRupiah(num? value) {
  if (value == null || value.isNaN) return 'Rp0';
  return 'Rp${formatNumber(value)}';
}

/// formatNumber(value) -> '1.234' (pemisah ribuan id-ID)
String formatNumber(num? value) {
  if (value == null || value.isNaN) return '0';
  final s = value.toString();
  final negative = s.startsWith('-');
  final unsigned = negative ? s.substring(1) : s;
  final parts = unsigned.split('.');
  final digits = parts[0];
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
    buf.write(digits[i]);
  }
  var result = (negative ? '-' : '') + buf.toString();
  if (parts.length > 1) {
    result += ',${parts[1]}';
  }
  return result;
}

/// parseRupiah('1.234') -> 1234. Sama dengan JS: buang semua non-digit.
int parseRupiah(String? str) {
  if (str == null || str.isEmpty) return 0;
  final cleaned = str.replaceAll(RegExp(r'[^0-9]'), '');
  return int.tryParse(cleaned) ?? 0;
}

/// Memotong bagian tanggal dari string date/ISO, abaikan zona waktu.
/// Backend mengirim `transaction_date` sebagai DATE `yyyy-MM-dd`.
DateTime? _parseOnlyDate(String dateStr) {
  if (dateStr.isEmpty) return null;
  final d = dateStr.substring(0, 10).split('-');
  if (d.length != 3) return null;
  final y = int.tryParse(d[0]);
  final m = int.tryParse(d[1]);
  final day = int.tryParse(d[2]);
  if (y == null || m == null || day == null) return null;
  return DateTime(y, m, day);
}

/// formatDate('2026-09-23') -> '23 Sep 2026'
String formatDate(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return '';
  final d = _parseOnlyDate(dateStr);
  if (d == null) return '';
  return '${d.day.toString().padLeft(2, '0')} ${_monthShort[d.month]} ${d.year}';
}

/// formatDateShort('2026-09-23') -> '23/09/2026'
String formatDateShort(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return '';
  final d = _parseOnlyDate(dateStr);
  if (d == null) return '';
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  return '$dd/$mm/${d.year}';
}

/// toInputDate -> 'yyyy-MM-dd' (untuk date picker / payload API)
String toInputDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// today() -> 'yyyy-MM-dd' (tanggal lokal, bukan UTC — beda dari JS yang iso)
String today() => toInputDate(DateTime.now());

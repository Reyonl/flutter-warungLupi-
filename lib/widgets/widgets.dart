import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

export 'customer_search_field.dart';
export 'product_search_field.dart';

/// Debouncer sederhana untuk pencarian (meniru `setTimeout(fetch, 350)`).
class Debouncer {
  final Duration delay;
  final VoidCallback? onDone;
  Debouncer(int ms, this.onDone) : delay = Duration(milliseconds: ms);
  Timer? _timer;

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, () {
      action();
      onDone?.call();
    });
  }

  void dispose() => _timer?.cancel();
}

/// Status badge — padanan komponen StatusBadge React (Tailwind).
/// Gaya: pill `inline-flex items-center px-2 py-0.5 rounded text-xs font-medium border`.
class StatusBadge extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final Color border;

  const StatusBadge({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    required this.border,
  });

  /// Badge "Aktif"/"Nonaktif" untuk pelanggan.
  factory StatusBadge.active({required bool isActive}) {
    return isActive
        ? const StatusBadge(
            label: 'Aktif',
            background: AppColors.successBg,
            foreground: AppColors.successText,
            border: AppColors.successBorder,
          )
        : const StatusBadge(
            label: 'Nonaktif',
            background: AppColors.gray100,
            foreground: AppColors.gray600,
            border: AppColors.gray200,
          );
  }

  /// Badge status bon — padanan `StatusBadge` v2 (Card.jsx):
  /// completed → "Selesai" (chipBg/text-muted), draft → "Draft" (chipBg).
  factory StatusBadge.bonStatus(String status) {
    return status == 'completed'
        ? const StatusBadge(
            label: 'Selesai',
            background: AppColors.chipBg,
            foreground: AppColors.textMuted,
            border: AppColors.chipBg,
          )
        : const StatusBadge(
            label: 'Draft',
            background: AppColors.chipBg,
            foreground: AppColors.textMuted,
            border: AppColors.chipBg,
          );
  }

  /// Badge pembayaran — padanan v2: paid → "Lunas" (success-soft/success),
  /// unpaid → "Hutang" (warning-soft/warning — amber, bukan merah).
  factory StatusBadge.payment(String paymentStatus) {
    return paymentStatus == 'paid'
        ? const StatusBadge(
            label: 'Lunas',
            background: AppColors.successBg,
            foreground: AppColors.successText,
            border: AppColors.successBg,
          )
        : const StatusBadge(
            label: 'Hutang',
            background: AppColors.warningBg,
            foreground: AppColors.warningText,
            border: AppColors.warningBg,
          );
  }

  /// Badge produk: Aktif (gray-100/gray-800) / Nonaktif (gray-50/gray-500).
  factory StatusBadge.product(bool active) {
    return active
        ? const StatusBadge(
            label: 'Aktif',
            background: AppColors.gray100,
            foreground: AppColors.gray800,
            border: AppColors.gray200,
          )
        : const StatusBadge(
            label: 'Nonaktif',
            background: AppColors.background,
            foreground: AppColors.gray500,
            border: AppColors.gray200,
          );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Kotak pesan sukses/error inline (padanan `<div class="bg-red-50 border...">`).
class InlineMessage extends StatelessWidget {
  final String message;
  final bool isError;

  const InlineMessage(this.message, {super.key, this.isError = true});

  @override
  Widget build(BuildContext context) {
    final bg = isError ? AppColors.dangerBg : AppColors.successBg;
    final fg = isError ? AppColors.dangerText : AppColors.successText;
    final bd = isError ? AppColors.dangerBorder : AppColors.successBorder;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: bd),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(message, style: TextStyle(color: fg, fontSize: 14)),
    );
  }
}

/// Empty state — padanan v2 `EmptyState` (States.jsx): teks sentral tanpa
/// border/kotak — hierarchy murni tipografi.
class EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.title,
    this.subtitle = '',
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textMain,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    );
  }
}

/// Loading state sentral.
class LoadingState extends StatelessWidget {
  final String text;
  const LoadingState({super.key, this.text = 'Memuat...'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              text,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tombol kecil abu-abu (padanan Tailwind `bg-gray-900 text-white ...`).
class DarkButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final double? height;

  const DarkButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.gray900,
          disabledBackgroundColor: AppColors.gray900.withValues(alpha: 0.5),
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        ),
        child: loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16),
                    const SizedBox(width: 6),
                  ],
                  Text(label),
                ],
              ),
      ),
    );
  }
}

/// Tombol kecil outline (padanan `border border-gray-300 bg-white text-gray-700`).
class OutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Color? foreground;

  const OutlineButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: loading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: foreground ?? AppColors.gray600,
        side: const BorderSide(color: AppColors.borderStrong),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      child: loading
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.textMuted,
              ),
            )
          : Text(label),
    );
  }
}

/// Tombol utama brand (padanan `bg-brand-600 text-white`).
class BrandButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool expand;
  final IconData? icon;

  const BrandButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.expand = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final btn = FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.brand600,
        disabledBackgroundColor: AppColors.brand600.withValues(alpha: 0.5),
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      ),
      child: loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16),
                  const SizedBox(width: 6),
                ],
                Text(label),
              ],
            ),
    );
    return expand ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

/// Dialog konfirmasi hapus — padanan ConfirmDialog React merah.
Future<bool?> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Hapus',
  bool destructive = true,
}) {
  Color confirmColor = destructive ? AppColors.dangerText : AppColors.brand600;
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(
        title,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
      content: Text(
        message,
        style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          style: TextButton.styleFrom(foregroundColor: AppColors.gray600),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: confirmColor,
            foregroundColor: Colors.white,
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}

/// Toast sederhana — padanan toast React (muncul, hilang otomatis).
void showToast(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.dangerText : AppColors.gray900,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
}

/// Header halaman — padanan v2 `PageHeader` (Card.jsx): tanpa ikon,
/// hierarchy murni tipografi (title bold tracking-tight, subtitle kecil).
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;

  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: AppColors.textMain,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actions != null) ...actions!,
        ],
      ),
    );
  }
}

/// Field input dengan label (padanan komponen Field React).
/// Dinamai `AppFormField` agar tidak bentrok dengan `FormField` bawaan Flutter.
class AppFormField extends StatelessWidget {
  final String label;
  final bool required;
  final String? error;
  final Widget child;

  const AppFormField({
    super.key,
    required this.label,
    this.required = false,
    this.error,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMain,
                ),
              ),
              if (required) ...[
                const SizedBox(width: 4),
                const Text('*', style: TextStyle(color: AppColors.dangerText)),
              ],
            ],
          ),
        ),
        child,
        if (error != null && error!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            error!,
            style: const TextStyle(fontSize: 12, color: AppColors.dangerText),
          ),
        ],
      ],
    );
  }
}

/// Input teks rupiah — meniru `handlePriceChange` di CreateTransaction.jsx:
/// hanya digit (dan minus di depan), auto format ribu dengan titik.
class RupiahInputField extends StatefulWidget {
  final String? initialValue;
  final ValueChanged<int> onChanged;
  final TextEditingController? controller;
  final bool autofocus;

  const RupiahInputField({
    super.key,
    this.initialValue,
    required this.onChanged,
    this.controller,
    this.autofocus = false,
  });

  @override
  State<RupiahInputField> createState() => _RupiahInputFieldState();
}

class _RupiahInputFieldState extends State<RupiahInputField> {
  late final TextEditingController _controller =
      widget.controller ??
      TextEditingController(text: widget.initialValue ?? '');
  late final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.controller == null &&
        (widget.initialValue?.isNotEmpty ?? false)) {
      _controller.value = TextEditingValue(
        text: formatDisplay(widget.initialValue!),
        selection: TextSelection.collapsed(offset: widget.initialValue!.length),
      );
    }
    _focus.addListener(() {
      if (_focus.hasFocus && _controller.text.isEmpty) {
        // fokus → tampilkan kosong untuk input
      }
    });
  }

  static String formatDisplay(String raw) {
    if (raw.isEmpty || raw == '-') return raw;
    final negative = raw.startsWith('-');
    final numStr = negative ? raw.substring(1) : raw;
    final cleaned = numStr.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.isEmpty) return negative ? '-' : '';
    final buf = StringBuffer();
    for (var i = 0; i < cleaned.length; i++) {
      if (i > 0 && (cleaned.length - i) % 3 == 0) buf.write('.');
      buf.write(cleaned[i]);
    }
    return (negative ? '-' : '') + buf.toString();
  }

  void _onChange(String value) {
    // sanitasi: hanya digit, minus hanya di posisi awal
    var raw = value.replaceAll(RegExp(r'[^0-9-]'), '');
    if (raw.lastIndexOf('-') > 0) {
      raw = raw.replaceAll('-', '');
    }
    if (raw != '0' && raw != '-' && raw != '-0') {
      raw = raw.replaceFirstMapped(
        RegExp(r'^(-?)0+(?=\d)'),
        (m) => m.group(1)!,
      );
    }
    final parsed = int.tryParse(raw.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final negative = raw.startsWith('-');

    // atur ulang teks agar terformat
    final formatted = formatDisplay(raw);
    if (formatted != value) {
      _controller.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
    widget.onChanged(negative ? -parsed : parsed);
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focus,
      autofocus: widget.autofocus,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.right,
      onChanged: _onChange,
      decoration: const InputDecoration(hintText: '0'),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../utils/format.dart';
import '../../widgets/widgets.dart';
import '../bon/bon_detail_screen.dart';

/// Laporan Rokok — meniru `pages/CigaretteReport.jsx`.
/// Preset tanggal, rentang date, filter item, cari bon/pelanggan,
/// summary compact, penjualan per item, dan bon paginated.
class CigaretteReportScreen extends StatefulWidget {
  /// `true` saat dirender sebagai body di Scaffold milik [HomeShell].
  final bool embedded;

  const CigaretteReportScreen({super.key, this.embedded = false});

  @override
  State<CigaretteReportScreen> createState() => _CigaretteReportScreenState();
}

/// Preset periode — padanan PRESETS di web.
class _Preset {
  final String label;
  final DateTime Function() from;
  final DateTime Function() to;
  const _Preset(this.label, this.from, this.to);
}

List<_Preset> _presets() {
  final now = DateTime.now();
  DateTime shift(int days) => now.add(Duration(days: days));
  return [
    _Preset('Hari ini', () => now, () => now),
    _Preset('Kemarin', () => shift(-1), () => shift(-1)),
    _Preset('7 hari', () => shift(-6), () => now),
    _Preset('30 hari', () => shift(-29), () => now),
  ];
}

class _CigaretteReportScreenState extends State<CigaretteReportScreen> {
  final _searchDebounce = Debouncer(350, () {});
  late final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final p = context.read<CigaretteReportProvider>();
      if (!p.hasData) p.load();
    });
  }

  @override
  void dispose() {
    _searchDebounce.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final p = context.read<CigaretteReportProvider>();
    final current = isFrom ? p.dateFrom : p.dateTo;
    final initial = DateTime.tryParse(current) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    if (isFrom) {
      p.setDateRange(toInputDate(picked), p.dateTo);
    } else {
      p.setDateRange(p.dateFrom, toInputDate(picked));
    }
  }

  void _applyPreset(_Preset preset) {
    context.read<CigaretteReportProvider>().setDateRange(
      toInputDate(preset.from()),
      toInputDate(preset.to()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<CigaretteReportProvider>();
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: PageHeader(
            title: 'Laporan Rokok',
            subtitle: 'Penjualan item berkategori atau bernama rokok — hanya bon selesai (hutang tetap dihitung).',
          ),
        ),
        _FilterBar(
          presets: _presets(),
          activeFrom: prov.dateFrom,
          activeTo: prov.dateTo,
          product: prov.product,
          productOptions: prov.report?.products ?? const [],
          searchController: _searchCtrl,
          onPreset: _applyPreset,
          onPickFrom: () => _pickDate(isFrom: true),
          onPickTo: () => _pickDate(isFrom: false),
          onProduct: prov.setProduct,
          onSearch: (v) => _searchDebounce.run(() => prov.setSearch(v)),
        ),
        Expanded(child: _ReportBody(prov: prov)),
      ],
    );

    if (widget.embedded) return body;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Laporan Rokok')),
      body: SafeArea(child: body),
    );
  }
}

/// Baris filter: preset chip + tanggal + produk + pencarian.
class _FilterBar extends StatelessWidget {
  final List<_Preset> presets;
  final String activeFrom;
  final String activeTo;
  final String product;
  final List<String> productOptions;
  final TextEditingController searchController;
  final ValueChanged<_Preset> onPreset;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final ValueChanged<String> onProduct;
  final ValueChanged<String> onSearch;

  const _FilterBar({
    required this.presets,
    required this.activeFrom,
    required this.activeTo,
    required this.product,
    required this.productOptions,
    required this.searchController,
    required this.onPreset,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onProduct,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    final activeLabel = presets
        .where(
          (p) =>
              toInputDate(p.from()) == activeFrom &&
              toInputDate(p.to()) == activeTo,
        )
        .map((p) => p.label)
        .firstOrNull;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final p in presets)
                InkWell(
                  onTap: () => onPreset(p),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: activeLabel == p.label
                          ? AppColors.brand100
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: activeLabel == p.label
                            ? AppColors.brand300
                            : AppColors.border,
                      ),
                    ),
                    child: Text(
                      p.label,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: activeLabel == p.label
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: activeLabel == p.label
                            ? AppColors.brand800
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _DateButton(
                  label: formatDate(activeFrom),
                  onTap: onPickFrom,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('—', style: TextStyle(color: AppColors.textMuted)),
              ),
              Expanded(
                child: _DateButton(
                  label: formatDate(activeTo),
                  onTap: onPickTo,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: productOptions.contains(product) ? product : '',
                  isExpanded: true,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textMain,
                  ),
                  dropdownColor: AppColors.surface,
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Semua Rokok'),
                    ),
                    for (final name in productOptions)
                      DropdownMenuItem(value: name, child: Text(name)),
                  ],
                  onChanged: (v) => onProduct(v ?? ''),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: searchController,
                    style: const TextStyle(fontSize: 13.5),
                    onChanged: onSearch,
                    decoration: const InputDecoration(
                      hintText: 'Cari bon / pelanggan...',
                      prefixIcon: Icon(Icons.search, size: 18),
                      prefixIconConstraints: BoxConstraints(
                        minWidth: 36,
                        minHeight: 0,
                      ),
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _DateButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.borderStrong),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 14,
              color: AppColors.textMuted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: AppColors.textMain),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Isi laporan: skeleton/error → summary + breakdown.
class _ReportBody extends StatelessWidget {
  final CigaretteReportProvider prov;
  const _ReportBody({required this.prov});

  @override
  Widget build(BuildContext context) {
    if (prov.loading && !prov.hasData) {
      return const LoadingState(text: 'Memuat laporan rokok...');
    }
    if (prov.error != null && !prov.hasData) {
      return EmptyState(
        title: 'Laporan gagal dimuat.',
        subtitle: prov.error ?? 'Data gagal dimuat. Coba muat ulang.',
        action: OutlineButton(
          label: 'Muat ulang',
          onPressed: () => prov.load(),
        ),
      );
    }
    final report = prov.report;
    if (report == null) return const SizedBox.shrink();
    final s = report.summary;

    return RefreshIndicator(
      color: AppColors.brand600,
      onRefresh: () => prov.load(page: report.currentPage),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _CompactSummary(summary: s),
          if (s.cigaretteSales == 0 && !prov.loading)
            const EmptyState(
              title: 'Tidak ada penjualan rokok pada periode ini.',
              subtitle: 'Coba ganti rentang tanggal, atau cek lagi setelah ada bon rokok yang diselesaikan.',
            )
          else ...[
            const SizedBox(height: 20),
            const _SectionLabel('Penjualan per item'),
            const SizedBox(height: 4),
            _HeaderRow(),
            ...report.items.map(_ItemRowTile.new),
            _TotalRow(quantity: s.cigaretteQuantity, total: s.cigaretteSales),
            const SizedBox(height: 24),
            const _SectionLabel('Bon dengan penjualan rokok'),
            const SizedBox(height: 8),
            ...report.bons.map((b) => _BonTile(bon: b)),
            if (report.lastPage > 1) _Pager(prov: prov, report: report),
          ],
          if (prov.loading)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Memuat ulang laporan...',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
            ),
        ],
      ),
    );
  }
}

/// Ringkasan compact — satu angka besar, sisanya kecil (padanan web v2).
class _CompactSummary extends StatelessWidget {
  final CigaretteSummary summary;
  const _CompactSummary({required this.summary});

  @override
  Widget build(BuildContext context) {
    const tnum = TextStyle(fontFeatures: [FontFeature.tabularFigures()]);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                formatRupiah(summary.cigaretteSales),
                style: tnum.copyWith(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: AppColors.textMain,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                summary.cigaretteSales == 0
                    ? 'penjualan'
                    : 'penjualan · ${summary.cigaretteQuantity} batang · ${summary.bonCount} bon',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          if (summary.cigaretteSales > 0) ...[
            if (summary.paidSales > 0)
              Text(
                'Lunas ${formatRupiah(summary.paidSales)}',
                style: tnum.copyWith(
                  fontSize: 13,
                  color: AppColors.successText,
                ),
              ),
            if (summary.unpaidSales > 0)
              Text(
                'Hutang ${formatRupiah(summary.unpaidSales)}',
                style: tnum.copyWith(
                  fontSize: 13,
                  color: AppColors.warningText,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: AppColors.textMuted,
    ),
  );
}

class _HeaderRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              'Item',
              style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              'Qty',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
            ),
          ),
          SizedBox(
            width: 96,
            child: Text(
              'Total',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemRowTile extends StatelessWidget {
  final CigaretteItemRow row;
  const _ItemRowTile(this.row);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              row.productName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                color: AppColors.textMain,
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              '${row.totalQuantity}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          SizedBox(
            width: 96,
            child: Text(
              formatRupiah(row.totalSales),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textMain,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final int quantity;
  final int total;
  const _TotalRow({required this.quantity, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Expanded(
            child: Text(
              'Total',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textMain,
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              '$quantity',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textMain,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          SizedBox(
            width: 96,
            child: Text(
              formatRupiah(total),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textMain,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Satu baris bon — tappable ke detail (padanan Link /bon/:id).
class _BonTile extends StatelessWidget {
  final CigaretteBonRow bon;
  const _BonTile({required this.bon});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Nav.push(BonDetailScreen(transactionId: bon.id)),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bon.transactionNumber,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brand700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${bon.customerName ?? '—'} · ${formatDateShort(bon.transactionDate)} · ${bon.cigaretteQuantity} batang',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatRupiah(bon.cigaretteTotal),
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMain,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 3),
                StatusBadge.payment(bon.paymentStatus),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Pager "Bon x–y dari z" + ← → (padanan web).
class _Pager extends StatelessWidget {
  final CigaretteReportProvider prov;
  final CigaretteReport report;
  const _Pager({required this.prov, required this.report});

  @override
  Widget build(BuildContext context) {
    const perPage = 20;
    final from = report.bonTotal > 0
        ? (report.currentPage - 1) * perPage + 1
        : 0;
    final to = report.currentPage * perPage;
    final clamped = to > report.bonTotal ? report.bonTotal : to;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Bon $from–$clamped dari ${report.bonTotal}',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          Row(
            children: [
              OutlineButton(
                label: '←',
                onPressed: report.currentPage > 1 ? prov.prevPage : null,
              ),
              const SizedBox(width: 8),
              OutlineButton(
                label: '→',
                onPressed: report.currentPage < report.lastPage
                    ? prov.nextPage
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

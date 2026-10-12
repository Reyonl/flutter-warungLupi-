import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/navigation.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../utils/format.dart';
import '../../widgets/widgets.dart';
import '../bon/bon_detail_screen.dart';

/// Pengeluaran — meniru `pages/expenses/ExpenseList.jsx`.
///
/// Daftar pengeluaran (manual + turunan bon) dengan filter tanggal/sumber,
/// pencarian, ringkasan total, catat/edit manual via form, dan hapus manual.
/// Pengeluaran `source=bon` TIDAK bisa diedit/dihapus manual — hanya lewat
/// ubah/hapus item minus pada bon terkait (backend menolak 422).
class ExpenseListScreen extends StatefulWidget {
  /// `true` saat dirender sebagai body di Scaffold milik [HomeShell].
  final bool embedded;

  const ExpenseListScreen({super.key, this.embedded = false});

  @override
  State<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends State<ExpenseListScreen> {
  final _searchDebounce = Debouncer(350, () {});
  final _searchCtrl = TextEditingController();

  // Form manual (tambah/edit)
  Expense? _editing;
  final _dateCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String? _formError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final p = context.read<ExpenseProvider>();
        if (!p.hasData) p.load();
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce.dispose();
    _searchCtrl.dispose();
    _dateCtrl.dispose();
    _titleCtrl.dispose();
    _categoryCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _openAdd() {
    setState(() {
      _editing = null;
      _dateCtrl.text = today();
      _titleCtrl.clear();
      _categoryCtrl.clear();
      _amountCtrl.clear();
      _notesCtrl.clear();
      _formError = null;
    });
    _showForm();
  }

  void _openEdit(Expense e) {
    if (e.isFromBon) return; // hanya manual yang bisa diedit
    setState(() {
      _editing = e;
      _dateCtrl.text = e.expenseDate.isEmpty ? today() : e.expenseDate;
      _titleCtrl.text = e.title;
      _categoryCtrl.text = e.category ?? '';
      _amountCtrl.text = e.amount.toString();
      _notesCtrl.text = e.notes ?? '';
      _formError = null;
    });
    _showForm();
  }

  Future<void> _showForm() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => _ExpenseFormSheet(
          isEditing: _editing != null,
          dateCtrl: _dateCtrl,
          titleCtrl: _titleCtrl,
          categoryCtrl: _categoryCtrl,
          amountCtrl: _amountCtrl,
          notesCtrl: _notesCtrl,
          error: _formError,
          saving: _saving,
          onPickDate: () async {
            final picked = await showDatePicker(
              context: ctx,
              initialDate: DateTime.tryParse(_dateCtrl.text) ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              setState(() => _dateCtrl.text = toInputDate(picked));
              setSheetState(() {});
            }
          },
          onSubmit: () async {
            setSheetState(() {});
            await _submit();
            setSheetState(() {});
            if (mounted && _formError == null && ctx.mounted) {
              Navigator.of(ctx).pop();
            }
          },
          onCancel: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final p = context.read<ExpenseProvider>();
    final title = _titleCtrl.text.trim();
    final amount = int.tryParse(_amountCtrl.text.replaceAll('.', '')) ?? 0;
    if (title.isEmpty || _dateCtrl.text.isEmpty || amount <= 0) {
      setState(
        () =>
            _formError = 'Judul, tanggal, dan nominal (minimal 1) wajib diisi.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _formError = null;
    });
    final err = await p.save(
      id: _editing?.id,
      expenseDate: _dateCtrl.text,
      title: title,
      category: _categoryCtrl.text.trim().isEmpty
          ? null
          : _categoryCtrl.text.trim(),
      amount: amount,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (err == null) {
      showToast(
        context,
        _editing == null ? 'Pengeluaran dicatat.' : 'Pengeluaran diperbarui.',
      );
    } else {
      setState(() => _formError = err);
    }
  }

  Future<void> _confirmDelete(Expense e) async {
    final confirm = await showConfirmDialog(
      context,
      title: 'Hapus pengeluaran ini?',
      message: '"${e.title}" akan dihapus permanen.',
      confirmLabel: 'Ya, Hapus',
    );
    if (confirm != true || !mounted) return;
    final p = context.read<ExpenseProvider>();
    final err = await p.delete(e);
    if (!mounted) return;
    if (err == null) {
      showToast(context, 'Pengeluaran dihapus.');
    } else {
      showToast(context, err, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ExpenseProvider>();
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: PageHeader(
            title: 'Pengeluaran',
            subtitle: 'Catat pengeluaran manual; potongan pada bon masuk otomatis sebagai pengeluaran.',
            actions: [
              BrandButton(
                label: 'Catat Pengeluaran',
                icon: Icons.add,
                onPressed: _openAdd,
              ),
            ],
          ),
        ),
        _FilterBar(
          prov: prov,
          searchController: _searchCtrl,
          onPreset: prov.setDateRange,
          onPickFrom: () => prov.pickDate(context, isFrom: true),
          onPickTo: () => prov.pickDate(context, isFrom: false),
          onSource: prov.setSource,
          onSearch: (v) => _searchDebounce.run(() => prov.setSearch(v)),
        ),
        Expanded(
          child: _ExpenseBody(
            prov: prov,
            onEdit: _openEdit,
            onDelete: _confirmDelete,
            onAdd: _openAdd,
          ),
        ),
      ],
    );

    if (widget.embedded) return body;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Pengeluaran')),
      body: SafeArea(child: body),
    );
  }
}

/// Baris filter: preset tanggal + rentang + sumber + pencarian.
class _FilterBar extends StatelessWidget {
  final ExpenseProvider prov;
  final TextEditingController searchController;
  final void Function(String from, String to) onPreset;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final ValueChanged<String> onSource;
  final ValueChanged<String> onSearch;

  const _FilterBar({
    required this.prov,
    required this.searchController,
    required this.onPreset,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onSource,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final presets = <(String, DateTime, DateTime)>[
      ('Hari ini', now, now),
      (
        'Kemarin',
        now.subtract(const Duration(days: 1)),
        now.subtract(const Duration(days: 1)),
      ),
      ('7 hari', now.subtract(const Duration(days: 6)), now),
      ('30 hari', now.subtract(const Duration(days: 29)), now),
    ];

    String? activeLabel;
    for (final (label, from, to) in presets) {
      if (toInputDate(from) == prov.dateFrom &&
          toInputDate(to) == prov.dateTo) {
        activeLabel = label;
        break;
      }
    }
    final hasFilter =
        prov.dateFrom.isNotEmpty ||
        prov.dateTo.isNotEmpty ||
        prov.source.isNotEmpty ||
        prov.search.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (label, from, to) in presets)
                InkWell(
                  onTap: () => onPreset(toInputDate(from), toInputDate(to)),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: activeLabel == label
                          ? AppColors.brand100
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: activeLabel == label
                            ? AppColors.brand300
                            : AppColors.border,
                      ),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: activeLabel == label
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: activeLabel == label
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
                  label: prov.dateFrom.isEmpty
                      ? 'Dari'
                      : formatDate(prov.dateFrom),
                  onTap: onPickFrom,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('—', style: TextStyle(color: AppColors.textMuted)),
              ),
              Expanded(
                child: _DateButton(
                  label: prov.dateTo.isEmpty
                      ? 'Sampai'
                      : formatDate(prov.dateTo),
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
                  initialValue: prov.source,
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
                  items: const [
                    DropdownMenuItem(value: '', child: Text('Semua Sumber')),
                    DropdownMenuItem(value: 'manual', child: Text('Manual')),
                    DropdownMenuItem(value: 'bon', child: Text('Dari Bon')),
                  ],
                  onChanged: (v) => onSource(v ?? ''),
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
                      hintText: 'Cari pengeluaran...',
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
          if (hasFilter) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                onTap: prov.resetFilter,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    'Bersihkan',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          ],
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

/// Isi daftar: skeleton/error → summary + list.
class _ExpenseBody extends StatelessWidget {
  final ExpenseProvider prov;
  final ValueChanged<Expense> onEdit;
  final ValueChanged<Expense> onDelete;
  final VoidCallback onAdd;

  const _ExpenseBody({
    required this.prov,
    required this.onEdit,
    required this.onDelete,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    if (prov.loading && !prov.hasData) {
      return const LoadingState(text: 'Memuat pengeluaran...');
    }
    if (prov.error != null && !prov.hasData) {
      return EmptyState(
        title: 'Pengeluaran gagal dimuat.',
        subtitle: prov.error ?? 'Data gagal dimuat. Coba muat ulang.',
        action: OutlineButton(
          label: 'Muat ulang',
          onPressed: () => prov.load(),
        ),
      );
    }
    final page = prov.page;
    if (page == null) return const SizedBox.shrink();

    final hasFilter =
        prov.dateFrom.isNotEmpty ||
        prov.dateTo.isNotEmpty ||
        prov.source.isNotEmpty ||
        prov.search.isNotEmpty;

    return RefreshIndicator(
      color: AppColors.brand600,
      onRefresh: () => prov.load(page: page.currentPage),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _SummaryHeader(summary: page.summary),
          const SizedBox(height: 16),
          if (page.data.isEmpty)
            EmptyState(
              title: hasFilter
                  ? 'Tidak ada pengeluaran yang cocok.'
                  : 'Belum ada pengeluaran.',
              subtitle: hasFilter
                  ? 'Coba ubah rentang tanggal atau kata kuncinya.'
                  : 'Catat pengeluaran manual, atau potongan (harga minus) pada bon akan masuk otomatis ke sini.',
              action: hasFilter
                  ? OutlineButton(
                      label: 'Bersihkan filter',
                      onPressed: prov.resetFilter,
                    )
                  : BrandButton(
                      label: 'Catat Pengeluaran',
                      icon: Icons.add,
                      onPressed: onAdd,
                    ),
            )
          else ...[
            ...page.data.map(
              (e) => _ExpenseTile(e: e, onEdit: onEdit, onDelete: onDelete),
            ),
            if (page.lastPage > 1) ...[
              const SizedBox(height: 12),
              _Pager(
                currentPage: page.currentPage,
                lastPage: page.lastPage,
                total: page.total,
                onPrev: page.currentPage > 1
                    ? () => prov.load(page: page.currentPage - 1)
                    : null,
                onNext: page.currentPage < page.lastPage
                    ? () => prov.load(page: page.currentPage + 1)
                    : null,
              ),
            ],
          ],
          if (prov.loading)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Memuat ulang pengeluaran...',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
            ),
        ],
      ),
    );
  }
}

/// Ringkasan pengeluaran — angka besar total + breakdown manual/bon.
class _SummaryHeader extends StatelessWidget {
  final ExpenseSummary summary;

  const _SummaryHeader({required this.summary});

  @override
  Widget build(BuildContext context) {
    const tnum = TextStyle(fontFeatures: [FontFeature.tabularFigures()]);
    return Container(
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
                formatRupiah(summary.totalAmount),
                style: tnum.copyWith(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: AppColors.textMain,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                summary.count > 0
                    ? 'total pengeluaran · ${summary.count} catatan'
                    : 'total pengeluaran',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          if (summary.manualAmount > 0)
            Text(
              'Manual ${formatRupiah(summary.manualAmount)}',
              style: tnum.copyWith(fontSize: 13, color: AppColors.textMuted),
            ),
          if (summary.bonAmount > 0)
            Text(
              'Dari Bon ${formatRupiah(summary.bonAmount)}',
              style: tnum.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.warningText,
              ),
            ),
        ],
      ),
    );
  }
}

/// Satu baris pengeluaran — badge sumber, nominal, aksi (manual saja).
class _ExpenseTile extends StatelessWidget {
  final Expense e;
  final ValueChanged<Expense> onEdit;
  final ValueChanged<Expense> onDelete;

  const _ExpenseTile({
    required this.e,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: e.isFromBon && e.transactionId != null
          ? () => Nav.push(BonDetailScreen(transactionId: e.transactionId!))
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      formatDateShort(e.expenseDate),
                      if (e.category != null && e.category!.isNotEmpty)
                        e.category!,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                  if (e.notes != null && e.notes!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      e.notes!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  if (e.isFromBon)
                    StatusBadge(
                      label: e.transactionNumber != null
                          ? 'Dari Bon ${e.transactionNumber}'
                          : 'Dari Bon',
                      background: AppColors.warningBg,
                      foreground: AppColors.warningText,
                      border: AppColors.warningBg,
                    )
                  else
                    const StatusBadge(
                      label: 'Manual',
                      background: AppColors.chipBg,
                      foreground: AppColors.textMuted,
                      border: AppColors.chipBg,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '-${formatRupiah(e.amount)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dangerText,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                if (!e.isFromBon) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () => onEdit(e),
                        child: const Text(
                          'Edit',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.gray600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: () => onDelete(e),
                        child: const Text(
                          'Hapus',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.gray600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Pager \"Hal. x/y (n catatan)\" + ← → (padanan web).
class _Pager extends StatelessWidget {
  final int currentPage;
  final int lastPage;
  final int total;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _Pager({
    required this.currentPage,
    required this.lastPage,
    required this.total,
    this.onPrev,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Hal. $currentPage / $lastPage ($total catatan)',
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textMuted,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        Row(
          children: [
            OutlineButton(label: '←', onPressed: onPrev),
            const SizedBox(width: 8),
            OutlineButton(label: '→', onPressed: onNext),
          ],
        ),
      ],
    );
  }
}

/// Modal form catat/edit pengeluaran manual.
class _ExpenseFormSheet extends StatelessWidget {
  final TextEditingController dateCtrl;
  final TextEditingController titleCtrl;
  final TextEditingController categoryCtrl;
  final TextEditingController amountCtrl;
  final TextEditingController notesCtrl;
  final String? error;
  final bool saving;
  final VoidCallback onPickDate;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;
  final bool isEditing;

  const _ExpenseFormSheet({
    required this.dateCtrl,
    required this.titleCtrl,
    required this.categoryCtrl,
    required this.amountCtrl,
    required this.notesCtrl,
    required this.error,
    required this.saving,
    required this.onPickDate,
    required this.onSubmit,
    required this.onCancel,
    required this.isEditing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isEditing ? 'Edit Pengeluaran' : 'Catat Pengeluaran',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textMain,
              ),
            ),
            const SizedBox(height: 16),
            if (error != null && error!.isNotEmpty) ...[
              InlineMessage(error!),
              const SizedBox(height: 8),
            ],
            AppFormField(
              label: 'Tanggal',
              required: true,
              child: InkWell(
                onTap: onPickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.borderStrong),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Text(
                        formatDate(dateCtrl.text),
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textMain,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.calendar_today,
                        size: 15,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            AppFormField(
              label: 'Keterangan',
              required: true,
              child: TextField(
                controller: titleCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Contoh: beli beras, ganti gas, ongkos',
                ),
              ),
            ),
            const SizedBox(height: 14),
            AppFormField(
              label: 'Kategori',
              child: TextField(
                controller: categoryCtrl,
                decoration: const InputDecoration(hintText: 'Contoh: Belanja'),
              ),
            ),
            const SizedBox(height: 14),
            AppFormField(
              label: 'Nominal',
              required: true,
              child: TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.right,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                ],
                decoration: const InputDecoration(hintText: 'Contoh: 50000'),
              ),
            ),
            const SizedBox(height: 14),
            AppFormField(
              label: 'Catatan',
              child: TextField(
                controller: notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Contoh: buat modal jualan besok',
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlineButton(label: 'Batal', onPressed: onCancel),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: BrandButton(
                    label: isEditing ? 'Simpan Perubahan' : 'Simpan',
                    loading: saving,
                    onPressed: onSubmit,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

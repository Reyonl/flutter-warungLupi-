import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../utils/format.dart';
import '../../widgets/widgets.dart';
import 'bon_create_screen.dart';
import 'bon_detail_screen.dart';

/// Riwayat Bon — meniru `pages/transactions/TransactionList.jsx`.
/// Search, filter tanggal, pagination, status badge, aksi Lihat/Edit/Hapus.
class BonListScreen extends StatefulWidget {
  /// `true` saat dirender sebagai body di dalam Scaffold milik [HomeShell]
  /// (via drawer). `false` (default) → layar membungkus dirinya sendiri
  /// dengan Scaffold + AppBar, sehingga aman di-push langsung lewat
  /// Navigator (mis. tombol "Lihat semua" di Dashboard) tanpa menjadi
  /// layar hitam/blank.
  final bool embedded;

  const BonListScreen({super.key, this.embedded = false});

  @override
  State<BonListScreen> createState() => _BonListScreenState();
}

class _BonListScreenState extends State<BonListScreen> {
  final _searchDebounce = Debouncer(400, () {});
  late final TextEditingController _searchCtrl = TextEditingController();
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<TransactionListProvider>().load();
    });
  }

  @override
  void dispose() {
    _searchDebounce.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom ? _dateFrom : _dateTo;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _dateFrom = picked;
      } else {
        _dateTo = picked;
      }
    });
    context.read<TransactionListProvider>().setDateRange(
      _dateFrom == null ? null : toInputDate(_dateFrom!),
      _dateTo == null ? null : toInputDate(_dateTo!),
    );
  }

  void _clearDateFilter() {
    setState(() {
      _dateFrom = null;
      _dateTo = null;
    });
    context.read<TransactionListProvider>().setDateRange(null, null);
  }

  Future<void> _confirmDelete(Transaction t) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Hapus Bon',
      message: 'Hapus bon ini? Semua catatan di dalamnya akan ikut terhapus.',
      confirmLabel: 'Hapus',
    );
    if (ok == true && mounted) {
      final err = await context.read<TransactionListProvider>().delete(t.id);
      if (err != null && mounted) showToast(context, err, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent(context);
    // Dipakai sebagai body di dalam Scaffold HomeShell → jangan bungkus lagi.
    if (widget.embedded) return content;
    // Di-push langsung (mis. Dashboard → "Lihat semua"): tanpa Scaffold,
    // halaman ini mewarisi kanvas Activity yang gelap/hitam sehingga teks
    // tampak hilang. Bungkus dengan Material + Scaffold bertema terang.
    return Material(
      color: AppColors.background,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Riwayat Bon')),
        body: SafeArea(child: content),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final prov = context.watch<TransactionListProvider>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: PageHeader(
            title: 'Riwayat Bon',
            actions: [
              BrandButton(
                label: 'Buat Bon',
                icon: Icons.add,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BonCreateScreen()),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              TextField(
                controller: _searchCtrl,
                onChanged: (v) {
                  _searchDebounce.run(() {
                    context.read<TransactionListProvider>().setSearch(v);
                  });
                },
                decoration: const InputDecoration(
                  hintText: 'Pelanggan / nomor bon',
                  prefixIcon: Icon(Icons.search, size: 20),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _DateFilterChip(
                      label: _dateFrom == null
                          ? 'Dari Tanggal'
                          : toInputDate(_dateFrom!),
                      onTap: () => _pickDate(isFrom: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DateFilterChip(
                      label: _dateTo == null
                          ? 'Sampai Tanggal'
                          : toInputDate(_dateTo!),
                      onTap: () => _pickDate(isFrom: false),
                    ),
                  ),
                  if (_dateFrom != null || _dateTo != null)
                    IconButton(
                      onPressed: _clearDateFilter,
                      icon: const Icon(
                        Icons.clear,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(child: _buildBody(prov)),
      ],
    );
  }

  Widget _buildBody(TransactionListProvider prov) {
    if (prov.loading && prov.transactions.isEmpty) {
      return const LoadingState();
    }
    if (prov.error != null && prov.transactions.isEmpty) {
      return InlineMessage(prov.error!);
    }
    if (prov.transactions.isEmpty) {
      // Empty state (mirror React)
      final hasFilter =
          prov.search.isNotEmpty ||
          prov.dateFrom != null ||
          prov.dateTo != null;
      return RefreshIndicator(
        onRefresh: () => prov.load(),
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: EmptyState(
                title: 'Belum ada bon',
                subtitle: hasFilter
                    ? 'Coba ubah filter pencarian.'
                    : 'Mulai dengan membuat bon baru.',
                action: hasFilter
                    ? null
                    : BrandButton(
                        label: 'Buat Bon Pertama',
                        icon: Icons.add,
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const BonCreateScreen(),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => prov.load(page: prov.currentPage),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: prov.transactions.length + 1,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, idx) {
          if (idx == prov.transactions.length) {
            // Pagination footer
            if (prov.lastPage <= 1) return const SizedBox(height: 12);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Hal ${prov.currentPage} / ${prov.lastPage}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: prov.currentPage > 1 ? prov.prevPage : null,
                    child: const Text('Prev'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: prov.currentPage < prov.lastPage
                        ? prov.nextPage
                        : null,
                    child: const Text('Next'),
                  ),
                ],
              ),
            );
          }
          final t = prov.transactions[idx];
          return _BonTile(
            transaction: t,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BonDetailScreen(transactionId: t.id),
              ),
            ),
            onEdit: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BonCreateScreen(editTransactionId: t.id),
              ),
            ),
            onDelete: () => _confirmDelete(t),
          );
        },
      ),
    );
  }
}

class _DateFilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _DateFilterChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.borderStrong),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.gray600),
            ),
            const Icon(
              Icons.calendar_today,
              size: 14,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _BonTile extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BonTile({
    required this.transaction,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.customer?.name ?? 'Tanpa Nama',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMain,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        transaction.transactionNumber,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatRupiah(transaction.totalAmount),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMain,
                      ),
                    ),
                    const SizedBox(height: 2),
                    StatusBadge.bonStatus(transaction.status),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              formatDate(transaction.transactionDate),
              style: const TextStyle(fontSize: 13, color: AppColors.gray600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _ActionLink(label: 'Lihat', onTap: onTap),
                const Text(
                  ' | ',
                  style: TextStyle(color: AppColors.gray300, fontSize: 12),
                ),
                _ActionLink(label: 'Edit', onTap: onEdit),
                const Text(
                  ' | ',
                  style: TextStyle(color: AppColors.gray300, fontSize: 12),
                ),
                _ActionLink(label: 'Hapus', onTap: onDelete, danger: true),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool danger;

  const _ActionLink({
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: danger ? AppColors.gray600 : AppColors.gray600,
        ),
      ),
    );
  }
}

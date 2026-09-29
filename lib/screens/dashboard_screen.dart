import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../providers/repositories.dart';
import '../utils/format.dart';
import '../widgets/widgets.dart';
import 'bon/bon_create_screen.dart';
import 'bon/bon_detail_screen.dart';
import 'bon/bon_list_screen.dart';

/// Dashboard — meniru `pages/Dashboard.jsx`.
/// Header "Dashboard", tombol "+ Buat Bon", 4 kartu statistik, tabel bon terbaru.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<DashboardProvider>().load();
    });
  }

  void _openBuatBon() {
    // Navigasi ke Buat Bon lewat HomeShell (set state page).
    // Layar di-render dalam shell; gunakan callback sederhana via Navigator pop
    // tidak cocok — shell menggunakan index. Kita navigate ulang dengan push
    // dedicated screen yang punya AppBar sendiri (navigasi standar mobile).
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const BonCreateScreen()));
  }

  void _openDetail(int id) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BonDetailScreen(transactionId: id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dash = context.watch<DashboardProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(
            'Dashboard',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textMain,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Selamat datang kembali di sistem operasional Warung Lupi.',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),

          // Primary action
          BrandButton(
            label: '+ Buat Bon',
            icon: Icons.add,
            onPressed: _openBuatBon,
          ),
          const SizedBox(height: 28),

          if (dash.loading && dash.data == null)
            const LoadingState(text: 'Memuat dashboard...')
          else if (dash.error != null && dash.data == null)
            InlineMessage(dash.error!)
          else if (dash.data != null) ...[
            _StatsGrid(data: dash.data!),
            const SizedBox(height: 24),
            _RecentBon(recent: dash.data!.recent, onTap: _openDetail),
          ] else
            const SizedBox(),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final DashboardData data;
  const _StatsGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 480;
        final cols = isWide ? 4 : 2;
        final items = [
          _StatCard(
            label: 'Bon Hari Ini',
            value: '${data.bonHariIni}',
            color: AppColors.textMain,
          ),
          _StatCard(
            label: 'Total Hari Ini',
            value: formatRupiah(data.totalHariIni),
            color: AppColors.textMain,
          ),
          _StatCard(
            label: 'Sudah Lunas',
            value: formatRupiah(data.lunasTotal),
            color: AppColors.successText,
            borderColor: AppColors.successBorder,
          ),
          _StatCard(
            label: 'Masih Hutang',
            value: formatRupiah(data.masihHutang),
            color: AppColors.dangerText,
            borderColor: AppColors.dangerBorder,
          ),
        ];
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.6,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: items,
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color? borderColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: borderColor ?? AppColors.border),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: AppColors.gray500,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentBon extends StatelessWidget {
  final List<TransactionSummary> recent;
  final ValueChanged<int> onTap;

  const _RecentBon({required this.recent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Bon Terbaru',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textMain,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BonListScreen()),
              ),
              style: TextButton.styleFrom(foregroundColor: AppColors.brand600),
              child: const Text(
                'Lihat semua →',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (recent.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Belum ada bon hari ini.',
              style: TextStyle(fontSize: 14, color: AppColors.textMuted),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.gray100,
                    border: Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: const Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Pelanggan',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.gray600,
                          ),
                        ),
                      ),
                      Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.gray600,
                        ),
                      ),
                    ],
                  ),
                ),
                ...recent.map(
                  (t) => InkWell(
                    onTap: () => onTap(t.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: AppColors.border),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.customerName ?? 'Tanpa Nama',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textMain,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  t.transactionDate,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                formatRupiah(t.totalAmount),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMain,
                                ),
                              ),
                              const SizedBox(height: 2),
                              StatusBadge.payment(t.paymentStatus ?? 'unpaid'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

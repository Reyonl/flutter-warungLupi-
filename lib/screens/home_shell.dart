import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'bon/bon_create_screen.dart';
import 'bon/bon_list_screen.dart';
import 'customers/customer_list_screen.dart';
import 'dashboard_screen.dart';
import 'products/category_list_screen.dart';
import 'products/cigarette_report_screen.dart';
import 'products/product_list_screen.dart';
import 'settings/settings_screen.dart';

/// HomeShell — shell utama aplikasi.
/// Meniru `Layout.jsx` v2: nav flat (tanpa tombol aksen oranye), brand
/// chip "WL" + "Warung Lupi" (Lupi sky-blue), entri **Laporan Rokok**,
/// dan footer "Sistem rekap warung".
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

enum ShellPage {
  dashboard,
  bonCreate,
  bonList,
  customers,
  items,
  categories,
  cigaretteReport,
  settings,
}

class _HomeShellState extends State<HomeShell> {
  ShellPage _page = ShellPage.dashboard;

  static const _titles = {
    ShellPage.dashboard: 'Ringkasan',
    ShellPage.bonCreate: 'Buat Bon',
    ShellPage.bonList: 'Riwayat Bon',
    ShellPage.customers: 'Pelanggan',
    ShellPage.items: 'Daftar Item',
    ShellPage.categories: 'Kategori',
    ShellPage.cigaretteReport: 'Laporan Rokok',
    ShellPage.settings: 'Pengaturan',
  };

  void _go(ShellPage page) {
    setState(() => _page = page);
    Navigator.of(context).pop(); // tutup drawer bila terbuka
  }

  /// Chip "WL" — padanan Brand() di Layout.jsx (bg-ink, rounded-lg).
  static Widget brandMark({double size = 28, double fontSize = 13}) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'WL',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  static const brandText = Text.rich(
    TextSpan(
      text: 'Warung ',
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: AppColors.textMain,
      ),
      children: [
        TextSpan(
          text: 'Lupi',
          style: TextStyle(color: AppColors.brand600),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Row(
          children: [
            brandMark(size: 24, fontSize: 11),
            const SizedBox(width: 8),
            Flexible(
              child: Text(_titles[_page]!, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
      drawer: _buildDrawer(context),
      body: _buildPage(),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    Widget item(ShellPage page, String label, IconData icon) {
      final active = _page == page;
      return ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        leading: Icon(
          icon,
          size: 19,
          color: active ? AppColors.brand600 : AppColors.textMuted,
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            color: active ? AppColors.brand700 : AppColors.textMuted,
          ),
        ),
        selected: active,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onTap: () => _go(page),
      );
    }

    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Row(
                children: [brandMark(), const SizedBox(width: 10), brandText],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  item(
                    ShellPage.dashboard,
                    'Ringkasan',
                    Icons.dashboard_outlined,
                  ),
                  item(ShellPage.bonCreate, 'Buat Bon', Icons.add_box_outlined),
                  item(
                    ShellPage.bonList,
                    'Riwayat Bon',
                    Icons.receipt_long_outlined,
                  ),
                  item(ShellPage.customers, 'Pelanggan', Icons.people_outline),
                  item(ShellPage.items, 'Item', Icons.inventory_2_outlined),
                  item(
                    ShellPage.categories,
                    'Kategori',
                    Icons.category_outlined,
                  ),
                  item(
                    ShellPage.cigaretteReport,
                    'Laporan Rokok',
                    Icons.bar_chart_outlined,
                  ),
                  item(ShellPage.settings, 'Pengaturan', Icons.tune_outlined),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(height: 1),
                  SizedBox(height: 12),
                  Text(
                    'Sistem rekap warung',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage() {
    switch (_page) {
      case ShellPage.dashboard:
        return const DashboardScreen();
      case ShellPage.bonCreate:
        return const BonCreateScreen();
      case ShellPage.bonList:
        return const BonListScreen(embedded: true);
      case ShellPage.customers:
        return const CustomerListScreen();
      case ShellPage.items:
        return const ProductListScreen();
      case ShellPage.categories:
        return const CategoryListScreen();
      case ShellPage.cigaretteReport:
        return const CigaretteReportScreen(embedded: true);
      case ShellPage.settings:
        return const SettingsScreen();
    }
  }
}

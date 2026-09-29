import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'bon/bon_create_screen.dart';
import 'bon/bon_list_screen.dart';
import 'customers/customer_list_screen.dart';
import 'dashboard_screen.dart';
import 'products/category_list_screen.dart';
import 'products/product_list_screen.dart';
import 'settings/settings_screen.dart';

/// HomeShell — shell utama aplikasi.
/// Meniru `Layout.jsx`: sidebar kiri (desktop) / drawer (mobile) dengan
/// brand "Warung Lupi", grup menu **Bon** & **Data**, dan Pengaturan.
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
  settings,
}

class _HomeShellState extends State<HomeShell> {
  ShellPage _page = ShellPage.dashboard;

  static const _titles = {
    ShellPage.dashboard: 'Dashboard',
    ShellPage.bonCreate: 'Buat Bon',
    ShellPage.bonList: 'Riwayat Bon',
    ShellPage.customers: 'Pelanggan',
    ShellPage.items: 'Daftar Item',
    ShellPage.categories: 'Kategori',
    ShellPage.settings: 'Pengaturan',
  };

  void _go(ShellPage page) {
    setState(() => _page = page);
    Navigator.of(context).pop(); // tutup drawer bila terbuka
  }

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
        title: Text(_titles[_page]!),
      ),
      drawer: _buildDrawer(context),
      body: _buildPage(),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    Widget item(
      ShellPage page,
      String label,
      IconData icon, {
      bool accent = false,
    }) {
      final active = _page == page;
      return ListTile(
        leading: Icon(
          icon,
          color: accent || active
              ? (accent ? Colors.white : AppColors.brand600)
              : AppColors.textMuted,
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: accent
                ? Colors.white
                : (active ? AppColors.textMain : AppColors.textMuted),
          ),
        ),
        tileColor: accent
            ? AppColors.brand600
            : (active ? AppColors.gray100 : null),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        onTap: () => _go(page),
      );
    }

    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 28, 20, 20),
              child: Text(
                'Warung Lupi',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMain,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: [
                  item(
                    ShellPage.dashboard,
                    'Dashboard',
                    Icons.dashboard_outlined,
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(12, 20, 12, 8),
                    child: Text(
                      'BON',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: AppColors.gray500,
                      ),
                    ),
                  ),
                  item(
                    ShellPage.bonCreate,
                    'Buat Bon',
                    Icons.add_box_outlined,
                    accent: true,
                  ),
                  item(
                    ShellPage.bonList,
                    'Riwayat Bon',
                    Icons.receipt_long_outlined,
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(12, 20, 12, 8),
                    child: Text(
                      'DATA',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: AppColors.gray500,
                      ),
                    ),
                  ),
                  item(ShellPage.customers, 'Pelanggan', Icons.people_outline),
                  item(ShellPage.items, 'Item', Icons.inventory_2_outlined),
                  item(
                    ShellPage.categories,
                    'Kategori',
                    Icons.category_outlined,
                  ),
                  const SizedBox(height: 24),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  item(
                    ShellPage.settings,
                    'Pengaturan',
                    Icons.settings_outlined,
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
      case ShellPage.settings:
        return const SettingsScreen();
    }
  }
}

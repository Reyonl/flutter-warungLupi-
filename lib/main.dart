import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api/api_client.dart';
import 'core/navigation.dart';
import 'core/storage/prefs.dart';
import 'core/theme/app_theme.dart';
import 'providers/providers.dart';
import 'providers/repositories.dart';
import 'screens/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Terapkan alamat server yang disimpan pengguna (bila ada) SEBELUM widget
  // pertama dibangun, supaya semua request memakai server yang benar.
  // Di produksi tidak ada override → langsung memakai
  // https://warunglupi.tplp004.com (lihat ApiConfig.productionBaseUrl).
  final savedBaseUrl = await Prefs.getApiBaseUrl();
  if (savedBaseUrl.isNotEmpty) {
    ApiConfig.runtimeOverride = savedBaseUrl;
    ApiClient.instance.setBaseUrl(savedBaseUrl);
  }

  runApp(const RekapanWarungApp());
}

class RekapanWarungApp extends StatelessWidget {
  const RekapanWarungApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => DashboardProvider(DashboardRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => CustomerProvider(CustomerRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => CategoryProvider(CategoryRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => ProductProvider(ProductRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => TransactionListProvider(TransactionRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => CigaretteReportProvider(CigaretteReportRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => BonDraftProvider(TransactionRepository()),
        ),
      ],
      child: MaterialApp(
        navigatorKey: Nav.navigatorKey,
        title: 'Warung Lupi',
        debugShowCheckedModeBanner: false,
        // Aplikasi ini dirancang light-only (lihat AppColors). Kunci ke
        // ThemeMode.light supaya dark mode sistem tidak pernah membuat
        // Scaffold gelap + teks gelap (halaman tampak hitam/blank).
        theme: AppTheme.light(),
        themeMode: ThemeMode.light,
        home: const HomeShell(),
      ),
    );
  }
}

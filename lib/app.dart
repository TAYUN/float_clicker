import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/clicker/clicker_guide_page.dart';
import 'features/clicker/clicker_page.dart';
import 'features/home/home_page.dart';

class FloatClickerApp extends StatelessWidget {
  const FloatClickerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Float Clicker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      initialRoute: HomePage.routeName,
      routes: {
        HomePage.routeName: (_) => const HomePage(),
        ClickerPage.routeName: (_) => const ClickerPage(),
        ClickerGuidePage.routeName: (_) => const ClickerGuidePage(),
      },
    );
  }
}

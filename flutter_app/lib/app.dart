import 'package:flutter/material.dart';

import 'config/app_config.dart';
import 'features/shell/presentation/app_shell_page.dart';

class NurioApp extends StatelessWidget {
  const NurioApp({super.key, required this.config});

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0F3D3E),
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: config.appTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: AppShellPage(config: config),
    );
  }
}

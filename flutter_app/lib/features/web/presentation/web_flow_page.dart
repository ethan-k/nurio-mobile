import 'package:flutter/material.dart';

import '../../../config/app_config.dart';
import '../../../ui/nurio_shell_page.dart';

class WebFlowPage extends StatelessWidget {
  const WebFlowPage({
    super.key,
    required this.config,
    required this.initialUri,
  });

  final AppConfig config;
  final Uri initialUri;

  @override
  Widget build(BuildContext context) {
    return NurioShellPage(
      config: config,
      initialUri: initialUri,
      showBottomNavigation: false,
    );
  }
}

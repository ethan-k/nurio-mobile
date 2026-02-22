import 'package:flutter/widgets.dart';

import 'app.dart';
import 'config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(NurioApp(config: AppConfig.fromEnvironment()));
}

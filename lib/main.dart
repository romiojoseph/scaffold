import 'dart:io';
import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:window_manager/window_manager.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

import 'services/icon_mapping_service.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await IconMappingConfig.load();

  if (Platform.isWindows) {
    await windowManager.ensureInitialized();

    doWhenWindowReady(() async {
      final initialSize = const Size(1280, 720);
      appWindow.minSize = const Size(1024, 600);
      appWindow.size = initialSize;
      appWindow.alignment = Alignment.center;
      appWindow.show();
    });
  }

  runApp(ScaffoldApp(initialArgs: args));
}

class ScaffoldApp extends StatelessWidget {
  final List<String> initialArgs;
  const ScaffoldApp({super.key, this.initialArgs = const []});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scaffold',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: HomeScreen(initialArgs: initialArgs),
    );
  }
}

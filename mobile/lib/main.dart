import 'package:flutter/material.dart';

import 'app_shell.dart';
import 'background_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeBackgroundService();
  runApp(const KhsaeTeiApp());
}

class KhsaeTeiApp extends StatelessWidget {
  const KhsaeTeiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KHSAE TEI',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber)),
      home: const AppShell(),
    );
  }
}

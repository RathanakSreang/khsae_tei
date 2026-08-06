import 'package:flutter/material.dart';

import 'pairing_screen.dart';

void main() {
  runApp(const KhsaeTeiApp());
}

class KhsaeTeiApp extends StatelessWidget {
  const KhsaeTeiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KHSAE TEI',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber)),
      home: const PairingScreen(),
    );
  }
}

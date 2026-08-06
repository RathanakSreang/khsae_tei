import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import 'background_service.dart';
import 'ws_client.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _running = false;
  bool _busy = false;
  ConnectionStatus _status = ConnectionStatus.disconnected;
  StreamSubscription<Map<String, dynamic>?>? _statusSub;

  @override
  void initState() {
    super.initState();
    // The background-service platform channel isn't available outside a
    // real Android/iOS run (e.g. plain widget tests) - degrade to "not
    // running" rather than crashing the screen.
    try {
      _statusSub = FlutterBackgroundService().on('statusUpdate').listen((event) {
        final name = event?['status'] as String?;
        final status = ConnectionStatus.values.firstWhere(
          (s) => s.name == name,
          orElse: () => ConnectionStatus.disconnected,
        );
        if (mounted) setState(() => _status = status);
      });
      _refreshRunning();
    } catch (_) {
      // No platform implementation available; stay in the default state.
    }
  }

  Future<void> _refreshRunning() async {
    try {
      final running = await FlutterBackgroundService().isRunning();
      if (mounted) setState(() => _running = running);
    } catch (_) {
      // No platform implementation available; stay in the default state.
    }
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    super.dispose();
  }

  Future<void> _toggle() async {
    setState(() => _busy = true);
    try {
      if (_running) {
        FlutterBackgroundService().invoke('stopService');
        setState(() {
          _running = false;
          _status = ConnectionStatus.disconnected;
        });
      } else {
        await requestNotificationPermission();
        await FlutterBackgroundService().startService();
        setState(() => _running = true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _statusLabel {
    if (!_running) return 'Not running';
    switch (_status) {
      case ConnectionStatus.disconnected:
        return 'Running — disconnected';
      case ConnectionStatus.connecting:
        return 'Running — connecting…';
      case ConnectionStatus.paired:
        return 'Running — paired';
      case ConnectionStatus.error:
        return 'Running — error';
    }
  }

  Color get _statusColor {
    if (!_running) return Colors.grey;
    switch (_status) {
      case ConnectionStatus.paired:
        return Colors.green;
      case ConnectionStatus.error:
        return Colors.red;
      case ConnectionStatus.connecting:
        return Colors.orange;
      case ConnectionStatus.disconnected:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset('assets/branding/khsae_tei_logo.png', width: 140, height: 140),
            ),
            const SizedBox(height: 16),
            const Text('ខ្សែតី KHSAE TEI', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(color: _statusColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(_statusLabel, style: const TextStyle(fontSize: 16)),
              ],
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _busy ? null : _toggle,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16)),
              child: Text(_running ? 'Stop' : 'Start', style: const TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}

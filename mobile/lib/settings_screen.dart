import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import 'discovery.dart';
import 'qr_scan_screen.dart';
import 'settings_store.dart';
import 'ws_client.dart';

const _batteryChannel = MethodChannel('khsae_tei/multicast_lock');

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '8787');
  final _relayUrlController = TextEditingController();
  final _codeController = TextEditingController();

  ConnectionMode _mode = ConnectionMode.lan;
  ConnectionStatus _status = ConnectionStatus.disconnected;
  final List<String> _log = [];
  bool _discovering = false;

  StreamSubscription<Map<String, dynamic>?>? _statusSub;
  StreamSubscription<Map<String, dynamic>?>? _eventSub;

  @override
  void initState() {
    super.initState();
    // Same as HomeScreen: the background-service platform channel isn't
    // available outside a real Android/iOS run.
    try {
      _statusSub = FlutterBackgroundService().on('statusUpdate').listen((event) {
        final name = event?['status'] as String?;
        final status = ConnectionStatus.values.firstWhere(
          (s) => s.name == name,
          orElse: () => ConnectionStatus.disconnected,
        );
        if (mounted) setState(() => _status = status);
      });
      _eventSub = FlutterBackgroundService().on('logEvent').listen((event) {
        final message = event?['message'] as String?;
        if (message != null && mounted) setState(() => _log.insert(0, message));
      });
    } catch (_) {
      // No platform implementation available; stay in the default state.
    }
    _loadSavedConfig();
  }

  Future<void> _loadSavedConfig() async {
    try {
      final saved = await SettingsStore().load();
      if (saved == null || !mounted) return;
      setState(() {
        _mode = saved.mode;
        _ipController.text = saved.ip;
        _portController.text = saved.port;
        _relayUrlController.text = saved.relayUrl;
        _codeController.text = saved.code;
      });
    } catch (_) {
      // No platform implementation available; keep the blank defaults.
    }
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _eventSub?.cancel();
    _ipController.dispose();
    _portController.dispose();
    _relayUrlController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    if (_mode == ConnectionMode.lan && _ipController.text.trim().isEmpty) return;
    if (_mode == ConnectionMode.internet && _relayUrlController.text.trim().isEmpty) return;

    final config = ConnectionConfig(
      mode: _mode,
      ip: _ipController.text.trim(),
      port: _portController.text.trim(),
      code: code,
      relayUrl: _relayUrlController.text.trim(),
    );
    await SettingsStore().save(config);

    final service = FlutterBackgroundService();
    if (!await service.isRunning()) {
      await service.startService();
    }
    service.invoke('updateConfig', config.toMap());
    service.invoke('connect');
  }

  void _disconnect() {
    FlutterBackgroundService().invoke('disconnect');
  }

  Future<void> _discover() async {
    setState(() => _discovering = true);
    try {
      final results = await MdnsDiscovery().discover();
      if (!mounted) return;
      if (results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No desktop found via mDNS. Enter IP/port manually.')),
        );
      } else {
        final found = results.first;
        _ipController.text = found.ip;
        _portController.text = found.port.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Found ${found.ip}:${found.port}')),
        );
      }
    } finally {
      if (mounted) setState(() => _discovering = false);
    }
  }

  Future<void> _scanQr() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
    if (result == null) return;
    final uri = Uri.tryParse(result);
    if (uri == null || uri.host.isEmpty) return;
    setState(() => _mode = ConnectionMode.lan);
    _ipController.text = uri.host;
    if (uri.hasPort) _portController.text = uri.port.toString();
    final code = uri.queryParameters['code'];
    if (code != null) _codeController.text = code;
    await _connect();
  }

  Future<void> _requestIgnoreBatteryOptimizations() async {
    await _batteryChannel.invokeMethod('requestIgnoreBatteryOptimizations');
  }

  String get _statusLabel {
    switch (_status) {
      case ConnectionStatus.disconnected:
        return 'Disconnected';
      case ConnectionStatus.connecting:
        return 'Connecting...';
      case ConnectionStatus.paired:
        return 'Paired';
      case ConnectionStatus.error:
        return 'Error';
    }
  }

  Color get _statusColor {
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
      appBar: AppBar(title: const Text('Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<ConnectionMode>(
              segments: const [
                ButtonSegment(value: ConnectionMode.lan, label: Text('LAN')),
                ButtonSegment(value: ConnectionMode.internet, label: Text('Internet')),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
            const SizedBox(height: 16),
            if (_mode == ConnectionMode.lan) ...[
              TextField(
                controller: _ipController,
                decoration: const InputDecoration(labelText: 'Desktop IP'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _portController,
                decoration: const InputDecoration(labelText: 'Port'),
                keyboardType: TextInputType.number,
              ),
            ] else
              TextField(
                controller: _relayUrlController,
                decoration: const InputDecoration(
                  labelText: 'Relay URL',
                  hintText: 'wss://your-relay-host',
                ),
                keyboardType: TextInputType.url,
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(labelText: 'Pairing code'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            if (_mode == ConnectionMode.lan)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _discovering ? null : _discover,
                      child: Text(_discovering ? 'Searching...' : 'Discover'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(onPressed: _scanQr, child: const Text('Scan QR')),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(onPressed: _connect, child: const Text('Connect')),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(onPressed: _disconnect, child: const Text('Disconnect')),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(color: _statusColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(_statusLabel),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _status == ConnectionStatus.paired
                  ? () => FlutterBackgroundService().invoke('testWhip')
                  : null,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 20)),
              child: const Text('Test Whip', style: TextStyle(fontSize: 20)),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _requestIgnoreBatteryOptimizations,
              child: const Text('Disable battery optimization for this app'),
            ),
            const SizedBox(height: 16),
            const Text('Events', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(
              height: 200,
              child: ListView.builder(
                itemCount: _log.length,
                itemBuilder: (context, i) => Text(_log[i], style: const TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

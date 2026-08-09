import 'dart:async';

import 'package:flutter/material.dart';

import 'discovery.dart';
import 'qr_scan_screen.dart';
import 'settings_store.dart';
import 'theme.dart';
import 'whip_controller.dart';
import 'widgets.dart';
import 'ws_client.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '8787');
  final _codeController = TextEditingController();

  ConnectionStatus _status = ConnectionStatus.disconnected;
  final List<String> _log = [];
  bool _discovering = false;
  bool _soundEnabled = true;

  StreamSubscription<ConnectionStatus>? _statusSub;
  StreamSubscription<String>? _eventSub;

  @override
  void initState() {
    super.initState();
    _statusSub = WhipController().status.listen((status) {
      if (mounted) setState(() => _status = status);
    });
    _eventSub = WhipController().events.listen((message) {
      if (mounted) setState(() => _log.insert(0, message));
    });
    _loadSavedConfig();
    _loadSoundSetting();
  }

  Future<void> _loadSavedConfig() async {
    try {
      final saved = await SettingsStore().load();
      if (saved == null || !mounted) return;
      setState(() {
        _ipController.text = saved.ip;
        _portController.text = saved.port;
        _codeController.text = saved.code;
      });
    } catch (_) {
      // No platform implementation available; keep the blank defaults.
    }
  }

  Future<void> _loadSoundSetting() async {
    try {
      final enabled = await SettingsStore().loadSoundEnabled();
      soundEnabledNotifier.value = enabled;
      if (mounted) setState(() => _soundEnabled = enabled);
    } catch (_) {
      // No platform implementation available; keep the default (on).
    }
  }

  Future<void> _setSoundEnabled(bool enabled) async {
    setState(() => _soundEnabled = enabled);
    soundEnabledNotifier.value = enabled;
    await SettingsStore().saveSoundEnabled(enabled);
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _eventSub?.cancel();
    _ipController.dispose();
    _portController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final code = _codeController.text.trim();
    final ip = _ipController.text.trim();
    if (code.isEmpty || ip.isEmpty) return;

    final config = ConnectionConfig(ip: ip, port: _portController.text.trim(), code: code);
    await SettingsStore().save(config);
    await WhipController().connect(config.ip, config.port, config.code);
  }

  void _disconnect() {
    WhipController().disconnect();
  }

  Future<void> _discover() async {
    // Guard re-entrancy here, not just via the button's onPressed: two taps
    // landing in the same frame (seen on a real iOS device) can both pass
    // the disabled check before the rebuild lands, and a second overlapping
    // MDnsClient.start() fails to bind the multicast socket the first one
    // is still holding.
    if (_discovering) return;
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
    _ipController.text = uri.host;
    if (uri.hasPort) _portController.text = uri.port.toString();
    final code = uri.queryParameters['code'];
    if (code != null) _codeController.text = code;
    await _connect();
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
        return const Color(0xFF3DDC7A);
      case ConnectionStatus.error:
        return const Color(0xFFFF5C5C);
      case ConnectionStatus.connecting:
        return const Color(0xFFFFB84D);
      case ConnectionStatus.disconnected:
        return Colors.white54;
    }
  }

  static const _fieldTextStyle = TextStyle(color: Colors.white);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: kBackgroundGradient),
        child: SafeArea(
          child: Theme(
            data: Theme.of(context).copyWith(inputDecorationTheme: kDarkInputDecorationTheme),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Settings',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _ipController,
                          style: _fieldTextStyle,
                          decoration: const InputDecoration(labelText: 'Desktop IP'),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _portController,
                          style: _fieldTextStyle,
                          decoration: const InputDecoration(labelText: 'Port'),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _codeController,
                          style: _fieldTextStyle,
                          decoration: const InputDecoration(labelText: 'Pairing code'),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedPillButton(
                                onPressed: _discovering ? null : _discover,
                                label: _discovering ? 'Searching...' : 'Discover',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: OutlinedPillButton(onPressed: _scanQr, label: 'Scan QR')),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: GradientPillButton(onPressed: _connect, label: 'Connect')),
                            const SizedBox(width: 8),
                            Expanded(child: OutlinedPillButton(onPressed: _disconnect, label: 'Disconnect')),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(color: _statusColor, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _statusLabel,
                              style: TextStyle(color: _statusColor, fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        GradientPillButton(
                          onPressed: _status == ConnectionStatus.paired ? () => WhipController().testWhip() : null,
                          label: 'Test Whip',
                          icon: Icons.bolt,
                          height: 56,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: kAccent,
                      title: const Text('Play whip sound', style: TextStyle(color: Colors.white)),
                      value: _soundEnabled,
                      onChanged: _setSoundEnabled,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Events',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 200,
                          child: ListView.builder(
                            itemCount: _log.length,
                            itemBuilder: (context, i) => Text(
                              _log[i],
                              style: const TextStyle(fontSize: 12, color: Colors.white60),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

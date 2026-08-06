import 'package:flutter/material.dart';

import 'discovery.dart';
import 'qr_scan_screen.dart';
import 'sound_player.dart';
import 'whip_detector.dart';
import 'ws_client.dart';

class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '8787');
  final _codeController = TextEditingController();

  final _client = WsClient();
  final _soundPlayer = SoundPlayer();
  final _whipDetector = WhipDetector();
  ConnectionStatus _status = ConnectionStatus.disconnected;
  final List<String> _log = [];
  bool _discovering = false;

  @override
  void initState() {
    super.initState();
    _client.status.listen((s) => setState(() => _status = s));
    _client.events.listen((e) => setState(() => _log.insert(0, e)));
    _whipDetector.onWhip.listen((_) => _onWhipGesture());
    _whipDetector.start();
  }

  @override
  void dispose() {
    _whipDetector.dispose();
    _soundPlayer.dispose();
    _client.dispose();
    _ipController.dispose();
    _portController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _connect() {
    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 8787;
    final code = _codeController.text.trim();
    if (ip.isEmpty || code.isEmpty) return;
    _client.connect(ip, port, code, 'Flutter Test Client');
  }

  void _onWhipGesture() {
    _soundPlayer.playWhip();
    _client.sendWhip();
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
    _ipController.text = uri.host;
    if (uri.hasPort) _portController.text = uri.port.toString();
    final code = uri.queryParameters['code'];
    if (code != null) _codeController.text = code;
    _connect();
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
      appBar: AppBar(title: const Text('ខ្សែតី KHSAE TEI')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
            const SizedBox(height: 8),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(labelText: 'Pairing code'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
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
            ElevatedButton(onPressed: _connect, child: const Text('Connect')),
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
              onPressed: _status == ConnectionStatus.paired ? _client.sendWhip : null,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 20)),
              child: const Text('Test Whip', style: TextStyle(fontSize: 20)),
            ),
            const SizedBox(height: 16),
            const Text('Events', style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
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

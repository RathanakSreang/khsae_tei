import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_classic_bluetooth/flutter_classic_bluetooth.dart';
import 'package:permission_handler/permission_handler.dart';

import 'discovery.dart';
import 'qr_scan_screen.dart';
import 'settings_store.dart';
import 'theme.dart';
import 'widgets.dart';
import 'ws_client.dart';

const _batteryChannel = MethodChannel('khsae_tei/multicast_lock');

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Bluetooth mode doesn't work yet on iOS (Apple only allows raw Bluetooth
  // Classic SPP for MFi-certified accessories, which this desktop server
  // isn't) or on a macOS desktop (bluetooth_server.py needs BlueZ, Linux-only)
  // - hidden from the UI until one of those has a real fix. LAN mode and all
  // the Bluetooth plumbing underneath are untouched; flip this back on to
  // restore the picker.
  static const _bluetoothEnabled = false;

  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '8787');
  final _codeController = TextEditingController();

  ConnectionMode _mode = ConnectionMode.lan;
  ConnectionStatus _status = ConnectionStatus.disconnected;
  final List<String> _log = [];
  bool _discovering = false;

  List<BtcDevice> _pairedDevices = [];
  String? _selectedBtAddress;
  bool _loadingPairedDevices = false;
  bool _soundEnabled = true;

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
    _loadSoundSetting();
  }

  Future<void> _loadSavedConfig() async {
    try {
      final saved = await SettingsStore().load();
      if (saved == null || !mounted) return;
      setState(() {
        _mode = _bluetoothEnabled ? saved.mode : ConnectionMode.lan;
        _ipController.text = saved.ip;
        _portController.text = saved.port;
        _selectedBtAddress = saved.btAddress.isEmpty ? null : saved.btAddress;
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
    FlutterBackgroundService().invoke('updateSoundEnabled', {'enabled': enabled});
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

  /// Android 12+ requires runtime consent for Bluetooth scan/connect (the
  /// plugin documents that it does not request these itself); older Android
  /// additionally needs location for classic-Bluetooth device discovery.
  Future<bool> _ensureBluetoothPermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    return statuses.values.every((s) => s.isGranted || s.isLimited);
  }

  Future<void> _loadPairedDevices() async {
    setState(() => _loadingPairedDevices = true);
    try {
      if (!await _ensureBluetoothPermissions()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bluetooth permission is required to list paired devices.')),
          );
        }
        return;
      }
      final devices = await FlutterClassicBluetooth().getPairedDevices();
      if (mounted) setState(() => _pairedDevices = devices);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not list paired devices: $e')));
      }
    } finally {
      if (mounted) setState(() => _loadingPairedDevices = false);
    }
  }

  Future<void> _connect() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    if (_mode == ConnectionMode.lan && _ipController.text.trim().isEmpty) return;
    if (_mode == ConnectionMode.bluetooth && (_selectedBtAddress ?? '').isEmpty) return;

    final config = ConnectionConfig(
      mode: _mode,
      ip: _ipController.text.trim(),
      port: _portController.text.trim(),
      code: code,
      btAddress: _selectedBtAddress ?? '',
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
                        if (_bluetoothEnabled) ...[
                          SegmentedButton<ConnectionMode>(
                            segments: const [
                              ButtonSegment(value: ConnectionMode.lan, label: Text('LAN')),
                              ButtonSegment(value: ConnectionMode.bluetooth, label: Text('Bluetooth')),
                            ],
                            selected: {_mode},
                            onSelectionChanged: (s) => setState(() => _mode = s.first),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (_bluetoothEnabled && _mode == ConnectionMode.bluetooth) ...[
                          const Text(
                            'Pair with the desktop from your phone\'s Bluetooth settings '
                            'first, then refresh below to pick it.',
                            style: TextStyle(color: Colors.white60, fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                          OutlinedPillButton(
                            onPressed: _loadingPairedDevices ? null : _loadPairedDevices,
                            label: _loadingPairedDevices ? 'Loading...' : 'Refresh paired devices',
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedBtAddress,
                            dropdownColor: kBgBottom,
                            style: _fieldTextStyle,
                            decoration: const InputDecoration(labelText: 'Paired device'),
                            items: _pairedDevices
                                .map((d) => DropdownMenuItem(value: d.address, child: Text(d.displayName)))
                                .toList(),
                            onChanged: (address) => setState(() => _selectedBtAddress = address),
                          ),
                        ] else ...[
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
                        ],
                        const SizedBox(height: 8),
                        TextField(
                          controller: _codeController,
                          style: _fieldTextStyle,
                          decoration: const InputDecoration(labelText: 'Pairing code'),
                          keyboardType: TextInputType.number,
                        ),
                        if (_mode == ConnectionMode.lan) ...[
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
                        ],
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
                          onPressed: _status == ConnectionStatus.paired
                              ? () => FlutterBackgroundService().invoke('testWhip')
                              : null,
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
                  if (Platform.isAndroid) ...[
                    const SizedBox(height: 16),
                    SectionCard(
                      child: OutlinedPillButton(
                        onPressed: _requestIgnoreBatteryOptimizations,
                        label: 'Disable battery optimization for this app',
                      ),
                    ),
                  ],
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

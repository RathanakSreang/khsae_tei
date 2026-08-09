import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import 'background_service.dart';
import 'settings_store.dart';
import 'theme.dart';
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
    SettingsStore().loadSoundEnabled().then((enabled) => soundEnabledNotifier.value = enabled);
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

  String get _statusDescription {
    if (!_running) return 'Tap Start to begin whip detection.';
    switch (_status) {
      case ConnectionStatus.paired:
        return 'Your device is connected and ready.';
      case ConnectionStatus.connecting:
        return 'Pairing with your desktop…';
      case ConnectionStatus.error:
        return 'Something went wrong - check Settings.';
      case ConnectionStatus.disconnected:
        return 'Detection is active, but no desktop is paired yet.';
    }
  }

  Color get _statusColor {
    if (!_running) return Colors.grey;
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

  String get _connectionStat {
    if (!_running) return 'Offline';
    switch (_status) {
      case ConnectionStatus.paired:
        return 'Stable';
      case ConnectionStatus.connecting:
        return 'Linking';
      case ConnectionStatus.error:
        return 'Error';
      case ConnectionStatus.disconnected:
        return 'Offline';
    }
  }

  void _showHelp() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How it works'),
        content: const Text(
          'Swing your phone like a whip. KHSAE TEI detects the motion, plays '
          'a sound, and tells your paired desktop to press Enter - handy for '
          'approving a prompt without reaching for the keyboard.\n\n'
          'Pair a desktop from the Settings tab first, then tap Start here.',
        ),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Got it'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(context),
      body: Container(
        decoration: const BoxDecoration(gradient: kBackgroundGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _CircleIconButton(icon: Icons.menu, onTap: () => Scaffold.of(context).openDrawer()),
                    _CircleIconButton(icon: Icons.help_outline, onTap: _showHelp),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'ខ្សែតី',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: kAccent, height: 1.3),
                ),
                const Text(
                  'KHSAE TEI',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Smart • Connected • Effortless',
                  style: TextStyle(fontSize: 14, color: kAccentDim, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 28),
                Container(
                  width: 240,
                  height: 240,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: kAccentDim, width: 1.5),
                    boxShadow: const [BoxShadow(color: Color(0x5535E3EA), blurRadius: 36, spreadRadius: 1)],
                  ),
                  child: Image.asset('assets/branding/khsae_tei_logo.png', fit: BoxFit.cover),
                ),
                const SizedBox(height: 24),
                _StatusCard(
                  statusColor: _statusColor,
                  statusLabel: _statusLabel,
                  statusDescription: _statusDescription,
                  running: _running,
                  busy: _busy,
                  onToggle: _toggle,
                ),
                const SizedBox(height: 16),
                _StatsRow(connectionStat: _connectionStat),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: kBgBottom,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset('assets/branding/khsae_tei_logo.png', width: 72, height: 72),
              ),
              const SizedBox(height: 16),
              const Text(
                'ខ្សែតី KHSAE TEI',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'A "whip-app": swing your phone to send an Enter keypress to a '
                'paired desktop over LAN.',
                style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kCardFill,
      shape: const CircleBorder(side: BorderSide(color: kCardBorder)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(12), child: Icon(icon, color: kAccent, size: 22)),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.statusColor,
    required this.statusLabel,
    required this.statusDescription,
    required this.running,
    required this.busy,
    required this.onToggle,
  });

  final Color statusColor;
  final String statusLabel;
  final String statusDescription;
  final bool running;
  final bool busy;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        color: kCardFill,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kCardBorder),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            statusDescription,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(27),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: running
                      ? null
                      : const LinearGradient(colors: [Color(0xFF35E3EA), Color(0xFF29C7B5)]),
                  color: running ? Colors.white.withValues(alpha: 0.06) : null,
                  borderRadius: BorderRadius.circular(27),
                  border: running ? Border.all(color: kCardBorder) : null,
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(27),
                  onTap: busy ? null : onToggle,
                  child: Center(
                    child: busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.power_settings_new, color: running ? Colors.white70 : Colors.black87),
                              const SizedBox(width: 8),
                              Text(
                                running ? 'Stop' : 'Start',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: running ? Colors.white70 : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.connectionStat});

  final String connectionStat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: kCardFill,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kCardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatTile(icon: Icons.link, label: 'Connection', value: connectionStat, valueColor: kAccent),
          ),
          const _StatDivider(),
          const Expanded(
            child: _StatTile(icon: Icons.wifi, label: 'Mode', value: 'LAN', valueColor: kAccent),
          ),
          const _StatDivider(),
          Expanded(
            child: ValueListenableBuilder<bool>(
              valueListenable: soundEnabledNotifier,
              builder: (context, enabled, _) => _StatTile(
                icon: enabled ? Icons.volume_up : Icons.volume_off,
                label: 'Sound',
                value: enabled ? 'On' : 'Off',
                valueColor: enabled ? kAccent : Colors.white38,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 44, color: kCardBorder);
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.label, required this.value, required this.valueColor});

  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: kCardBorder)),
          child: Icon(icon, color: kAccent, size: 18),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: valueColor, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

import 'package:shared_preferences/shared_preferences.dart';

enum ConnectionMode { lan, internet }

/// Everything needed to (re)connect to the desktop, persisted across app
/// restarts so Settings is prefilled and the background service can
/// reconnect without the UI having to supply it again.
class ConnectionConfig {
  ConnectionConfig({
    required this.mode,
    required this.ip,
    required this.port,
    required this.code,
    required this.relayUrl,
  });

  final ConnectionMode mode;
  final String ip;
  final String port;
  final String code;
  final String relayUrl;

  Map<String, String> toMap() => {
    'mode': mode.name,
    'ip': ip,
    'port': port,
    'code': code,
    'relayUrl': relayUrl,
  };

  static ConnectionConfig fromMap(Map<String, String> map) => ConnectionConfig(
    mode: ConnectionMode.values.firstWhere(
      (m) => m.name == map['mode'],
      orElse: () => ConnectionMode.lan,
    ),
    ip: map['ip'] ?? '',
    port: map['port'] ?? '8787',
    code: map['code'] ?? '',
    relayUrl: map['relayUrl'] ?? '',
  );
}

class SettingsStore {
  static const _keys = ['mode', 'ip', 'port', 'code', 'relayUrl'];

  Future<ConnectionConfig?> load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('mode')) return null;
    return ConnectionConfig.fromMap({for (final k in _keys) k: prefs.getString(k) ?? ''});
  }

  Future<void> save(ConnectionConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    for (final entry in config.toMap().entries) {
      await prefs.setString(entry.key, entry.value);
    }
  }
}

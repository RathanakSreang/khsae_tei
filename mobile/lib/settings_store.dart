import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ConnectionMode { lan, bluetooth }

/// Shared, in-memory mirror of the persisted whip-sound setting so Home's
/// status tile can reflect a change made on the Settings tab immediately -
/// both screens stay alive under the app shell's IndexedStack, so a plain
/// re-read on navigation wouldn't notice the update.
final soundEnabledNotifier = ValueNotifier<bool>(true);

/// Everything needed to (re)connect to the desktop, persisted across app
/// restarts so Settings is prefilled and the background service can
/// reconnect without the UI having to supply it again.
class ConnectionConfig {
  ConnectionConfig({
    required this.mode,
    required this.ip,
    required this.port,
    required this.code,
    required this.btAddress,
  });

  final ConnectionMode mode;
  final String ip;
  final String port;
  final String code;
  final String btAddress;

  Map<String, String> toMap() => {
    'mode': mode.name,
    'ip': ip,
    'port': port,
    'code': code,
    'btAddress': btAddress,
  };

  static ConnectionConfig fromMap(Map<String, String> map) => ConnectionConfig(
    mode: ConnectionMode.values.firstWhere(
      (m) => m.name == map['mode'],
      orElse: () => ConnectionMode.lan,
    ),
    ip: map['ip'] ?? '',
    port: map['port'] ?? '8787',
    code: map['code'] ?? '',
    btAddress: map['btAddress'] ?? '',
  );
}

class SettingsStore {
  static const _keys = ['mode', 'ip', 'port', 'code', 'btAddress'];
  static const _soundEnabledKey = 'whipSoundEnabled';

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

  Future<bool> loadSoundEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_soundEnabledKey) ?? true;
  }

  Future<void> saveSoundEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundEnabledKey, enabled);
  }
}

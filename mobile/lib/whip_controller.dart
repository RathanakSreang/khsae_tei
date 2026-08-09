import 'settings_store.dart';
import 'sound_player.dart';
import 'whip_detector.dart';
import 'ws_client.dart';

/// App-lifetime singleton owning the live connection/whip-detection/sound
/// objects directly in the UI process - replaces the old
/// flutter_background_service isolate (removed: no longer needed). Home and
/// Settings both stay alive under AppShell's IndexedStack and observe this
/// same instance's broadcast streams directly instead of going through a
/// service invoke()/on() pub-sub.
class WhipController {
  WhipController._() {
    _whipDetector.onWhip.listen((_) {
      if (soundEnabledNotifier.value) _soundPlayer.playWhip();
      _client.sendWhip();
    });
  }

  static final WhipController _instance = WhipController._();
  factory WhipController() => _instance;

  final WsClient _client = WsClient();
  final WhipDetector _whipDetector = WhipDetector();
  final SoundPlayer _soundPlayer = SoundPlayer();
  final SettingsStore _settingsStore = SettingsStore();

  bool _running = false;
  bool get running => _running;

  Stream<ConnectionStatus> get status => _client.status;
  Stream<String> get events => _client.events;

  void _ensureRunning() {
    if (_running) return;
    _running = true;
    _whipDetector.start();
  }

  /// Starts whip detection and reconnects using the last saved config, if
  /// any - mirrors what the background service used to do on its own
  /// startup tail.
  Future<void> start() async {
    _ensureRunning();
    final config = await _settingsStore.load();
    if (config != null) await connect(config.ip, config.port, config.code);
  }

  void stop() {
    _running = false;
    _whipDetector.stop();
    _client.disconnect();
  }

  Future<void> connect(String ip, String port, String code) async {
    _ensureRunning();
    final parsedPort = int.tryParse(port) ?? 8787;
    await _client.connect(Uri(scheme: 'ws', host: ip, port: parsedPort), code, 'KHSAE TEI Phone');
  }

  void disconnect() => _client.disconnect();

  void testWhip() => _client.sendWhip();
}

import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'settings_store.dart';
import 'sound_player.dart';
import 'whip_detector.dart';
import 'ws_client.dart';

const notificationChannelId = 'khsae_tei_running';
const notificationId = 888;

/// Configures (but does not start) the background service. Must be called
/// from main() before runApp() - the actual start happens later from the UI
/// (Home's Start button, or Settings' Connect, which starts it implicitly).
Future<void> initializeBackgroundService() async {
  final plugin = FlutterLocalNotificationsPlugin();
  final androidPlugin = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  // Low importance + no sound/vibration/badge: the least intrusive notification
  // Android allows for a foreground service - it can't be hidden entirely,
  // since that's what stops apps silently running forever in the background.
  await androidPlugin?.createNotificationChannel(
    const AndroidNotificationChannel(
      notificationChannelId,
      'KHSAE TEI running',
      description: 'Shown while whip detection is active in the background',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
      showBadge: false,
    ),
  );

  await FlutterBackgroundService().configure(
    iosConfiguration: IosConfiguration(),
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      autoStartOnBoot: false,
      isForegroundMode: true,
      notificationChannelId: notificationChannelId,
      foregroundServiceNotificationId: notificationId,
      foregroundServiceTypes: [AndroidForegroundType.connectedDevice],
      initialNotificationTitle: 'KHSAE TEI',
      initialNotificationContent: 'Starting…',
    ),
  );
}

/// Android 13+ requires explicit runtime consent to show any notification,
/// including the foreground service's - without it the service still runs,
/// but the (already minimized) notification silently never appears.
Future<void> requestNotificationPermission() async {
  await FlutterLocalNotificationsPlugin()
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();
}

Uri? _buildUri(ConnectionConfig config) {
  if (config.mode == ConnectionMode.lan) {
    if (config.ip.isEmpty) return null;
    final port = int.tryParse(config.port) ?? 8787;
    return Uri(scheme: 'ws', host: config.ip, port: port);
  }
  if (config.relayUrl.isEmpty) return null;
  return Uri.tryParse(config.relayUrl);
}

String _statusLabel(ConnectionStatus status) {
  switch (status) {
    case ConnectionStatus.disconnected:
      return 'Disconnected';
    case ConnectionStatus.connecting:
      return 'Connecting…';
    case ConnectionStatus.paired:
      return 'Paired';
    case ConnectionStatus.error:
      return 'Error';
  }
}

/// Entrypoint for the background isolate. Runs independently of any UI -
/// owns the real WsClient/WhipDetector/SoundPlayer so the connection and
/// gesture detection keep working while the app is backgrounded.
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final client = WsClient();
  final soundPlayer = SoundPlayer();
  final whipDetector = WhipDetector();
  final settingsStore = SettingsStore();
  ConnectionConfig? currentConfig;

  Future<void> updateNotification(String content) async {
    if (service is AndroidServiceInstance) {
      await service.setForegroundNotificationInfo(title: 'KHSAE TEI', content: content);
    }
  }

  client.status.listen((status) {
    service.invoke('statusUpdate', {'status': status.name});
    updateNotification(_statusLabel(status));
  });
  client.events.listen((event) => service.invoke('logEvent', {'message': event}));
  client.onAck.listen((_) => soundPlayer.playSuccess());

  whipDetector.onWhip.listen((_) {
    soundPlayer.playWhip();
    client.sendWhip();
  });
  whipDetector.start();

  service.on('updateConfig').listen((event) async {
    if (event == null) return;
    final config = ConnectionConfig.fromMap(event.map((k, v) => MapEntry(k, v.toString())));
    currentConfig = config;
    await settingsStore.save(config);
  });

  service.on('connect').listen((_) {
    final config = currentConfig;
    if (config == null) return;
    final uri = _buildUri(config);
    if (uri == null) return;
    client.connect(uri, config.code, 'KHSAE TEI Phone');
  });

  service.on('disconnect').listen((_) => client.disconnect());
  service.on('testWhip').listen((_) => client.sendWhip());

  service.on('stopService').listen((_) async {
    whipDetector.dispose();
    client.dispose();
    soundPlayer.dispose();
    await service.stopSelf();
  });

  // Home's Start button just starts the service without going through
  // Settings first - if we have a config from a previous session, resume
  // it automatically instead of leaving the user connectionless.
  currentConfig = await settingsStore.load();
  final savedConfig = currentConfig;
  if (savedConfig != null) {
    final uri = _buildUri(savedConfig);
    if (uri != null) client.connect(uri, savedConfig.code, 'KHSAE TEI Phone');
  }
}

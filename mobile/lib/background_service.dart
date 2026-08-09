import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'bt_client.dart';
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
    // iOS has no equivalent of Android's foreground service - onForeground
    // just runs onStart for as long as the app is active/on-screen, which is
    // the only regime iOS reliably allows; there's no onBackground handler
    // because BGAppRefreshTask's ~15s opportunistic, 15-minute-minimum-interval
    // budget isn't enough to keep a live accelerometer/socket session going.
    iosConfiguration: IosConfiguration(onForeground: onStart),
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

Uri? _buildLanUri(ConnectionConfig config) {
  if (config.ip.isEmpty) return null;
  final port = int.tryParse(config.port) ?? 8787;
  return Uri(scheme: 'ws', host: config.ip, port: port);
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
  final btClient = BtClient();
  final soundPlayer = SoundPlayer();
  final whipDetector = WhipDetector();
  final settingsStore = SettingsStore();
  ConnectionConfig? currentConfig;
  bool soundEnabled = await settingsStore.loadSoundEnabled();

  Future<void> updateNotification(String content) async {
    if (service is AndroidServiceInstance) {
      await service.setForegroundNotificationInfo(title: 'KHSAE TEI', content: content);
    }
  }

  // Both transports are wired up permanently rather than swapped in and out
  // per-mode - only whichever one connect() is actually called on will ever
  // emit anything, so this stays simple without extra subscription juggling.
  client.status.listen((status) {
    service.invoke('statusUpdate', {'status': status.name});
    updateNotification(_statusLabel(status));
  });
  client.events.listen((event) => service.invoke('logEvent', {'message': event}));
  btClient.status.listen((status) {
    service.invoke('statusUpdate', {'status': status.name});
    updateNotification(_statusLabel(status));
  });
  btClient.events.listen((event) => service.invoke('logEvent', {'message': event}));

  void sendWhip() {
    if (currentConfig?.mode == ConnectionMode.bluetooth) {
      btClient.sendWhip();
    } else {
      client.sendWhip();
    }
  }

  void connectCurrent() {
    final config = currentConfig;
    if (config == null) return;
    if (config.mode == ConnectionMode.bluetooth) {
      client.disconnect();
      if (config.btAddress.isEmpty) return;
      btClient.connect(config.btAddress, config.code, 'KHSAE TEI Phone');
    } else {
      btClient.disconnect();
      final uri = _buildLanUri(config);
      if (uri == null) return;
      client.connect(uri, config.code, 'KHSAE TEI Phone');
    }
  }

  whipDetector.onWhip.listen((_) {
    if (soundEnabled) soundPlayer.playWhip();
    sendWhip();
  });
  whipDetector.start();

  service.on('updateConfig').listen((event) async {
    if (event == null) return;
    final config = ConnectionConfig.fromMap(event.map((k, v) => MapEntry(k, v.toString())));
    currentConfig = config;
    await settingsStore.save(config);
  });

  service.on('updateSoundEnabled').listen((event) async {
    final enabled = event?['enabled'] as bool? ?? true;
    soundEnabled = enabled;
    await settingsStore.saveSoundEnabled(enabled);
  });

  service.on('connect').listen((_) => connectCurrent());

  service.on('disconnect').listen((_) {
    client.disconnect();
    btClient.disconnect();
  });
  service.on('testWhip').listen((_) => sendWhip());

  service.on('stopService').listen((_) async {
    whipDetector.dispose();
    client.dispose();
    btClient.dispose();
    soundPlayer.dispose();
    await service.stopSelf();
  });

  // Home's Start button just starts the service without going through
  // Settings first - if we have a config from a previous session, resume
  // it automatically instead of leaving the user connectionless.
  currentConfig = await settingsStore.load();
  if (currentConfig != null) connectCurrent();
}

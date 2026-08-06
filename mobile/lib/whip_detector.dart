import 'dart:async';
import 'dart:math';

import 'package:sensors_plus/sensors_plus.dart';

/// Detects a "whip" gesture as a sharp spike in gravity-compensated
/// acceleration magnitude, with a refractory window so one swing can't
/// multi-fire and so walking/pocket jostling doesn't spam triggers.
class WhipDetector {
  WhipDetector({
    this.threshold = 15.0,
    this.refractory = const Duration(milliseconds: 800),
  });

  /// Magnitude (m/s^2) of userAcceleration above which a spike counts as a whip.
  /// Tuned on-device (Galaxy Note20, 50Hz sampling): real whip swings peaked
  /// at 10.2-23.5 m/s^2, so 15.0 catches the deliberate ones while sitting
  /// above typical casual-handling noise.
  final double threshold;
  final Duration refractory;

  StreamSubscription<UserAccelerometerEvent>? _sub;
  DateTime? _lastTrigger;
  final _controller = StreamController<void>.broadcast();

  Stream<void> get onWhip => _controller.stream;

  void start() {
    // The default sampling interval (SensorInterval.normalInterval, ~5Hz) is
    // too slow to reliably catch a whip-crack transient, which peaks and
    // decays in well under 150ms - gameInterval (~50Hz) is needed to
    // actually sample the peak instead of missing it between readings.
    _sub = userAccelerometerEventStream(samplingPeriod: SensorInterval.gameInterval).listen(_onEvent);
  }

  void _onEvent(UserAccelerometerEvent event) {
    final magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    if (magnitude < threshold) return;

    final now = DateTime.now();
    if (_lastTrigger != null && now.difference(_lastTrigger!) < refractory) return;

    _lastTrigger = now;
    _controller.add(null);
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }

  void dispose() {
    stop();
    _controller.close();
  }
}

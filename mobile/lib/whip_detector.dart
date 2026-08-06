import 'dart:async';
import 'dart:math';

import 'package:sensors_plus/sensors_plus.dart';

/// Detects a "whip" gesture as a sharp spike in gravity-compensated
/// acceleration magnitude, with a refractory window so one swing can't
/// multi-fire and so walking/pocket jostling doesn't spam triggers.
class WhipDetector {
  WhipDetector({
    this.threshold = 30.0,
    this.refractory = const Duration(milliseconds: 800),
  });

  /// Magnitude (m/s^2) of userAcceleration above which a spike counts as a whip.
  /// Start around 25-35; tune against real false positives (M4).
  final double threshold;
  final Duration refractory;

  StreamSubscription<UserAccelerometerEvent>? _sub;
  DateTime? _lastTrigger;
  final _controller = StreamController<void>.broadcast();

  Stream<void> get onWhip => _controller.stream;

  void start() {
    _sub = userAccelerometerEventStream().listen(_onEvent);
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

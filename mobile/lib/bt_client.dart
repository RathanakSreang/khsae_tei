import 'dart:async';
import 'dart:convert';

import 'package:flutter_classic_bluetooth/flutter_classic_bluetooth.dart';

import 'ws_client.dart';

/// Bluetooth Classic (RFCOMM/SPP) counterpart to [WsClient] - same public
/// shape (status/events/onAck streams, connect/sendWhip/disconnect) and the
/// exact same hello/paired/ack/error state machine, just framed as
/// newline-delimited JSON over a raw byte stream instead of WebSocket text
/// frames, since RFCOMM doesn't preserve message boundaries.
class BtClient {
  StreamSubscription<String>? _sub;
  BtcConnection? _connection;
  Timer? _reconnectTimer;

  final _statusController = StreamController<ConnectionStatus>.broadcast();
  final _eventController = StreamController<String>.broadcast();
  final _ackController = StreamController<void>.broadcast();

  Stream<ConnectionStatus> get status => _statusController.stream;
  Stream<String> get events => _eventController.stream;
  Stream<void> get onAck => _ackController.stream;

  ConnectionStatus _current = ConnectionStatus.disconnected;

  // Same reconnect discipline as WsClient: only auto-retry an unexpected
  // drop of a connection the user asked for, not an explicit disconnect()
  // or a rejected pairing code.
  String? _address;
  String? _code;
  String? _clientName;
  bool _autoReconnect = false;
  int _backoffSeconds = 1;
  static const _maxBackoffSeconds = 16;

  Future<void> connect(String address, String code, String clientName) async {
    _address = address;
    _code = code;
    _clientName = clientName;
    _autoReconnect = true;
    _backoffSeconds = 1;
    await _openConnection();
  }

  Future<void> _openConnection() async {
    _reconnectTimer?.cancel();
    _teardownConnection();
    _current = ConnectionStatus.connecting;
    _statusController.add(_current);

    try {
      final connection = await FlutterClassicBluetooth().connect(address: _address!);
      _connection = connection;

      _sub = connection.input.lines().listen(
        _onMessage,
        onError: (Object err) {
          _current = ConnectionStatus.error;
          _statusController.add(_current);
          _eventController.add('Connection error: $err');
          _maybeScheduleReconnect();
        },
        onDone: () {
          _current = ConnectionStatus.disconnected;
          _statusController.add(_current);
          _eventController.add('Disconnected');
          _maybeScheduleReconnect();
        },
      );

      await _send({'type': 'hello', 'code': _code, 'clientName': _clientName});
    } catch (e) {
      _current = ConnectionStatus.error;
      _statusController.add(_current);
      _eventController.add('Connect failed: $e');
      _maybeScheduleReconnect();
    }
  }

  void _maybeScheduleReconnect() {
    if (!_autoReconnect) return;
    _eventController.add('Reconnecting in ${_backoffSeconds}s...');
    _reconnectTimer = Timer(Duration(seconds: _backoffSeconds), () {
      if (_autoReconnect) _openConnection();
    });
    _backoffSeconds = (_backoffSeconds * 2).clamp(1, _maxBackoffSeconds);
  }

  void _onMessage(String raw) {
    final msg = jsonDecode(raw) as Map<String, dynamic>;
    switch (msg['type']) {
      case 'paired':
        _current = ConnectionStatus.paired;
        _statusController.add(_current);
        _eventController.add('Paired');
        _backoffSeconds = 1;
        break;
      case 'ack':
        _eventController.add('Whip acknowledged');
        _ackController.add(null);
        break;
      case 'error':
        _current = ConnectionStatus.error;
        _statusController.add(_current);
        _eventController.add('Server error: ${msg['reason']}');
        if (msg['reason'] == 'invalid_code') _autoReconnect = false;
        break;
      case 'agent_waiting':
        _eventController.add('Agent waiting: ${msg['label']} — ${msg['prompt']}');
        break;
    }
  }

  void sendWhip() {
    if (_current != ConnectionStatus.paired) return;
    _send({'type': 'whip', 'ts': DateTime.now().millisecondsSinceEpoch});
  }

  Future<void> _send(Map<String, dynamic> msg) async {
    await _connection?.output.writeLine(jsonEncode(msg), newline: '\n');
  }

  void _teardownConnection() {
    _sub?.cancel();
    _sub = null;
    final connection = _connection;
    _connection = null;
    connection?.close();
    connection?.dispose();
  }

  void disconnect() {
    _autoReconnect = false;
    _reconnectTimer?.cancel();
    _teardownConnection();
    _current = ConnectionStatus.disconnected;
  }

  void dispose() {
    disconnect();
    _statusController.close();
    _eventController.close();
    _ackController.close();
  }
}

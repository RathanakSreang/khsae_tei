import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

enum ConnectionStatus { disconnected, connecting, paired, error }

class WsClient {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _reconnectTimer;

  final _statusController = StreamController<ConnectionStatus>.broadcast();
  final _eventController = StreamController<String>.broadcast();

  Stream<ConnectionStatus> get status => _statusController.stream;
  Stream<String> get events => _eventController.stream;

  ConnectionStatus _current = ConnectionStatus.disconnected;

  // Reconnect state: only auto-reconnect after an unexpected drop of a
  // connection the user asked to establish, not after an explicit
  // disconnect() or a rejected pairing code (retrying that would just fail
  // again until the user fixes the code).
  String? _ip;
  int? _port;
  String? _code;
  String? _clientName;
  bool _autoReconnect = false;
  int _backoffSeconds = 1;
  static const _maxBackoffSeconds = 16;

  Future<void> connect(String ip, int port, String code, String clientName) async {
    _ip = ip;
    _port = port;
    _code = code;
    _clientName = clientName;
    _autoReconnect = true;
    _backoffSeconds = 1;
    await _openSocket();
  }

  Future<void> _openSocket() async {
    _reconnectTimer?.cancel();
    _teardownSocket();
    _current = ConnectionStatus.connecting;
    _statusController.add(_current);

    try {
      _channel = WebSocketChannel.connect(Uri.parse('ws://$_ip:$_port'));
      await _channel!.ready;

      _sub = _channel!.stream.listen(
        _onMessage,
        onError: (err) {
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

      _send({'type': 'hello', 'code': _code, 'clientName': _clientName});
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
      if (_autoReconnect) _openSocket();
    });
    _backoffSeconds = (_backoffSeconds * 2).clamp(1, _maxBackoffSeconds);
  }

  void _onMessage(dynamic raw) {
    final msg = jsonDecode(raw as String) as Map<String, dynamic>;
    switch (msg['type']) {
      case 'paired':
        _current = ConnectionStatus.paired;
        _statusController.add(_current);
        _eventController.add('Paired');
        _backoffSeconds = 1;
        break;
      case 'ack':
        _eventController.add('Whip acknowledged');
        break;
      case 'error':
        _current = ConnectionStatus.error;
        _statusController.add(_current);
        _eventController.add('Server error: ${msg['reason']}');
        if (msg['reason'] == 'invalid_code') _autoReconnect = false;
        break;
    }
  }

  void sendWhip() {
    if (_current != ConnectionStatus.paired) return;
    _send({'type': 'whip', 'ts': DateTime.now().millisecondsSinceEpoch});
  }

  void _send(Map<String, dynamic> msg) {
    _channel?.sink.add(jsonEncode(msg));
  }

  void _teardownSocket() {
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;
    _sub = null;
  }

  void disconnect() {
    _autoReconnect = false;
    _reconnectTimer?.cancel();
    _teardownSocket();
    _current = ConnectionStatus.disconnected;
  }

  void dispose() {
    disconnect();
    _statusController.close();
    _eventController.close();
  }
}

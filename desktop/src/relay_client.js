const WebSocket = require('ws');
const { EventEmitter } = require('events');

const MAX_BACKOFF_SECONDS = 16;

/**
 * Maintains one persistent outbound connection to a relay server so phones
 * on a different network can reach this desktop. Reuses WhipServer's
 * hello/whip/ack session logic unchanged - the relay just forwards frames
 * between this connection and whichever phone it paired under our code.
 */
class RelayClient extends EventEmitter {
  constructor(whipServer) {
    super();
    this.whipServer = whipServer;
    this.url = null;
    this.ws = null;
    this.session = null;
    this.wanted = false;
    this.reconnectTimer = null;
    this.backoffSeconds = 1;

    whipServer.on('event', (event) => {
      if (event.kind === 'code_regenerated') this._sendRegisterFrame();
    });
  }

  connect(url) {
    this.url = url;
    this.wanted = true;
    this.backoffSeconds = 1;
    this._open();
  }

  _open() {
    clearTimeout(this.reconnectTimer);
    this.session = null;

    let ws;
    try {
      ws = new WebSocket(this.url);
    } catch (err) {
      this.emit('event', { kind: 'relay_error', error: String(err) });
      this._scheduleReconnect();
      return;
    }
    this.ws = ws;

    ws.on('open', () => {
      this.backoffSeconds = 1;
      this._sendRegisterFrame();
      this.emit('event', { kind: 'relay_connected', url: this.url });
    });

    ws.on('message', (raw) => {
      const text = raw.toString();
      let msg;
      try {
        msg = JSON.parse(text);
      } catch {
        return;
      }
      if (msg.type === 'relay_registered') return;

      // Each "hello" starts a new phone's pairing cycle on this same
      // persistent relay connection, so it needs a fresh session handler -
      // otherwise a previous phone's already-paired state would silently
      // swallow the next phone's hello (WhipServer sessions are one-shot).
      if (msg.type === 'hello') {
        this.session = this.whipServer.createSessionHandler({
          send: (m) => ws.send(JSON.stringify(m)),
          close: () => ws.close(),
          remoteLabel: 'relay',
        });
      }
      this.session?.handleMessage(text);
    });

    ws.on('close', () => {
      this.session = null;
      this.emit('event', { kind: 'relay_disconnected' });
      if (this.wanted) this._scheduleReconnect();
    });

    ws.on('error', (err) => {
      this.emit('event', { kind: 'relay_error', error: String(err) });
    });
  }

  _sendRegisterFrame() {
    if (this.ws?.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify({ type: 'relay_register', code: this.whipServer.code }));
    }
  }

  _scheduleReconnect() {
    this.reconnectTimer = setTimeout(() => {
      if (this.wanted) this._open();
    }, this.backoffSeconds * 1000);
    this.backoffSeconds = Math.min(this.backoffSeconds * 2, MAX_BACKOFF_SECONDS);
  }

  disconnect() {
    this.wanted = false;
    clearTimeout(this.reconnectTimer);
    this.ws?.close();
    this.ws = null;
    this.session = null;
  }
}

module.exports = { RelayClient };

const { WebSocketServer } = require('ws');

const DEFAULT_PORT = 9090;

/**
 * Rendezvous relay: a desktop registers under its own pairing code, a phone
 * "hello"s with the same code, and from then on the relay is a dumb
 * bidirectional pipe between that one desktop connection and that one phone
 * connection. It never interprets whip/ack/paired frames - only the
 * relay-specific "relay_register" control message and the phone's "hello"
 * (which it needs to peek at to find the right desktop and to reject a
 * second phone trying to join an already-paired session).
 */
class Relay {
  constructor(port = DEFAULT_PORT) {
    this.port = port;
    this.sessions = new Map(); // code -> { deskWs, phoneWs }
    this.wss = null;
  }

  start() {
    this.wss = new WebSocketServer({ host: '0.0.0.0', port: this.port });

    this.wss.on('connection', (ws) => {
      let role = null; // 'desktop' | 'phone', set on first message
      let code = null;

      ws.on('message', (raw) => {
        const text = raw.toString();
        let msg;
        try {
          msg = JSON.parse(text);
        } catch {
          ws.close();
          return;
        }

        if (role === 'desktop') {
          if (msg.type === 'relay_register') {
            this._rekeyDesktop(code, msg.code, ws);
            code = msg.code;
            ws.send(JSON.stringify({ type: 'relay_registered' }));
            return;
          }
          this.sessions.get(code)?.phoneWs?.send(text);
          return;
        }

        if (role === 'phone') {
          this.sessions.get(code)?.deskWs?.send(text);
          return;
        }

        // First message on this connection: establishes its role.
        if (msg.type === 'relay_register') {
          role = 'desktop';
          code = msg.code;
          this._rekeyDesktop(null, code, ws);
          ws.send(JSON.stringify({ type: 'relay_registered' }));
          return;
        }

        if (msg.type === 'hello') {
          role = 'phone';
          code = msg.code;
          const session = this.sessions.get(code);
          if (!session || session.deskWs.readyState !== ws.OPEN) {
            ws.send(JSON.stringify({ type: 'error', reason: 'invalid_code' }));
            ws.close();
            return;
          }
          if (session.phoneWs) {
            ws.send(JSON.stringify({ type: 'error', reason: 'already_paired' }));
            ws.close();
            return;
          }
          session.phoneWs = ws;
          session.deskWs.send(text);
          return;
        }

        ws.close();
      });

      ws.on('close', () => {
        const session = this.sessions.get(code);
        if (!session) return;
        if (role === 'desktop' && session.deskWs === ws) {
          session.phoneWs?.close();
          this.sessions.delete(code);
        } else if (role === 'phone' && session.phoneWs === ws) {
          session.phoneWs = null;
        }
      });
    });
  }

  /** Moves a desktop's session entry to a new code, preserving any attached phone. */
  _rekeyDesktop(oldCode, newCode, ws) {
    const existing = oldCode ? this.sessions.get(oldCode) : null;
    if (oldCode) this.sessions.delete(oldCode);
    this.sessions.set(newCode, { deskWs: ws, phoneWs: existing?.phoneWs ?? null });
  }

  stop() {
    if (this.wss) this.wss.close();
  }
}

module.exports = { Relay, DEFAULT_PORT };

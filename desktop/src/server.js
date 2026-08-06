const { WebSocketServer } = require('ws');
const { EventEmitter } = require('events');
const { simulateEnter } = require('./keypress');

const DEFAULT_PORT = 8787;

function generateCode() {
  return String(Math.floor(100000 + Math.random() * 900000));
}

class WhipServer extends EventEmitter {
  constructor(port = DEFAULT_PORT) {
    super();
    this.port = port;
    this.code = generateCode();
    this.wss = null;
  }

  start() {
    this.wss = new WebSocketServer({ host: '0.0.0.0', port: this.port });

    this.wss.on('connection', (ws, req) => {
      let paired = false;
      const remote = req.socket.remoteAddress;

      ws.on('message', async (raw) => {
        let msg;
        try {
          msg = JSON.parse(raw.toString());
        } catch {
          ws.close();
          return;
        }

        if (!paired) {
          if (msg.type !== 'hello') {
            ws.close();
            return;
          }
          if (msg.code !== this.code) {
            ws.send(JSON.stringify({ type: 'error', reason: 'invalid_code' }));
            ws.close();
            this.emit('event', { kind: 'pair_failed', remote, clientName: msg.clientName });
            return;
          }
          paired = true;
          ws.send(JSON.stringify({ type: 'paired' }));
          this.emit('event', { kind: 'paired', remote, clientName: msg.clientName });
          return;
        }

        if (msg.type === 'whip') {
          try {
            await simulateEnter();
            ws.send(JSON.stringify({ type: 'ack' }));
            this.emit('event', { kind: 'whip', remote, ts: msg.ts });
          } catch (err) {
            ws.send(JSON.stringify({ type: 'error', reason: 'keypress_failed' }));
            this.emit('event', { kind: 'keypress_failed', remote, error: String(err) });
          }
        }
      });

      ws.on('close', () => {
        if (paired) this.emit('event', { kind: 'disconnected', remote });
      });
    });

    this.emit('event', { kind: 'listening', port: this.port });
  }

  regenerateCode() {
    this.code = generateCode();
    this.emit('event', { kind: 'code_regenerated' });
    return this.code;
  }

  stop() {
    if (this.wss) this.wss.close();
  }
}

module.exports = { WhipServer, DEFAULT_PORT };

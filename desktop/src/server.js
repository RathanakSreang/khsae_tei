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
      const remote = req.socket.remoteAddress;
      const session = this.createSessionHandler({
        send: (msg) => ws.send(JSON.stringify(msg)),
        close: () => ws.close(),
        remoteLabel: remote,
      });

      ws.on('message', (raw) => session.handleMessage(raw.toString()));
      ws.on('close', () => {
        if (session.isPaired()) this.emit('event', { kind: 'disconnected', remote });
      });
    });

    this.emit('event', { kind: 'listening', port: this.port });
  }

  /**
   * Builds the hello/whip/ack state machine used for one logical connection,
   * decoupled from the transport so both the LAN WebSocketServer and the
   * relay client (a single outbound connection multiplexing many phones)
   * can share identical pairing/keypress behavior.
   */
  createSessionHandler({ send, close, remoteLabel }) {
    let paired = false;

    const handleMessage = async (raw) => {
      let msg;
      try {
        msg = JSON.parse(raw);
      } catch {
        close();
        return;
      }

      if (!paired) {
        if (msg.type !== 'hello') {
          close();
          return;
        }
        if (msg.code !== this.code) {
          send({ type: 'error', reason: 'invalid_code' });
          close();
          this.emit('event', { kind: 'pair_failed', remote: remoteLabel, clientName: msg.clientName });
          return;
        }
        paired = true;
        send({ type: 'paired' });
        this.emit('event', { kind: 'paired', remote: remoteLabel, clientName: msg.clientName });
        return;
      }

      if (msg.type === 'whip') {
        try {
          await simulateEnter();
          send({ type: 'ack' });
          this.emit('event', { kind: 'whip', remote: remoteLabel, ts: msg.ts });
        } catch (err) {
          send({ type: 'error', reason: 'keypress_failed' });
          this.emit('event', { kind: 'keypress_failed', remote: remoteLabel, error: String(err) });
        }
      }
    };

    return { handleMessage, isPaired: () => paired };
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

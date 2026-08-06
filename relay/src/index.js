const { Relay, DEFAULT_PORT } = require('./server');

const port = Number(process.env.PORT) || DEFAULT_PORT;
const relay = new Relay(port);
relay.start();
console.log(`KHSAE TEI relay listening on port ${port}`);

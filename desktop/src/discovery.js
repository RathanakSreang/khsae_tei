const { Bonjour } = require('bonjour-service');

let bonjour = null;
let service = null;

function advertise(port) {
  bonjour = new Bonjour();
  service = bonjour.publish({
    name: 'KHSAE TEI',
    type: 'khsaetei',
    protocol: 'tcp',
    port,
  });
}

function stop() {
  if (service) service.stop();
  if (bonjour) bonjour.destroy();
  service = null;
  bonjour = null;
}

module.exports = { advertise, stop };

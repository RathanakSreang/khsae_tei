const addressEl = document.getElementById('address');
const codeEl = document.getElementById('code');
const qrEl = document.getElementById('qr');
const logEl = document.getElementById('log');
const regenBtn = document.getElementById('regen');

function log(line) {
  const time = new Date().toLocaleTimeString();
  logEl.textContent += `[${time}] ${line}\n`;
  logEl.scrollTop = logEl.scrollHeight;
}

window.khsaeTei.onServerInfo((info) => {
  addressEl.textContent = `${info.ip}:${info.port}`;
  codeEl.textContent = info.code;
  qrEl.src = info.qrDataUrl;
  log(`Server listening on ${info.ip}:${info.port}`);
});

window.khsaeTei.onServerEvent((event) => {
  switch (event.kind) {
    case 'listening':
      log(`Server listening on port ${event.port}`);
      break;
    case 'paired':
      log(`Paired: ${event.clientName || event.remote}`);
      break;
    case 'pair_failed':
      log(`Rejected wrong code from ${event.remote}`);
      break;
    case 'whip':
      log(`Whip received from ${event.remote} -> Enter sent`);
      break;
    case 'keypress_failed':
      log(`Keypress failed: ${event.error}`);
      break;
    case 'disconnected':
      log(`Disconnected: ${event.remote}`);
      break;
    case 'code_regenerated':
      log('Pairing code regenerated');
      break;
    default:
      log(JSON.stringify(event));
  }
});

regenBtn.addEventListener('click', async () => {
  const newCode = await window.khsaeTei.regenerateCode();
  codeEl.textContent = newCode;
});

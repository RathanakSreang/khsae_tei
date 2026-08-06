const { app, BrowserWindow, ipcMain } = require('electron');
const path = require('path');
const os = require('os');
const QRCode = require('qrcode');
const { WhipServer, DEFAULT_PORT } = require('./server');
const { RelayClient } = require('./relay_client');
const discovery = require('./discovery');

let mainWindow;
let whipServer;
let relayClient;

function getLanIp() {
  const interfaces = os.networkInterfaces();
  for (const name of Object.keys(interfaces)) {
    for (const iface of interfaces[name]) {
      if (iface.family === 'IPv4' && !iface.internal) {
        return iface.address;
      }
    }
  }
  return '127.0.0.1';
}

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 420,
    height: 660,
    icon: path.join(__dirname, '..', 'assets', 'icon.png'),
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });
  mainWindow.loadFile(path.join(__dirname, '..', 'renderer', 'index.html'));
}

async function sendServerInfo() {
  if (!mainWindow) return;
  const ip = getLanIp();
  const port = whipServer.port;
  const code = whipServer.code;
  const qrDataUrl = await QRCode.toDataURL(`ws://${ip}:${port}?code=${code}`);
  mainWindow.webContents.send('server-info', { ip, port, code, qrDataUrl });
}

app.whenReady().then(() => {
  createWindow();

  whipServer = new WhipServer(DEFAULT_PORT);
  whipServer.on('event', (event) => {
    if (mainWindow) mainWindow.webContents.send('server-event', event);
  });
  whipServer.start();
  discovery.advertise(whipServer.port);

  relayClient = new RelayClient(whipServer);
  relayClient.on('event', (event) => {
    if (mainWindow) mainWindow.webContents.send('server-event', event);
  });

  mainWindow.webContents.on('did-finish-load', sendServerInfo);

  ipcMain.handle('regenerate-code', async () => {
    whipServer.regenerateCode();
    await sendServerInfo();
    return whipServer.code;
  });

  ipcMain.handle('relay-connect', (_event, url) => {
    relayClient.connect(url);
  });

  ipcMain.handle('relay-disconnect', () => {
    relayClient.disconnect();
  });
});

app.on('window-all-closed', () => {
  discovery.stop();
  if (relayClient) relayClient.disconnect();
  if (whipServer) whipServer.stop();
  if (process.platform !== 'darwin') app.quit();
});

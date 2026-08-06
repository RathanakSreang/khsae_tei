const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('khsaeTei', {
  onServerInfo: (callback) => ipcRenderer.on('server-info', (_e, info) => callback(info)),
  onServerEvent: (callback) => ipcRenderer.on('server-event', (_e, event) => callback(event)),
  regenerateCode: () => ipcRenderer.invoke('regenerate-code'),
  relayConnect: (url) => ipcRenderer.invoke('relay-connect', url),
  relayDisconnect: () => ipcRenderer.invoke('relay-disconnect'),
});

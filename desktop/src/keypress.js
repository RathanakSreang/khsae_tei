const { keyboard, Key } = require('@nut-tree-fork/nut-js');

async function simulateEnter() {
  await keyboard.pressKey(Key.Enter);
  await keyboard.releaseKey(Key.Enter);
}

module.exports = { simulateEnter };

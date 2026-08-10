from pynput.keyboard import Controller, Key

_keyboard = Controller()

_ARROW_KEYS = {
    "up": Key.up,
    "down": Key.down,
    "left": Key.left,
    "right": Key.right,
}


async def simulate_enter():
    _keyboard.press(Key.enter)
    _keyboard.release(Key.enter)


async def simulate_arrow(direction):
    key = _ARROW_KEYS[direction]
    _keyboard.press(key)
    _keyboard.release(key)

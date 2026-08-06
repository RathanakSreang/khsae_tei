from pynput.keyboard import Controller, Key

_keyboard = Controller()


async def simulate_enter():
    _keyboard.press(Key.enter)
    _keyboard.release(Key.enter)

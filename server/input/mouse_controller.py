import pyautogui
from Xlib import display as xlib_display

pyautogui.PAUSE = 0
pyautogui.FAILSAFE = False

class MouseController:

    def __init__(self, display=None):
        self.display = display if display is not None else xlib_display.Display()

    def move_relative(self, dx, dy):
        self.display.warp_pointer(int(dx), int(dy))
        self.display.flush()

    def press(self, button):
        pyautogui.mouseDown(button=button)

    def release(self, button):
        pyautogui.mouseUp(button=button)

import pyautogui

pyautogui.PAUSE = 0

class FailsafeTriggeredError(Exception):
    """Raised when the cursor hits pyautogui's failsafe corner"""

class MouseController:

    def move_relative(self, dx, dy):
        try:
            pyautogui.moveRel(dx, dy, duration=0)
        except pyautogui.FailSafeException as exc:
            raise FailsafeTriggeredError("Cursor hit failsafe zone corner") from exc

    def press(self, button):
        pyautogui.mouseDown(button=button)

    def release(self, button):
        pyautogui.mouseUp(button=button)
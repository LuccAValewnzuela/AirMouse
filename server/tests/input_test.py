from server.input.mouse_controller import MouseController, FailsafeTriggeredError
import unittest
from unittest.mock import patch
import pyautogui

class InputTest(unittest.TestCase):

    def setUp(self):
        self.service = MouseController()

    @patch("server.input.mouse_controller.pyautogui.moveRel")
    def test_move_safe(self, mock_move):
        self.service.move_relative(10, 20)
        mock_move.assert_called_once_with(10, 20, duration=0)

    @patch("server.input.mouse_controller.pyautogui.moveRel")
    def test_move_failsafe(self, mock_move):
        mock_move.side_effect = pyautogui.FailSafeException
        with self.assertRaises(FailsafeTriggeredError) as excep:
            self.service.move_relative(0,0)
        self.assertIsInstance(excep.exception.__cause__, pyautogui.FailSafeException)

    @patch("server.input.mouse_controller.pyautogui.mouseDown")
    def test_mouse_down(self, mock_down):
        self.service.press("left")
        mock_down.assert_called_once_with(button="left")

    @patch("server.input.mouse_controller.pyautogui.mouseUp")
    def test_mouse_up(self, mock_up):
        self.service.release("left")
        mock_up.assert_called_once_with(button="left")

if __name__ == "__main__":
    unittest.main()
import unittest
from unittest.mock import MagicMock, patch

import pyautogui

from server.input.mouse_controller import MouseController

class InputTest(unittest.TestCase):

    def setUp(self):
        self.display = MagicMock()
        self.service = MouseController(display=self.display)

    def test_failsafe_is_disabled(self):
        self.assertFalse(pyautogui.FAILSAFE)
        self.assertEqual(pyautogui.PAUSE, 0)

    def test_move_warps_pointer_relative(self):
        self.service.move_relative(10, -20)
        self.display.warp_pointer.assert_called_once_with(10, -20)
        self.display.flush.assert_called_once_with()

    def test_move_truncates_fractional_pixels(self):
        self.service.move_relative(9.7, -0.2)
        self.display.warp_pointer.assert_called_once_with(9, 0)

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

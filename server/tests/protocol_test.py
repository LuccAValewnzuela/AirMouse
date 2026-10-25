import json
import unittest

from server.protocol.protocol import (
    ButtonDownInput,
    ButtonUpInput,
    JSONDecodeErrorTriggered,
    MessageParser,
    MoveInput,
    SensitivityInput,
)


class ProtocolTest(unittest.TestCase):

    def test_move_message_returns_move_input(self):
        parser = MessageParser('{"type": "move", "dx": 0.1, "dy": -0.05}')
        result = parser.parse_message()
        self.assertIsInstance(result, MoveInput)
        self.assertEqual(result, MoveInput(dx=0.1, dy=-0.05))

    def test_move_message_at_range_boundary_is_valid(self):
        parser = MessageParser('{"type": "move", "dx": 0.2, "dy": -0.2}')
        result = parser.parse_message()
        self.assertEqual(result, MoveInput(dx=0.2, dy=-0.2))

    def test_button_down_message_returns_button_down_input(self):
        parser = MessageParser('{"type": "button_down", "button": "left"}')
        result = parser.parse_message()
        self.assertEqual(result, ButtonDownInput(button="left"))

    def test_button_up_message_returns_button_up_input(self):
        parser = MessageParser('{"type": "button_up", "button": "right"}')
        result = parser.parse_message()
        self.assertEqual(result, ButtonUpInput(button="right"))

    def test_invalid_json_raises_json_decode_error_triggered(self):
        with self.assertRaises(JSONDecodeErrorTriggered) as ctx:
            MessageParser("{not valid json")
        self.assertIsInstance(ctx.exception.__cause__, json.JSONDecodeError)

    def test_unsupported_action_raises_value_error(self):
        payloads = [
            '{"type": "scroll", "amount": 3}',
            '{"dx": 0.1, "dy": 0.1}',
        ]
        for payload in payloads:
            with self.subTest(payload=payload):
                with self.assertRaisesRegex(ValueError, "not supported"):
                    MessageParser(payload).parse_message()

    def test_move_with_non_numeric_dx_raises_value_error(self):
        with self.assertRaisesRegex(ValueError, "dx value must be numeric"):
            MessageParser('{"type": "move", "dx": "fast", "dy": 0.1}').parse_message()

    def test_move_with_non_numeric_dy_raises_value_error(self):
        with self.assertRaisesRegex(ValueError, "dy value must be numeric"):
            MessageParser('{"type": "move", "dx": 0.1, "dy": [5]}').parse_message()

    def test_move_out_of_range_raises_value_error(self):
        payloads = [
            '{"type": "move", "dx": 0.5, "dy": 0.0}',
            '{"type": "move", "dx": 0.0, "dy": -0.9}',
            '{"type": "move", "dx": 1, "dy": 1}',
        ]
        for payload in payloads:
            with self.subTest(payload=payload):
                with self.assertRaisesRegex(ValueError, "Invalid movement values"):
                    MessageParser(payload).parse_message()

    def test_button_message_with_non_string_button_raises_value_error(self):
        with self.assertRaisesRegex(ValueError, "button value must be string"):
            MessageParser('{"type": "button_down", "button": 3}').parse_message()

    def test_button_message_with_unknown_button_raises_value_error(self):
        with self.assertRaisesRegex(ValueError, "button value is not correct"):
            MessageParser('{"type": "button_up", "button": "middle"}').parse_message()

    def test_sensitivity_message_returns_sensitivity_input(self):
        parser = MessageParser('{"type": "sensitivity", "value": 4000}')
        result = parser.parse_message()
        self.assertEqual(result, SensitivityInput(value=4000))

    def test_sensitivity_message_at_range_boundary_is_valid(self):
        for value in (100, 20000):
            with self.subTest(value=value):
                parser = MessageParser(f'{{"type": "sensitivity", "value": {value}}}')
                result = parser.parse_message()
                self.assertEqual(result, SensitivityInput(value=value))

    def test_sensitivity_with_non_numeric_value_raises_value_error(self):
        with self.assertRaisesRegex(ValueError, "sensitivity value must be numeric"):
            MessageParser('{"type": "sensitivity", "value": "fast"}').parse_message()

    def test_sensitivity_with_boolean_value_raises_value_error(self):
        with self.assertRaisesRegex(ValueError, "sensitivity value must be numeric"):
            MessageParser('{"type": "sensitivity", "value": true}').parse_message()

    def test_sensitivity_out_of_range_raises_value_error(self):
        payloads = [
            '{"type": "sensitivity", "value": 50}',
            '{"type": "sensitivity", "value": 60001}',
            '{"type": "sensitivity", "value": 0}',
        ]
        for payload in payloads:
            with self.subTest(payload=payload):
                with self.assertRaisesRegex(ValueError, "sensitivity value out of range"):
                    MessageParser(payload).parse_message()


if __name__ == "__main__":
    unittest.main()

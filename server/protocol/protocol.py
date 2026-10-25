from dataclasses import dataclass
import json

ACCEPTED_ACTIONS = ["move", "button_down", "button_up", "sensitivity"]

@dataclass
class MoveInput:
    dx: float
    dy: float
    type: str = "move"

@dataclass
class ButtonDownInput:
    button: str
    type: str = "button_down"

@dataclass
class ButtonUpInput:
    button: str
    type: str = "button_up"

@dataclass
class SensitivityInput:
    value: float
    type: str = "sensitivity"

class JSONDecodeErrorTriggered(Exception):
    """Raised when the raw message recieved is invalid"""

class MessageParser():

    def __init__(self, raw_message: str):
        try:
            data = json.loads(raw_message)
            self.message = data
        except json.JSONDecodeError as exc:
            raise JSONDecodeErrorTriggered("Invalid JSON from message") from exc

    def parse_message(self) -> MoveInput | ButtonDownInput | ButtonUpInput | SensitivityInput:
        message_action = self.message.get("type")

        if message_action not in ACCEPTED_ACTIONS:
            raise ValueError("Message action not supported")

        if message_action == "move":
            return self._parse_move_message()
        elif message_action == "sensitivity":
            return self._parse_sensitivity_message()
        else:
            return self._parse_button_message()

    def _parse_move_message(self) -> MoveInput:
        dx = self.message.get("dx")
        dy = self.message.get("dy")

        if not isinstance(dx, (int, float)):
            raise ValueError("dx value must be numeric")
        if not isinstance(dy, (int, float)):
            raise ValueError("dy value must be numeric")

        if not (-0.2 <= dx <= 0.2) or  not(-0.2 <= dy <= 0.2):
            raise ValueError("Invalid movement values for dx and/or dy")

        return MoveInput(dx, dy)

    def _parse_sensitivity_message(self) -> SensitivityInput:
        value = self.message.get("value")

        if not isinstance(value, (int, float)) or isinstance(value, bool):
            raise ValueError("sensitivity value must be numeric")
        if not (100 <= value <= 20000):
            raise ValueError("sensitivity value out of range")

        return SensitivityInput(value)

    def _parse_button_message(self) -> ButtonDownInput | ButtonUpInput:
        action = self.message.get("type")
        button = self.message.get("button")

        if not isinstance(button, str):
            raise ValueError("button value must be string")
        if button not in ["right", "left"]:
            raise ValueError("button value is not correct")

        return ButtonUpInput(button) if action == "button_up" else ButtonDownInput(button)
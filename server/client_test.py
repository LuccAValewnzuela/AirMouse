import websockets
import asyncio
import json

WS_URL = "ws://127.0.0.1:8765"
MESSAGES = [
    {"type": "move", "dx": 0.05, "dy": 0.05},
    {"type": "move", "dx": -0.05, "dy": 0.05},
    {"type": "move", "dx": 0.1, "dy": -0.1},
    {"type": "move", "dx": 0.05, "dy": 0.05},
    {"type": "move", "dx": 0.05, "dy": 0.05},
    {"type": "button_down", "button": "left"},
    {"type": "move", "dx": 0.21, "dy": -0.19},
    {"type": "button_up", "button": "left"},
]

async def main():

    async with websockets.connect(WS_URL) as websocket:
        for message in MESSAGES:
            raw_message = json.dumps(message)
            await websocket.send(raw_message)
            print(f"Message sent: {raw_message}")

            await asyncio.sleep(0.1)

if __name__ == "__main__":
    asyncio.run(main())
import asyncio
import logging

from server.connection.server import WebSocketServer
from server.input.mouse_controller import MouseController
from server.movement.movement import MovementProcessor
from server.protocol.protocol import MessageParser

mouse = MouseController()
movement = MovementProcessor()

def handle_message(raw_message: str):
    message = MessageParser(raw_message).parse_message()

    if message.type == "move":
        dx_pixel, dy_pixel = movement.process(message.dx, message.dy)
        mouse.move_relative(dx_pixel, dy_pixel)
    elif message.type == "button_down":
        mouse.press(message.button)
    elif message.type == "button_up":
        mouse.release(message.button)

async def main():
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(name)s %(levelname)s %(message)s",
    )
    server = WebSocketServer(on_message=handle_message)
    await server.start()

if __name__ == "__main__":
    asyncio.run(main())

import logging
import websockets

logger = logging.getLogger(__name__)

class ConnectionClosedError(Exception):
    """Raised when the connection with a client is closed"""

class WebSocketServer():

    def __init__(self, on_message, host="0.0.0.0", port=8765):
        self.host = host
        self.port = port
        self.on_message = on_message
        self.server = None

    async def handle_client(self, websocket):
        logger.info("Client connected")

        try:
            async for message in websocket:
                logger.info("Message received: %s", message)
                self.on_message(message)

        except websockets.exceptions.ConnectionClosed as exc:
            raise ConnectionClosedError("Connection closed") from exc

    async def start(self):
        self.server = await websockets.serve(self.handle_client, self.host, self.port)
        logger.info("Server listening on %s:%s", self.host, self.port)

        await self.server.serve_forever()

    async def stop(self):
        if self.server is not None:
            self.server.close()
            await self.server.wait_closed()
            logger.info("Server closed")
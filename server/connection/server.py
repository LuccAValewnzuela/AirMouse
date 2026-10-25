import logging
import socket

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
        self._enable_tcp_nodelay(websocket)
        logger.info("Client connected")

        try:
            async for message in websocket:
                logger.debug("Message received: %s", message)
                self.on_message(message)

        except websockets.exceptions.ConnectionClosed as exc:
            raise ConnectionClosedError("Connection closed") from exc

    @staticmethod
    def _enable_tcp_nodelay(websocket):
        transport = getattr(websocket, "transport", None)
        sock = transport.get_extra_info("socket") if transport is not None else None
        if sock is None:
            return
        try:
            sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        except OSError:
            logger.debug("Could not set TCP_NODELAY on client socket")

    async def start(self):
        self.server = await websockets.serve(self.handle_client, self.host, self.port)
        logger.info("Server listening on %s:%s", self.host, self.port)

        await self.server.serve_forever()

    async def stop(self):
        if self.server is not None:
            self.server.close()
            await self.server.wait_closed()
            logger.info("Server closed")
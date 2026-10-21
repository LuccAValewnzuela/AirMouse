import asyncio
import unittest
from unittest.mock import AsyncMock, MagicMock, call, patch

import websockets
import websockets.exceptions

from server.connection.server import ConnectionClosedError, WebSocketServer


class FakeWebSocket:
    def __init__(self, messages=None, error=None):
        self._messages = list(messages or [])
        self._error = error

    def __aiter__(self):
        return self

    async def __anext__(self):
        if self._messages:
            return self._messages.pop(0)
        if self._error is not None:
            error, self._error = self._error, None
            raise error
        raise StopAsyncIteration


class WebSocketServerUnitTest(unittest.TestCase):

    def setUp(self):
        self.received = MagicMock()
        self.server = WebSocketServer(self.received)

    @patch("connection.server.websockets.serve", new_callable=AsyncMock)
    def test_start_serves_on_host_and_port(self, mock_serve):
        mock_serve.return_value.serve_forever = AsyncMock()
        asyncio.run(self.server.start())
        mock_serve.assert_awaited_once_with(
            self.server.handle_client, "0.0.0.0", 8765
        )

    def test_stop_closes_the_server(self):
        mock_running_server = MagicMock()
        mock_running_server.close = MagicMock()
        mock_running_server.wait_closed = AsyncMock()
        self.server.server = mock_running_server

        asyncio.run(self.server.stop())

        mock_running_server.close.assert_called_once_with()
        mock_running_server.wait_closed.assert_awaited_once()

    def test_stop_without_start_is_safe(self):
        asyncio.run(self.server.stop())

    def test_handle_client_forwards_each_message_to_callback(self):
        fake = FakeWebSocket(["hello", "world"])

        with self.assertLogs("connection.server", level="INFO") as logs:
            asyncio.run(self.server.handle_client(fake))

        self.received.assert_has_calls([call("hello"), call("world")])
        self.assertEqual(self.received.call_count, 2)
        self.assertEqual(
            [record.getMessage() for record in logs.records],
            ["Client connected", "Message received: hello", "Message received: world"],
        )

    def test_handle_client_translates_connection_closed(self):
        error = websockets.exceptions.ConnectionClosedError(None, None)
        fake = FakeWebSocket(error=error)

        with self.assertRaises(ConnectionClosedError) as ctx:
            asyncio.run(self.server.handle_client(fake))

        self.assertIsInstance(
            ctx.exception.__cause__, websockets.exceptions.ConnectionClosed
        )


class WebSocketServerIntegrationTest(unittest.IsolatedAsyncioTestCase):

    async def test_real_client_messages_reach_callback(self):
        received = []
        got_all = asyncio.Event()

        def on_message(message):
            received.append(message)
            if len(received) >= 3:
                got_all.set()

        server = WebSocketServer(on_message, host="127.0.0.1", port=8791)
        server_task = asyncio.create_task(server.start())

        client = None
        for _ in range(100):
            try:
                client = await websockets.connect("ws://127.0.0.1:8791")
                break
            except OSError:
                await asyncio.sleep(0.02)
        self.assertIsNotNone(client, "server never started listening")

        try:
            await client.send("hello")
            await client.send("world")
            await client.send("!")
            await asyncio.wait_for(got_all.wait(), timeout=2)
        finally:
            await client.close()
            await server.stop()
            await asyncio.wait_for(server_task, timeout=2)

        self.assertEqual(received, ["hello", "world", "!"])


if __name__ == "__main__":
    unittest.main()

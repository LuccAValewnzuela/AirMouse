import Foundation
import os

enum ConnectionState { case disconnected, connecting, connected }

final class WebSocketClient: NSObject, URLSessionWebSocketDelegate {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: String(describing: WebSocketClient.self))
    static let serverURL = URL(string: "ws://100.121.155.27:8765")!

    private let url : URL
    private let stateQueue = DispatchQueue(label: "ws.state")
    private var session: URLSession!
    private var task: URLSessionWebSocketTask?
    private var shouldReconnect = false
    private var reconnectAttempts = 0
    private var pendingRetry: DispatchWorkItem?

    var onStateChange: ((ConnectionState) -> Void)?

    override init() {
        self.url = Self.serverURL
        super.init()
        self.session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }

    func connect() {
        stateQueue.async{
            guard self.task == nil else { return }
            self.shouldReconnect = true
            self.setState(.connecting)
            let task = self.session.webSocketTask(with: self.url)
            self.task = task
            task.resume()
            self.logger.info("Connecting to websocket")
        }
    }

    func disconnect() {
        stateQueue.async{
            self.pendingRetry?.cancel()
            self.pendingRetry = nil

            self.task?.cancel(with: .goingAway, reason: nil)
            self.task = nil
            self.shouldReconnect = false
            self.setState(.disconnected)
            self.logger.info("Disconnected from websocket")
        }
    }

    func sendText(_ text: String) {
        let currentTask: URLSessionWebSocketTask? = stateQueue.sync{ task }
        currentTask?.send(.string(text)) {
            error in if let error { self.handleDisconnect(from: error) }
        }
    }

    private func setState(_ newState: ConnectionState ) {
        DispatchQueue.main.async{ self.onStateChange?(newState) }
    }

    private func handleDisconnect(from error: Error?) {
        stateQueue.async{
            self.task = nil
            guard self.shouldReconnect else { return }
            let retry = DispatchWorkItem { [weak self] self?.connect() }
            self.pendingRetry = retry
            let delay = min(0.5 * pow(2, Double(self.reconnectAttempts)), 10)
            self.reconnectAttempts += 1
            self.setState(.connecting)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: retry)
        }
    }

    
    func urlSession(_ s: URLSession, webSocketTask t: URLSessionWebSocketTask, didOpenWithProtocol p: String?) {
        stateQueue.async{
            self.reconnectAttempts = 0
            self.setState(.connected)
            self.logger.info("Connected to websocket correctly")
        }
        listenForClose()
    }

    func urlSession(_ s: URLSession, webSocketTask t: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        self.handleDisconnect(from: nil)
    }

    //Listen to detect failure
    private func listenForClose() {
        let currentTask: URLSessionWebSocketTask? = stateQueue.sync { task }
        currentTask?.receive { [weak self] result in
            switch result {
            case .success: self?.listenForClose()

            case .failure: self?.handleDisconnect(from: nil)
            }
        }
    }
}
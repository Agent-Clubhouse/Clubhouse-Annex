import Foundation

enum WSEvent: Sendable {
    case snapshot(SnapshotPayload)
    case ptyData(PtyDataPayload)
    case ptyExit(PtyExitPayload)
    case hookEvent(HookEventPayload)
    case themeChanged(ThemeColors)
    case agentSpawned(AgentSpawnedPayload)
    case agentStatus(AgentStatusPayload)
    case agentCompleted(AgentCompletedPayload)
    case agentWoken(AgentWokenPayload)
    case permissionRequest(PermissionRequestPayload)
    case disconnected(Error?)
}

final class WebSocketClient: Sendable {
    private let url: URL
    private let session: URLSession
    nonisolated(unsafe) private var task: URLSessionWebSocketTask?
    nonisolated(unsafe) private var isConnected = false

    init(url: URL, session: URLSession = .shared) {
        self.url = url
        self.session = session
    }

    func connect() -> AsyncStream<WSEvent> {
        AsyncStream { continuation in
            let wsTask = session.webSocketTask(with: url)
            self.task = wsTask
            self.isConnected = true
            print("[Annex] WS connecting to \(url)")
            wsTask.resume()

            Task {
                await self.receiveLoop(task: wsTask, continuation: continuation)
            }

            continuation.onTermination = { @Sendable _ in
                wsTask.cancel(with: .goingAway, reason: nil)
            }
        }
    }

    func disconnect() {
        isConnected = false
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }

    private func receiveLoop(task: URLSessionWebSocketTask, continuation: AsyncStream<WSEvent>.Continuation) async {
        while isConnected {
            do {
                let message = try await task.receive()
                switch message {
                case .string(let text):
                    if let event = parseMessage(text) {
                        continuation.yield(event)
                    }
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8),
                       let event = parseMessage(text) {
                        continuation.yield(event)
                    }
                @unknown default:
                    break
                }
            } catch {
                print("[Annex] WS receive error: \(error)")
                if isConnected {
                    continuation.yield(.disconnected(error))
                }
                continuation.finish()
                return
            }
        }
        continuation.finish()
    }

    private func parseMessage(_ text: String) -> WSEvent? {
        guard let data = text.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()

        // First decode the envelope to get the type
        guard let envelope = try? decoder.decode(WSMessage.self, from: data) else {
            print("[Annex] WS failed to decode envelope: \(text.prefix(200))")
            return nil
        }

        print("[Annex] WS received type=\(envelope.type)")

        // Re-decode payload section based on type
        struct PayloadExtractor<T: Decodable>: Decodable {
            let payload: T
        }

        func extract<T: Decodable>(_ type: T.Type) -> T? {
            do {
                return try decoder.decode(PayloadExtractor<T>.self, from: data).payload
            } catch {
                print("[Annex] WS decode error for \(envelope.type): \(error)")
                return nil
            }
        }

        switch envelope.type {
        case "snapshot":
            guard let payload = extract(SnapshotPayload.self) else { return nil }
            return .snapshot(payload)

        case "pty:data":
            guard let payload = extract(PtyDataPayload.self) else { return nil }
            return .ptyData(payload)

        case "pty:exit":
            guard let payload = extract(PtyExitPayload.self) else { return nil }
            return .ptyExit(payload)

        case "hook:event":
            guard let payload = extract(HookEventPayload.self) else { return nil }
            return .hookEvent(payload)

        case "theme:changed":
            guard let payload = extract(ThemeColors.self) else { return nil }
            return .themeChanged(payload)

        case "agent:spawned":
            guard let payload = extract(AgentSpawnedPayload.self) else { return nil }
            return .agentSpawned(payload)

        case "agent:status":
            guard let payload = extract(AgentStatusPayload.self) else { return nil }
            return .agentStatus(payload)

        case "agent:completed":
            guard let payload = extract(AgentCompletedPayload.self) else { return nil }
            return .agentCompleted(payload)

        case "agent:woken":
            guard let payload = extract(AgentWokenPayload.self) else { return nil }
            return .agentWoken(payload)

        case "permission:request":
            guard let payload = extract(PermissionRequestPayload.self) else { return nil }
            return .permissionRequest(payload)

        default:
            print("[Annex] WS unknown message type: \(envelope.type)")
            return nil
        }
    }
}

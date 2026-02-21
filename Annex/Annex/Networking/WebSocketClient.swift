import Foundation

enum WSEvent: Sendable {
    case snapshot(SnapshotPayload)
    case ptyData(PtyDataPayload)
    case ptyExit(PtyExitPayload)
    case hookEvent(HookEventPayload)
    case themeChanged(ThemeColors)
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
        guard let envelope = try? decoder.decode(WSMessage.self, from: data) else { return nil }

        // Re-decode payload section based on type
        // We need to extract just the payload from the raw data
        struct PayloadExtractor<T: Decodable>: Decodable {
            let payload: T
        }

        switch envelope.type {
        case "snapshot":
            guard let extracted = try? decoder.decode(PayloadExtractor<SnapshotPayload>.self, from: data) else { return nil }
            return .snapshot(extracted.payload)

        case "pty:data":
            guard let extracted = try? decoder.decode(PayloadExtractor<PtyDataPayload>.self, from: data) else { return nil }
            return .ptyData(extracted.payload)

        case "pty:exit":
            guard let extracted = try? decoder.decode(PayloadExtractor<PtyExitPayload>.self, from: data) else { return nil }
            return .ptyExit(extracted.payload)

        case "hook:event":
            guard let extracted = try? decoder.decode(PayloadExtractor<HookEventPayload>.self, from: data) else { return nil }
            return .hookEvent(extracted.payload)

        case "theme:changed":
            guard let extracted = try? decoder.decode(PayloadExtractor<ThemeColors>.self, from: data) else { return nil }
            return .themeChanged(extracted.payload)

        default:
            return nil
        }
    }
}

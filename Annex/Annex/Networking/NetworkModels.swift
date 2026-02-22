import Foundation

// MARK: - REST Responses

struct PairResponse: Codable, Sendable {
    let token: String
}

struct StatusResponse: Codable, Sendable {
    let version: String
    let deviceName: String
    let agentCount: Int
    let orchestratorCount: Int
}

struct ErrorResponse: Codable, Sendable {
    let error: String
}

// MARK: - WebSocket Message Envelope

struct WSMessage: Codable, Sendable {
    let type: String
    let payload: JSONValue
}

// MARK: - WebSocket Payloads

struct SnapshotPayload: Codable, Sendable {
    let projects: [Project]
    let agents: [String: [DurableAgent]]
    let theme: ThemeColors
    let orchestrators: [String: OrchestratorEntry]
}

struct PtyDataPayload: Codable, Sendable {
    let agentId: String
    let data: String
}

struct PtyExitPayload: Codable, Sendable {
    let agentId: String
    let exitCode: Int
}

struct HookEventPayload: Codable, Sendable {
    let agentId: String
    let event: ServerHookEvent
}

/// Wire format for hook events from the server (spec §5.5).
/// Converted to the app's `HookEvent` model after decoding.
struct ServerHookEvent: Codable, Sendable {
    let kind: HookEventKind
    let toolName: String?
    let toolInput: JSONValue?
    let message: String?
    let toolVerb: String?
    let timestamp: Int

    func toHookEvent(agentId: String) -> HookEvent {
        HookEvent(
            id: UUID(),
            agentId: agentId,
            kind: kind,
            toolName: toolName,
            toolVerb: toolVerb,
            message: message,
            timestamp: timestamp
        )
    }
}

// MARK: - Flexible JSON type for arbitrary payloads

enum JSONValue: Codable, Sendable, Hashable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let num = try? container.decode(Double.self) {
            self = .number(num)
        } else if let str = try? container.decode(String.self) {
            self = .string(str)
        } else if let arr = try? container.decode([JSONValue].self) {
            self = .array(arr)
        } else if let obj = try? container.decode([String: JSONValue].self) {
            self = .object(obj)
        } else {
            throw DecodingError.typeMismatch(
                JSONValue.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported JSON value")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .number(let n): try container.encode(n)
        case .bool(let b): try container.encode(b)
        case .object(let o): try container.encode(o)
        case .array(let a): try container.encode(a)
        case .null: try container.encodeNil()
        }
    }
}

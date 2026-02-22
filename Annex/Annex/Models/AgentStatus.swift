import Foundation

enum AgentStatus: String, Codable, Hashable, Sendable {
    case starting, running, sleeping, error
    case completed, failed, cancelled
}

enum AgentState: String, Codable, Hashable, Sendable {
    case idle, working
    case needsPermission = "needs_permission"
    case toolError = "tool_error"
}

struct AgentDetailedStatus: Hashable, Codable, Sendable {
    let state: AgentState
    let message: String
    let toolName: String?
    let timestamp: Int
}

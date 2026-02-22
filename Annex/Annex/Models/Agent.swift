import Foundation

// Matches spec §5.3 — the fields that come from the server
struct DurableAgent: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let name: String?
    let kind: String?              // "durable"
    let color: String?
    let branch: String?
    let model: String?
    let orchestrator: String?
    let freeAgentMode: Bool?
    let icon: String?

    // Client-side state derived from hook events / snapshot
    var status: AgentStatus?
    var mission: String?
    var detailedStatus: AgentDetailedStatus?
    var quickAgents: [QuickAgent]?
}

struct QuickAgent: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let name: String?
    let kind: String               // "quick"
    var status: AgentStatus?
    let mission: String?
    let prompt: String?
    let model: String?
    var detailedStatus: AgentDetailedStatus?
    let orchestrator: String?
    let parentAgentId: String?
    let projectId: String?
    let freeAgentMode: Bool?

    // Populated on completion (from agent:completed event)
    var summary: String?
    var filesModified: [String]?
    var durationMs: Int?
    var costUsd: Double?
    var toolsUsed: [String]?

    /// Display label: name, prompt preview, or ID
    var label: String {
        if let name, !name.isEmpty { return name }
        if let prompt, !prompt.isEmpty { return String(prompt.prefix(40)) }
        return id
    }
}

// Matches spec §5.6
struct OrchestratorEntry: Hashable, Codable, Sendable {
    let displayName: String
    let shortName: String
    let badge: String?
}

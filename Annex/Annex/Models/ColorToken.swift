import SwiftUI

// Matches spec §6 — the 8 agent/project colors
enum AgentColor: String, CaseIterable, Sendable {
    case indigo, emerald, amber, rose, cyan, violet, orange, teal

    var hex: String {
        switch self {
        case .indigo:  return "#6366f1"
        case .emerald: return "#10b981"
        case .amber:   return "#f59e0b"
        case .rose:    return "#f43f5e"
        case .cyan:    return "#06b6d4"
        case .violet:  return "#8b5cf6"
        case .orange:  return "#f97316"
        case .teal:    return "#14b8a6"
        }
    }

    var color: Color { Color(hex: hex) }

    static func color(for id: String?) -> Color {
        guard let id, let token = AgentColor(rawValue: id) else { return .gray }
        return token.color
    }
}

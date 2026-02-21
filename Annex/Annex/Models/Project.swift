import Foundation

struct Project: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let name: String
    let path: String
    let color: String?
    let icon: String?
    let displayName: String?
    let orchestrator: String?

    var label: String { displayName ?? name }
}

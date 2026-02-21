import Foundation

enum HookEventKind: String, Hashable, Sendable {
    case preTool = "pre_tool"
    case postTool = "post_tool"
    case toolError = "tool_error"
    case stop
    case notification
    case permissionRequest = "permission_request"
}

struct HookEvent: Identifiable, Hashable, Sendable {
    let id: UUID
    let agentId: String
    let kind: HookEventKind
    let toolName: String?
    let toolVerb: String?
    let message: String?
    let timestamp: Int
}

import Testing
import Foundation
import SwiftUI
@testable import Annex

// MARK: - Model Decoding Tests

struct ModelDecodingTests {
    @Test func decodePairResponse() throws {
        let json = """
        {"token": "550e8400-e29b-41d4-a716-446655440000"}
        """
        let response = try JSONDecoder().decode(PairResponse.self, from: Data(json.utf8))
        #expect(response.token == "550e8400-e29b-41d4-a716-446655440000")
    }

    @Test func decodeStatusResponse() throws {
        let json = """
        {"version":"1","deviceName":"Clubhouse on Mason's Mac","agentCount":5,"orchestratorCount":1}
        """
        let response = try JSONDecoder().decode(StatusResponse.self, from: Data(json.utf8))
        #expect(response.version == "1")
        #expect(response.deviceName == "Clubhouse on Mason's Mac")
        #expect(response.agentCount == 5)
        #expect(response.orchestratorCount == 1)
    }

    @Test func decodeErrorResponse() throws {
        let json = """
        {"error": "invalid_pin"}
        """
        let response = try JSONDecoder().decode(ErrorResponse.self, from: Data(json.utf8))
        #expect(response.error == "invalid_pin")
    }

    @Test func decodeProject() throws {
        let json = """
        {"id":"proj_abc123","name":"my-app","path":"/Users/mason/source/my-app","color":"emerald","icon":null,"displayName":"My App","orchestrator":"claude-code"}
        """
        let project = try JSONDecoder().decode(Project.self, from: Data(json.utf8))
        #expect(project.id == "proj_abc123")
        #expect(project.name == "my-app")
        #expect(project.color == "emerald")
        #expect(project.displayName == "My App")
        #expect(project.label == "My App")
    }

    @Test func decodeProjectWithoutDisplayName() throws {
        let json = """
        {"id":"proj_1","name":"api-server","path":"/path","color":null,"icon":null,"displayName":null,"orchestrator":null}
        """
        let project = try JSONDecoder().decode(Project.self, from: Data(json.utf8))
        #expect(project.label == "api-server")
    }

    @Test func decodeDurableAgent() throws {
        let json = """
        {"id":"durable_1737000000000_abc123","name":"faithful-urchin","kind":"durable","color":"emerald","branch":"faithful-urchin/standby","model":"claude-opus-4-5","orchestrator":"claude-code","freeAgentMode":false,"icon":null}
        """
        let agent = try JSONDecoder().decode(DurableAgent.self, from: Data(json.utf8))
        #expect(agent.id == "durable_1737000000000_abc123")
        #expect(agent.name == "faithful-urchin")
        #expect(agent.kind == "durable")
        #expect(agent.freeAgentMode == false)
        #expect(agent.orchestrator == "claude-code")
    }

    @Test func decodeOrchestratorEntry() throws {
        let json = """
        {"displayName":"Claude Code","shortName":"CC","badge":null}
        """
        let entry = try JSONDecoder().decode(OrchestratorEntry.self, from: Data(json.utf8))
        #expect(entry.displayName == "Claude Code")
        #expect(entry.shortName == "CC")
        #expect(entry.badge == nil)
    }

    @Test func decodeThemeColors() throws {
        let json = """
        {"base":"#1e1e2e","mantle":"#181825","crust":"#11111b","text":"#cdd6f4","subtext0":"#a6adc8","subtext1":"#bac2de","surface0":"#313244","surface1":"#45475a","surface2":"#585b70","accent":"#89b4fa","link":"#89b4fa"}
        """
        let theme = try JSONDecoder().decode(ThemeColors.self, from: Data(json.utf8))
        #expect(theme.base == "#1e1e2e")
        #expect(theme.accent == "#89b4fa")
        #expect(theme.isDark == true)
    }
}

// MARK: - WebSocket Message Parsing Tests

struct WSMessageParsingTests {
    @Test func decodeSnapshotMessage() throws {
        let json = """
        {
            "type": "snapshot",
            "payload": {
                "projects": [
                    {"id":"p1","name":"test","path":"/test","color":null,"icon":null,"displayName":null,"orchestrator":null}
                ],
                "agents": {},
                "theme": {"base":"#1e1e2e","mantle":"#181825","crust":"#11111b","text":"#cdd6f4","subtext0":"#a6adc8","subtext1":"#bac2de","surface0":"#313244","surface1":"#45475a","surface2":"#585b70","accent":"#89b4fa","link":"#89b4fa"},
                "orchestrators": {}
            }
        }
        """
        // Verify the envelope decodes
        let envelope = try JSONDecoder().decode(WSMessage.self, from: Data(json.utf8))
        #expect(envelope.type == "snapshot")

        // Verify the snapshot payload decodes
        struct PayloadExtractor<T: Decodable>: Decodable { let payload: T }
        let snapshot = try JSONDecoder().decode(PayloadExtractor<SnapshotPayload>.self, from: Data(json.utf8))
        #expect(snapshot.payload.projects.count == 1)
        #expect(snapshot.payload.projects[0].id == "p1")
    }

    @Test func decodePtyDataMessage() throws {
        let json = """
        {"type":"pty:data","payload":{"agentId":"agent_1","data":"Hello world\\n"}}
        """
        struct PayloadExtractor<T: Decodable>: Decodable { let payload: T }
        let msg = try JSONDecoder().decode(PayloadExtractor<PtyDataPayload>.self, from: Data(json.utf8))
        #expect(msg.payload.agentId == "agent_1")
        #expect(msg.payload.data == "Hello world\n")
    }

    @Test func decodePtyExitMessage() throws {
        let json = """
        {"type":"pty:exit","payload":{"agentId":"agent_1","exitCode":0}}
        """
        struct PayloadExtractor<T: Decodable>: Decodable { let payload: T }
        let msg = try JSONDecoder().decode(PayloadExtractor<PtyExitPayload>.self, from: Data(json.utf8))
        #expect(msg.payload.agentId == "agent_1")
        #expect(msg.payload.exitCode == 0)
    }

    @Test func decodeHookEventMessage() throws {
        let json = """
        {"type":"hook:event","payload":{"agentId":"agent_1","event":{"kind":"pre_tool","toolName":"EditFile","toolInput":{"path":"/src/main.ts"},"message":null,"toolVerb":"Editing file","timestamp":1737000000000}}}
        """
        struct PayloadExtractor<T: Decodable>: Decodable { let payload: T }
        let msg = try JSONDecoder().decode(PayloadExtractor<HookEventPayload>.self, from: Data(json.utf8))
        #expect(msg.payload.agentId == "agent_1")
        #expect(msg.payload.event.kind == .preTool)
        #expect(msg.payload.event.toolName == "EditFile")
        #expect(msg.payload.event.toolVerb == "Editing file")
        #expect(msg.payload.event.timestamp == 1737000000000)
    }

    @Test func decodeThemeChangedMessage() throws {
        let json = """
        {"type":"theme:changed","payload":{"base":"#1e1e2e","mantle":"#181825","crust":"#11111b","text":"#cdd6f4","subtext0":"#a6adc8","subtext1":"#bac2de","surface0":"#313244","surface1":"#45475a","surface2":"#585b70","accent":"#f38ba8","link":"#f38ba8"}}
        """
        struct PayloadExtractor<T: Decodable>: Decodable { let payload: T }
        let msg = try JSONDecoder().decode(PayloadExtractor<ThemeColors>.self, from: Data(json.utf8))
        #expect(msg.payload.accent == "#f38ba8")
    }

    @Test func hookEventConversion() throws {
        let serverEvent = ServerHookEvent(
            kind: .preTool,
            toolName: "Read",
            toolInput: .object(["path": .string("/src/main.ts")]),
            message: nil,
            toolVerb: "Reading file",
            timestamp: 1737000000000
        )
        let hookEvent = serverEvent.toHookEvent(agentId: "agent_1")
        #expect(hookEvent.agentId == "agent_1")
        #expect(hookEvent.kind == .preTool)
        #expect(hookEvent.toolName == "Read")
        #expect(hookEvent.toolVerb == "Reading file")
        #expect(hookEvent.timestamp == 1737000000000)
    }
}

// MARK: - HookEventKind Tests

struct HookEventKindTests {
    @Test func decodeAllKinds() throws {
        let kinds: [(String, HookEventKind)] = [
            ("\"pre_tool\"", .preTool),
            ("\"post_tool\"", .postTool),
            ("\"tool_error\"", .toolError),
            ("\"stop\"", .stop),
            ("\"notification\"", .notification),
            ("\"permission_request\"", .permissionRequest),
        ]
        for (json, expected) in kinds {
            let decoded = try JSONDecoder().decode(HookEventKind.self, from: Data(json.utf8))
            #expect(decoded == expected)
        }
    }
}

// MARK: - API Client Tests

struct APIClientTests {
    @Test func urlConstruction() throws {
        let client = AnnexAPIClient(host: "192.168.1.100", port: 8080)
        #expect(client.baseURL == "http://192.168.1.100:8080")
    }

    @Test func webSocketURLConstruction() throws {
        let client = AnnexAPIClient(host: "192.168.1.100", port: 8080)
        let url = try client.webSocketURL(token: "test-token-123")
        #expect(url.absoluteString == "ws://192.168.1.100:8080/ws?token=test-token-123")
    }
}

// MARK: - AppStore Tests

@MainActor
struct AppStoreTests {
    @Test func initialState() {
        let store = AppStore()
        #expect(store.isPaired == false)
        #expect(store.projects.isEmpty)
        #expect(store.agentsByProject.isEmpty)
        #expect(store.totalAgentCount == 0)
        #expect(store.connectionState.isConnected == false)
    }

    @Test func loadMockData() {
        let store = AppStore()
        store.loadMockData()
        #expect(store.isPaired == true)
        #expect(store.projects.count == 3)
        #expect(store.totalAgentCount == 5)
        #expect(store.serverName == "Clubhouse on Mason's Mac")
        #expect(store.connectionState.isConnected == true)
    }

    @Test func disconnect() {
        let store = AppStore()
        store.loadMockData()
        store.disconnect()
        #expect(store.isPaired == false)
        #expect(store.projects.isEmpty)
        #expect(store.agentsByProject.isEmpty)
        #expect(store.serverName == "")
        #expect(store.connectionState.isConnected == false)
    }

    @Test func agentsForProject() {
        let store = AppStore()
        store.loadMockData()
        let proj = store.projects[0]
        let agents = store.agents(for: proj)
        #expect(!agents.isEmpty)
    }

    @Test func activityForAgent() {
        let store = AppStore()
        store.loadMockData()
        let events = store.activity(for: "durable_1737000000000_abc123")
        #expect(!events.isEmpty)
    }

    @Test func runningAgentCount() {
        let store = AppStore()
        store.loadMockData()
        #expect(store.runningAgentCount > 0)
        #expect(store.runningAgentCount <= store.totalAgentCount)
    }
}

// MARK: - JSONValue Tests

struct JSONValueTests {
    @Test func decodeString() throws {
        let json = "\"hello\""
        let value = try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
        #expect(value == .string("hello"))
    }

    @Test func decodeNumber() throws {
        let json = "42"
        let value = try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
        #expect(value == .number(42.0))
    }

    @Test func decodeBool() throws {
        let json = "true"
        let value = try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
        #expect(value == .bool(true))
    }

    @Test func decodeNull() throws {
        let json = "null"
        let value = try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
        #expect(value == .null)
    }

    @Test func decodeObject() throws {
        let json = """
        {"key": "value", "num": 1}
        """
        let value = try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
        if case .object(let dict) = value {
            #expect(dict["key"] == .string("value"))
            #expect(dict["num"] == .number(1.0))
        } else {
            #expect(Bool(false), "Expected object")
        }
    }

    @Test func decodeArray() throws {
        let json = "[1, \"two\", true]"
        let value = try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
        if case .array(let arr) = value {
            #expect(arr.count == 3)
            #expect(arr[0] == .number(1.0))
            #expect(arr[1] == .string("two"))
            #expect(arr[2] == .bool(true))
        } else {
            #expect(Bool(false), "Expected array")
        }
    }
}

// MARK: - ConnectionState Tests

struct ConnectionStateTests {
    @Test func labels() {
        #expect(ConnectionState.disconnected.label == "Disconnected")
        #expect(ConnectionState.connected.label == "Connected")
        #expect(ConnectionState.connecting.label == "Connecting...")
        #expect(ConnectionState.reconnecting(attempt: 3).label == "Reconnecting (3)...")
    }

    @Test func isConnected() {
        #expect(ConnectionState.connected.isConnected == true)
        #expect(ConnectionState.disconnected.isConnected == false)
        #expect(ConnectionState.reconnecting(attempt: 1).isConnected == false)
    }
}

// MARK: - AgentColor Tests

struct AgentColorTests {
    @Test func allColorsHaveHex() {
        for color in AgentColor.allCases {
            #expect(color.hex.hasPrefix("#"))
            #expect(color.hex.count == 7)
        }
    }

    @Test func colorForId() {
        let color = AgentColor.color(for: "emerald")
        #expect(color != .gray)
    }

    @Test func colorForInvalidId() {
        let color = AgentColor.color(for: "nonexistent")
        #expect(color == .gray)
    }
}

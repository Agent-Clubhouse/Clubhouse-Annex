import Foundation

enum ConnectionState: Sendable {
    case disconnected
    case discovering
    case pairing
    case connecting
    case connected
    case reconnecting(attempt: Int)

    var label: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .discovering: return "Searching..."
        case .pairing: return "Pairing..."
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .reconnecting(let n): return "Reconnecting (\(n))..."
        }
    }

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}

@Observable final class AppStore {
    // MARK: - State

    var projects: [Project] = []
    var agentsByProject: [String: [DurableAgent]] = [:]
    var activityByAgent: [String: [HookEvent]] = [:]
    var isPaired: Bool = false
    var theme: ThemeColors = .mock
    var serverName: String = ""
    var orchestrators: [String: OrchestratorEntry] = [:]
    var connectionState: ConnectionState = .disconnected
    var lastError: String?

    // MARK: - Networking

    private(set) var apiClient: AnnexAPIClient?
    private var webSocket: WebSocketClient?
    private var wsStreamTask: Task<Void, Never>?
    private var token: String?
    private var reconnectAttempt = 0
    private static let maxReconnectAttempts = 10

    // MARK: - Queries

    func agents(for project: Project) -> [DurableAgent] {
        agentsByProject[project.id] ?? []
    }

    func allQuickAgents(for project: Project) -> [QuickAgent] {
        agents(for: project).flatMap { $0.quickAgents ?? [] }
    }

    func activity(for agentId: String) -> [HookEvent] {
        activityByAgent[agentId] ?? []
    }

    var totalAgentCount: Int {
        agentsByProject.values.flatMap { $0 }.count
    }

    var runningAgentCount: Int {
        agentsByProject.values.flatMap { $0 }.filter { $0.status == .running }.count
    }

    // MARK: - Pairing

    func pair(host: String, port: UInt16, pin: String) async throws {
        connectionState = .pairing
        lastError = nil
        let client = AnnexAPIClient(host: host, port: port)

        do {
            let response = try await client.pair(pin: pin)
            self.token = response.token
            self.apiClient = client
            KeychainHelper.saveToken(response.token)
            KeychainHelper.saveServer(host: host, port: port)
            await connectAfterPairing()
        } catch let error as APIError {
            connectionState = .disconnected
            lastError = error.userMessage
            throw error
        }
    }

    /// Attempt to restore a previous session from Keychain.
    func restoreSession() async {
        guard let token = KeychainHelper.loadToken(),
              let server = KeychainHelper.loadServer() else { return }

        self.token = token
        let client = AnnexAPIClient(host: server.host, port: server.port)
        self.apiClient = client

        connectionState = .connecting
        do {
            let status = try await client.getStatus(token: token)
            serverName = status.deviceName
            await connectWebSocket()
        } catch {
            // Token invalid or server unreachable — clear and go to pairing
            KeychainHelper.clearAll()
            self.token = nil
            self.apiClient = nil
            connectionState = .disconnected
        }
    }

    // MARK: - Connection Lifecycle

    private func connectAfterPairing() async {
        guard let apiClient, let token else { return }
        connectionState = .connecting

        do {
            let status = try await apiClient.getStatus(token: token)
            serverName = status.deviceName
            isPaired = true
            await connectWebSocket()
        } catch {
            connectionState = .disconnected
            lastError = "Failed to connect after pairing"
        }
    }

    private func connectWebSocket() async {
        guard let apiClient, let token else { return }
        wsStreamTask?.cancel()
        webSocket?.disconnect()

        guard let url = try? apiClient.webSocketURL(token: token) else { return }
        let ws = WebSocketClient(url: url)
        self.webSocket = ws

        let stream = ws.connect()
        reconnectAttempt = 0

        wsStreamTask = Task {
            for await event in stream {
                await handleWSEvent(event)
            }
        }
    }

    private func handleWSEvent(_ event: WSEvent) async {
        switch event {
        case .snapshot(let payload):
            projects = payload.projects
            agentsByProject = payload.agents
            theme = payload.theme
            orchestrators = payload.orchestrators
            activityByAgent = [:]  // Reset activity on fresh snapshot
            connectionState = .connected
            isPaired = true

        case .ptyData:
            // PTY data is handled by terminal views if/when added
            break

        case .ptyExit:
            // Could update agent status, but snapshot updates will cover this
            break

        case .hookEvent(let payload):
            let hookEvent = payload.event.toHookEvent(agentId: payload.agentId)
            var events = activityByAgent[payload.agentId] ?? []
            events.append(hookEvent)
            activityByAgent[payload.agentId] = events

        case .themeChanged(let newTheme):
            theme = newTheme

        case .disconnected:
            if isPaired {
                await attemptReconnect()
            }
        }
    }

    private func attemptReconnect() async {
        guard reconnectAttempt < Self.maxReconnectAttempts else {
            // Exhausted retries — return to pairing
            disconnectInternal()
            lastError = "Lost connection to server"
            return
        }

        reconnectAttempt += 1
        connectionState = .reconnecting(attempt: reconnectAttempt)

        // Exponential backoff: 1s, 2s, 4s, 8s... capped at 30s
        let delay = min(pow(2.0, Double(reconnectAttempt - 1)), 30.0)
        try? await Task.sleep(for: .seconds(delay))

        guard isPaired else { return }

        // Check if token is still valid
        guard let apiClient, let token else {
            disconnectInternal()
            return
        }

        do {
            _ = try await apiClient.getStatus(token: token)
            await connectWebSocket()
        } catch let error as APIError {
            if case .unauthorized = error {
                // Token revoked — must re-pair
                disconnectInternal()
                lastError = "Session expired. Please re-pair."
            } else {
                // Network issue — keep trying
                await attemptReconnect()
            }
        }
    }

    // MARK: - Disconnect

    func disconnect() {
        disconnectInternal()
        KeychainHelper.clearAll()
    }

    private func disconnectInternal() {
        wsStreamTask?.cancel()
        wsStreamTask = nil
        webSocket?.disconnect()
        webSocket = nil
        isPaired = false
        connectionState = .disconnected
        projects = []
        agentsByProject = [:]
        activityByAgent = [:]
        serverName = ""
        orchestrators = [:]
        token = nil
        apiClient = nil
        reconnectAttempt = 0
    }

    // MARK: - Mock Data (for previews)

    func loadMockData() {
        projects = MockData.projects
        agentsByProject = MockData.agents
        activityByAgent = MockData.activity
        serverName = "Clubhouse on Mason's Mac"
        orchestrators = MockData.orchestrators
        isPaired = true
        connectionState = .connected
    }
}

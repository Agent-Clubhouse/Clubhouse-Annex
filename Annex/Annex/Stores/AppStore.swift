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
    var ptyBufferByAgent: [String: String] = [:]
    var isPaired: Bool = false
    var hasCompletedOnboarding: Bool = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
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

    func ptyBuffer(for agentId: String) -> String {
        ptyBufferByAgent[agentId] ?? ""
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
        print("[Annex] Pairing with host=\(host) port=\(port) baseURL=\(client.baseURL)")

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
            print("[Annex] Pair failed: \(error) — \(error.userMessage)")
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
        guard let apiClient, let token else {
            print("[Annex] connectAfterPairing: no apiClient or token")
            return
        }
        connectionState = .connecting

        do {
            let status = try await apiClient.getStatus(token: token)
            print("[Annex] Status: device=\(status.deviceName) agents=\(status.agentCount)")
            serverName = status.deviceName
            isPaired = true
            await connectWebSocket()
        } catch {
            print("[Annex] connectAfterPairing failed: \(error)")
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
            print("[Annex] Snapshot: \(payload.projects.count) projects, \(payload.agents.count) agent groups")
            projects = payload.projects
            agentsByProject = payload.agents
            theme = payload.theme
            orchestrators = payload.orchestrators
            activityByAgent = [:]
            ptyBufferByAgent = [:]
            connectionState = .connected
            isPaired = true

        case .ptyData(let payload):
            var buf = ptyBufferByAgent[payload.agentId] ?? ""
            buf.append(payload.data)
            // Cap at ~64KB to avoid unbounded growth
            if buf.count > 65_536 {
                buf = String(buf.suffix(49_152))
            }
            ptyBufferByAgent[payload.agentId] = buf

        case .ptyExit:
            // Could update agent status, but snapshot updates will cover this
            break

        case .hookEvent(let payload):
            print("[Annex] Hook event: agent=\(payload.agentId) kind=\(payload.event.kind)")
            let hookEvent = payload.event.toHookEvent(agentId: payload.agentId)
            var events = activityByAgent[payload.agentId] ?? []
            events.append(hookEvent)
            activityByAgent[payload.agentId] = events

        case .themeChanged(let newTheme):
            theme = newTheme

        case .disconnected(let error):
            print("[Annex] WS disconnected: \(String(describing: error))")
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

    // MARK: - Onboarding

    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }

    // MARK: - Disconnect & Reset

    func disconnect() {
        disconnectInternal()
        KeychainHelper.clearAll()
    }

    /// Full reset: disconnect, clear credentials, and return to welcome screen.
    func resetApp() {
        disconnect()
        hasCompletedOnboarding = false
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
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
        ptyBufferByAgent = [:]
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

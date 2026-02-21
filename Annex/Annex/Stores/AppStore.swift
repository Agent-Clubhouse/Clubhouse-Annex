import Foundation

@Observable class AppStore {
    var projects: [Project] = []
    var agentsByProject: [String: [DurableAgent]] = [:]
    var activityByAgent: [String: [HookEvent]] = [:]
    var isPaired: Bool = false
    var theme: ThemeColors = .mock
    var serverName: String = ""
    var orchestrators: [String: OrchestratorEntry] = [:]

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

    func disconnect() {
        isPaired = false
        projects = []
        agentsByProject = [:]
        activityByAgent = [:]
        serverName = ""
        orchestrators = [:]
    }

    func loadMockData() {
        projects = MockData.projects
        agentsByProject = MockData.agents
        activityByAgent = MockData.activity
        serverName = "Clubhouse on Mason's Mac"
        orchestrators = MockData.orchestrators
    }
}

import Foundation

enum APIError: Error, Sendable {
    case invalidURL
    case unauthorized
    case invalidPin
    case invalidJSON
    case notFound
    case projectNotFound
    case serverError(String)
    case networkError(Error)
    case decodingError(Error)

    var userMessage: String {
        switch self {
        case .invalidURL: return "Invalid server address"
        case .unauthorized: return "Session expired. Please re-pair."
        case .invalidPin: return "Invalid PIN. Check the code in Clubhouse."
        case .invalidJSON: return "Request error"
        case .notFound: return "Not found"
        case .projectNotFound: return "Project not found"
        case .serverError(let msg): return msg
        case .networkError: return "Cannot reach server"
        case .decodingError: return "Unexpected server response"
        }
    }
}

final class AnnexAPIClient: Sendable {
    let host: String
    let port: UInt16
    private let session: URLSession

    /// Host formatted for use in URLs (IPv6 addresses wrapped in brackets).
    private nonisolated var urlHost: String {
        if host.contains(":") {
            let escaped = host.replacingOccurrences(of: "%", with: "%25")
            return "[\(escaped)]"
        }
        return host
    }

    nonisolated var baseURL: String { "http://\(urlHost):\(port)" }

    init(host: String, port: UInt16, session: URLSession = .shared) {
        self.host = host
        self.port = port
        self.session = session
    }

    // MARK: - POST /pair

    func pair(pin: String) async throws(APIError) -> PairResponse {
        let url = try makeURL("/pair")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(["pin": pin])

        let data = try await perform(request)
        return try decode(PairResponse.self, from: data)
    }

    // MARK: - GET /api/v1/status

    func getStatus(token: String) async throws(APIError) -> StatusResponse {
        let url = try makeURL("/api/v1/status")
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let data = try await perform(request)
        return try decode(StatusResponse.self, from: data)
    }

    // MARK: - GET /api/v1/projects

    func getProjects(token: String) async throws(APIError) -> [Project] {
        let url = try makeURL("/api/v1/projects")
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let data = try await perform(request)
        return try decode([Project].self, from: data)
    }

    // MARK: - GET /api/v1/projects/{projectId}/agents

    func getAgents(projectId: String, token: String) async throws(APIError) -> [DurableAgent] {
        let url = try makeURL("/api/v1/projects/\(projectId)/agents")
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let data = try await perform(request)
        return try decode([DurableAgent].self, from: data)
    }

    // MARK: - GET /api/v1/agents/{agentId}/buffer

    func getBuffer(agentId: String, token: String) async throws(APIError) -> String {
        let url = try makeURL("/api/v1/agents/\(agentId)/buffer")
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let data = try await perform(request)
        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: - WebSocket URL

    func webSocketURL(token: String) throws(APIError) -> URL {
        guard let url = URL(string: "ws://\(urlHost):\(port)/ws?token=\(token)") else {
            throw .invalidURL
        }
        return url
    }

    // MARK: - Helpers

    private func makeURL(_ path: String) throws(APIError) -> URL {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw .invalidURL
        }
        return url
    }

    private nonisolated func perform(_ request: URLRequest) async throws(APIError) -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw .networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw .networkError(URLError(.badServerResponse))
        }

        switch http.statusCode {
        case 200:
            return data
        case 401:
            if let errResp = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                if errResp.error == "invalid_pin" { throw .invalidPin }
            }
            throw .unauthorized
        case 400:
            throw .invalidJSON
        case 404:
            if let errResp = try? JSONDecoder().decode(ErrorResponse.self, from: data),
               errResp.error == "project_not_found" {
                throw .projectNotFound
            }
            throw .notFound
        default:
            if let errResp = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw .serverError(errResp.error)
            }
            throw .serverError("HTTP \(http.statusCode)")
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws(APIError) -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw .decodingError(error)
        }
    }
}

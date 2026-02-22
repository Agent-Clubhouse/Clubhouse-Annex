import Foundation
import Network

struct DiscoveredServer: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let host: String
    let port: UInt16

    static func == (lhs: DiscoveredServer, rhs: DiscoveredServer) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

@Observable final class BonjourDiscovery {
    private(set) var servers: [DiscoveredServer] = []
    private(set) var isSearching = false

    private var browser: NWBrowser?
    private var connections: [String: NWConnection] = [:]

    func startSearching() {
        guard !isSearching else { return }
        isSearching = true
        servers = []

        let params = NWParameters()
        params.includePeerToPeer = true
        let browser = NWBrowser(for: .bonjour(type: "_clubhouse-annex._tcp", domain: nil), using: params)

        browser.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .failed:
                    self?.isSearching = false
                case .cancelled:
                    self?.isSearching = false
                default:
                    break
                }
            }
        }

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in
                self?.handleResultsChanged(results)
            }
        }

        browser.start(queue: .main)
        self.browser = browser
    }

    func stopSearching() {
        browser?.cancel()
        browser = nil
        isSearching = false
        for conn in connections.values {
            conn.cancel()
        }
        connections = [:]
    }

    private func handleResultsChanged(_ results: Set<NWBrowser.Result>) {
        // Track which endpoints we've seen
        var currentIds = Set<String>()

        for result in results {
            let endpointId = "\(result.endpoint)"
            currentIds.insert(endpointId)

            // Skip if we already have this server
            if servers.contains(where: { $0.id == endpointId }) {
                continue
            }

            // Resolve the endpoint to get host and port
            resolveEndpoint(result.endpoint, id: endpointId, metadata: result.metadata)
        }

        // Remove servers that are no longer visible
        servers.removeAll { !currentIds.contains($0.id) }
    }

    private func resolveEndpoint(_ endpoint: NWEndpoint, id: String, metadata: NWBrowser.Result.Metadata?) {
        let conn = NWConnection(to: endpoint, using: .tcp)
        connections[id] = conn

        // Extract service name from metadata or endpoint description
        let serviceName: String
        if case .service(let name, _, _, _) = endpoint {
            serviceName = name
        } else {
            serviceName = "Clubhouse Server"
        }

        conn.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                guard let self else { return }
                switch state {
                case .ready:
                    if let innerEndpoint = conn.currentPath?.remoteEndpoint,
                       case .hostPort(let host, let port) = innerEndpoint {
                        let hostStr: String
                        switch host {
                        case .ipv4(let addr):
                            // Strip interface scope ID (e.g. "%en0") from resolved address
                            let raw = "\(addr)"
                            hostStr = raw.split(separator: "%").first.map(String.init) ?? raw
                        case .ipv6(let addr):
                            let raw = "\(addr)"
                            hostStr = raw.split(separator: "%").first.map(String.init) ?? raw
                        case .name(let name, _):
                            hostStr = name
                        @unknown default:
                            hostStr = "\(host)"
                        }
                        let server = DiscoveredServer(
                            id: id,
                            name: serviceName,
                            host: hostStr,
                            port: port.rawValue
                        )
                        print("[Annex] Bonjour resolved: name=\(serviceName) host=\(hostStr) port=\(port.rawValue)")
                        if !self.servers.contains(where: { $0.id == id }) {
                            self.servers.append(server)
                        }
                    }
                    conn.cancel()
                    self.connections.removeValue(forKey: id)
                case .failed:
                    conn.cancel()
                    self.connections.removeValue(forKey: id)
                default:
                    break
                }
            }
        }

        conn.start(queue: .main)
    }
}

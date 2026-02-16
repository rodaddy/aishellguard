import Foundation
import Network

/// Lightweight HTTP API server for SSH host authorization checks.
/// Binds to 127.0.0.1 only (loopback) using Network.framework (no dependencies).
@MainActor
class APIServer: ObservableObject {
    private var listener: NWListener?
    private let stateManager: StateManager
    private let port: UInt16

    init(stateManager: StateManager, port: UInt16 = UInt16(AppSettings.apiPort)) {
        self.stateManager = stateManager
        self.port = port
        startServer()
    }

    private func startServer() {
        do {
            let params = NWParameters.tcp
            params.requiredLocalEndpoint = NWEndpoint.hostPort(
                host: NWEndpoint.Host("127.0.0.1"),
                port: NWEndpoint.Port(rawValue: port)!
            )

            listener = try NWListener(using: params)
            listener?.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in
                    self?.handleConnection(connection)
                }
            }
            listener?.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    print("[APIServer] Listening on 127.0.0.1:\(self.port)")
                case .failed(let error):
                    print("[APIServer] Failed to start: \(error)")
                default:
                    break
                }
            }
            listener?.start(queue: .main)
        } catch {
            print("[APIServer] Init error: \(error)")
        }
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .main)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, _, error in
            guard let self, let data, error == nil else {
                connection.cancel()
                return
            }

            let request = String(data: data, encoding: .utf8) ?? ""
            Task { @MainActor in
                let response = self.routeRequest(request)
                self.sendResponse(connection: connection, body: response)
            }
        }
    }

    private func routeRequest(_ raw: String) -> String {
        // Parse GET /check?host=...&user=...
        guard let firstLine = raw.split(separator: "\r\n").first ?? raw.split(separator: "\n").first else {
            return errorJSON("Bad request")
        }

        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2, parts[0] == "GET" else {
            return errorJSON("Method not allowed")
        }

        let pathAndQuery = String(parts[1])
        guard let url = URLComponents(string: pathAndQuery), url.path == "/check" else {
            return errorJSON("Not found. Use GET /check?host=<ip>&user=<user>")
        }

        let queryItems = url.queryItems ?? []
        guard let hostParam = queryItems.first(where: { $0.name == "host" })?.value, !hostParam.isEmpty else {
            return errorJSON("Missing 'host' parameter")
        }

        let userParam = queryItems.first(where: { $0.name == "user" })?.value

        return checkHost(target: hostParam, user: userParam)
    }

    private func checkHost(target: String, user: String?) -> String {
        if let host = stateManager.state.findHost(byIPOrHostname: target) {
            var fields: [String] = [
                "\"state\":\"\(host.state.rawValue)\"",
                "\"hostname\":\(jsonString(host.hostname))",
                "\"ip\":\"\(host.ip)\"",
                "\"user\":\"\(host.user)\"",
            ]
            if let note = host.note {
                fields.append("\"note\":\(jsonString(note))")
            }
            return "{\(fields.joined(separator: ","))}"
        }

        return "{\"state\":\"unknown\"}"
    }

    private func sendResponse(connection: NWConnection, body: String) {
        let bodyData = body.data(using: .utf8) ?? Data()
        let header = """
        HTTP/1.1 200 OK\r
        Content-Type: application/json\r
        Content-Length: \(bodyData.count)\r
        Connection: close\r
        \r\n
        """
        var responseData = header.data(using: .utf8) ?? Data()
        responseData.append(bodyData)

        connection.send(content: responseData, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func errorJSON(_ message: String) -> String {
        "{\"error\":\"\(message)\"}"
    }

    private func jsonString(_ value: String?) -> String {
        guard let value else { return "null" }
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    deinit {
        listener?.cancel()
    }
}

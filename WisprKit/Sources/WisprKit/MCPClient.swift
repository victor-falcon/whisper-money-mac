import Foundation

public enum WisprError: Error, LocalizedError, Equatable {
    case http(Int)
    case unauthorized
    case rpc(code: Int, message: String)
    case tool(String)
    case badResponse(String)

    public var errorDescription: String? {
        switch self {
        case .http(let code): return "El servidor respondió HTTP \(code)."
        case .unauthorized: return "Token rechazado por Wispr Money."
        case .rpc(_, let message): return "Error del servidor MCP: \(message)"
        case .tool(let message): return "Wispr Money devolvió un error: \(message)"
        case .badResponse(let detail): return "Respuesta inesperada: \(detail)"
        }
    }
}

/// Cliente MCP (transporte Streamable HTTP, JSON-RPC 2.0) contra el endpoint `/mcp` de Wispr Money.
///
/// Sin caché de ningún tipo: sesión efímera, sin `URLCache` y cada request ignora caché local y remota.
/// Cada llamada a una herramienta es una consulta en vivo al servidor.
public actor MCPClient {
    public static let protocolVersion = "2025-06-18"

    private let endpoint: URL
    private let token: String
    private let session: URLSession
    private var sessionID: String?
    private var initialized = false
    private var nextID = 1

    public init(endpoint: URL, token: String, session: URLSession? = nil) {
        self.endpoint = endpoint
        self.token = token
        self.session = session ?? MCPClient.makeUncachedSession()
    }

    public static func makeUncachedSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.timeoutIntervalForRequest = 20
        return URLSession(configuration: config)
    }

    /// Llama una herramienta y devuelve el texto (JSON) de su resultado.
    public func callTool(_ name: String, arguments: [String: JSONValue] = [:]) async throws -> Data {
        do {
            return try await callToolOnce(name, arguments: arguments)
        } catch WisprError.http(404) where sessionID != nil {
            // La sesión MCP expiró en el servidor: se renegocia una vez.
            resetSession()
            return try await callToolOnce(name, arguments: arguments)
        }
    }

    private func callToolOnce(_ name: String, arguments: [String: JSONValue]) async throws -> Data {
        try await ensureInitialized()
        let result = try await request(method: "tools/call",
                                       params: .object(["name": .string(name), "arguments": .object(arguments)]))
        let tool = try JSONDecoder().decode(ToolResult.self, from: JSONEncoder().encode(result))
        let text = tool.content.first(where: { $0.type == "text" })?.text ?? ""
        if tool.isError == true { throw WisprError.tool(text) }
        guard let data = text.data(using: .utf8) else { throw WisprError.badResponse("contenido no UTF-8") }
        return data
    }

    private func resetSession() {
        sessionID = nil
        initialized = false
    }

    private func ensureInitialized() async throws {
        guard !initialized else { return }
        _ = try await request(method: "initialize", params: .object([
            "protocolVersion": .string(Self.protocolVersion),
            "capabilities": .object([:]),
            "clientInfo": .object(["name": .string("WisprMac"), "version": .string("0.1.0")]),
        ]))
        try await notify(method: "notifications/initialized")
        initialized = true
    }

    private func baseRequest(body: Data) -> URLRequest {
        var req = URLRequest(url: endpoint, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData)
        req.httpMethod = "POST"
        req.httpBody = body
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        req.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        if initialized { req.setValue(Self.protocolVersion, forHTTPHeaderField: "MCP-Protocol-Version") }
        if let sessionID { req.setValue(sessionID, forHTTPHeaderField: "Mcp-Session-Id") }
        return req
    }

    private func notify(method: String) async throws {
        let body = try JSONEncoder().encode(RPCMessage(id: nil, method: method, params: nil))
        let (_, response) = try await session.data(for: baseRequest(body: body))
        try check(response)
    }

    private func request(method: String, params: JSONValue) async throws -> JSONValue {
        let id = nextID
        nextID += 1
        let body = try JSONEncoder().encode(RPCMessage(id: id, method: method, params: params))
        let (data, response) = try await session.data(for: baseRequest(body: body))
        let http = try check(response)
        if let sid = http.value(forHTTPHeaderField: "Mcp-Session-Id") { sessionID = sid }

        let contentType = http.value(forHTTPHeaderField: "Content-Type") ?? ""
        let reply: RPCResponse
        if contentType.contains("text/event-stream") {
            reply = try Self.parseSSE(data, id: id)
        } else {
            reply = try JSONDecoder().decode(RPCResponse.self, from: data)
        }
        if let error = reply.error { throw WisprError.rpc(code: error.code, message: error.message) }
        guard let result = reply.result else { throw WisprError.badResponse("sin result en \(method)") }
        return result
    }

    @discardableResult
    private func check(_ response: URLResponse) throws -> HTTPURLResponse {
        guard let http = response as? HTTPURLResponse else { throw WisprError.badResponse("no es HTTP") }
        switch http.statusCode {
        case 200..<300: return http
        case 401, 403: throw WisprError.unauthorized
        default: throw WisprError.http(http.statusCode)
        }
    }

    /// Extrae de un stream SSE el mensaje JSON-RPC que responde a `id`.
    static func parseSSE(_ data: Data, id: Int) throws -> RPCResponse {
        let text = String(decoding: data, as: UTF8.self).replacingOccurrences(of: "\r\n", with: "\n")
        for event in text.components(separatedBy: "\n\n") {
            let payload = event
                .split(separator: "\n", omittingEmptySubsequences: false)
                .filter { $0.hasPrefix("data:") }
                .map { $0.dropFirst(5).drop(while: { $0 == " " }) }
                .joined(separator: "\n")
            guard !payload.isEmpty,
                  let message = try? JSONDecoder().decode(RPCResponse.self, from: Data(payload.utf8)),
                  message.id == id
            else { continue }
            return message
        }
        throw WisprError.badResponse("el stream SSE no trajo la respuesta \(id)")
    }
}

struct RPCMessage: Encodable {
    let jsonrpc = "2.0"
    let id: Int?
    let method: String
    let params: JSONValue?

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(jsonrpc, forKey: .jsonrpc)
        try c.encodeIfPresent(id, forKey: .id)
        try c.encode(method, forKey: .method)
        try c.encodeIfPresent(params, forKey: .params)
    }

    enum CodingKeys: String, CodingKey { case jsonrpc, id, method, params }
}

struct RPCResponse: Decodable {
    struct RPCErrorBody: Decodable { let code: Int; let message: String }
    let id: Int?
    let result: JSONValue?
    let error: RPCErrorBody?
}

struct ToolResult: Decodable {
    struct Content: Decodable { let type: String; let text: String? }
    let content: [Content]
    let isError: Bool?
}

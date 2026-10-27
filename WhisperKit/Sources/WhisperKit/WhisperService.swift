import Foundation

/// Operaciones de Whisper Money. Cada método es una llamada en vivo al servidor; nada se guarda.
public struct WhisperService: Sendable {
    private let client: MCPClient

    public init(client: MCPClient) {
        self.client = client
    }

    public init(credentials: Credentials) {
        self.init(client: MCPClient(endpoint: credentials.endpoint, token: credentials.token))
    }

    public func budgets() async throws -> BudgetsResponse {
        try await call("list_budgets")
    }

    public func accounts() async throws -> AccountsResponse {
        try await call("list_accounts")
    }

    public func categories() async throws -> CategoriesResponse {
        try await call("list_categories")
    }

    public func transactions(_ filter: TransactionFilter) async throws -> TransactionsResponse {
        try await call("search_transactions", filter.arguments)
    }

    /// Crea un movimiento manual. Whisper Money no deduplica: solo para lo que el banco no va a sincronizar.
    public func createTransaction(_ new: NewTransaction) async throws {
        _ = try await client.callTool("create_transaction", arguments: new.arguments)
    }

    public func cashflow(from: String, to: String) async throws -> CashflowResponse {
        try await call("get_cashflow", ["from": .string(from), "to": .string(to)])
    }

    public func spending(from: String, to: String, parentCategoryID: String? = nil) async throws -> SpendingResponse {
        var args: [String: JSONValue] = ["from": .string(from), "to": .string(to)]
        if let parentCategoryID { args["parent_category_id"] = .string(parentCategoryID) }
        return try await call("spending_by_category", args)
    }

    public func netWorth(from: String, to: String, daily: Bool = false) async throws -> NetWorthResponse {
        try await call("get_net_worth", ["from": .string(from), "to": .string(to),
                                         "granularity": .string(daily ? "daily" : "monthly")])
    }

    private func call<T: Decodable>(_ tool: String, _ arguments: [String: JSONValue] = [:]) async throws -> T {
        let data = try await client.callTool(tool, arguments: arguments)
        return try WhisperDecoder.decode(T.self, from: data)
    }
}

public enum WhisperDecoder {
    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(type, from: data)
    }
}

/// Fechas `YYYY-MM-DD` en el calendario local, como las espera el MCP.
public enum WhisperDate {
    public static func string(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    public static func startOfMonth(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    public static func endOfMonth(_ date: Date, calendar: Calendar = .current) -> Date {
        let start = startOfMonth(date, calendar: calendar)
        return calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start) ?? date
    }

    /// Lee `YYYY-MM-DD` o `YYYY-MM` (etiquetas mensuales de `get_net_worth`). `nil` si no encaja.
    public static func date(_ string: String, calendar: Calendar = .current) -> Date? {
        let parts = string.split(separator: "-").map { Int($0) }
        guard (2...3).contains(parts.count), let year = parts[0], let month = parts[1] else { return nil }
        let day = parts.count == 3 ? parts[2] : 1
        guard let day else { return nil }
        return calendar.date(from: DateComponents(year: year, month: month, day: day))
    }
}

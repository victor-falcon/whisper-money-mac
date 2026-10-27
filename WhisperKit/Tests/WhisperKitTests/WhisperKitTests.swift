import Foundation
import Testing
@testable import WhisperKit

// Fixtures sintéticos con la misma forma que las respuestas reales del MCP (montos inventados).

let budgetsJSON = """
{"currency":"MXN","budgets":[
 {"id":"b1","name":"Comida","period_type":"monthly","period_start_day":1,"rollover_type":"reset","is_catch_all":false,
  "categories":[{"id":"c1","name":"Food"}],"labels":[],
  "current_period":{"id":"p1","start_date":"2026-01-01","end_date":"2026-01-31","allocated_amount":100000,
   "carried_over_amount":0,"spent_amount":150000,"remaining_amount":-50000,"processing_historical":false}},
 {"id":"b2","name":"Transporte","period_type":"monthly","period_start_day":1,"rollover_type":"reset","is_catch_all":false,
  "categories":[],"labels":[{"id":"l1","name":"Uber"}],
  "current_period":{"id":"p2","start_date":"2026-01-01","end_date":"2026-01-31","allocated_amount":80000,
   "carried_over_amount":20000,"spent_amount":25000,"remaining_amount":75000,"processing_historical":true}},
 {"id":"b3","name":"Sin periodo","period_type":"monthly","period_start_day":1,"rollover_type":"reset","is_catch_all":false,
  "categories":[],"labels":[],"current_period":null}
]}
"""

@Test func decodesBudgetsAndComputesPercent() throws {
    let r = try WhisperDecoder.decode(BudgetsResponse.self, from: Data(budgetsJSON.utf8))
    #expect(r.currency == "MXN")
    #expect(r.budgets.count == 3)
    let food = try #require(r.budgets[0].currentPeriod)
    #expect(food.spentFraction == 1.5)
    #expect(food.isOver)
    let transport = try #require(r.budgets[1].currentPeriod)
    #expect(transport.available == 100000)
    #expect(transport.spentFraction == 0.25)
    #expect(transport.processingHistorical)
    #expect(r.budgets[2].currentPeriod == nil)
}

@Test func decodesNetWorthDynamicKeys() throws {
    let json = """
    {"granularity":"monthly","current":{"current":-5000,"previous":-7000,"currency_code":"MXN"},
     "evolution":{"data":[
       {"month":"2026-01","timestamp":100,"acc-a":1000,"acc-b":-300},
       {"month":"2026-02","timestamp":200,"acc-a":1200}
     ],"accounts":{}},"currency_code":"MXN"}
    """
    let r = try WhisperDecoder.decode(NetWorthResponse.self, from: Data(json.utf8))
    #expect(r.current.current == -5000)
    #expect(r.evolution.data[0].label == "2026-01")
    #expect(r.latestBalances == ["acc-a": 1200, "acc-b": -300])
}

@Test func decodesTransactionsAccountsAndCashflow() throws {
    let tx = """
    {"space_id":"s","count":1,"transactions":[{"id":"t1","date":"2026-01-05","description":"Café","amount":-4500,
     "currency":"MXN","category_id":null,"category":null,"category_source":null,"account_id":"a1","account":"Débito",
     "source":"manually_created","creditor_name":null,"debtor_name":null,"split_parent_id":null,"labels":[]}]}
    """
    let t = try WhisperDecoder.decode(TransactionsResponse.self, from: Data(tx.utf8))
    #expect(t.transactions[0].amount == -4500)
    #expect(t.transactions[0].category == nil)

    let acc = """
    {"space_id":"s","accounts":[{"id":"a1","name":"Tarjeta","type":"credit_card","currency":"MXN","bank":"X",
     "is_connected":false,"ownership_percentage":100}]}
    """
    let a = try WhisperDecoder.decode(AccountsResponse.self, from: Data(acc.utf8))
    #expect(a.accounts[0].isLiability)

    let cf = """
    {"summary":{"current":{"income":100,"expense":50,"net":50,"savings_rate":50.0,"savings":0,"investments":0},
                "previous":{"income":0,"expense":0,"net":0,"savings_rate":null,"savings":0,"investments":0}},
     "sankey":{"income_categories":[{"category_id":null,"category":{"id":null,"name":"Unknown Income","type":"income",
        "color":"gray","icon":"HelpCircle"},"amount":100,"has_children":false,"is_direct":false}],
       "expense_categories":[],"total_income":100,"total_expense":50},
     "trend":{"data":[{"month":"2026-01","income":100,"expense":50,"net":50}]}}
    """
    let c = try WhisperDecoder.decode(CashflowResponse.self, from: Data(cf.utf8))
    #expect(c.summary.previous.savingsRate == nil)
    #expect(c.sankey.incomeCategories[0].category.id == nil)
}

@Test func formatsMoneyByCurrencyExponent() {
    #expect(Money.exponent(for: "MXN") == 2)
    #expect(Money.exponent(for: "CLP") == 0)
    #expect(Money.minor(fromMajor: Decimal(string: "12.345")!, currency: "MXN") == 1235)
    #expect(Money.format(123456, currency: "MXN").contains("1,234.56"))
}

@Test func parsesWhisperDatesAndMonthLabels() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/Mexico_City")!
    let day = WhisperDate.date("2026-09-15", calendar: calendar)
    #expect(day.map { calendar.dateComponents([.year, .month, .day], from: $0) } == DateComponents(year: 2026, month: 9, day: 15))
    let month = WhisperDate.date("2025-10", calendar: calendar)
    #expect(month.map { calendar.dateComponents([.year, .month, .day], from: $0) } == DateComponents(year: 2025, month: 10, day: 1))
    #expect(WhisperDate.date("", calendar: calendar) == nil)
    #expect(WhisperDate.date("octubre", calendar: calendar) == nil)
}

@Test func parsesSSEPickingMatchingID() throws {
    let sse = "event: message\r\ndata: {\"jsonrpc\":\"2.0\",\"method\":\"notifications/progress\"}\r\n\r\n" +
        "event: message\r\ndata: {\"jsonrpc\":\"2.0\",\"id\":7,\"result\":{\"ok\":true}}\r\n\r\n"
    let r = try MCPClient.parseSSE(Data(sse.utf8), id: 7)
    #expect(r.result == .object(["ok": .bool(true)]))
}

// MARK: Handshake contra un servidor MCP simulado

final class FakeMCPServer: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var log: [(method: String, session: String?, auth: String?)] = []
    nonisolated(unsafe) static var expireNextToolCall = false

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    // URLSession entrega el cuerpo a URLProtocol como stream, no en `httpBody`.
    static func readAll(_ stream: InputStream?) -> Data {
        guard let stream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let n = stream.read(&buffer, maxLength: buffer.count)
            if n <= 0 { break }
            data.append(buffer, count: n)
        }
        return data
    }

    override func startLoading() {
        let body = request.httpBody ?? Self.readAll(request.httpBodyStream)
        let json = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] ?? [:]
        let method = json["method"] as? String ?? ""
        let id = json["id"] as? Int
        let session = request.value(forHTTPHeaderField: "Mcp-Session-Id")
        Self.log.append((method, session, request.value(forHTTPHeaderField: "Authorization")))

        var status = 200
        var headers = ["Content-Type": "application/json"]
        var payload = Data()
        switch method {
        case "initialize":
            headers["Mcp-Session-Id"] = "sess-\(Self.log.count)"
            payload = Data("{\"jsonrpc\":\"2.0\",\"id\":\(id!),\"result\":{\"protocolVersion\":\"2025-06-18\"}}".utf8)
        case "notifications/initialized":
            status = 202
        case "tools/call" where Self.expireNextToolCall:
            Self.expireNextToolCall = false
            status = 404
        case "tools/call":
            headers["Content-Type"] = "text/event-stream"
            let text = budgetsJSON.replacingOccurrences(of: "\n", with: "")
            let result: [String: Any] = ["jsonrpc": "2.0", "id": id!,
                                         "result": ["content": [["type": "text", "text": text]]]]
            let line = String(decoding: try! JSONSerialization.data(withJSONObject: result), as: UTF8.self)
            payload = Data("event: message\ndata: \(line)\n\n".utf8)
        default:
            status = 400
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: payload)
        client?.urlProtocolDidFinishLoading(self)
    }
}

@Suite(.serialized) struct HandshakeTests {
    func makeService() -> WhisperService {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [FakeMCPServer.self]
        let client = MCPClient(endpoint: URL(string: "https://example.invalid/mcp")!, token: "tkn",
                               session: URLSession(configuration: config))
        return WhisperService(client: client)
    }

    @Test func handshakeThenToolCallWithSession() async throws {
        FakeMCPServer.log = []
        let service = makeService()
        let r = try await service.budgets()
        #expect(r.budgets.count == 3)
        #expect(FakeMCPServer.log.map(\.method) == ["initialize", "notifications/initialized", "tools/call"])
        #expect(FakeMCPServer.log[2].session == "sess-1")
        #expect(FakeMCPServer.log.allSatisfy { $0.auth == "Bearer tkn" })

        _ = try await service.budgets()   // segunda consulta: otra llamada real, sin repetir handshake
        #expect(FakeMCPServer.log.map(\.method).last == "tools/call")
        #expect(FakeMCPServer.log.count == 4)
    }

    @Test func expiredSessionRenegotiatesOnce() async throws {
        FakeMCPServer.log = []
        let service = makeService()
        _ = try await service.budgets()
        FakeMCPServer.expireNextToolCall = true
        let r = try await service.budgets()
        #expect(r.budgets.count == 3)
        #expect(FakeMCPServer.log.map(\.method).suffix(4) ==
                ["tools/call", "initialize", "notifications/initialized", "tools/call"])
    }
}

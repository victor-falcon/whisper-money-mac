#if DEBUG
import Foundation
import WhisperKit

/// Datos sintéticos solo para `#Preview`. Cifras inventadas; nunca datos reales de Whisper Money.
enum PreviewData {
    static let budgets: BudgetsResponse = decode("""
    {"currency":"MXN","budgets":[
     \(budget("b1", "Comida", spent: 336_000, allocated: 300_000, categories: ["Restaurantes", "Súper"])),
     \(budget("b2", "Transporte", spent: 129_000, allocated: 150_000, categories: ["Gasolina", "Taxis"])),
     \(budget("b3", "Ocio", spent: 87_000, allocated: 150_000, categories: ["Cine", "Conciertos"])),
     \(budget("b4", "Suscripciones", spent: 34_000, allocated: 100_000, categories: ["Streaming"]))
    ]}
    """)

    static let accounts: AccountsResponse = decode("""
    {"space_id":"demo","accounts":[
     {"id":"a1","name":"Nómina","type":"checking","currency":"MXN","bank":"Banco Uno","is_connected":true},
     {"id":"a2","name":"Ahorro","type":"savings","currency":"MXN","bank":"Banco Uno","is_connected":true},
     {"id":"a3","name":"Efectivo","type":"cash","currency":"MXN","bank":null,"is_connected":false},
     {"id":"c1","name":"Tarjeta oro","type":"credit_card","currency":"MXN","bank":"Banco Dos","is_connected":true},
     {"id":"c2","name":"Tarjeta digital","type":"credit_card","currency":"MXN","bank":"Banco Tres","is_connected":true},
     {"id":"l1","name":"Préstamo auto","type":"loan","currency":"MXN","bank":"Financiera","is_connected":false}
    ]}
    """)

    /// 12 meses: activos que crecen, tarjetas en negativo y un préstamo que baja.
    static let netWorth: NetWorthResponse = {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .month, value: -11, to: WhisperDate.startOfMonth(.now))!
        let points: [[String: Any]] = (0..<12).map { i in
            let date = calendar.date(byAdding: .month, value: i, to: start)!
            let label = String(WhisperDate.string(date).prefix(7))
            let wave = Int(sin(Double(i) / 1.7) * 400_000)
            return [
                "month": label,
                "timestamp": Int(date.timeIntervalSince1970),
                "a1": 2_400_000 + i * 90_000 + wave,
                "a2": 5_000_000 + i * 250_000,
                "a3": 300_000 - (i % 3) * 60_000,
                "c1": -(1_200_000 + (i % 4) * 350_000),
                "c2": -(400_000 + (i % 5) * 120_000),
                "l1": 9_000_000 - i * 400_000,
            ]
        }
        let json: [String: Any] = [
            "current": ["current": 4_024_523, "previous": 3_400_000, "currency_code": "MXN"],
            "evolution": ["data": points],
        ]
        return try! WhisperDecoder.decode(NetWorthResponse.self, from: JSONSerialization.data(withJSONObject: json))
    }()

    static let cashflow: CashflowResponse = decode("""
    {"summary":{
      "current":{"income":4500000,"expense":3720000,"net":780000,"savings_rate":17.3,"savings":500000,"investments":0},
      "previous":{"income":4500000,"expense":4010000,"net":490000,"savings_rate":10.9,"savings":300000,"investments":0}},
     "sankey":{"total_income":4500000,"total_expense":3720000,
      "income_categories":[\(category("i1", "Salario", "green", 4500000))],
      "expense_categories":[
       \(category("e1", "Vivienda", "blue", 1400000, children: true)),
       \(category("e2", "Comida", "orange", 820000, children: true)),
       \(category("e3", "Transporte", "teal", 510000)),
       \(category("e4", "Ocio", "purple", 420000)),
       \(category("e5", "Salud", "red", 310000)),
       \(category("e6", "Suscripciones", "pink", 260000))]},
     "trend":{"data":[
      {"month":"2026-04","income":4300000,"expense":3900000,"net":400000},
      {"month":"2026-05","income":4300000,"expense":4400000,"net":-100000},
      {"month":"2026-06","income":4500000,"expense":3600000,"net":900000},
      {"month":"2026-07","income":4500000,"expense":4100000,"net":400000},
      {"month":"2026-08","income":4500000,"expense":4010000,"net":490000},
      {"month":"2026-09","income":4500000,"expense":3720000,"net":780000}]}}
    """)

    private static func budget(_ id: String, _ name: String, spent: Int, allocated: Int, categories: [String]) -> String {
        let refs = categories.enumerated().map { #"{"id":"\#(id)-\#($0.offset)","name":"\#($0.element)"}"# }
        return """
        {"id":"\(id)","name":"\(name)","period_type":"monthly","categories":[\(refs.joined(separator: ","))],"labels":[],
         "current_period":{"start_date":"2026-09-01","end_date":"2026-09-30","allocated_amount":\(allocated),
          "carried_over_amount":0,"spent_amount":\(spent),"remaining_amount":\(allocated - spent),"processing_historical":false}}
        """
    }

    private static func category(_ id: String, _ name: String, _ color: String, _ amount: Int, children: Bool = false) -> String {
        #"{"category_id":"\#(id)","category":{"id":"\#(id)","name":"\#(name)","color":"\#(color)"},"amount":\#(amount),"has_children":\#(children)}"#
    }

    private static func decode<T: Decodable>(_ json: String) -> T {
        try! WhisperDecoder.decode(T.self, from: Data(json.utf8))
    }
}
#endif

import Foundation

// Modelos de las respuestas del MCP de Wispr Money. Los montos son enteros en unidades menores
// de su moneda (ver `Money`). Se decodifican con `keyDecodingStrategy = .convertFromSnakeCase`.

// MARK: Presupuestos (list_budgets)

public struct BudgetsResponse: Decodable, Sendable {
    public let currency: String
    public let budgets: [Budget]
}

public struct Budget: Decodable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let periodType: String
    public let categories: [NamedRef]
    public let labels: [NamedRef]
    public let currentPeriod: BudgetPeriod?
}

public struct BudgetPeriod: Decodable, Sendable {
    public let startDate: String
    public let endDate: String
    public let allocatedAmount: Int
    public let carriedOverAmount: Int
    public let spentAmount: Int
    public let remainingAmount: Int
    public let processingHistorical: Bool

    /// Lo disponible en el periodo: lo asignado más lo arrastrado del periodo anterior.
    public var available: Int { allocatedAmount + carriedOverAmount }

    /// Fracción gastada (1.0 = 100 %). Puede pasar de 1 si se excedió. `nil` si no hay nada asignado.
    public var spentFraction: Double? {
        available > 0 ? Double(spentAmount) / Double(available) : nil
    }

    public var isOver: Bool { remainingAmount < 0 }
}

public struct NamedRef: Decodable, Sendable, Hashable {
    public let id: String
    public let name: String
}

// MARK: Cuentas (list_accounts)

public struct AccountsResponse: Decodable, Sendable {
    public let spaceId: String
    public let accounts: [Account]
}

public struct Account: Decodable, Sendable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let type: String
    public let currency: String
    public let bank: String?
    public let isConnected: Bool

    /// Préstamos y tarjetas: su saldo es deuda.
    public var isLiability: Bool { type == "loan" || type == "credit_card" }
}

// MARK: Movimientos (search_transactions / create_transaction)

public struct TransactionsResponse: Decodable, Sendable {
    public let count: Int
    public let transactions: [Transaction]
}

public struct Transaction: Decodable, Sendable, Identifiable {
    public let id: String
    public let date: String
    public let description: String
    public let amount: Int
    public let currency: String
    public let categoryId: String?
    public let category: String?
    public let accountId: String
    public let account: String
    public let labels: [NamedRef]
}

public struct TransactionFilter: Sendable, Hashable {
    public var query: String = ""
    public var accountID: String?
    public var categoryID: String?
    public var from: String?
    public var to: String?
    public var limit: Int = 100

    public init() {}

    var arguments: [String: JSONValue] {
        var args: [String: JSONValue] = ["limit": .int(limit)]
        if !query.isEmpty { args["query"] = .string(query) }
        if let accountID { args["account_id"] = .string(accountID) }
        if let categoryID { args["category_id"] = .string(categoryID) }
        if let from { args["from"] = .string(from) }
        if let to { args["to"] = .string(to) }
        return args
    }
}

public struct NewTransaction: Sendable {
    public var accountID: String
    public var description: String
    /// Con signo, en unidades menores: negativo = gasto, positivo = ingreso.
    public var amount: Int
    public var date: String
    public var categoryID: String?
    public var notes: String?

    public init(accountID: String, description: String, amount: Int, date: String,
                categoryID: String? = nil, notes: String? = nil) {
        self.accountID = accountID
        self.description = description
        self.amount = amount
        self.date = date
        self.categoryID = categoryID
        self.notes = notes
    }

    var arguments: [String: JSONValue] {
        var args: [String: JSONValue] = [
            "account_id": .string(accountID),
            "description": .string(description),
            "amount": .int(amount),
            "transaction_date": .string(date),
        ]
        if let categoryID { args["category_id"] = .string(categoryID) }
        if let notes, !notes.isEmpty { args["notes"] = .string(notes) }
        return args
    }
}

// MARK: Categorías (list_categories, spending_by_category, get_cashflow)

public struct CategoriesResponse: Decodable, Sendable {
    public let categories: [Category]
}

public struct Category: Decodable, Sendable, Hashable {
    public let id: String?
    public let name: String
    public let icon: String?
    public let color: String?
    public let type: String?
    public let parentId: String?
}

public struct CategoryAmount: Decodable, Sendable, Identifiable {
    public let categoryId: String?
    public let category: Category
    public let amount: Int
    public let hasChildren: Bool

    public var id: String { categoryId ?? "sin-categoria-\(category.name)" }
}

public struct SpendingResponse: Decodable, Sendable {
    public let categories: [CategoryAmount]
}

public struct CashflowResponse: Decodable, Sendable {
    public struct Summary: Decodable, Sendable {
        public let current: Totals
        public let previous: Totals
    }

    public struct Totals: Decodable, Sendable {
        public let income: Int
        public let expense: Int
        public let net: Int
        public let savingsRate: Double?
        public let savings: Int
        public let investments: Int
    }

    public struct Sankey: Decodable, Sendable {
        public let incomeCategories: [CategoryAmount]
        public let expenseCategories: [CategoryAmount]
        public let totalIncome: Int
        public let totalExpense: Int
    }

    public struct Trend: Decodable, Sendable {
        public let data: [TrendPoint]
    }

    public struct TrendPoint: Decodable, Sendable, Identifiable {
        public let month: String
        public let income: Int
        public let expense: Int
        public let net: Int
        public var id: String { month }
    }

    public let summary: Summary
    public let sankey: Sankey
    public let trend: Trend
}

// MARK: Patrimonio (get_net_worth)

public struct NetWorthResponse: Decodable, Sendable {
    public struct Current: Decodable, Sendable {
        public let current: Int
        public let previous: Int
        public let currencyCode: String
    }

    public struct Evolution: Decodable, Sendable {
        public let data: [NetWorthPoint]
    }

    public let current: Current
    public let evolution: Evolution

    /// Último saldo conocido de cada cuenta dentro del rango consultado.
    public var latestBalances: [String: Int] {
        var result: [String: Int] = [:]
        for point in evolution.data.sorted(by: { $0.timestamp < $1.timestamp }) {
            for (account, value) in point.balances { result[account] = value }
        }
        return result
    }
}

/// Un punto de la evolución: `month`/`date`, `timestamp` y un saldo por id de cuenta (claves dinámicas).
public struct NetWorthPoint: Decodable, Sendable, Identifiable {
    public let label: String
    public let timestamp: Int
    public let balances: [String: Int]

    public var id: Int { timestamp }

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode([String: JSONValue].self)
        label = raw["month"]?.stringValue ?? raw["date"]?.stringValue ?? ""
        timestamp = raw["timestamp"]?.intValue ?? 0
        var balances: [String: Int] = [:]
        for (key, value) in raw where !["month", "date", "timestamp"].contains(key) {
            if let amount = value.intValue { balances[key] = amount }
        }
        self.balances = balances
    }
}

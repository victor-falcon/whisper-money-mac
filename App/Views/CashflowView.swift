import Charts
import SwiftUI
import WisprKit

struct CashflowView: View {
    let service: WisprService
    @State private var month = WisprDate.startOfMonth(.now)

    struct Snapshot {
        let month: CashflowResponse
        let trend: [CashflowResponse.TrendPoint]
        /// Moneda base de la cuenta (el cashflow no la trae; `list_budgets` sí).
        let currency: String
    }

    var body: some View {
        LiveView(key: month, load: { [month] in try await load(month) }) { snapshot in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    summary(snapshot.month.summary, currency: snapshot.currency)
                    expenses(snapshot.month.sankey.expenseCategories, currency: snapshot.currency)
                    trend(snapshot.trend, currency: snapshot.currency)
                }
                .padding(20)
            }
        }
        .toolbar { ToolbarItem { MonthStepper(month: $month) } }
    }

    private func load(_ month: Date) async throws -> Snapshot {
        let end = WisprDate.endOfMonth(month)
        let sixBack = Calendar.current.date(byAdding: .month, value: -5, to: month) ?? month
        async let current = service.cashflow(from: WisprDate.string(month), to: WisprDate.string(end))
        async let history = service.cashflow(from: WisprDate.string(sixBack), to: WisprDate.string(end))
        async let base = service.budgets()
        return try await Snapshot(month: current, trend: history.trend.data, currency: base.currency)
    }

    private func summary(_ s: CashflowResponse.Summary, currency: String) -> some View {
        HStack(spacing: 12) {
            StatCard(title: "Ingresos", value: s.current.income, previous: s.previous.income, currency: currency, tint: .green)
            StatCard(title: "Gastos", value: s.current.expense, previous: s.previous.expense, currency: currency, tint: .red)
            StatCard(title: "Neto", value: s.current.net, previous: s.previous.net, currency: currency, tint: s.current.net < 0 ? .red : .green)
            VStack(alignment: .leading, spacing: 6) {
                Text("Tasa de ahorro").font(.caption).foregroundStyle(.secondary)
                Text(s.current.savingsRate.map { "\($0.formatted(.number.precision(.fractionLength(1)))) %" } ?? "—")
                    .font(.title2.bold().monospacedDigit())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private func expenses(_ categories: [CategoryAmount], currency: String) -> some View {
        let sorted = categories.sorted { $0.amount > $1.amount }
        return VStack(alignment: .leading, spacing: 10) {
            Text("Gasto por categoría").font(.headline)
            Chart(sorted) { item in
                BarMark(x: .value("Monto", Money.double(item.amount, currency: currency)),
                        y: .value("Categoría", item.category.name))
                    .foregroundStyle(Color.named(item.category.color))
            }
            .chartXAxis { AxisMarks(format: .currency(code: currency).precision(.fractionLength(0))) }
            .frame(height: CGFloat(max(sorted.count, 1)) * 26 + 30)
            ForEach(sorted.filter(\.hasChildren)) { item in
                if let id = item.categoryId {
                    NavigationLink("Ver desglose de \(item.category.name)") {
                        SubcategoryView(service: service, parent: item.category, parentID: id, month: month, currency: currency)
                    }
                    .font(.callout)
                }
            }
        }
    }

    private func trend(_ points: [CashflowResponse.TrendPoint], currency: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Últimos 6 meses").font(.headline)
            Chart(points) { p in
                BarMark(x: .value("Mes", p.month), y: .value("Monto", Money.double(p.income, currency: currency)))
                    .foregroundStyle(by: .value("Tipo", "Ingresos"))
                    .position(by: .value("Tipo", "Ingresos"))
                BarMark(x: .value("Mes", p.month), y: .value("Monto", Money.double(p.expense, currency: currency)))
                    .foregroundStyle(by: .value("Tipo", "Gastos"))
                    .position(by: .value("Tipo", "Gastos"))
            }
            .chartForegroundStyleScale(["Ingresos": Color.green, "Gastos": Color.red])
            .frame(height: 200)
        }
    }
}

private struct StatCard: View {
    let title: String
    let value: Int
    let previous: Int
    let currency: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(Money.format(value, currency: currency))
                .font(.title2.bold().monospacedDigit())
                .foregroundStyle(tint)
            Text("Periodo anterior: \(Money.format(previous, currency: currency))")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct SubcategoryView: View {
    let service: WisprService
    let parent: WisprKit.Category
    let parentID: String
    let month: Date
    let currency: String

    var body: some View {
        LiveView(load: {
            try await service.spending(from: WisprDate.string(month),
                                       to: WisprDate.string(WisprDate.endOfMonth(month)),
                                       parentCategoryID: parentID)
        }) { response in
            List(response.categories.sorted { $0.amount > $1.amount }) { item in
                HStack {
                    Text(item.category.name)
                    Spacer()
                    Text(Money.format(item.amount, currency: currency)).monospacedDigit()
                }
            }
        }
        .navigationTitle(parent.name)
    }
}

extension Color {
    /// Colores con nombre de Tailwind que usa Wispr para sus categorías.
    static func named(_ name: String?) -> Color {
        switch name {
        case "red", "rose": .red
        case "orange", "amber": .orange
        case "yellow": .yellow
        case "lime", "green", "emerald": .green
        case "teal", "cyan": .teal
        case "sky", "blue": .blue
        case "indigo", "violet": .indigo
        case "purple", "fuchsia": .purple
        case "pink": .pink
        default: .gray
        }
    }
}

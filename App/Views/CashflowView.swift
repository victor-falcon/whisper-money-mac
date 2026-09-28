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
            CashflowContent(snapshot: snapshot, month: month, service: service)
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
}

struct CashflowContent: View {
    let snapshot: CashflowView.Snapshot
    let month: Date
    let service: WisprService

    private var currency: String { snapshot.currency }

    var body: some View {
        let s = snapshot.month.summary
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 16)], spacing: 16) {
                    StatCard(title: "Ingresos", value: s.current.income, previous: s.previous.income,
                             currency: currency, tint: .green, higherIsBetter: true)
                    StatCard(title: "Gastos", value: s.current.expense, previous: s.previous.expense,
                             currency: currency, tint: .red, higherIsBetter: false)
                    StatCard(title: "Neto", value: s.current.net, previous: s.previous.net,
                             currency: currency, tint: s.current.net < 0 ? .red : .primary, higherIsBetter: true)
                    savingsRate(s)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 380), spacing: 16, alignment: .top)], spacing: 16) {
                    expenses(snapshot.month.sankey.expenseCategories)
                    trend(snapshot.trend)
                }
            }
            .padding(24)
        }
        .pageBackground(s.current.net < 0 ? .red : .green)
    }

    private func savingsRate(_ s: CashflowResponse.Summary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Figure(label: "Tasa de ahorro",
                   value: s.current.savingsRate.map { "\($0.formatted(.number.precision(.fractionLength(1)))) %" } ?? "—")
            Gauge(value: min(max(s.current.savingsRate ?? 0, 0), 100), in: 0...100) { EmptyView() }
                .gaugeStyle(.accessoryLinearCapacity)
                .tint(.green)
            Spacer(minLength: 0)
        }
        .card()
    }

    private func expenses(_ categories: [CategoryAmount]) -> some View {
        let sorted = categories.sorted { $0.amount > $1.amount }
        return VStack(alignment: .leading, spacing: 16) {
            CardTitle(title: "Gasto por categoría", subtitle: month.formatted(.dateTime.month(.wide).year()).capitalized)
            Chart(sorted) { item in
                BarMark(x: .value("Monto", Money.double(item.amount, currency: currency)),
                        y: .value("Categoría", item.category.name))
                    .foregroundStyle(Color.named(item.category.color).gradient)
                    .clipShape(.rect(cornerRadius: 5))
                    .annotation(position: .trailing, spacing: 6) {
                        Text(Money.format(item.amount, currency: currency))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
            }
            .chartXAxis(.hidden)
            .chartXScale(range: .plotDimension(endPadding: 90))
            .frame(height: CGFloat(max(sorted.count, 1)) * 34)
            let withChildren = sorted.filter(\.hasChildren)
            if !withChildren.isEmpty {
                Divider()
                ForEach(withChildren) { item in
                    if let id = item.categoryId {
                        NavigationLink {
                            SubcategoryView(service: service, parent: item.category, parentID: id, month: month, currency: currency)
                        } label: {
                            HStack {
                                Text("Desglose de \(item.category.name)")
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                            }
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .font(.callout)
                    }
                }
            }
        }
        .card(padding: 24)
    }

    private func trend(_ points: [CashflowResponse.TrendPoint]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            CardTitle(title: "Últimos 6 meses", subtitle: "Ingresos contra gastos")
            Chart(points) { p in
                BarMark(x: .value("Mes", monthLabel(p.month)), y: .value("Monto", Money.double(p.income, currency: currency)))
                    .foregroundStyle(by: .value("Tipo", "Ingresos"))
                    .position(by: .value("Tipo", "Ingresos"))
                    .clipShape(.rect(cornerRadius: 4))
                BarMark(x: .value("Mes", monthLabel(p.month)), y: .value("Monto", Money.double(p.expense, currency: currency)))
                    .foregroundStyle(by: .value("Tipo", "Gastos"))
                    .position(by: .value("Tipo", "Gastos"))
                    .clipShape(.rect(cornerRadius: 4))
            }
            .chartForegroundStyleScale(["Ingresos": Color.green.gradient, "Gastos": Color.red.gradient])
            .chartLegend(position: .top, alignment: .leading)
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(amount.formatted(.currency(code: currency).notation(.compactName)))
                        }
                    }
                }
            }
            .frame(height: 240)
        }
        .card(padding: 24)
    }

    /// "2026-04" → "abr".
    private func monthLabel(_ raw: String) -> String {
        WisprDate.date(raw).map { $0.formatted(.dateTime.month(.abbreviated)) } ?? raw
    }
}

private struct StatCard: View {
    let title: String
    let value: Int
    let previous: Int
    let currency: String
    let tint: Color
    let higherIsBetter: Bool

    var body: some View {
        let delta = value - previous
        let good = (delta >= 0) == higherIsBetter
        VStack(alignment: .leading, spacing: 10) {
            Figure(label: title, value: Money.format(value, currency: currency), tint: tint)
            if delta != 0 {
                Pill(text: "\(delta > 0 ? "+" : "")\(Money.format(delta, currency: currency))",
                     symbol: delta > 0 ? "arrow.up.right" : "arrow.down.right",
                     tint: good ? .green : .red)
                    .help("Contra el periodo anterior: \(Money.format(previous, currency: currency))")
            } else {
                Text("Igual que el periodo anterior").font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .card()
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

#if DEBUG
#Preview("Flujo") {
    NavigationStack {
        CashflowContent(snapshot: .init(month: PreviewData.cashflow, trend: PreviewData.cashflow.trend.data, currency: "MXN"),
                        month: WisprDate.date("2026-09-01")!,
                        service: WisprService(credentials: Credentials(endpoint: URL(string: "https://example.invalid/mcp")!, token: "preview")))
            .navigationTitle("Flujo")
    }
    .frame(width: 1080, height: 720)
}

#Preview("Flujo, ancho mínimo") {
    NavigationStack {
        CashflowContent(snapshot: .init(month: PreviewData.cashflow, trend: PreviewData.cashflow.trend.data, currency: "MXN"),
                        month: WisprDate.date("2026-09-01")!,
                        service: WisprService(credentials: Credentials(endpoint: URL(string: "https://example.invalid/mcp")!, token: "preview")))
    }
    .frame(width: 630, height: 720)
}
#endif

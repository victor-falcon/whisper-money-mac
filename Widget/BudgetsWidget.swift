import SwiftUI
import WidgetKit
import WisprKit

/// Widget de presupuestos. Cada actualización consulta `list_budgets` en vivo; no guarda montos.
/// Si la consulta falla muestra "Sin conexión" en lugar de números viejos.
struct BudgetsEntry: TimelineEntry {
    enum State {
        case placeholder
        case live(BudgetsResponse)
        case notConfigured
        case failed(String)
    }

    let date: Date
    let state: State
}

struct BudgetsProvider: TimelineProvider {
    static let refresh: TimeInterval = 15 * 60

    func placeholder(in context: Context) -> BudgetsEntry {
        BudgetsEntry(date: .now, state: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (BudgetsEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        Task { completion(await fetch()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BudgetsEntry>) -> Void) {
        Task {
            let entry = await fetch()
            completion(Timeline(entries: [entry], policy: .after(entry.date.addingTimeInterval(Self.refresh))))
        }
    }

    private func fetch() async -> BudgetsEntry {
        do {
            guard let credentials = try CredentialStore.fromBundle().load() else {
                return BudgetsEntry(date: .now, state: .notConfigured)
            }
            let budgets = try await WisprService(credentials: credentials).budgets()
            return BudgetsEntry(date: .now, state: .live(budgets))
        } catch {
            return BudgetsEntry(date: .now, state: .failed(error.localizedDescription))
        }
    }
}

struct BudgetsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BudgetsEntry

    private var maxRows: Int {
        switch family {
        case .systemSmall: 2
        case .systemMedium: 3
        default: 7
        }
    }

    var body: some View {
        content
            .containerBackground(.fill.tertiary, for: .widget)
            .widgetURL(URL(string: "wisprmac://presupuestos"))
    }

    @ViewBuilder
    private var content: some View {
        switch entry.state {
        case .placeholder:
            rows(Self.sample.budgets, currency: Self.sample.currency)
                .redacted(reason: .placeholder)
        case .live(let response):
            rows(response.budgets, currency: response.currency)
        case .notConfigured:
            message("Abre Wispr Money para conectar tu servidor.", symbol: "key")
        case .failed(let reason):
            message(reason, symbol: "wifi.exclamationmark", title: "Sin conexión")
        }
    }

    private func rows(_ budgets: [Budget], currency: String) -> some View {
        // Los más excedidos primero.
        let ordered = budgets
            .filter { $0.currentPeriod != nil }
            .sorted { ($0.currentPeriod?.spentFraction ?? 0) > ($1.currentPeriod?.spentFraction ?? 0) }
            .prefix(maxRows)
        return VStack(alignment: .leading, spacing: family == .systemSmall ? 8 : 10) {
            HStack {
                Text("Presupuestos").font(.caption.bold())
                Spacer()
                Text(Stamp.time(entry.date)).font(.caption2).foregroundStyle(.secondary)
            }
            ForEach(Array(ordered)) { budget in
                if let period = budget.currentPeriod {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(budget.name).font(.caption).lineLimit(1)
                            Spacer(minLength: 4)
                            Text(period.percentText)
                                .font(.caption.bold().monospacedDigit())
                                .foregroundStyle(BudgetTone.color(for: period.spentFraction))
                        }
                        BudgetBar(fraction: period.spentFraction, height: 6)
                        if family != .systemSmall {
                            Text(period.isOver
                                 ? "Excedido \(Money.format(-period.remainingAmount, currency: currency))"
                                 : "Quedan \(Money.format(period.remainingAmount, currency: currency))")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(period.isOver ? .red : .secondary)
                        }
                    }
                }
            }
            if ordered.isEmpty {
                Text("Sin presupuestos activos").font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private func message(_ text: String, symbol: String, title: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol).font(.title3).foregroundStyle(.orange)
            if let title { Text(title).font(.caption.bold()) }
            Text(text).font(.caption2).foregroundStyle(.secondary).lineLimit(4)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Solo para el placeholder redactado (se ve como barras grises, nunca como números).
    static let sample: BudgetsResponse = {
        let json = """
        {"currency":"MXN","budgets":[
         {"id":"a","name":"Presupuesto","period_type":"monthly","categories":[],"labels":[],
          "current_period":{"start_date":"","end_date":"","allocated_amount":100,"carried_over_amount":0,
           "spent_amount":60,"remaining_amount":40,"processing_historical":false}},
         {"id":"b","name":"Presupuesto","period_type":"monthly","categories":[],"labels":[],
          "current_period":{"start_date":"","end_date":"","allocated_amount":100,"carried_over_amount":0,
           "spent_amount":30,"remaining_amount":70,"processing_historical":false}}]}
        """
        return try! WisprDecoder.decode(BudgetsResponse.self, from: Data(json.utf8))
    }()
}

@main
struct BudgetsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "mx.diego.wisprmac.budgets", provider: BudgetsProvider()) { entry in
            BudgetsWidgetView(entry: entry)
        }
        .configurationDisplayName("Presupuestos")
        .description("Porcentaje gastado de cada presupuesto, consultado en vivo a Wispr Money.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

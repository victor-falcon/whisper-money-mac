import SwiftUI
import WidgetKit
import WhisperKit

/// Una "foto" del widget: lo que devolvió la consulta en vivo a `list_budgets`, o por qué falló.
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

/// Vista del widget "Presupuestos". Vive en Shared para poder previsualizarla desde la app.
struct BudgetsWidgetView: View {
    @Environment(\.widgetFamily) private var environmentFamily
    @Environment(\.widgetRenderingMode) private var renderingMode
    let entry: BudgetsEntry
    /// Solo para previews en la app: macOS no previsualiza extensiones de widget.
    var familyOverride: WidgetFamily?

    private var family: WidgetFamily { familyOverride ?? environmentFamily }

    var body: some View {
        content
            .containerBackground(for: .widget) { background }
            .widgetURL(URL(string: "whispermac://presupuestos"))
    }

    @ViewBuilder
    private var content: some View {
        switch entry.state {
        case .placeholder:
            live(Self.sample)
                .redacted(reason: .placeholder)
        case .live(let response):
            live(response)
        case .notConfigured:
            message("Abre Whisper Money para conectar tu servidor.", symbol: "key")
        case .failed(let reason):
            message(reason, symbol: "wifi.exclamationmark", title: "Sin conexión")
        }
    }

    /// En modo tintado/vidrio el sistema quita el fondo; el degradado solo va a todo color.
    @ViewBuilder
    private var background: some View {
        if renderingMode == .fullColor, case .live(let response) = entry.state {
            LinearGradient(colors: [BudgetTone.color(for: BudgetSummary(response.budgets).fraction).opacity(0.22), .clear],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .background(.fill.tertiary)
        } else {
            Rectangle().fill(.fill.tertiary)
        }
    }

    @ViewBuilder
    private func live(_ response: BudgetsResponse) -> some View {
        let summary = BudgetSummary(response.budgets)
        let ordered = Budget.byUrgency(response.budgets)
        VStack(alignment: .leading, spacing: 0) {
            header
            if ordered.isEmpty {
                Spacer()
                Text("Sin presupuestos activos").font(.caption).foregroundStyle(.secondary)
                Spacer()
            } else {
                switch family {
                case .systemSmall: small(summary, currency: response.currency)
                case .systemMedium: medium(summary, Array(ordered.prefix(3)), currency: response.currency)
                default: large(summary, Array(ordered.prefix(5)), currency: response.currency)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Presupuestos").font(.caption.bold())
            Spacer()
            Text(Stamp.time(entry.date)).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func small(_ summary: BudgetSummary, currency: String) -> some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)
            BudgetRingLabel(fraction: summary.fraction, lineWidth: 12, font: .system(.title3, design: .rounded))
                .frame(width: 88, height: 88)
            Spacer(minLength: 0)
            balance(summary, currency: currency, font: .caption)
        }
        .frame(maxWidth: .infinity)
    }

    private func medium(_ summary: BudgetSummary, _ budgets: [Budget], currency: String) -> some View {
        HStack(spacing: 14) {
            VStack(spacing: 6) {
                BudgetRingLabel(fraction: summary.fraction, lineWidth: 12, font: .system(.title3, design: .rounded))
                    .frame(width: 92, height: 92)
                balance(summary, currency: currency, font: .caption2)
            }
            .frame(width: 112)
            Divider().padding(.vertical, 4)
            HStack(alignment: .top, spacing: 8) {
                ForEach(budgets) { budget in
                    VStack(spacing: 5) {
                        BudgetRingLabel(fraction: budget.currentPeriod?.spentFraction, lineWidth: 7,
                                        font: .system(.caption, design: .rounded))
                            .frame(width: 60, height: 60)
                        Text(budget.name).font(.caption2).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.top, 10)
        .frame(maxHeight: .infinity)
    }

    private func large(_ summary: BudgetSummary, _ budgets: [Budget], currency: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                BudgetRingLabel(fraction: summary.fraction, lineWidth: 14, font: .system(.title2, design: .rounded))
                    .frame(width: 112, height: 112)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Gastado").font(.caption).foregroundStyle(.secondary)
                    Text(Money.format(summary.spent, currency: currency))
                        .font(.system(.title, design: .rounded).bold().monospacedDigit())
                        .minimumScaleFactor(0.6)
                        .widgetAccentable()
                    Text("de \(Money.format(summary.available, currency: currency))")
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    if summary.overCount > 0 {
                        Text("\(summary.overCount) de \(summary.activeCount) excedidos")
                            .font(.caption.weight(.medium)).foregroundStyle(.red)
                    }
                }
            }
            .padding(.top, 10)
            Divider()
            ForEach(budgets) { budget in
                if let period = budget.currentPeriod {
                    HStack(spacing: 10) {
                        BudgetRing(fraction: period.spentFraction, lineWidth: 5)
                            .frame(width: 30, height: 30)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(budget.name).font(.caption.weight(.medium)).lineLimit(1)
                            remaining(period, currency: currency)
                        }
                        Spacer(minLength: 4)
                        Text(period.percentText)
                            .font(.system(.callout, design: .rounded).bold().monospacedDigit())
                            .foregroundStyle(BudgetTone.color(for: period.spentFraction))
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func balance(_ summary: BudgetSummary, currency: String, font: Font) -> some View {
        Text(summary.remaining < 0
             ? "Excedido \(Money.format(-summary.remaining, currency: currency))"
             : "Quedan \(Money.format(summary.remaining, currency: currency))")
            .font(font.weight(.semibold).monospacedDigit())
            .foregroundStyle(summary.remaining < 0 ? .red : .primary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    private func remaining(_ period: BudgetPeriod, currency: String) -> some View {
        Text(period.isOver
             ? "Excedido \(Money.format(-period.remainingAmount, currency: currency))"
             : "Quedan \(Money.format(period.remainingAmount, currency: currency))")
            .font(.caption2.monospacedDigit())
            .foregroundStyle(period.isOver ? .red : .secondary)
    }

    private func message(_ text: String, symbol: String, title: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol).font(.title3).foregroundStyle(.orange).widgetAccentable()
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
        return try! WhisperDecoder.decode(BudgetsResponse.self, from: Data(json.utf8))
    }()
}

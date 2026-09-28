import SwiftUI
import WisprKit

struct BudgetsView: View {
    let service: WisprService

    var body: some View {
        LiveView(load: { try await service.budgets() }) { response in
            BudgetsContent(response: response)
        }
    }
}

struct BudgetsContent: View {
    let response: BudgetsResponse

    var body: some View {
        if response.budgets.isEmpty {
            ContentUnavailableView("Sin presupuestos", systemImage: "chart.pie",
                                   description: Text("Créalos en Wispr Money."))
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    BudgetSummaryCard(summary: BudgetSummary(response.budgets), currency: response.currency)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 16)], spacing: 16) {
                        ForEach(Budget.byUrgency(response.budgets)) { budget in
                            BudgetCard(budget: budget, currency: response.currency)
                        }
                        ForEach(response.budgets.filter { $0.currentPeriod == nil }) { budget in
                            BudgetCard(budget: budget, currency: response.currency)
                        }
                    }
                }
                .padding(24)
            }
            .pageBackground(BudgetTone.color(for: BudgetSummary(response.budgets).fraction))
        }
    }
}

private struct BudgetSummaryCard: View {
    let summary: BudgetSummary
    let currency: String

    var body: some View {
        HStack(spacing: 28) {
            BudgetRingLabel(fraction: summary.fraction, lineWidth: 16,
                            font: .system(.title, design: .rounded))
                .frame(width: 140, height: 140)
            VStack(alignment: .leading, spacing: 10) {
                Text("Gastado en el periodo").font(.subheadline).foregroundStyle(.secondary)
                Text(Money.format(summary.spent, currency: currency))
                    .font(.system(size: 40, weight: .bold, design: .rounded).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("de \(Money.format(summary.available, currency: currency)) presupuestados")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                // Si las píldoras no caben en una fila (ventana angosta), se apilan.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { pills }
                    VStack(alignment: .leading, spacing: 6) { pills }
                }
                .padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
        .card(padding: 24)
    }

    @ViewBuilder
    private var pills: some View {
        if summary.remaining < 0 {
            Pill(text: "Excedido \(Money.format(-summary.remaining, currency: currency))",
                 symbol: "exclamationmark.triangle.fill", tint: .red)
        } else {
            Pill(text: "Quedan \(Money.format(summary.remaining, currency: currency))",
                 symbol: "checkmark.circle.fill", tint: .green)
        }
        if summary.overCount > 0 {
            Pill(text: "\(summary.overCount) de \(summary.activeCount) excedidos", tint: .red)
        }
        if let days = summary.daysLeft {
            Pill(text: days == 1 ? "Último día" : "Faltan \(days) días", symbol: "calendar")
        }
    }
}

private struct BudgetCard: View {
    let budget: Budget
    let currency: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                BudgetRingLabel(fraction: budget.currentPeriod?.spentFraction, lineWidth: 10)
                    .frame(width: 84, height: 84)
                VStack(alignment: .leading, spacing: 4) {
                    Text(budget.name).font(.title3.weight(.semibold))
                    if let period = budget.currentPeriod {
                        Text(Money.format(period.spentAmount, currency: currency))
                            .font(.system(.title2, design: .rounded).weight(.semibold).monospacedDigit())
                        Text("de \(Money.format(period.available, currency: currency))")
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Sin periodo activo hoy").foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            if let period = budget.currentPeriod {
                HStack {
                    Text(period.isOver
                         ? "Excedido \(Money.format(-period.remainingAmount, currency: currency))"
                         : "Quedan \(Money.format(period.remainingAmount, currency: currency))")
                        .font(.callout.weight(.medium).monospacedDigit())
                        .foregroundStyle(period.isOver ? .red : .primary)
                    Spacer()
                    Text(period.rangeText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if period.processingHistorical {
                    Label("Wispr sigue asignando movimientos; el gasto puede cambiar.", systemImage: "hourglass")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            let tracked = budget.categories.map(\.name) + budget.labels.map { "#\($0.name)" }
            if !tracked.isEmpty {
                Text(tracked.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .card()
    }
}

#if DEBUG
#Preview("Presupuestos") {
    NavigationStack {
        BudgetsContent(response: PreviewData.budgets)
            .navigationTitle("Presupuestos")
    }
    .frame(width: 980, height: 640)
}

#Preview("Presupuestos, ancho mínimo") {
    NavigationStack {
        BudgetsContent(response: PreviewData.budgets)
    }
    .frame(width: 630, height: 640)
}
#endif

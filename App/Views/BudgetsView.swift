import SwiftUI
import WisprKit

struct BudgetsView: View {
    let service: WisprService

    var body: some View {
        LiveView(load: { try await service.budgets() }) { response in
            if response.budgets.isEmpty {
                ContentUnavailableView("Sin presupuestos", systemImage: "chart.bar",
                                       description: Text("Créalos en Wispr Money."))
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 16)], spacing: 16) {
                        ForEach(response.budgets) { budget in
                            BudgetCard(budget: budget, currency: response.currency)
                        }
                    }
                    .padding(20)
                }
            }
        }
    }
}

private struct BudgetCard: View {
    let budget: Budget
    let currency: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(budget.name).font(.headline)
                Spacer()
                if let period = budget.currentPeriod {
                    Text(period.percentText)
                        .font(.title2.monospacedDigit().bold())
                        .foregroundStyle(BudgetTone.color(for: period.spentFraction))
                }
            }
            if let period = budget.currentPeriod {
                BudgetBar(fraction: period.spentFraction, height: 10)
                HStack {
                    Text("\(Money.format(period.spentAmount, currency: currency)) de \(Money.format(period.available, currency: currency))")
                    Spacer()
                    Text(period.isOver
                         ? "Excedido \(Money.format(-period.remainingAmount, currency: currency))"
                         : "Quedan \(Money.format(period.remainingAmount, currency: currency))")
                        .foregroundStyle(period.isOver ? .red : .secondary)
                }
                .font(.callout.monospacedDigit())
                Text("\(period.startDate) → \(period.endDate)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                if period.processingHistorical {
                    Label("Wispr sigue asignando movimientos; el gasto puede cambiar.", systemImage: "hourglass")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            } else {
                Text("Sin periodo activo hoy.").foregroundStyle(.secondary)
            }
            let tracked = budget.categories.map(\.name) + budget.labels.map { "#\($0.name)" }
            if !tracked.isEmpty {
                Text(tracked.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
    }
}

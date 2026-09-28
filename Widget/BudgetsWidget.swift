import SwiftUI
import WidgetKit
import WisprKit

/// Widget de presupuestos. Cada actualización consulta `list_budgets` en vivo; no guarda montos.
/// Si la consulta falla muestra "Sin conexión" en lugar de números viejos.
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

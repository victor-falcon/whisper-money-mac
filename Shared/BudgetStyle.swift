import SwiftUI
import WidgetKit
import WisprKit

// Componentes compartidos por la app y el widget.

enum BudgetTone {
    /// Verde < 80 %, naranja 80–100 %, rojo si se excedió.
    static func color(for fraction: Double?) -> Color {
        guard let fraction else { return .gray }
        if fraction > 1 { return .red }
        if fraction >= 0.8 { return .orange }
        return .green
    }
}

/// Anillo tipo Actividad. Pasado el 100 % da una segunda vuelta más oscura, así el exceso se lee
/// por la forma aunque el widget en modo tintado aplane los colores.
struct BudgetRing: View {
    let fraction: Double?
    var lineWidth: CGFloat = 10
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        let value = max(fraction ?? 0, 0)
        let tone = BudgetTone.color(for: fraction)
        // En modo tintado/vidrio todo se vuelve blanco y solo sobrevive la opacidad: la primera
        // vuelta se atenúa al excederse para que la vuelta extra se distinga.
        let tinted = renderingMode != .fullColor
        ZStack {
            Circle()
                .stroke(tone.opacity(0.2), lineWidth: lineWidth)
            arc(to: min(value, 1), color: tone)
                .opacity(tinted && value > 1 ? 0.4 : 1)
            if value > 1 {
                arc(to: min(value - 1, 1), color: tone.mix(with: .black, by: 0.3))
                    .shadow(color: .black.opacity(tinted ? 0 : 0.35), radius: lineWidth / 3)
            }
        }
        .padding(lineWidth / 2)
        .accessibilityHidden(true)
    }

    private func arc(to end: Double, color: Color) -> some View {
        Circle()
            .trim(from: 0, to: end)
            .stroke(color.gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .widgetAccentable()
    }
}

/// Anillo con el porcentaje al centro.
struct BudgetRingLabel: View {
    let fraction: Double?
    var lineWidth: CGFloat = 10
    var font: Font = .system(.title3, design: .rounded)

    var body: some View {
        BudgetRing(fraction: fraction, lineWidth: lineWidth)
            .overlay {
                Text(BudgetPeriod.percentText(fraction))
                    .font(font.weight(.bold).monospacedDigit())
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .padding(lineWidth * 1.2)
            }
    }
}

/// Suma de los presupuestos con periodo activo (misma moneda: la de `list_budgets`).
struct BudgetSummary {
    let spent: Int
    let available: Int
    let overCount: Int
    let activeCount: Int
    /// Fin más próximo entre los periodos activos.
    let endsOn: Date?

    init(_ budgets: [Budget]) {
        let periods = budgets.compactMap(\.currentPeriod)
        spent = periods.reduce(0) { $0 + $1.spentAmount }
        available = periods.reduce(0) { $0 + $1.available }
        overCount = periods.filter(\.isOver).count
        activeCount = periods.count
        endsOn = periods.compactMap { WisprDate.date($0.endDate) }.min()
    }

    var fraction: Double? { available > 0 ? Double(spent) / Double(available) : nil }
    var remaining: Int { available - spent }

    /// Días que faltan, contando hoy.
    var daysLeft: Int? {
        guard let endsOn else { return nil }
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: .now), to: endsOn).day
        return days.map { max($0 + 1, 0) }
    }
}

extension Budget {
    /// Los más excedidos primero.
    static func byUrgency(_ budgets: [Budget]) -> [Budget] {
        budgets
            .filter { $0.currentPeriod != nil }
            .sorted { ($0.currentPeriod?.spentFraction ?? 0) > ($1.currentPeriod?.spentFraction ?? 0) }
    }
}

extension BudgetPeriod {
    var percentText: String { Self.percentText(spentFraction) }

    static func percentText(_ fraction: Double?) -> String {
        fraction.map { $0.formatted(.percent.precision(.fractionLength(0))) } ?? "—"
    }

    /// "1 – 30 sep", o las fechas crudas si no se pueden leer.
    var rangeText: String {
        guard let start = WisprDate.date(startDate), let end = WisprDate.date(endDate) else {
            return "\(startDate) → \(endDate)"
        }
        return (start..<end).formatted(.interval.day().month(.abbreviated))
    }
}

enum Stamp {
    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}

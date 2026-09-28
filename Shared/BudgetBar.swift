import SwiftUI
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

struct BudgetBar: View {
    let fraction: Double?
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule()
                    .fill(BudgetTone.color(for: fraction))
                    .frame(width: geo.size.width * min(max(fraction ?? 0, 0), 1))
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

extension BudgetPeriod {
    var percentText: String {
        spentFraction.map { $0.formatted(.percent.precision(.fractionLength(0))) } ?? "—"
    }
}

enum Stamp {
    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}

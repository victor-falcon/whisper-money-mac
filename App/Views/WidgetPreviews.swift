#if DEBUG
import SwiftUI
import WidgetKit

// macOS no previsualiza extensiones de widget: esta galería dibuja la vista del widget desde la
// app, a los tamaños del escritorio, con datos sintéticos. La prueba final es el widget real.

private struct WidgetFrame: View {
    let family: WidgetFamily
    let entry: BudgetsEntry

    private var size: CGSize {
        switch family {
        case .systemSmall: CGSize(width: 170, height: 170)
        case .systemMedium: CGSize(width: 364, height: 170)
        default: CGSize(width: 364, height: 382)
        }
    }

    var body: some View {
        BudgetsWidgetView(entry: entry, familyOverride: family)
            .padding(16)
            .frame(width: size.width, height: size.height)
            .background(.fill.tertiary, in: .rect(cornerRadius: 24))
            .clipShape(.rect(cornerRadius: 24))
    }
}

#Preview("Widget") {
    let live = BudgetsEntry(date: .now, state: .live(PreviewData.budgets))
    HStack(alignment: .top, spacing: 20) {
        VStack(spacing: 20) {
            WidgetFrame(family: .systemSmall, entry: live)
            WidgetFrame(family: .systemMedium, entry: live)
            WidgetFrame(family: .systemMedium, entry: BudgetsEntry(date: .now, state: .failed("No se pudo conectar con el servidor.")))
        }
        WidgetFrame(family: .systemLarge, entry: live)
    }
    .padding(24)
    .background(LinearGradient(colors: [Color(red: 0.16, green: 0.12, blue: 0.30), Color(red: 0.04, green: 0.18, blue: 0.24)],
                               startPoint: .topLeading, endPoint: .bottomTrailing))
}
#endif

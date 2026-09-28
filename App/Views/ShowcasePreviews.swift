#if DEBUG
import SwiftUI
import WisprKit

// La app completa (barra lateral + pantalla) con datos sintéticos, para las capturas del README
// (`docs/screenshots/`). Nunca uses datos reales aquí.

private struct Showcase<Content: View>: View {
    let section: AppSection
    @ViewBuilder let content: Content

    var body: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: .constant(section)) { item in
                Label(item.title, systemImage: item.symbol).tag(item)
            }
            .navigationSplitViewColumnWidth(190)
        } detail: {
            NavigationStack {
                content
                    .navigationTitle(section.title)
                    .navigationSubtitle("En vivo · 9:41:00 a.m.")
            }
        }
        .frame(width: 1280, height: 800)
    }
}

private let demoService = WisprService(credentials: Credentials(endpoint: URL(string: "https://example.invalid/mcp")!,
                                                                token: "preview"))

#Preview("Presupuestos") {
    Showcase(section: .presupuestos) { BudgetsContent(response: PreviewData.budgets) }
}

#Preview("Patrimonio") {
    Showcase(section: .patrimonio) {
        NetWorthContent(worth: PreviewData.netWorth, accounts: PreviewData.accounts.accounts)
    }
}

#Preview("Flujo") {
    Showcase(section: .flujo) {
        CashflowContent(snapshot: .init(month: PreviewData.cashflow, trend: PreviewData.cashflow.trend.data, currency: "MXN"),
                        month: WisprDate.date("2026-09-01")!, service: demoService)
    }
}

#Preview("Cuentas") {
    Showcase(section: .cuentas) {
        AccountsContent(snapshot: .init(accounts: PreviewData.accounts.accounts,
                                        balances: PreviewData.netWorth.latestBalances))
    }
}
#endif

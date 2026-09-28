import SwiftUI
import WisprKit

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        if let service = model.service {
            NavigationSplitView {
                List(AppSection.allCases, selection: Binding($model.section)) { section in
                    Label(section.title, systemImage: section.symbol).tag(section)
                }
                .navigationSplitViewColumnWidth(min: 170, ideal: 190)
            } detail: {
                NavigationStack {
                    switch model.section {
                    case .presupuestos: BudgetsView(service: service)
                    case .cuentas: AccountsView(service: service)
                    case .movimientos: TransactionsView(service: service)
                    case .flujo: CashflowView(service: service)
                    case .patrimonio: NetWorthView(service: service)
                    }
                }
                .navigationTitle(model.section.title)
            }
        } else {
            SetupView()
        }
    }
}

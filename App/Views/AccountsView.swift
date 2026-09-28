import SwiftUI
import WisprKit

/// `list_accounts` no trae saldos: el saldo de cada cuenta es el último punto de `get_net_worth`.
struct AccountsView: View {
    let service: WisprService

    struct Snapshot {
        let accounts: [Account]
        let balances: [String: Int]
    }

    var body: some View {
        LiveView(load: load) { snapshot in
            List {
                group("Débito y efectivo", snapshot, where: { !$0.isLiability },
                      note: nil)
                group("Tarjetas de crédito", snapshot, where: { $0.type == "credit_card" },
                      note: "Saldo negativo = lo que debes en la tarjeta.")
                group("Préstamos", snapshot, where: { $0.type == "loan" },
                      note: "Saldo = lo que falta por pagar.")
            }
            .listStyle(.inset)
        }
    }

    private func load() async throws -> Snapshot {
        let today = Date.now
        let from = Calendar.current.date(byAdding: .month, value: -12, to: today) ?? today
        async let accounts = service.accounts()
        async let worth = service.netWorth(from: WisprDate.string(from), to: WisprDate.string(today))
        return try await Snapshot(accounts: accounts.accounts, balances: worth.latestBalances)
    }

    @ViewBuilder
    private func group(_ title: String, _ snapshot: Snapshot, where include: (Account) -> Bool, note: String?) -> some View {
        let rows = snapshot.accounts.filter(include)
        if !rows.isEmpty {
            Section {
                ForEach(rows) { account in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(account.name)
                            Text(account.bank ?? account.type).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let balance = snapshot.balances[account.id] {
                            Text(Money.format(balance, currency: account.currency))
                                .monospacedDigit()
                                .foregroundStyle(balance < 0 ? .red : .primary)
                        } else {
                            Text("sin saldo").foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Text(title)
            } footer: {
                if let note { Text(note).font(.caption) }
            }
        }
    }
}

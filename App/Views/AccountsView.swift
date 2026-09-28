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
            AccountsContent(snapshot: snapshot)
        }
    }

    private func load() async throws -> Snapshot {
        let today = Date.now
        let from = Calendar.current.date(byAdding: .month, value: -12, to: today) ?? today
        async let accounts = service.accounts()
        async let worth = service.netWorth(from: WisprDate.string(from), to: WisprDate.string(today))
        return try await Snapshot(accounts: accounts.accounts, balances: worth.latestBalances)
    }
}

struct AccountsContent: View {
    let snapshot: AccountsView.Snapshot

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 380), spacing: 16, alignment: .top)], spacing: 16) {
                group("Débito y efectivo", where: { !$0.isLiability }, note: nil)
                group("Tarjetas de crédito", where: { $0.type == "credit_card" },
                      note: "Saldo negativo = lo que debes en la tarjeta.")
                group("Préstamos", where: { $0.type == "loan" },
                      note: "Saldo = lo que falta por pagar.")
            }
            .padding(24)
        }
        .pageBackground(.teal)
    }

    @ViewBuilder
    private func group(_ title: String, where include: (Account) -> Bool, note: String?) -> some View {
        let rows = snapshot.accounts.filter(include)
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title).font(.headline)
                    Spacer()
                    Text("\(rows.count) \(rows.count == 1 ? "cuenta" : "cuentas")")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(.bottom, 8)
                ForEach(rows) { account in
                    row(account)
                    if account.id != rows.last?.id { Divider().padding(.leading, 44) }
                }
                if let note {
                    Text(note).font(.caption).foregroundStyle(.secondary).padding(.top, 8)
                }
            }
            .card()
        }
    }

    private func row(_ account: Account) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol(for: account))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(tint(for: account).gradient, in: .rect(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 1) {
                Text(account.name).font(.body.weight(.medium))
                Text(account.bank ?? account.type).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let balance = snapshot.balances[account.id] {
                Text(Money.format(balance, currency: account.currency))
                    .font(.system(.body, design: .rounded).weight(.semibold).monospacedDigit())
                    .foregroundStyle(balance < 0 ? .red : .primary)
            } else {
                Text("sin saldo").foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 6)
    }

    private func symbol(for account: Account) -> String {
        switch account.type {
        case "credit_card": "creditcard.fill"
        case "loan": "banknote.fill"
        case "savings": "building.columns.fill"
        case "cash": "dollarsign"
        case "investment": "chart.line.uptrend.xyaxis"
        default: "wallet.pass.fill"
        }
    }

    private func tint(for account: Account) -> Color {
        switch account.type {
        case "credit_card": .orange
        case "loan": .red
        case "savings": .indigo
        case "cash": .green
        default: .blue
        }
    }
}

#if DEBUG
#Preview("Cuentas") {
    NavigationStack {
        AccountsContent(snapshot: .init(accounts: PreviewData.accounts.accounts,
                                        balances: PreviewData.netWorth.latestBalances))
            .navigationTitle("Cuentas")
    }
    .frame(width: 980, height: 640)
}
#endif

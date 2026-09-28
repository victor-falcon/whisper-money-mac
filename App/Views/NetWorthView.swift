import Charts
import SwiftUI
import WisprKit

struct NetWorthView: View {
    let service: WisprService

    struct Snapshot {
        let worth: NetWorthResponse
        let names: [String: String]
    }

    struct SeriesPoint: Identifiable {
        let id = UUID()
        let label: String
        let account: String
        let value: Double
    }

    var body: some View {
        LiveView(load: load) { snapshot in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header(snapshot.worth.current)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Saldo por cuenta, últimos 12 meses").font(.headline)
                        Chart(series(snapshot)) { p in
                            LineMark(x: .value("Mes", p.label), y: .value("Saldo", p.value))
                                .foregroundStyle(by: .value("Cuenta", p.account))
                                .symbol(by: .value("Cuenta", p.account))
                        }
                        .chartYAxis { AxisMarks(format: .currency(code: snapshot.worth.current.currencyCode).precision(.fractionLength(0))) }
                        .frame(height: 320)
                    }
                }
                .padding(20)
            }
        }
    }

    private func load() async throws -> Snapshot {
        let today = Date.now
        let from = WisprDate.startOfMonth(Calendar.current.date(byAdding: .month, value: -11, to: today) ?? today)
        async let worth = service.netWorth(from: WisprDate.string(from), to: WisprDate.string(today))
        async let accounts = service.accounts()
        let names = try await Dictionary(uniqueKeysWithValues: accounts.accounts.map { ($0.id, $0.name) })
        return try await Snapshot(worth: worth, names: names)
    }

    private func header(_ c: NetWorthResponse.Current) -> some View {
        let delta = c.current - c.previous
        return VStack(alignment: .leading, spacing: 6) {
            Text("Patrimonio neto").font(.caption).foregroundStyle(.secondary)
            Text(Money.format(c.current, currency: c.currencyCode))
                .font(.system(size: 34, weight: .bold).monospacedDigit())
                .foregroundStyle(c.current < 0 ? .red : .primary)
            Label("\(delta >= 0 ? "+" : "")\(Money.format(delta, currency: c.currencyCode)) vs. periodo anterior",
                  systemImage: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.callout)
                .foregroundStyle(delta >= 0 ? .green : .red)
        }
    }

    private func series(_ s: Snapshot) -> [SeriesPoint] {
        let currency = s.worth.current.currencyCode
        return s.worth.evolution.data.flatMap { point in
            point.balances.map { id, value in
                SeriesPoint(label: point.label, account: s.names[id] ?? id,
                            value: Money.double(value, currency: currency))
            }
        }
    }
}

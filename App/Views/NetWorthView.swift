import Charts
import SwiftUI
import WhisperKit

struct NetWorthView: View {
    let service: WhisperService

    struct Snapshot {
        let worth: NetWorthResponse
        let accounts: [Account]
    }

    var body: some View {
        LiveView(load: load) { snapshot in
            NetWorthContent(worth: snapshot.worth, accounts: snapshot.accounts)
        }
    }

    private func load() async throws -> Snapshot {
        let today = Date.now
        let from = WhisperDate.startOfMonth(Calendar.current.date(byAdding: .month, value: -11, to: today) ?? today)
        async let worth = service.netWorth(from: WhisperDate.string(from), to: WhisperDate.string(today))
        async let accounts = service.accounts()
        return try await Snapshot(worth: worth, accounts: accounts.accounts)
    }
}

/// Saldos por cuenta listos para un área apilada: activos hacia arriba, deudas hacia abajo.
/// Préstamos y tarjetas cuentan siempre como deuda (Whisper Money manda los préstamos en positivo y las
/// tarjetas en negativo). Cada cuenta aporta dos series, su parte positiva y su parte negativa, para
/// que si un activo cambia de signo entre meses la transición pase por cero sin cruzar otras capas.
struct NetWorthBreakdown {
    struct Line: Identifiable {
        let id: String
        let name: String
        let isDebt: Bool
        let latest: Int
        let color: Color
    }

    struct Layer: Identifiable {
        let series: String
        let date: Date
        let low: Double
        let high: Double
        var id: String { "\(series)-\(date.timeIntervalSince1970)" }
    }

    struct Total: Identifiable {
        let date: Date
        let net: Int
        let assets: Int
        let debts: Int
        var id: Date { date }
    }

    let currency: String
    let lines: [Line]
    let layers: [Layer]
    let totals: [Total]

    var assets: [Line] { lines.filter { !$0.isDebt } }
    var debts: [Line] { lines.filter(\.isDebt) }

    /// Dominio y colores para `chartForegroundStyleScale`: dos series por cuenta, mismo color.
    var seriesDomain: [String] { lines.flatMap { [Self.up($0.id), Self.down($0.id)] } }
    var seriesColors: [Color] { lines.flatMap { [$0.color, $0.color] } }

    private static func up(_ id: String) -> String { id + "+" }
    private static func down(_ id: String) -> String { id + "-" }

    private static let assetColors: [Color] = [.blue, .teal, .cyan, .indigo, .mint, .green]
    private static let debtColors: [Color] = [.red, .orange, .pink, .yellow, .brown, .purple]

    init(worth: NetWorthResponse, accounts: [Account]) {
        currency = worth.current.currencyCode
        let byID = Dictionary(accounts.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let points = worth.evolution.data
            .compactMap { point in WhisperDate.date(point.label).map { (date: $0, balances: point.balances) } }
            .sorted { $0.date < $1.date }

        func signed(_ id: String, _ value: Int) -> Int {
            byID[id]?.isLiability == true ? -abs(value) : value
        }

        // Cuentas con algún saldo distinto de cero, las más grandes primero dentro de cada grupo.
        let latest = worth.latestBalances
        let ids = Set(points.flatMap { $0.balances.filter { $0.value != 0 }.keys })
        let ranked = ids.map { id in
            let value = signed(id, latest[id] ?? 0)
            return (id: id, value: value, debt: byID[id]?.isLiability == true || value < 0)
        }
        .sorted { ($0.debt ? 1 : 0, -abs($0.value), $0.id) < ($1.debt ? 1 : 0, -abs($1.value), $1.id) }

        var assetIndex = 0, debtIndex = 0
        lines = ranked.map { item in
            let palette = item.debt ? Self.debtColors : Self.assetColors
            let index = item.debt ? debtIndex : assetIndex
            if item.debt { debtIndex += 1 } else { assetIndex += 1 }
            let base = palette[index % palette.count]
            let color = index < palette.count ? base : base.mix(with: .white, by: 0.35)
            return Line(id: item.id, name: byID[item.id]?.name ?? item.id, isDebt: item.debt,
                        latest: item.value, color: color)
        }

        var layers: [Layer] = []
        var totals: [Total] = []
        for point in points {
            var up = 0.0, down = 0.0
            var assets = 0, debts = 0
            for line in lines {
                let minor = signed(line.id, point.balances[line.id] ?? 0)
                let positive = Money.double(max(minor, 0), currency: currency)
                let negative = Money.double(min(minor, 0), currency: currency)
                layers.append(Layer(series: Self.up(line.id), date: point.date, low: up, high: up + positive))
                layers.append(Layer(series: Self.down(line.id), date: point.date, low: down + negative, high: down))
                up += positive
                down += negative
                if minor >= 0 { assets += minor } else { debts += minor }
            }
            totals.append(Total(date: point.date, net: assets + debts, assets: assets, debts: debts))
        }
        self.layers = layers
        self.totals = totals
    }
}

struct NetWorthContent: View {
    let worth: NetWorthResponse
    let accounts: [Account]
    @State private var selected: Date?

    var body: some View {
        let breakdown = NetWorthBreakdown(worth: worth, accounts: accounts)
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header(breakdown)
                chart(breakdown)
                HStack(alignment: .top, spacing: 16) {
                    group("Activos", breakdown.assets, currency: breakdown.currency)
                    group("Deudas", breakdown.debts, currency: breakdown.currency)
                }
            }
            .padding(24)
        }
        .pageBackground(worth.current.current < 0 ? .red : .blue)
    }

    private func header(_ b: NetWorthBreakdown) -> some View {
        let c = worth.current
        let delta = c.current - c.previous
        let last = b.totals.last
        let total = VStack(alignment: .leading, spacing: 8) {
            Text("Patrimonio neto").font(.subheadline).foregroundStyle(.secondary)
            Text(Money.format(c.current, currency: c.currencyCode))
                .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(c.current < 0 ? .red : .primary)
                .lineLimit(1)
            Pill(text: "\(delta >= 0 ? "+" : "")\(Money.format(delta, currency: c.currencyCode)) vs. anterior",
                 symbol: delta >= 0 ? "arrow.up.right" : "arrow.down.right",
                 tint: delta >= 0 ? .green : .red)
        }
        let split = HStack(spacing: 32) {
            if let last {
                Figure(label: "Activos", value: Money.format(last.assets, currency: b.currency))
                Figure(label: "Deudas", value: Money.format(-last.debts, currency: b.currency), tint: .red)
            }
        }
        return VStack(alignment: .leading, spacing: 12) {
            // Si el total y el desglose no caben en una fila (ventana angosta), el desglose baja.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .bottom, spacing: 32) {
                    total
                    Spacer(minLength: 0)
                    split
                }
                VStack(alignment: .leading, spacing: 16) {
                    total
                    split
                }
            }
            if let last, last.net != c.current {
                Text("La suma de tus cuentas da \(Money.format(last.net, currency: b.currency)): Whisper Money calcula este total con otro criterio.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .card(padding: 24)
    }

    private func chart(_ b: NetWorthBreakdown) -> some View {
        let focus = selected.flatMap { date in
            b.totals.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
        }
        return VStack(alignment: .leading, spacing: 16) {
            CardTitle(title: "Evolución", subtitle: "Activos arriba; préstamos y tarjetas abajo. La línea es la suma de tus cuentas.")
            Chart {
                ForEach(b.layers) { layer in
                    AreaMark(x: .value("Mes", layer.date, unit: .month),
                             yStart: .value("Desde", layer.low),
                             yEnd: .value("Hasta", layer.high))
                        .foregroundStyle(by: .value("Cuenta", layer.series))
                        .opacity(0.8)
                }
                RuleMark(y: .value("Cero", 0))
                    .foregroundStyle(.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1))
                ForEach(b.totals) { total in
                    LineMark(x: .value("Mes", total.date, unit: .month),
                             y: .value("Neto", Money.double(total.net, currency: b.currency)),
                             series: .value("Serie", "Neto"))
                        .foregroundStyle(Color.primary)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                }
                if let focus {
                    RuleMark(x: .value("Mes", focus.date, unit: .month))
                        .foregroundStyle(.secondary.opacity(0.5))
                        .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                            tooltip(focus, currency: b.currency)
                        }
                    PointMark(x: .value("Mes", focus.date, unit: .month),
                              y: .value("Neto", Money.double(focus.net, currency: b.currency)))
                        .foregroundStyle(Color.primary)
                        .symbolSize(70)
                }
            }
            .chartForegroundStyleScale(domain: b.seriesDomain, range: b.seriesColors)
            .chartLegend(.hidden)
            .chartXSelection(value: $selected)
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(amount.formatted(.currency(code: b.currency).notation(.compactName)))
                        }
                    }
                }
            }
            .frame(height: 320)
        }
        .card(padding: 24)
    }

    private func tooltip(_ total: NetWorthBreakdown.Total, currency: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(total.date.formatted(.dateTime.month(.wide).year()).capitalized)
                .font(.caption).foregroundStyle(.secondary)
            Text(Money.format(total.net, currency: currency))
                .font(.system(.headline, design: .rounded).monospacedDigit())
            Text("Activos \(Money.format(total.assets, currency: currency))")
                .font(.caption.monospacedDigit())
            Text("Deudas \(Money.format(-total.debts, currency: currency))")
                .font(.caption.monospacedDigit()).foregroundStyle(.red)
        }
        .padding(10)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
    }

    private func group(_ title: String, _ lines: [NetWorthBreakdown.Line], currency: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.headline)
                Spacer()
                Text(Money.format(abs(lines.reduce(0) { $0 + $1.latest }), currency: currency))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(title == "Deudas" ? .red : .primary)
            }
            if lines.isEmpty {
                Text("Nada por aquí").font(.callout).foregroundStyle(.secondary)
            }
            ForEach(lines) { line in
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 3).fill(line.color.gradient).frame(width: 10, height: 10)
                    Text(line.name).lineLimit(1)
                    Spacer(minLength: 8)
                    Text(Money.format(abs(line.latest), currency: currency))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .font(.callout)
            }
        }
        .card()
    }
}

#if DEBUG
#Preview("Patrimonio") {
    NavigationStack {
        NetWorthContent(worth: PreviewData.netWorth, accounts: PreviewData.accounts.accounts)
            .navigationTitle("Patrimonio")
    }
    .frame(width: 980, height: 820)
}

#Preview("Patrimonio, ancho mínimo") {
    NavigationStack {
        NetWorthContent(worth: PreviewData.netWorth, accounts: PreviewData.accounts.accounts)
    }
    .frame(width: 630, height: 640)
}
#endif

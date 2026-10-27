import SwiftUI
import WidgetKit
import WhisperKit

struct TransactionsView: View {
    let service: WhisperService

    @State private var month = WhisperDate.startOfMonth(.now)
    @State private var search = ""
    @State private var debounced = ""
    @State private var accountID: String?
    @State private var accounts: [Account] = []
    @State private var showingNew = false
    @State private var reload = 0

    private var filter: TransactionFilter {
        var f = TransactionFilter()
        f.query = debounced
        f.accountID = accountID
        f.from = WhisperDate.string(WhisperDate.startOfMonth(month))
        f.to = WhisperDate.string(WhisperDate.endOfMonth(month))
        f.limit = 200
        return f
    }

    var body: some View {
        LiveView(key: FilterKey(filter: filter, reload: reload), load: { [filter] in
            try await service.transactions(filter)
        }) { response in
            Table(response.transactions) {
                TableColumn("Fecha", value: \.date).width(90)
                TableColumn("Descripción") { tx in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tx.description)
                        if !tx.labels.isEmpty {
                            Text(tx.labels.map(\.name).joined(separator: ", "))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                TableColumn("Cuenta", value: \.account).width(min: 90, ideal: 110)
                TableColumn("Categoría") { tx in
                    Text(tx.category ?? "Sin categoría").foregroundStyle(tx.category == nil ? .secondary : .primary)
                }
                .width(min: 100, ideal: 140)
                TableColumn("Monto") { tx in
                    Text(Money.format(tx.amount, currency: tx.currency))
                        .monospacedDigit()
                        .foregroundStyle(tx.amount < 0 ? Color.primary : Color.green)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(min: 90, ideal: 110)
            }
            .overlay {
                if response.transactions.isEmpty {
                    ContentUnavailableView.search
                }
            }
            .safeAreaInset(edge: .top) {
                if response.count >= filter.limit {
                    Text("Se muestran los primeros \(filter.limit). Filtra por cuenta o texto para ver el resto.")
                        .font(.caption).foregroundStyle(.orange).padding(.top, 4)
                }
            }
        }
        .searchable(text: $search, prompt: "Descripción, comercio…")
        .task(id: search) {
            try? await Task.sleep(for: .milliseconds(350))
            if !Task.isCancelled { debounced = search }
        }
        .task { accounts = (try? await service.accounts().accounts) ?? [] }
        .toolbar {
            ToolbarItemGroup {
                MonthStepper(month: $month)
                Picker("Cuenta", selection: $accountID) {
                    Text("Todas las cuentas").tag(String?.none)
                    ForEach(accounts) { Text($0.name).tag(Optional($0.id)) }
                }
                .frame(width: 170)
                Button { showingNew = true } label: { Label("Nuevo movimiento", systemImage: "plus") }
                    .keyboardShortcut("n", modifiers: .command)
                    .disabled(accounts.isEmpty)
            }
        }
        .sheet(isPresented: $showingNew) {
            NewTransactionView(service: service, accounts: accounts) {
                reload += 1
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }

    private struct FilterKey: Hashable {
        let filter: TransactionFilter
        let reload: Int
    }
}

struct NewTransactionView: View {
    let service: WhisperService
    let accounts: [Account]
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var accountID = ""
    @State private var description = ""
    @State private var amount: Decimal?
    @State private var isExpense = true
    @State private var date = Date.now
    @State private var categoryID: String?
    @State private var notes = ""
    @State private var categories: [WhisperKit.Category] = []
    @State private var saving = false
    @State private var error: String?

    private var currency: String {
        accounts.first(where: { $0.id == accountID })?.currency ?? "MXN"
    }

    var body: some View {
        Form {
            Picker("Cuenta", selection: $accountID) {
                ForEach(accounts) { Text($0.name).tag($0.id) }
            }
            TextField("Descripción", text: $description)
            Picker("Tipo", selection: $isExpense) {
                Text("Gasto").tag(true)
                Text("Ingreso").tag(false)
            }
            .pickerStyle(.segmented)
            TextField("Monto (\(currency))", value: $amount, format: .number.precision(.fractionLength(0...Money.exponent(for: currency))))
            DatePicker("Fecha", selection: $date, displayedComponents: .date)
            Picker("Categoría", selection: $categoryID) {
                Text("Sin categoría").tag(String?.none)
                ForEach(categories.filter { $0.id != nil }, id: \.id) { Text($0.name).tag($0.id) }
            }
            TextField("Notas", text: $notes, axis: .vertical)
            Text("Whisper Money no deduplica: registra aquí solo lo que el banco no va a sincronizar.")
                .font(.caption).foregroundStyle(.secondary)
            if let error { Text(error).foregroundStyle(.red) }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") { Task { await save() } }
                    .disabled(saving || accountID.isEmpty || description.isEmpty || (amount ?? 0) <= 0)
            }
        }
        .task {
            if accountID.isEmpty { accountID = accounts.first?.id ?? "" }
            categories = ((try? await service.categories().categories) ?? []).sorted { $0.name < $1.name }
        }
    }

    private func save() async {
        guard let amount else { return }
        saving = true
        defer { saving = false }
        let minor = Money.minor(fromMajor: amount, currency: currency)
        let new = NewTransaction(accountID: accountID, description: description,
                                 amount: isExpense ? -minor : minor, date: WhisperDate.string(date),
                                 categoryID: categoryID, notes: notes)
        do {
            try await service.createTransaction(new)
            onSaved()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

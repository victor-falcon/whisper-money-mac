import SwiftUI

/// Consulta en vivo a Whisper Money: carga al aparecer, vuelve a pedir cada `interval` mientras la vista
/// está visible y con ⌘R. Si una consulta falla, se muestra el error, nunca números anteriores.
struct LiveView<Value, Content: View>: View {
    var key: AnyHashable = 0
    var interval: Duration = .seconds(60)
    let load: () async throws -> Value
    @ViewBuilder let content: (Value) -> Content

    @State private var value: Value?
    @State private var error: String?
    @State private var fetchedAt: Date?
    @State private var loading = false
    @State private var manualTick = 0

    var body: some View {
        Group {
            if let error {
                ContentUnavailableView {
                    Label("Sin conexión con Whisper Money", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(error)
                } actions: {
                    Button("Reintentar") { manualTick += 1 }
                }
            } else if let value {
                content(value)
            } else {
                ProgressView("Consultando Whisper Money…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        // La hora de la última consulta vive en el subtítulo de la ventana, bajo el título.
        .navigationSubtitle(status)
        .toolbar {
            ToolbarItem {
                Button { manualTick += 1 } label: {
                    if loading {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Actualizar", systemImage: "arrow.clockwise")
                    }
                }
                .help("Consultar a Whisper Money de nuevo (⌘R)")
                .keyboardShortcut("r", modifiers: .command)
            }
        }
        .task(id: TaskKey(key: key, tick: manualTick)) {
            while !Task.isCancelled {
                await fetch()
                try? await Task.sleep(for: interval)
            }
        }
    }

    private var status: String {
        if error != nil { return "Sin conexión" }
        guard let fetchedAt else { return "Consultando…" }
        return "En vivo · \(fetchedAt.formatted(date: .omitted, time: .standard))"
    }

    private func fetch() async {
        loading = true
        defer { loading = false }
        do {
            let fresh = try await load()
            guard !Task.isCancelled else { return }
            value = fresh
            error = nil
            fetchedAt = .now
        } catch is CancellationError {
        } catch {
            guard !Task.isCancelled else { return }
            value = nil
            self.error = error.localizedDescription
            fetchedAt = nil
        }
    }

    private struct TaskKey: Hashable {
        let key: AnyHashable
        let tick: Int
    }
}

/// Selector de mes con flechas.
struct MonthStepper: View {
    @Binding var month: Date

    var body: some View {
        HStack(spacing: 4) {
            Button { shift(-1) } label: { Image(systemName: "chevron.left") }
            Text(month.formatted(.dateTime.month(.wide).year()).capitalized)
                .frame(minWidth: 130)
            Button { shift(1) } label: { Image(systemName: "chevron.right") }
        }
        .buttonStyle(.borderless)
    }

    private func shift(_ delta: Int) {
        month = Calendar.current.date(byAdding: .month, value: delta, to: month) ?? month
    }
}

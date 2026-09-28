import SwiftUI

struct SetupView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "dollarsign.circle")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("Conectar con Wispr Money")
                .font(.title2.bold())
            Text("La app consulta tu servidor en vivo por MCP. El token se guarda en el Llavero de macOS; ningún dato financiero se guarda en la Mac.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 420)
            ConnectionForm()
                .frame(maxWidth: 440)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ConnectionForm: View {
    @Environment(AppModel.self) private var model
    @State private var endpoint = ""
    @State private var token = ""
    @State private var connecting = false
    @State private var error: String?

    var body: some View {
        Form {
            TextField("Endpoint MCP", text: $endpoint, prompt: Text("https://…/mcp"))
            SecureField("Token", text: $token)
            if let error {
                Text(error).foregroundStyle(.red).font(.callout)
            }
            if let keychainError = model.keychainError {
                Text(keychainError).foregroundStyle(.orange).font(.callout)
            }
            HStack {
                Spacer()
                Button {
                    Task { await connect() }
                } label: {
                    if connecting { ProgressView().controlSize(.small) } else { Text("Conectar") }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(connecting || URL(string: endpoint)?.scheme == nil || token.isEmpty)
            }
        }
        .formStyle(.grouped)
    }

    private func connect() async {
        guard let url = URL(string: endpoint.trimmingCharacters(in: .whitespaces)) else { return }
        connecting = true
        defer { connecting = false }
        do {
            // Acepta el token con o sin el prefijo "Bearer ".
            var clean = token.trimmingCharacters(in: .whitespacesAndNewlines)
            if clean.lowercased().hasPrefix("bearer ") { clean = String(clean.dropFirst(7)) }
            try await model.connect(endpoint: url, token: clean)
            token = ""
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            if let endpoint = model.endpoint {
                LabeledContent("Conectado a", value: endpoint.host() ?? endpoint.absoluteString)
                Button("Desconectar y borrar token", role: .destructive) { model.disconnect() }
            } else {
                Text("Sin conexión configurada.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .padding()
    }
}

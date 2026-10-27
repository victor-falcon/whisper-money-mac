import Foundation
import WhisperKit

// Prueba la conexión real con Whisper Money sin Xcode. Imprime solo conteos y nombres, nunca montos.
//   WHISPER_ENDPOINT=https://<host>/mcp WHISPER_TOKEN=<token> swift run whisper-probe

let env = ProcessInfo.processInfo.environment
guard let raw = env["WHISPER_ENDPOINT"], let endpoint = URL(string: raw), var token = env["WHISPER_TOKEN"], !token.isEmpty else {
    FileHandle.standardError.write(Data("Faltan WHISPER_ENDPOINT y/o WHISPER_TOKEN.\n".utf8))
    exit(2)
}
if token.lowercased().hasPrefix("bearer ") { token = String(token.dropFirst(7)) }

let service = WhisperService(credentials: Credentials(endpoint: endpoint, token: token))
do {
    let budgets = try await service.budgets()
    print("OK list_budgets: \(budgets.budgets.count) presupuestos (\(budgets.budgets.map(\.name).joined(separator: ", ")))")
    let accounts = try await service.accounts()
    print("OK list_accounts: \(accounts.accounts.count) cuentas")
    let today = WhisperDate.string(.now)
    let worth = try await service.netWorth(from: today, to: today)
    print("OK get_net_worth: \(worth.latestBalances.count) cuentas con saldo")
    print("Conexión directa verificada.")
} catch {
    print("FALLÓ: \(error.localizedDescription)")
    exit(1)
}

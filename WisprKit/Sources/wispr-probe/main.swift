import Foundation
import WisprKit

// Prueba la conexión real con Wispr Money sin Xcode. Imprime solo conteos y nombres, nunca montos.
//   WISPR_ENDPOINT=https://<host>/mcp WISPR_TOKEN=<token> swift run wispr-probe

let env = ProcessInfo.processInfo.environment
guard let raw = env["WISPR_ENDPOINT"], let endpoint = URL(string: raw), var token = env["WISPR_TOKEN"], !token.isEmpty else {
    FileHandle.standardError.write(Data("Faltan WISPR_ENDPOINT y/o WISPR_TOKEN.\n".utf8))
    exit(2)
}
if token.lowercased().hasPrefix("bearer ") { token = String(token.dropFirst(7)) }

let service = WisprService(credentials: Credentials(endpoint: endpoint, token: token))
do {
    let budgets = try await service.budgets()
    print("OK list_budgets: \(budgets.budgets.count) presupuestos (\(budgets.budgets.map(\.name).joined(separator: ", ")))")
    let accounts = try await service.accounts()
    print("OK list_accounts: \(accounts.accounts.count) cuentas")
    let today = WisprDate.string(.now)
    let worth = try await service.netWorth(from: today, to: today)
    print("OK get_net_worth: \(worth.latestBalances.count) cuentas con saldo")
    print("Conexión directa verificada.")
} catch {
    print("FALLÓ: \(error.localizedDescription)")
    exit(1)
}

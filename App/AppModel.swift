import Foundation
import Observation
import SwiftUI
import WidgetKit
import WisprKit

enum AppSection: String, CaseIterable, Identifiable {
    case presupuestos, cuentas, movimientos, flujo, patrimonio

    var id: String { rawValue }

    var title: String {
        switch self {
        case .presupuestos: "Presupuestos"
        case .cuentas: "Cuentas"
        case .movimientos: "Movimientos"
        case .flujo: "Flujo"
        case .patrimonio: "Patrimonio"
        }
    }

    var symbol: String {
        switch self {
        case .presupuestos: "chart.bar.fill"
        case .cuentas: "building.columns"
        case .movimientos: "list.bullet.rectangle"
        case .flujo: "arrow.left.arrow.right"
        case .patrimonio: "chart.line.uptrend.xyaxis"
        }
    }

    var shortcut: KeyEquivalent {
        switch self {
        case .presupuestos: "1"
        case .cuentas: "2"
        case .movimientos: "3"
        case .flujo: "4"
        case .patrimonio: "5"
        }
    }
}

@MainActor
@Observable
final class AppModel {
    var section: AppSection = .presupuestos
    private(set) var service: WisprService?
    private(set) var endpoint: URL?
    var keychainError: String?

    private let store = CredentialStore.fromBundle()

    init() {
        do {
            if let credentials = try store.load() { use(credentials) }
        } catch {
            keychainError = error.localizedDescription
        }
    }

    /// Prueba la conexión con una consulta real antes de guardar nada en el Llavero.
    func connect(endpoint: URL, token: String) async throws {
        let credentials = Credentials(endpoint: endpoint, token: token)
        let candidate = WisprService(credentials: credentials)
        _ = try await candidate.budgets()
        try store.save(credentials)
        use(credentials)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func disconnect() {
        try? store.delete()
        service = nil
        endpoint = nil
        WidgetCenter.shared.reloadAllTimelines()
    }

    func open(_ url: URL) {
        guard url.scheme == "wisprmac", let host = url.host(), let target = AppSection(rawValue: host) else { return }
        section = target
    }

    private func use(_ credentials: Credentials) {
        service = WisprService(credentials: credentials)
        endpoint = credentials.endpoint
    }
}

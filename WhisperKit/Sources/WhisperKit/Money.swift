import Foundation

/// Montos en unidades menores → texto. Cuántas unidades menores tiene la unidad mayor depende de la
/// moneda (no siempre 100), según las instrucciones del MCP de Whisper Money.
public enum Money {
    static let exponents: [String: Int] = [
        "COP": 0, "CLP": 0, "PYG": 0, "JPY": 0, "PKR": 0,
        "KWD": 3,
        "BTC": 8,
    ]

    public static func exponent(for currency: String) -> Int {
        exponents[currency.uppercased()] ?? 2
    }

    public static func major(_ minor: Int, currency: String) -> Decimal {
        Decimal(minor) / pow(10, exponent(for: currency))
    }

    /// Para ejes de gráficas (Swift Charts pide `Double`); nunca para aritmética de dinero.
    public static func double(_ minor: Int, currency: String) -> Double {
        NSDecimalNumber(decimal: major(minor, currency: currency)).doubleValue
    }

    public static func minor(fromMajor major: Decimal, currency: String) -> Int {
        var scaled = major * pow(10, exponent(for: currency))
        var rounded = Decimal()
        NSDecimalRound(&rounded, &scaled, 0, .plain)
        return NSDecimalNumber(decimal: rounded).intValue
    }

    public static func format(_ minor: Int, currency: String, locale: Locale = Locale(identifier: "es_MX")) -> String {
        major(minor, currency: currency).formatted(
            .currency(code: currency)
                .locale(locale)
                .precision(.fractionLength(exponent(for: currency)))
        )
    }
}

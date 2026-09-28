import SwiftUI

// Lenguaje visual de las pantallas: tarjetas de material sobre un fondo con el tinte de la sección.
// El vidrio (Liquid Glass) queda para la capa flotante —barra lateral y toolbar—, no para el contenido.

extension View {
    /// Tarjeta de contenido: material con borde fino, esquinas continuas.
    func card(padding: CGFloat = 20) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: .rect(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.separator.opacity(0.5), lineWidth: 0.5))
    }

    /// Fondo de pantalla con un degradado suave del color de la sección, para que el vidrio de la
    /// toolbar tenga algo que refractar.
    func pageBackground(_ tint: Color) -> some View {
        background {
            LinearGradient(colors: [tint.opacity(0.16), tint.opacity(0.04), .clear],
                           startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
        }
    }
}

/// Título de bloque dentro de una tarjeta.
struct CardTitle: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.headline)
            if let subtitle {
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}

/// Cifra grande con su etiqueta arriba.
struct Figure: View {
    let label: String
    let value: String
    var tint: Color = .primary
    var size: Font = .system(.title2, design: .rounded)

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Text(value)
                .font(size.weight(.semibold).monospacedDigit())
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }
}

/// Píldora de estado ("2 excedidos", "+$1,200 vs. mes anterior").
struct Pill: View {
    let text: String
    var symbol: String?
    var tint: Color = .secondary

    var body: some View {
        Label {
            Text(text)
        } icon: {
            if let symbol { Image(systemName: symbol) }
        }
        .font(.callout.weight(.medium).monospacedDigit())
        .lineLimit(1)
        .fixedSize()
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(tint.opacity(0.14), in: .capsule)
    }
}

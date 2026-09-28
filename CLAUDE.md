# CLAUDE.md — Wispr Money para Mac

App nativa de macOS (SwiftUI, sin vistas web) + widget WidgetKit para Wispr Money self-hosted.
Arquitectura, pantallas y principio "nada pre-cacheado" en `README.md`. Idioma: español.

## Reglas no negociables

- **Conexión directa, sin caché:** toda cifra viene de una llamada en vivo al MCP de Wispr
  (`WisprKit/MCPClient`). Nada de persistir montos (ni UserDefaults, ni app group, ni archivos).
  Si una consulta falla se muestra el error, nunca valores anteriores.
- El widget refresca ~cada 15 min pidiendo en vivo, muestra la hora de consulta y "Sin conexión"
  si falla (acordado con Diego).
- Datos financieros reales: no van a commits, tests, fixtures, capturas en el repo ni reportes.
  Los tests usan fixtures sintéticos. Capturas de pantalla solo al scratchpad.
- El token vive en el Llavero (grupo `7QQ3Y399CF.mx.diego.wisprmac.shared`); nunca se imprime.
- Montos en unidades menores (`Money`); la moneda sale de la respuesta, no se hardcodea.

## Compilar, instalar, probar

`xcode-select` apunta a las Command Line Tools: usa siempre
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodegen generate
xcodebuild -project WisprMac.xcodeproj -scheme WisprMac -derivedDataPath .build/xcode -allowProvisioningUpdates build
pkill -x WisprMoney; ditto .build/xcode/Build/Products/Debug/WisprMoney.app /Applications/WisprMoney.app && open /Applications/WisprMoney.app
./scripts/test.sh                      # tests de WisprKit
```

Team ID en `Config/Team.local.xcconfig` (ignorado por git). Instalar en `/Applications` es lo que
hace que macOS registre el widget.

## MCPs del proyecto (`.mcp.json`)

- `xcode` (`xcrun mcpbridge`): RenderPreview, build, DocumentationSearch. Requiere Xcode abierto con
  el proyecto y "Xcode Tools" activado en Settings → Intelligence.
- `peekaboo`: capturas y árbol de accesibilidad de la app real y del widget en el escritorio.
- `sosumi`: docs de Apple, HIG y WWDC.

Skills a usar para UI: `swiftui-expert-skill` (AvdLee), `swiftui-pro`, `swiftui-liquid-glass`,
`macos-design-guidelines`.

## Siguiente trabajo: rediseño (pedido 28-sep-2026)

Diego calificó la UI de la app y del widget como "horrible". Plan acordado:

1. Estética macOS 26 Tahoe: sidebar translúcida, toolbar con Liquid Glass, tipografía con
   jerarquía, tarjetas con materiales en vez de cajas grises.
2. Patrimonio: área apilada activos vs deudas (préstamos y tarjetas como deuda, hacia abajo) en vez
   de 12 líneas encimadas; hoy hay mucho espacio muerto y la leyenda es diminuta.
3. Presupuestos: anillos de progreso tipo Actividad + resumen del mes.
4. Widget: soportar modos vidrio/tintado (`widgetAccentable`, `widgetRenderingMode`,
   `containerBackground`), anillos grandes y total del mes.
5. Verificar con capturas antes/después de cada pantalla y del widget (Peekaboo o RenderPreview);
   no pedirle a Diego que diga si se ve bien.

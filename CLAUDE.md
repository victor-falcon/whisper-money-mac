# CLAUDE.md — Whisper Money para Mac

App nativa de macOS (SwiftUI, sin vistas web) + widget WidgetKit para Whisper Money self-hosted.
Arquitectura, pantallas y principio "nada pre-cacheado" en `README.md`. Idioma: español.

## Reglas no negociables

- **Conexión directa, sin caché:** toda cifra viene de una llamada en vivo al MCP de Whisper Money
  (`WhisperKit/MCPClient`). Nada de persistir montos (ni UserDefaults, ni app group, ni archivos).
  Si una consulta falla se muestra el error, nunca valores anteriores.
- El widget refresca ~cada 15 min pidiendo en vivo, muestra la hora de consulta y "Sin conexión"
  si falla (acordado con Diego).
- Datos financieros reales: no van a commits, tests, fixtures, capturas en el repo ni reportes.
  Los tests usan fixtures sintéticos. Capturas de pantalla solo al scratchpad.
- El token vive en el Llavero (grupo `<TeamID>.mx.diego.whispermac.shared`); nunca se imprime.
- Montos en unidades menores (`Money`); la moneda sale de la respuesta, no se hardcodea.

## Compilar, instalar, probar

`xcode-select` apunta a las Command Line Tools: usa siempre
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodegen generate
xcodebuild -project WhisperMac.xcodeproj -scheme WhisperMac -derivedDataPath .build/xcode -allowProvisioningUpdates build
pkill -x WhisperMoney; ditto .build/xcode/Build/Products/Debug/WhisperMoney.app /Applications/WhisperMoney.app && open /Applications/WhisperMoney.app
./scripts/test.sh                      # tests de WhisperKit
```

Tras reinstalar, el escritorio sigue mostrando la extensión vieja del widget (WidgetKit la cachea si
no cambia la versión): `pkill -f BudgetsWidget.appex; killall chronod` y vuelve a abrir la app.
macOS no previsualiza widgets; la galería `App/Views/WidgetPreviews.swift` los dibuja desde la app.

Team ID en `Config/Team.local.xcconfig` (ignorado por git). Instalar en `/Applications` es lo que
hace que macOS registre el widget.

## MCPs del proyecto (`.mcp.json`)

- `xcode` (`xcrun mcpbridge`): RenderPreview, build, DocumentationSearch. Requiere Xcode abierto con
  el proyecto y "Xcode Tools" activado en Settings → Intelligence.
- `peekaboo`: capturas y árbol de accesibilidad de la app real y del widget en el escritorio.
- `sosumi`: docs de Apple, HIG y WWDC.

Skills a usar para UI: `swiftui-expert-skill` (AvdLee), `swiftui-pro`, `swiftui-liquid-glass`,
`macos-design-guidelines`.

## Rediseño (28-sep-2026): hecho

Target macOS 26. Cada pantalla es `XView` (carga en `LiveView`) + `XContent` pura con `#Preview` y
datos sintéticos de `Shared/PreviewData.swift`. Tarjetas de material (`App/Views/Surface.swift`);
el vidrio queda para sidebar y toolbar. Anillos en `Shared/BudgetStyle.swift`, compartidos con el
widget; en modo tintado el exceso se lee por opacidad.

Pendiente de Diego: el `current` de `get_net_worth` no coincide con la suma de cuentas
(préstamos y tarjetas como deuda). Patrimonio muestra la cifra de Whisper Money y, debajo, la suma propia.
Seguimiento en el issue #2. Repo: github.com/Chere3/whisper-money-mac.

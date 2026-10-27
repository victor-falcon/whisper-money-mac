# Contribuir

¡Gracias por querer mejorar Whisper Money para Mac! Issues y PRs en español o inglés.

## Reglas no negociables

- **Nada de datos financieros reales** en commits, tests, fixtures, capturas ni issues. Usa
  `Shared/PreviewData.swift` (previews) o fixtures sintéticos (tests).
- **Sin caché de montos:** toda cifra viene de una llamada en vivo al MCP. Nada de persistir montos
  en `UserDefaults`, app group ni archivos. Si una consulta falla se muestra el error, nunca valores
  anteriores.
- Montos en unidades menores (`Money`); la moneda sale de la respuesta, no se hardcodea.
- El token vive en el Llavero y nunca se imprime ni se registra.

## Flujo de trabajo

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodegen generate
xcodebuild -project WhisperMac.xcodeproj -scheme WhisperMac build
./scripts/test.sh
```

- Cada pantalla es `XView` (carga en `LiveView`) + `XContent` puro con `#Preview`. Cambios de UI:
  itera en el preview y adjunta capturas de antes y después (con datos sintéticos) en el PR.
- macOS no previsualiza widgets: usa la galería `App/Views/WidgetPreviews.swift`. Tras instalar una
  versión nueva, `pkill -f BudgetsWidget.appex; killall chronod` para que el escritorio la cargue.
- Commits con [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`,
  `docs:`…).
- Las imágenes del README se regeneran con `scripts/make-docs-images.py` (ver su docstring).

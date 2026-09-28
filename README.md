# Wispr Money para Mac

App nativa de macOS (SwiftUI, sin vistas web) y widget de escritorio para **Wispr Money**
self-hosted. Habla directo con el endpoint MCP del servidor (`/mcp`, Streamable HTTP + JSON-RPC
con token Bearer), el mismo que usa Claude Code.

## Principio: nada pre-cacheado

- Cada pantalla consulta al servidor al abrirse, cada 60 s mientras está visible y con ⌘R.
  El subtítulo de la ventana dice a qué hora fue la última consulta.
- Sesión HTTP efímera, sin `URLCache`, con `reloadIgnoringLocalAndRemoteCacheData`.
- Si una consulta falla, se muestra el error; nunca los números de la consulta anterior.
- Lo único que se guarda en la Mac es el endpoint y el token, en el Llavero.

**Límite del widget (lo impone macOS):** un widget no puede tener una conexión viva. El sistema le
pide una "foto" y la muestra hasta la siguiente. Aquí cada foto se pide en vivo a Wispr
(`list_budgets`); se renueva cada ~15 min (según el presupuesto de refrescos de macOS) y cada vez
que abres la app. Muestra la hora de consulta y, si no hay red, "Sin conexión" en vez de cifras viejas.

## Pantallas

| Sección (⌘1–⌘5) | Herramientas MCP |
|---|---|
| Presupuestos: % gastado, restante, excedido | `list_budgets` |
| Cuentas: saldo de cada cuenta, por tipo | `list_accounts` + `get_net_worth` (último punto) |
| Movimientos: búsqueda por mes, texto y cuenta; alta manual (⌘N) | `search_transactions`, `create_transaction`, `list_categories` |
| Flujo: ingresos, gastos, neto, tasa de ahorro, gasto por categoría con desglose, tendencia de 6 meses | `get_cashflow`, `spending_by_category` |
| Patrimonio: total contra el periodo anterior, evolución por cuenta | `get_net_worth` |

Widget "Presupuestos" en tamaños pequeño, mediano y grande. Muestra primero los más excedidos
(verde < 80 %, naranja 80–100 %, rojo > 100 %).

## Estructura

```
WisprKit/   paquete SPM: cliente MCP, modelos, dinero, Llavero (+ tests)
App/        app SwiftUI
Widget/     extensión WidgetKit
Shared/     vistas compartidas por la app y el widget
project.yml definición del proyecto para xcodegen (el .xcodeproj no se versiona)
```

## Compilar

Requiere **Xcode** completo: el widget es una extensión que solo Xcode empaqueta y firma.

1. Instala Xcode y ejecuta `sudo xcode-select -s /Applications/Xcode.app`.
2. Xcode → Settings → Accounts: agrega tu Apple ID (el equipo personal gratuito basta).
3. Crea `Config/Team.local.xcconfig` con tu Team ID; está en `.gitignore`:
   ```
   WISPR_TEAM_ID = ABCDE12345
   ```
   El Team ID aparece en Xcode → Settings → Accounts → tu equipo. App y widget lo necesitan para
   compartir el token por un grupo de Llavero.
4. `xcodegen generate && open WisprMac.xcodeproj`, luego ▶︎ con el esquema **WisprMac**.
5. En la app, pega el endpoint (`https://<tu-host>/mcp`) y el token. Se prueba la conexión antes de guardarlo.
6. Agrega el widget: clic derecho en el escritorio → Editar widgets → "Presupuestos".

Tailscale debe estar activo: el servidor solo es accesible dentro del tailnet.

## Tests

```
./scripts/test.sh
```

Usa `swift test`. Con solo Command Line Tools, el script agrega las banderas para encontrar
Swift Testing. Los tests usan fixtures sintéticos y un servidor MCP simulado (`URLProtocol`); no
tocan el servidor real ni contienen datos financieros reales.

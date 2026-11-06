# Claude Desktop Side by Side

[English](README.md) | [Português (Brasil)](README.pt-BR.md) | **Español**

<p align="center">
  <img src="docs/two-accounts-taskbar.jpg" alt="Dos íconos de Claude Desktop en la barra de tareas de Windows: la cuenta principal en naranja y una segunda cuenta en azul" width="720">
</p>
<p align="center"><b>Tu cuenta principal de Claude en naranja, una segunda cuenta en azul.<br>Las dos abiertas al mismo tiempo, cada una con su propio botón en la barra de tareas.</b></p>

> [!IMPORTANT]
> **Para iniciar sesión en cada perfil adicional, usa "Continue with email" y escribe el código que recibas. No uses "Continue with Google".**
> El inicio de sesión con Google (y el enlace del correo) te devuelve a la ventana principal de Claude, así que el nuevo perfil nunca termina de iniciar sesión. [Detalles](#sign-in-important)

Usa **dos o más cuentas de Claude Desktop al mismo tiempo**, por ejemplo una cuenta personal y una del trabajo, o cuentas de dos empresas diferentes. Cada una tiene su propia ventana y su propio **ícono de color**.

Se acabó cerrar sesión y volver a entrar para cambiar de cuenta.

| Plataforma | Estado | Qué obtienes |
|---|---|---|
| **Windows 10/11** | ✅ Probado | Cuentas separadas lado a lado, acceso directo de color en el escritorio y el menú Inicio **y botón de color en la barra de tareas** |
| **macOS** | 🧪 Experimental, sin probar | Cuentas separadas lado a lado y una app lanzadora de color (Dock/Launchpad/Spotlight). La ventana abierta mantiene el ícono normal de Claude en el Dock |

> **Solución alternativa no oficial, hecha por la comunidad.** No está afiliada, respaldada ni soportada por Anthropic. Usa el comportamiento estándar de Electron y del sistema operativo, no una función documentada de Claude, así que una actualización de la app podría romperla. El soporte nativo para varias cuentas se pidió en [anthropics/claude-code#18435](https://github.com/anthropics/claude-code/issues/18435). Si tú también lo quieres, deja un 👍 allí.

## Cómo funciona

- Cada perfil es una instancia separada de Claude Desktop, abierta con la opción `--user-data-dir` de Electron, así que tiene **su propio inicio de sesión, configuración e historial**. Tu Claude Desktop normal no se modifica y sigue siendo tu cuenta "principal".
- El ícono de color se genera **en tu computadora**, a partir de tu Claude instalado, cambiando su tono. No se descarga nada.
- En Windows, el lanzador también le da a la ventana del perfil su propia identidad en la barra de tareas (AppUserModelID), para que tenga su propio botón de color.

---

## Windows

### Requisitos

- Windows 10 u 11
- Claude Desktop instalado desde [claude.ai/download](https://claude.ai/download) o la Microsoft Store
- Windows PowerShell 5.1 (incluido en Windows)

Probado en Windows 11 con Claude Desktop 4.23118 (versión de la Microsoft Store/MSIX). El instalador clásico está soportado por el script, pero se ha probado menos. Los reportes son bienvenidos.

### Crear un perfil

1. Descarga [`claude-profile.ps1`](claude-profile.ps1) y léelo. Lee siempre los scripts antes de ejecutarlos.
2. Abre PowerShell en la carpeta donde lo guardaste y ejecuta:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\claude-profile.ps1 -Install -Name Trabajo -Color blue
   ```

   - `-Name`: solo letras sin tilde, números, `-` y `_` (p. ej. `Trabajo`, `EmpresaX`, `Personal`).
   - `-Color`: consulta [Colores](#colors).

   Esto crea un acceso directo **Claude (Trabajo)** en el escritorio y en el menú Inicio. También copia el script a `%LOCALAPPDATA%\ClaudeProfiles\`, así los accesos directos siguen funcionando aunque borres el archivo descargado.

3. Repite con otro nombre para cada cuenta adicional.
4. Abre **Claude (Trabajo)** e inicia sesión con **Continue with email**, escribiendo el código que te llegue por correo. No uses Google ([por qué](#sign-in-important)).

### Uso diario

- Abre cada cuenta desde su acceso directo. La app principal y todos los perfiles pueden estar abiertos al mismo tiempo.
- **Barra de tareas:** unos segundos después de abrirlo, el botón del perfil en la barra de tareas cambia a su color y se separa del botón de Claude principal.
- **Anclarlo:** haz clic derecho en el *botón de color* del perfil abierto y elige **Anclar a la barra de tareas**. El botón anclado mantiene el color y abre ese perfil.
- Si la ventana de un perfil se abrió de otra forma (no desde su acceso directo o botón anclado), puede mostrar el ícono predeterminado. Ábrelo de nuevo desde el acceso directo para corregirlo.

### Otros comandos

```powershell
$cp = "$env:LOCALAPPDATA\ClaudeProfiles\claude-profile.ps1"

powershell -ExecutionPolicy Bypass -File $cp -List                                  # listar perfiles
powershell -ExecutionPolicy Bypass -File $cp -Install -Name Trabajo -Color purple    # cambiar el color (mantiene la sesión)
powershell -ExecutionPolicy Bypass -File $cp -Uninstall -Name Trabajo                # quitar accesos directos, mantener la sesión
powershell -ExecutionPolicy Bypass -File $cp -Uninstall -Name Trabajo -RemoveData    # quitar todo lo de ese perfil
powershell -ExecutionPolicy Bypass -File $cp -Name Trabajo -OpenUrl "claude://..."   # enviar un enlace de inicio de sesión a ese perfil
```

Cierra la ventana del perfil (y sal de él desde la bandeja del sistema) antes de desinstalarlo.

Después de cambiar el color, abre el perfil de nuevo desde su acceso directo. Si lo anclaste a la barra de tareas, desánclalo y vuelve a anclarlo, porque Windows guarda en caché los íconos anclados.

### Dónde se guardan los datos

| | Ubicación |
|---|---|
| Script e íconos | `%LOCALAPPDATA%\ClaudeProfiles\` |
| Datos del perfil (versión de la Store) | `%LOCALAPPDATA%\Packages\Claude_<id>\LocalCache\Roaming\Claude-<Nombre>` (Windows redirige los datos de las apps de la Store) |
| Datos del perfil (instalador clásico) | `%APPDATA%\Claude-<Nombre>` |

---

## macOS (experimental)

> 🧪 **Sin probar.** El script de macOS usa el mismo mecanismo de Electron que el de Windows, pero todavía no se ha ejecutado en una Mac. Si lo pruebas, envía un [reporte de prueba en macOS](../../issues/new?template=macos_test_report.yml), aunque todo haya funcionado.

<a id="what-to-expect"></a>
### Qué esperar

- ✅ Cuentas separadas lado a lado (cada perfil es su propia instancia de Claude con su propia carpeta de datos).
- ✅ Una app lanzadora **Claude (Trabajo).app** en `~/Applications` con un ícono de color, que puedes dejar en el Dock o abrir desde Spotlight/Launchpad.
- ❌ **La ventana abierta sigue mostrando el ícono naranja normal de Claude en el Dock.** macOS no permite que otro programa cambie el ícono del Dock de una app que ya está en ejecución. Para eso habría que modificar el propio Claude.app, lo que rompe su firma y sus actualizaciones, así que este proyecto no lo hace. Distingue las ventanas por la cuenta que aparece dentro de la app.

### Crear un perfil

```bash
curl -O https://raw.githubusercontent.com/pdmoura/claude-desktop-side-by-side/main/claude-profile.sh
less claude-profile.sh           # léelo primero
chmod +x claude-profile.sh
./claude-profile.sh install Trabajo blue
```

Luego abre **Claude (Trabajo)** desde Spotlight, Launchpad o `~/Applications`, arrástralo al Dock si quieres e inicia sesión con **Continue with email** + el código (no uses Google, [por qué](#sign-in-important)).

### Otros comandos

```bash
cp="$HOME/Library/Application Support/ClaudeProfiles/claude-profile.sh"

"$cp" list                                # listar perfiles
"$cp" install Trabajo purple              # cambiar el color (mantiene la sesión)
"$cp" launch Trabajo                      # abrir sin la app lanzadora
"$cp" uninstall Trabajo                   # quitar el lanzador, mantener la sesión
"$cp" uninstall Trabajo --remove-data     # quitar todo lo de ese perfil
"$cp" launch Trabajo "claude://..."       # intentar enviar un enlace de inicio de sesión a ese perfil (no verificado en macOS)
```

Los datos del perfil se guardan en `~/Library/Application Support/Claude-<Nombre>`.

### Requisitos

macOS con Claude Desktop en `/Applications` o `~/Applications`. Solo se usan herramientas incluidas en el sistema (`open`, `sips`, `iconutil`, `osascript`/Core Image).

---

<a id="sign-in-important"></a>
## Iniciar sesión (importante)

Aplica a todas las plataformas. Abre el perfil y luego:

1. Haz clic en **Continue with email** (o la opción de correo equivalente si la app está en español). No uses "Continue with Google".
2. Escribe el correo de la cuenta (las direcciones de Gmail y Google Workspace también funcionan).
3. **Escribe en la app el código** que te llega por correo. No hagas clic en el enlace del correo.

**Por qué:** el inicio de sesión con Google y el enlace del correo vuelven a la app mediante un enlace `claude://`. El sistema operativo entrega ese enlace a tu Claude *principal*, y la ventana del perfil se queda esperando para siempre. El código por correo mantiene todo el inicio de sesión dentro de la ventana del perfil. Solo tienes que hacerlo una vez, y el perfil se mantiene conectado.

Si tu organización solo permite iniciar sesión con Google/SSO, copia el enlace `claude://...` desde el navegador en lugar de dejar que abra Claude, y pásalo al perfil con el comando `-OpenUrl` (Windows) o `launch Trabajo "claude://..."` (macOS) que aparecen arriba.

<a id="colors"></a>
## Colores

`red` (rojo), `orange` (naranja), `yellow` (amarillo), `green` (verde), `teal` (verde azulado), `blue` (azul), `indigo` (índigo), `purple` (morado), `pink` (rosa), o cualquier número de tono de `0` a `360` (por ejemplo `195` para azul cielo o `300` para magenta). Usa los nombres en inglés en el comando.

El color es un cambio de tono del logo de Claude, así que conserva su brillo y saturación originales. No se admiten negro, blanco, gris ni colores hexadecimales exactos.

## Limitaciones

- No oficial: una actualización de Claude Desktop podría cambiar este comportamiento.
- Cada perfil es una instancia completa de la app, así que usa tanta memoria como una segunda ventana de Claude.
- Windows: Alt+Tab puede seguir mostrando el ícono predeterminado de Claude. Un pequeño proceso oculto de PowerShell se ejecuta unos segundos al abrir un perfil (para poner el ícono de la barra de tareas) y luego se cierra.
- macOS: consulta [Qué esperar](#what-to-expect).

## Cómo contribuir

Los reportes de errores, los reportes de prueba en macOS y los pull requests son bienvenidos. Consulta [CONTRIBUTING.md](CONTRIBUTING.md) (en inglés) para saber cómo se revisan y aceptan los cambios, y [SECURITY.md](SECURITY.md) para reportar una vulnerabilidad de forma privada. Los issues y pull requests pueden escribirse en español, inglés o portugués.

## Licencia

MIT. Consulta [LICENSE](LICENSE).

# Guía para agentes de IA

Este archivo es para ti, el agente (GitHub Copilot, Claude Code, Cursor u otro) que trabaja en este repositorio. La guía para personas está en [README.md](README.md).

Hay dos situaciones posibles, y casi siempre será la primera:

- **Te pidieron instalar esta configuración** en el VS Code de alguien: sigue [Instalar la configuración](#instalar-la-configuración).
- **Te pidieron cambiar el repositorio** (añadir una extensión, corregir un script): ve a [Mantener el repositorio](#mantener-el-repositorio).

## Instalar la configuración

### Qué es y cuándo está bien hecho

vscode-setup es la configuración visual de VS Code de su autor, empaquetada para que otras personas la copien: 38 extensiones (temas, iconos, ayudas visuales, una mascota), unos 30 ajustes del editor y dos partes opcionales (la terminal, y una imagen de fondo con fuente propia para la interfaz).

El trabajo está bien hecho cuando se cumplen tres cosas: el VS Code de la persona tiene este aspecto, todo lo que ya tenía sigue ahí, y la persona sabe qué cambió, qué le queda por hacer a ella y cómo volver atrás.

Quien te lo pide puede no saber programar. Háblale en su idioma y sin jerga, y no le traslades decisiones técnicas que puedas resolver tú con un valor seguro.

### El instalador hace casi todo

No reproduzcas a mano lo que hacen los scripts. Ya resuelven los casos difíciles: un `settings.json` con comentarios, extensiones que la persona ya tenía, copias de seguridad y la posibilidad de deshacerlo todo.

| Sistema | Instalar | Desinstalar |
|---|---|---|
| Linux y macOS | `./install.sh` | `./uninstall.sh` |
| Windows | `powershell -ExecutionPolicy Bypass -File .\install.ps1` | `powershell -ExecutionPolicy Bypass -File .\uninstall.ps1` |

| Opción en Linux y macOS | En Windows | Qué añade |
|---|---|---|
| `--simular` | `-Simular` | No cambia nada; solo muestra lo que haría |
| `--terminal` | no existe | Tema de Starship, tema de bat y alias en el shell |
| `--fondo` | `-Fondo` | Imagen de fondo y fuente de la interfaz (Custom UI Style) |
| `--imagen RUTA` | `-Imagen RUTA` | Lo mismo que el fondo, con una imagen de la persona |
| `--todo` | `-Todo` | Todas las partes opcionales |

Sin opciones, el instalador toca solo dos cosas, las dos dentro de VS Code: mezcla `config/settings.json` con el `settings.json` de la persona (guardando antes una copia) e instala las extensiones de `extensiones.txt`. Se puede repetir sin miedo, porque solo hace lo que falte. Termina con código 0 si todo salió bien y con 1 si algo falló; cada fallo aparece marcado con `✗` (`[X]` en Windows).

### Pasos

1. **Consigue el repositorio** si aún no lo tienes: `git clone https://github.com/NicoElMaster/vscode-setup.git`. Clónalo en una carpeta que la persona vaya a conservar, no en una temporal: el desinstalador está dentro. Si más adelante la borra, basta con volver a clonarlo para poder desinstalar.
2. **Comprueba que existe el comando `code`** con `code --version`. Si la persona usa otro editor de la familia, indícalo con la variable `VSCODE_BIN` (se reconocen `code-insiders`, `codium`, `code-oss` y `cursor`).
3. **Mira antes de tocar.** Ejecuta el instalador con `--simular` y lee la salida. Si va a cambiar algo que la persona claramente eligió (ya usa otro tema de color, o tiene su propia fuente), díselo en una frase antes de seguir. No hace falta pedir permiso ajuste por ajuste: hay copia de seguridad y todo se puede deshacer.
4. **Instala lo básico**: ejecuta el instalador sin opciones.
5. **Ofrece las partes opcionales** y deja que decida la persona, porque cambian cosas fuera de VS Code:
   - **Terminal** (`--terminal`, solo Linux y macOS). Cambia el aspecto del prompt en todas sus terminales, no solo en la de VS Code, pone el tema de `bat` y añade un bloque con alias a su `.zshrc` o `.bashrc`. Necesita `starship`, `eza` y `bat`; si faltan, el instalador lo avisa y deja la configuración lista para cuando se instalen.
   - **Fondo y fuente** (`--fondo`). Instala Custom UI Style, que modifica los archivos de instalación de VS Code. Antes de aceptar, la persona debe saber tres cosas: VS Code mostrará un aviso de que la instalación «parece dañada», hay que repetir el último paso tras cada actualización de VS Code, y en Linux y macOS requiere cambiar con `sudo` el dueño de la carpeta donde está instalado VS Code.
6. **Verifica** el resultado (más abajo).
7. **Cuéntale qué pasó** (más abajo).

### Lo que no debes hacer por tu cuenta

- **Ejecutar comandos con `sudo`**: instalar paquetes del sistema o el `chown` que pide el fondo. Piden la contraseña de la persona y cambian su sistema, así que la decisión es suya. Dale el comando exacto (el instalador lo imprime) para que lo ejecute ella.
- **Cerrar o reiniciar VS Code.** Los comandos de la paleta, como «Developer: Reload Window» o «Custom UI Style: Reload», no se pueden ejecutar desde la terminal; pídeselos a la persona. No fuerces un reinicio para sustituirlos: puede tener trabajo sin guardar, y si trabajas dentro de VS Code te cerrarías a ti mismo.
- **Copiar los ajustes a mano cuando el instalador se niega.** Si dice que `settings.json` no es un JSON válido, no lo ha tocado. Enséñale el error, ofrécete a corregirlo y vuelve a ejecutar el instalador. Copiar los ajustes a mano haría perder el registro que permite deshacerlos.

### Verificar

No puedes ver la pantalla, así que comprueba lo que sí está a tu alcance y dilo tal cual:

- El instalador terminó con código 0.
- `code --list-extensions` contiene todos los identificadores de `extensiones.txt` (sin distinguir mayúsculas).
- El `settings.json` de la persona contiene `"workbench.colorTheme": "Catppuccin Mocha"`.

El aspecto final solo lo puede confirmar la persona después de recargar la ventana. Pídele que lo haga y que te diga si ve el tema oscuro y los iconos nuevos.

### Qué contarle al terminar

- Qué se instaló, en una o dos frases.
- Lo que le toca hacer: recargar la ventana (`Ctrl+Shift+P`, o `Cmd+Shift+P` en macOS, y «Developer: Reload Window»); instalar la fuente si el instalador avisó de que falta; y los pasos del fondo si lo eligió.
- Dónde verá la mascota: en el explorador de archivos, abajo, en la sección «VS Code Pets».
- Dónde quedó la copia de sus ajustes (el instalador imprime la ruta) y que puede volver atrás con el desinstalador.

### Si algo falla

| Síntoma | Qué hacer |
|---|---|
| No existe el comando `code` | En macOS: paleta de comandos de VS Code, «Shell Command: Install 'code' command in PATH». En Windows y Linux lo añade el instalador de VS Code; suele bastar con reabrir la terminal. |
| Algunas extensiones no se instalaron | Suele ser la red. Vuelve a ejecutar el instalador: solo reintenta las que faltan. En VSCodium y otros editores que no usan el Marketplace de Microsoft puede que alguna no exista; di cuáles. |
| Falta `python3` (Linux y macOS) | El instalador lo necesita para modificar `settings.json` sin romperlo. Pide permiso para instalarlo. |
| Windows no deja ejecutar scripts | Usa la forma completa con `-ExecutionPolicy Bypass` de la tabla de arriba. |
| El instalador no reconoce el editor | Indica la carpeta de ajustes con `VSCODE_USER_DIR=/ruta/a/User`. |
| Un script de Windows falla con un error de PowerShell | Los scripts de Windows se probaron con PowerShell 7, pero todavía no en un Windows real. Enséñale el error y sigue con [docs/instalacion-manual.md](docs/instalacion-manual.md). |

Más casos en [docs/solucion-de-problemas.md](docs/solucion-de-problemas.md).

### Deshacer

El desinstalador devuelve cada ajuste al valor que tenía antes (los que la persona cambió después de instalar se respetan), quita solo las extensiones que añadió el instalador y restaura la terminal. Si se configuró el fondo, deja instalada Custom UI Style a propósito y explica los dos pasos manuales que faltan; transmíteselos a la persona.

## Mantener el repositorio

### Mapa

| Ruta | Qué es |
|---|---|
| `extensiones.txt` | Las 38 extensiones de la instalación básica. Es la lista que leen los instaladores. |
| `extensiones-fondo.txt` | Las 2 extensiones que modifican los archivos de VS Code. Solo con `--fondo`. |
| `.vscode/extensions.json` | Las mismas 38 como recomendaciones del área de trabajo, para instalarlas desde la interfaz. |
| `config/settings.json` | Ajustes de la instalación básica. |
| `config/settings-fondo.json` | Ajustes de Custom UI Style. La dirección de la imagen la calcula el instalador. |
| `terminal/` | Tema de Starship y configuración de bat. |
| `assets/fondos/` | Imagen de fondo y sus créditos. |
| `install.sh`, `uninstall.sh`, `scripts/lib.sh`, `scripts/settings.py` | Instalador de Linux y macOS. |
| `install.ps1`, `uninstall.ps1`, `scripts/lib.ps1` | Instalador de Windows. |
| `docs/` | Guías para personas. |

### Reglas que no se ven a simple vista

- **Dos listas, un contenido.** Si cambias `extensiones.txt`, actualiza `.vscode/extensions.json` con los mismos identificadores, y también la tabla de [docs/extensiones.md](docs/extensiones.md) y los números que aparecen en el README, en este archivo y en la ayuda de los instaladores (38 básicas, 40 con las del fondo).
- **Dos instaladores, un comportamiento.** `scripts/settings.py` y `scripts/lib.ps1` hacen lo mismo con `settings.json` y comparten el formato del archivo de estado. Un cambio en uno va también en el otro.
- **Los ajustes van antes que las extensiones.** Algunas extensiones actúan en cuanto se activan (Background ofrece aplicar sus imágenes de muestra si no encuentra `background.enabled: false`), así que el orden de los pasos del instalador importa.
- **Custom UI Style no entra en la instalación básica.** Muestra un aviso en cada arranque hasta que se inicializa, y por eso solo se instala con `--fondo`.
- **Compatibilidad.** Los `.sh` deben funcionar con bash 3.2, el de macOS: nada de arreglos asociativos, `mapfile` ni `${variable,,}`. Los `.ps1` deben funcionar con Windows PowerShell 5.1 y conservar la marca BOM de UTF-8 al principio; sin ella, PowerShell 5.1 estropea las tildes.
- **Idioma.** La documentación y los mensajes de los scripts están en español.

### Probar sin tocar tu propio VS Code

```bash
# Ver qué haría sobre la configuración real, sin cambiar nada
./install.sh --todo --simular

# Instalar de verdad en carpetas aisladas
carpeta=$(mktemp -d)
printf '#!/bin/sh\nexec code --user-data-dir "%s/datos" --extensions-dir "%s/ext" "$@"\n' \
    "$carpeta" "$carpeta" > "$carpeta/code"
chmod +x "$carpeta/code"
aislado() {
    env -u ZDOTDIR -u XDG_CONFIG_HOME -u STARSHIP_CONFIG -u BAT_CONFIG_PATH \
        HOME="$carpeta/home" VSCODE_BIN="$carpeta/code" VSCODE_USER_DIR="$carpeta/datos/User" "$@"
}
aislado ./install.sh --todo
aislado ./uninstall.sh
```

Cambiar `HOME` y vaciar esas variables hace que la parte de terminal escriba en la carpeta de prueba y no en tu `.zshrc` ni en tu Starship. Antes de dar un cambio por bueno, comprueba que instalar dos veces seguidas no duplica nada y que desinstalar deja `settings.json` como estaba.

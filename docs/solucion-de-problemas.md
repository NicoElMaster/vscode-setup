# Solución de problemas

En macOS, donde aquí dice `Ctrl` usa `Cmd`.

## Al instalar

### «No encuentro el comando 'code'»

El instalador necesita poder llamar a VS Code desde la terminal.

- **macOS:** abre VS Code, pulsa `Cmd+Shift+P` y ejecuta **Shell Command: Install 'code' command in PATH**. Después abre una terminal nueva.
- **Windows:** cierra PowerShell y vuelve a abrirlo. Si sigue igual, reinstala VS Code dejando marcada la casilla de añadirlo al PATH.
- **Linux:** comprueba que `code --version` funciona. Si instalaste VS Code con Flatpak, el comando no existe con ese nombre; instala la versión `.deb`, `.rpm` o la de tu distribución.

Si usas VSCodium, Cursor u otro editor de la familia, dile al instalador cuál:

```bash
VSCODE_BIN=codium ./install.sh
```

### «Permission denied» al ejecutar `./install.sh`

El archivo perdió el permiso de ejecución, algo habitual al descargar el ZIP. Ejecútalo así:

```bash
bash install.sh
```

### Windows dice que «la ejecución de scripts está deshabilitada»

Usa el comando completo, que da permiso solo para esa ejecución:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

### Algunas extensiones no se instalaron

Casi siempre es un corte de conexión. Vuelve a ejecutar el instalador: solo reintenta las que faltan.

En VSCodium y otros editores que no usan el Marketplace de Microsoft, alguna extensión puede no existir en su catálogo. El resto se instala igual.

### «No sé dónde guarda sus ajustes»

El instalador no reconoce tu editor. Indícale la carpeta `User`, que es donde está tu `settings.json`:

```bash
VSCODE_USER_DIR="$HOME/.config/MiEditor/User" ./install.sh
```

### «settings.json no es un JSON válido»

Tu archivo de ajustes tiene un error de sintaxis y el instalador no lo ha tocado. Ábrelo con `Ctrl+Shift+P` → **Preferences: Open User Settings (JSON)**, corrige lo que VS Code subraya en rojo (suele ser una coma o una llave) y vuelve a ejecutar el instalador.

### Mis comentarios de `settings.json` desaparecieron

Al reescribir el archivo, el instalador no puede conservar los comentarios. No se han perdido: están en la copia de seguridad, cuya ruta muestra el instalador al terminar. Está dentro de la carpeta `vscode-setup/copias`, junto a tu `settings.json`.

## Después de instalar

### No veo ningún cambio

Recarga la ventana: `Ctrl+Shift+P` → **Developer: Reload Window**. Si sigue igual, pulsa `Ctrl+K` y luego `Ctrl+T` y elige **Catppuccin Mocha**.

### Las letras se ven igual que antes, sin ligaduras

Falta la fuente JetBrainsMono Nerd Font. Instálala siguiendo el [README](../README.md#-antes-de-empezar) y reinicia VS Code por completo; recargar la ventana no basta para que detecte fuentes nuevas.

### En la terminal salen cuadrados o signos raros

Es la misma fuente. En la terminal integrada de VS Code basta con instalarla. En tu programa de terminal, además, tienes que elegirla en sus preferencias.

### No encuentro la mascota

Está en el explorador de archivos (`Ctrl+Shift+E`), abajo del todo, en una sección plegada que se llama **VS Code Pets**: pulsa sobre el título para desplegarla. Si no aparece, abre el menú `···` que hay junto al título del explorador y marca **VS Code Pets**, o ejecuta **Pet Coding: Start pet coding session**.

### GitLens me muestra avisos de su versión de pago

Es normal. Lo que usa esta configuración (ver quién cambió cada línea) es gratuito, y puedes cerrar los avisos. Si te molestan, desinstala GitLens; Git Graph cubre el historial.

### Las partículas al escribir me distraen

Ejecuta **Disable Power Mode** en la paleta de comandos.

### Uso Settings Sync y los cambios llegaron a mis otros equipos

Settings Sync copia los ajustes y las extensiones a todos los equipos donde tengas la sesión iniciada. Si no lo quieres, desactívalo antes de instalar con `Ctrl+Shift+P` → **Settings Sync: Turn Off**.

## Con el fondo

### VS Code dice que la instalación «parece dañada»

Es lo esperado cuando se usa la parte de fondo, porque modifica los archivos de VS Code. En el aviso, pulsa el engranaje y elige **Don't Show Again**. Está explicado en [fondo-y-fuente.md](fondo-y-fuente.md).

### Cada vez que abro VS Code, Custom UI Style pregunta si quiero inicializar

Lo hace hasta que le respondas **Yes** y pueda aplicar los cambios. Si responder **Yes** da un error de permisos, te falta el paso del `sudo chown` de [fondo-y-fuente.md](fondo-y-fuente.md). Si has decidido no usar el fondo, desinstala la extensión Custom UI Style y la pregunta desaparece.

### El fondo desapareció tras actualizar VS Code

La actualización restaura los archivos originales. Responde **Yes** cuando la extensión pregunte al abrir; en Linux, repite antes el comando `sudo chown`.

### El fondo no aparece

Comprueba, por este orden:

1. Que ejecutaste **Custom UI Style: Reload** y aceptaste el reinicio.
2. Que la imagen existe en la ruta que indica `custom-ui-style.background.url` en tu `settings.json`.
3. Que `custom-ui-style.background.opacity` no vale `1`: con ese valor la imagen queda tapada por completo.
4. Que VS Code no está instalado con Snap o Flatpak. Con esas instalaciones no funciona.

## Volver atrás

```bash
./uninstall.sh                                             # Linux y macOS
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1   # Windows
```

Si borraste la carpeta del repositorio, vuelve a clonarla: el desinstalador usa lo que el instalador dejó apuntado junto a tu `settings.json`, no la carpeta original.

Si prefieres restaurar a mano, tus ajustes anteriores están en la carpeta `vscode-setup/copias`, junto a tu `settings.json`:

| Sistema | Carpeta |
|---|---|
| Linux | `~/.config/Code/User/vscode-setup/copias` |
| macOS | `~/Library/Application Support/Code/User/vscode-setup/copias` |
| Windows | `%APPDATA%\Code\User\vscode-setup\copias` |

## ¿No está aquí?

[Abre un issue](https://github.com/NicoElMaster/vscode-setup/issues) contando qué sistema usas, qué comando ejecutaste y el mensaje completo que apareció.

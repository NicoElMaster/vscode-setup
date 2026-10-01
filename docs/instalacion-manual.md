# Instalación manual, paso a paso

Esta guía hace a mano lo mismo que el instalador, para que veas y decidas cada cambio. Son tres pasos obligatorios y dos opcionales.

En macOS, donde aquí dice `Ctrl` usa `Cmd`.

## Antes de empezar

Descarga el repositorio. Con Git:

```bash
git clone https://github.com/NicoElMaster/vscode-setup.git
```

Sin Git, entra en la página del repositorio, pulsa el botón verde **Code**, elige **Download ZIP** y descomprime el archivo.

Instala también la fuente JetBrainsMono Nerd Font si quieres ver las ligaduras; las instrucciones están en el [README](../README.md#-antes-de-empezar).

## Paso 1: instala las extensiones

Elige una de estas tres formas. Todas instalan las 38 extensiones de [extensiones.txt](../extensiones.txt).

### Forma A: desde VS Code, con un clic

1. En VS Code, abre la carpeta del repositorio con **File → Open Folder**.
2. Si abajo a la derecha aparece un aviso que pregunta si quieres instalar las extensiones recomendadas, pulsa **Install**.
3. Si no aparece, abre el panel de extensiones (`Ctrl+Shift+X`), escribe `@recommended` en el buscador y pulsa el icono de la nube que hay junto al título **Workspace Recommendations**.

### Forma B: desde la terminal, con un comando

Abre una terminal dentro de la carpeta del repositorio.

En Linux y macOS:

```bash
grep -v '^#' extensiones.txt | grep . | xargs -n 1 code --install-extension
```

En Windows, con PowerShell:

```powershell
Get-Content extensiones.txt | Where-Object { $_ -and $_ -notmatch '^\s*#' } | ForEach-Object { code --install-extension $_ }
```

### Forma C: una por una

Abre [extensiones.md](extensiones.md), entra en el enlace de cada extensión que te interese y pulsa **Install**. Es la forma más lenta, pero te deja elegir solo las que quieras.

## Paso 2: copia los ajustes

1. En VS Code pulsa `Ctrl+Shift+P`, escribe `settings json` y elige **Preferences: Open User Settings (JSON)**. Se abre tu archivo `settings.json`.
2. Abre [config/settings.json](../config/settings.json) de este repositorio y copia todo lo que hay **entre** la primera llave `{` y la última `}`, sin incluirlas.
3. Pégalo en tu archivo, justo antes de la llave `}` final.
4. Guarda con `Ctrl+S`.

Dos detalles que suelen dar problemas:

- **La coma.** Si tu archivo ya tenía ajustes, la última línea que había antes de lo que pegaste tiene que terminar en coma. VS Code subraya en rojo el sitio exacto si falta.
- **Los repetidos.** Si un ajuste ya estaba en tu archivo (por ejemplo `"workbench.colorTheme"`), aparecerá dos veces y VS Code lo marcará con un aviso. Borra el antiguo.

Si tu archivo estaba vacío, puedes sustituirlo entero por el contenido de `config/settings.json`.

## Paso 3: recarga VS Code

Pulsa `Ctrl+Shift+P` y ejecuta **Developer: Reload Window**. Deberías ver el tema oscuro Catppuccin Mocha, los iconos nuevos y, en el explorador de archivos, la sección **VS Code Pets** con un gato.

## Opcional: fondo y fuente de la interfaz

Pone una imagen detrás del editor y usa la misma fuente en los menús y paneles. Modifica los archivos de VS Code, así que tiene su propia guía: [fondo-y-fuente.md](fondo-y-fuente.md).

## Opcional: la terminal

Cambia el aspecto del prompt y de los comandos `ls` y `cat`. Solo para Linux y macOS: [terminal.md](terminal.md).

## Deshacerlo a mano

1. Abre de nuevo tu `settings.json` y borra las líneas que pegaste.
2. En el panel de extensiones, desinstala las que no quieras conservar.
3. Recarga la ventana.

Si instalaste con el instalador y no a mano, es más fácil usar `./uninstall.sh` (o `uninstall.ps1` en Windows): recuerda qué había antes y lo restaura solo.

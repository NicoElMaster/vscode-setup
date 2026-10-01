# La terminal

Esta parte es opcional y solo para Linux y macOS. Le da a la terminal los mismos colores que al editor, tanto dentro de VS Code como fuera.

## Qué cambia

| Herramienta | Qué es | Qué hace el instalador |
|---|---|---|
| [Starship](https://starship.rs) | El prompt: la línea donde escribes los comandos | Copia [terminal/starship.toml](../terminal/starship.toml), un tema en bloques de colores que muestra carpeta, rama de Git y hora |
| [bat](https://github.com/sharkdp/bat) | Un `cat` que colorea el código | Le pone el tema Catppuccin Mocha |
| [eza](https://github.com/eza-community/eza) | Un `ls` con iconos y colores | Añade los alias `ls` y `ll` |

El tema de Starship se aplica a todas tus terminales, no solo a la de VS Code.

## Paso 1: instala las herramientas

El instalador de este repositorio no instala programas en tu sistema; solo los configura. Instálalos antes:

| Sistema | Comando |
|---|---|
| Arch Linux | `sudo pacman -S starship eza bat` |
| macOS (Homebrew) | `brew install starship eza bat` |
| Debian 13 y Ubuntu 24.04 en adelante | `sudo apt install bat eza`, y para Starship: `curl -sS https://starship.rs/install.sh \| sh` |
| Otros | Guías oficiales de [Starship](https://starship.rs/guide/), [eza](https://github.com/eza-community/eza/blob/main/INSTALL.md) y [bat](https://github.com/sharkdp/bat#installation) |

En Debian y Ubuntu, `bat` se instala con el nombre `batcat`; el instalador lo tiene en cuenta. El tema Catppuccin Mocha viene con bat a partir de la versión 0.25: si la tuya es anterior, el instalador deja bat como está y te avisa.

Si te falta alguna herramienta no pasa nada: el instalador deja la configuración lista y empieza a funcionar cuando la instales.

## Paso 2: ejecuta el instalador

```bash
./install.sh --terminal
```

Hace tres cosas, y de cada archivo que modifica guarda antes una copia:

1. Copia el tema a `~/.config/starship.toml`.
2. Pone `--theme="Catppuccin Mocha"` en la configuración de bat, sin tocar tus otras opciones.
3. Añade al final de tu `~/.zshrc` (o `~/.bashrc`, según tu shell) un bloque marcado con `# >>> vscode-setup >>>`. Si tu archivo ya inicia Starship o ya tiene un alias para `ls` o `cat`, esa línea se omite para no pisar la tuya.

Abre una terminal nueva para ver el resultado.

## Paso 3: pon la fuente en tu terminal

El prompt usa símbolos que solo existen en las Nerd Fonts. Dentro de VS Code ya está resuelto, porque los ajustes de este repositorio ponen JetBrainsMono Nerd Font en la terminal integrada. En tu programa de terminal (Konsole, GNOME Terminal, iTerm2, Terminal de macOS...) tienes que elegirla tú en sus preferencias. Si ves cuadrados o signos de interrogación en el prompt, es esto.

## Hacerlo a mano

```bash
mkdir -p ~/.config/bat
cp terminal/starship.toml ~/.config/starship.toml
cp terminal/bat.conf ~/.config/bat/config
```

Y añade al final de tu `~/.zshrc`:

```bash
eval "$(starship init zsh)"
alias ls='eza --icons=auto'
alias ll='eza -la --icons=auto'
alias cat='bat'
```

En `~/.bashrc`, cambia `zsh` por `bash` en la primera línea. En fish, la primera línea es `starship init fish | source` y va en `~/.config/fish/config.fish`.

## ¿Y en Windows?

Starship también funciona en PowerShell, aunque este repositorio no lo configura por ti. Instálalo con `winget install --id Starship.Starship`, copia `terminal\starship.toml` a `C:\Users\tu-usuario\.config\starship.toml` y añade esta línea a tu perfil de PowerShell (ábrelo con `notepad $PROFILE`):

```powershell
Invoke-Expression (&starship init powershell)
```

## Quitarlo

`./uninstall.sh` borra el bloque de tu `.zshrc` o `.bashrc` y restaura las configuraciones de Starship y de bat que tenías antes. Si editaste alguno de esos archivos después de instalar, lo deja como está para no borrar tus cambios y te dice dónde está la copia anterior.

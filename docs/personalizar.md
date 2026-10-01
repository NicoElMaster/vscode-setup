# Hazlo tuyo

Esta configuración es un punto de partida. Aquí tienes cómo cambiar lo que más se suele cambiar.

Casi todo se ajusta en tu archivo `settings.json`: pulsa `Ctrl+Shift+P` y ejecuta **Preferences: Open User Settings (JSON)**. En macOS, donde aquí dice `Ctrl` usa `Cmd`.

## Tema e iconos

| Para cambiar... | Haz esto |
|---|---|
| El tema de color | `Ctrl+K` y luego `Ctrl+T`. Con las flechas ves cada tema aplicado en vivo; `Enter` lo deja puesto |
| Los iconos de archivos y carpetas | `Ctrl+Shift+P` → **Preferences: File Icon Theme** |
| Los iconos de la interfaz | `Ctrl+Shift+P` → **Preferences: Product Icon Theme** |

Para que todo combine con Catppuccin, elige también **Catppuccin Mocha** como tema de iconos de archivos. Si prefieres un editor claro, prueba Catppuccin Latte, Rosé Pine Dawn o GitHub Light.

## La mascota

Vive en el explorador de archivos, en la sección **VS Code Pets**. Escribe `pet` en la paleta de comandos para ver lo que puedes hacer:

| Comando | Qué hace |
|---|---|
| **Pet Coding: Spawn pet** | Añade otro animal; puedes tener varios a la vez |
| **Pet Coding: Throw ball** | Lanza una pelota para que la persigan |
| **Pet Coding: Change theme** | Cambia el paisaje de fondo |
| **Pet Coding: Remove all pets** | Los quita todos |

Y estos son sus ajustes:

| Ajuste | Valor de esta configuración | Otros valores |
|---|---|---|
| `vscode-pets.petType` | `cat` | `dog`, `fox`, `panda`, `totoro`, `turtle`, `frog`, `snake`, `rubber-duck`, `crab`, `clippy` y más |
| `vscode-pets.petSize` | `medium` | `nano`, `small`, `large` |
| `vscode-pets.theme` | `forest` | `none`, `castle`, `beach`, `winter`, `autumn` |
| `vscode-pets.position` | `explorer` | `panel`, para tenerla junto a la terminal |
| `vscode-pets.throwBallWithMouse` | `true` | `false` |

## Las partículas al escribir

Son de Power Mode. Para apagarlas, ejecuta **Disable Power Mode** en la paleta de comandos o pon `"powermode.enabled": false`.

| Ajuste | Valor de esta configuración | Otros valores |
|---|---|---|
| `powermode.presets` | `particles` | `fireworks`, `flames`, `magic`, `clippy`, `simple-rift`, `exploding-rift` |
| `powermode.shake.enabled` | `false` | `true` hace temblar la pantalla al escribir. Es vistoso, pero cuesta leer |

## El diseño de la ventana

| Ajuste | Valor de esta configuración | Para volver a lo normal |
|---|---|---|
| `workbench.activityBar.location` | `top`: barra de actividad arriba, en horizontal | `default` |
| `window.titleBarStyle` | `custom`: barra de título dibujada por VS Code, con el buscador en el centro | `native` |
| `editor.minimap.renderCharacters` | `false`: el minimapa muestra bloques en vez de letras | `true`. Para quitar el minimapa: `"editor.minimap.enabled": false` |
| `editor.stickyScroll.enabled` | `true`: el nombre de la función actual se queda fijo arriba | `false` |
| `editor.cursorSmoothCaretAnimation` | `on`: el cursor se desliza | `off` |

## La fuente

```json
"editor.fontFamily": "'JetBrainsMono Nerd Font', 'JetBrainsMono NF', Consolas, Menlo, 'Droid Sans Mono', monospace",
"editor.fontLigatures": true
```

VS Code usa la primera fuente de la lista que esté instalada en tu equipo. Para usar otra, por ejemplo Fira Code, ponla al principio: `"'Fira Code', ..."`. Si no te gustan las ligaduras, pon `"editor.fontLigatures": false`. El tamaño se cambia con `"editor.fontSize": 15`.

## El fondo y la terminal

Tienen su propia guía: [fondo-y-fuente.md](fondo-y-fuente.md) y [terminal.md](terminal.md).

## Tu propia versión del repositorio

Si quieres compartir tu configuración, haz un *fork* de este repositorio y cambia estos archivos:

| Archivo | Para qué |
|---|---|
| `extensiones.txt` | Añadir o quitar extensiones. Una por línea, con el identificador que aparece en su página del Marketplace |
| `.vscode/extensions.json` | La misma lista, para la instalación desde la interfaz de VS Code. Mantenla igual que la anterior |
| `config/settings.json` | Tus ajustes. Solo JSON normal, sin comentarios |
| `terminal/starship.toml` | El prompt. Con `starship preset --list` ves otros preajustes |
| `assets/fondos/` | Tu imagen de fondo. Cambia también el nombre del archivo en `install.sh` e `install.ps1` |

Después, cambia `NicoElMaster` por tu usuario en las direcciones del README y de las guías.

Para comprobar que tu versión funciona sin tocar tu propio VS Code, sigue la receta de pruebas que hay al final de [AGENTS.md](../AGENTS.md).

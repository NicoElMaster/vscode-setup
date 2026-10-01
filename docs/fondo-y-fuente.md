# Fondo y fuente de la interfaz

Esta parte es opcional. Pone una imagen detrás de todo el editor y hace que los menús, las pestañas y los paneles usen la misma fuente que el código.

En macOS, donde aquí dice `Ctrl` usa `Cmd`.

## Léelo antes de decidir

VS Code no permite esto de forma oficial. La extensión que lo consigue, [Custom UI Style](https://marketplace.visualstudio.com/items?itemName=subframe7536.custom-ui-style), lo hace modificando los archivos de instalación de VS Code. Eso tiene tres consecuencias:

- **VS Code avisará de que la instalación «parece dañada»** y pondrá `[Unsupported]` en el título de la ventana. Es lo esperado y no afecta al funcionamiento. En el aviso, pulsa el engranaje y elige **Don't Show Again**.
- **Hay que volver a aplicarlo tras cada actualización de VS Code**, porque la actualización restaura los archivos originales.
- **En Linux y macOS tu usuario necesita permiso para modificar la carpeta donde está instalado VS Code.** Se consigue con un comando que pide tu contraseña de administrador.

Si alguna no te convence, sáltate esta parte. El resto de la configuración no depende de ella.

No funciona con VS Code instalado mediante Snap o Flatpak: esas instalaciones son de solo lectura.

## Paso 1: prepara la configuración

Con el instalador, desde la carpeta del repositorio:

```bash
./install.sh --fondo                       # con la imagen incluida
./install.sh --imagen ~/Imágenes/foto.jpg  # con tu propia imagen
```

En Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -Fondo
powershell -ExecutionPolicy Bypass -File .\install.ps1 -Imagen C:\Users\tu-usuario\Pictures\foto.jpg
```

Esto instala la extensión, copia la imagen junto a tus ajustes de VS Code y añade la configuración. Todavía no cambia nada a la vista: falta el paso 2.

<details>
<summary>Hacerlo a mano, sin el instalador</summary>

1. Instala la extensión [Custom UI Style](https://marketplace.visualstudio.com/items?itemName=subframe7536.custom-ui-style).
2. Pulsa `Ctrl+Shift+P`, ejecuta **Preferences: Open User Settings (JSON)** y añade estas líneas, poniendo la ruta completa de tu imagen:

```json
"custom-ui-style.font.sansSerif": "'JetBrainsMono Nerd Font', 'JetBrainsMono NF', 'Adwaita Sans', 'Segoe UI', system-ui, sans-serif",
"custom-ui-style.font.monospace": "'JetBrainsMono Nerd Font', 'JetBrainsMono NF', monospace",
"custom-ui-style.background.url": "file:///ruta/completa/a/tu/imagen.jpg",
"custom-ui-style.background.opacity": 0.9,
"custom-ui-style.background.size": "cover"
```

La dirección de la imagen empieza siempre por `file:///`:

| Sistema | Ejemplo |
|---|---|
| Linux | `file:///home/tu-usuario/Imágenes/fondo.jpg` |
| macOS | `file:///Users/tu-usuario/Pictures/fondo.jpg` |
| Windows | `file:///C:/Users/tu-usuario/Pictures/fondo.jpg` |

</details>

## Paso 2: aplícalo en VS Code

### Linux

1. Cierra VS Code por completo.
2. Da permiso a tu usuario sobre la carpeta de instalación. El instalador te muestra el comando exacto al terminar; en la mayoría de los casos es:

   ```bash
   sudo chown -R "$(whoami)" /usr/share/code
   ```

   Si VS Code está en otro sitio, la carpeta correcta es la que contiene `resources/app`. Otras ubicaciones habituales son `/opt/visual-studio-code` y `/usr/lib/code`.
3. Abre VS Code. La extensión preguntará **«Seems like first time use or new version is installed, initialize and reload config now?»**. Responde **Yes**. Si no aparece la pregunta, pulsa `Ctrl+Shift+P` y ejecuta **Custom UI Style: Reload**.
4. VS Code se reinicia y ya muestra el fondo y la fuente nueva.

### macOS

Igual que en Linux, con este comando en el paso 2:

```bash
sudo chown -R "$(whoami)" "/Applications/Visual Studio Code.app"
```

### Windows

Normalmente no hace falta dar permisos: abre VS Code y responde **Yes** a la pregunta de la extensión, o ejecuta **Custom UI Style: Reload**.

Si VS Code está instalado para todos los usuarios (en `C:\Program Files`), ciérralo y ábrelo una vez con clic derecho → **Ejecutar como administrador** antes de aplicar.

## Ajustarlo a tu gusto

Todo se cambia en `settings.json`. Con el ajuste `custom-ui-style.watch` activado, que es lo normal, la extensión pregunta si quieres aplicar los cambios cada vez que guardas.

| Para... | Cambia |
|---|---|
| Que la imagen se vea más | Baja `custom-ui-style.background.opacity`: con `0.9` apenas se nota, con `0.75` se ve claramente. No bajes mucho, porque el texto pierde contraste |
| Usar otra imagen | Vuelve a ejecutar el instalador con `--imagen`, o cambia `custom-ui-style.background.url` |
| Quitar la imagen y dejar solo la fuente | Borra la línea `custom-ui-style.background.url` |
| Otra fuente para la interfaz | Cambia `custom-ui-style.font.sansSerif`. Para una fuente normal, no monoespaciada: `"'Adwaita Sans', 'Segoe UI', system-ui, sans-serif"` |

## Después de actualizar VS Code

La actualización restaura los archivos originales, así que el fondo desaparece. Al abrir VS Code, la extensión lo detecta y vuelve a preguntar; responde **Yes**. En Linux hay que repetir antes el comando `sudo chown`, porque la actualización devuelve la carpeta al administrador.

## Quitarlo

1. En VS Code, pulsa `Ctrl+Shift+P` y ejecuta **Custom UI Style: Rollback**. Devuelve los archivos de VS Code a su estado original.
2. Borra de `settings.json` las líneas que empiezan por `custom-ui-style`, o ejecuta `./uninstall.sh`.
3. Desinstala la extensión Custom UI Style.

Hazlo en ese orden: si desinstalas la extensión primero, ya no tendrás el comando que restaura los archivos. En ese caso, vuelve a instalarla y ejecuta el Rollback, o espera a la siguiente actualización de VS Code, que también los restaura.

## ¿Y la extensión Background?

[Background](https://marketplace.visualstudio.com/items?itemName=shalldie.background) es otra extensión para poner imágenes de fondo, y también modifica los archivos de VS Code. Se instala con esta parte, pero apagada (`"background.enabled": false`), porque dos extensiones modificando los mismos archivos se estorban.

Si prefieres usarla en lugar de Custom UI Style, haz primero el Rollback de arriba y después pon `"background.enabled": true`. No uses las dos a la vez.

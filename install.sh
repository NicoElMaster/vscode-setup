#!/usr/bin/env bash
#
# vscode-setup · instalador para Linux y macOS
#
# Aplica los ajustes de config/settings.json encima de los que ya tengas (con
# copia de seguridad) e instala las extensiones de extensiones.txt. La terminal
# y el fondo son opcionales: --terminal, --fondo o --todo.
#
# Se puede ejecutar las veces que haga falta: solo hace lo que falte.
# Para deshacerlo, ./uninstall.sh

if [ -z "${BASH_VERSION:-}" ]; then
    echo "Este instalador necesita bash. Ejecútalo así: bash install.sh" >&2
    exit 1
fi

set -eu

RAIZ=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/lib.sh
. "$RAIZ/scripts/lib.sh"

ayuda() {
    cat <<'EOF'
vscode-setup · instalador para Linux y macOS

Uso: ./install.sh [opciones]

Sin opciones aplica los ajustes visuales e instala las 38 extensiones básicas.
Tus ajustes actuales se conservan y antes de tocarlos se guarda una copia.

Opciones:
  --terminal      Además configura la terminal: tema de Starship, tema de bat
                  y alias para eza y bat.
  --fondo         Además prepara la imagen de fondo y la fuente de la interfaz
                  con Custom UI Style. Termina con un paso manual.
  --imagen RUTA   Como --fondo, pero con tu propia imagen.
  --todo          Lo mismo que --terminal --fondo.
  --simular       Muestra lo que haría, sin cambiar nada.
  -h, --ayuda     Muestra esta ayuda.

Variables de entorno:
  VSCODE_BIN       Comando del editor. Por defecto "code"; también se reconocen
                   code-insiders, codium, code-oss y cursor.
  VSCODE_USER_DIR  Carpeta "User" del editor, si no está en el lugar habitual.

Para deshacerlo todo: ./uninstall.sh
EOF
}

CON_TERMINAL=0
CON_FONDO=0
SIMULAR=0
IMAGEN=""

while [ $# -gt 0 ]; do
    case "$1" in
        --terminal) CON_TERMINAL=1 ;;
        --fondo)    CON_FONDO=1 ;;
        --imagen)
            [ $# -ge 2 ] || morir "A --imagen le falta la ruta de la imagen."
            IMAGEN=$2
            CON_FONDO=1
            shift ;;
        --imagen=*) IMAGEN=${1#--imagen=}; CON_FONDO=1 ;;
        --todo)     CON_TERMINAL=1; CON_FONDO=1 ;;
        --simular)  SIMULAR=1 ;;
        -h|--ayuda|--help) ayuda; exit 0 ;;
        *)
            fallo "Opción desconocida: $1"
            detalle "Ejecuta ./install.sh --ayuda para ver las opciones."
            exit 2 ;;
    esac
    shift
done

if [ -n "$IMAGEN" ] && [ ! -f "$IMAGEN" ]; then
    morir "No existe la imagen: $IMAGEN"
fi

FALLOS=0
HAY_CAMBIOS_DE_TERMINAL=0
FALTAN_HERRAMIENTAS=""

# ── Pasos ────────────────────────────────────────────────────────────────────

paso_ajustes() {
    local salida estado=0 imagen destino url
    local -a argumentos
    argumentos=(aplicar "$SETTINGS" "$ESTADO_AJUSTES" "$RAIZ/config/settings.json")

    if [ "$CON_FONDO" = 1 ]; then
        imagen="${IMAGEN:-$RAIZ/assets/fondos/kde-next-oscuro.jpg}"
        destino="$CARPETA_ESTADO/fondos/$(basename "$imagen")"
        if [ "$SIMULAR" = 1 ]; then
            paso "Se copiaría la imagen de fondo a $destino"
        else
            mkdir -p "$CARPETA_ESTADO/fondos"
            if ! cmp -s "$imagen" "$destino"; then
                cp "$imagen" "$destino"
            fi
            bien "Imagen de fondo en $destino"
        fi
        # Custom UI Style necesita la dirección completa de la imagen, que
        # depende de cada equipo; por eso no está en settings-fondo.json.
        url=$(ajustes_py uri "$destino")
        argumentos+=("$RAIZ/config/settings-fondo.json" --cadena custom-ui-style.background.url "$url")
    fi

    argumentos+=(--copias "$CARPETA_COPIAS")
    if [ "$SIMULAR" = 1 ]; then
        argumentos+=(--simular)
    fi

    salida=$(ajustes_py "${argumentos[@]}" 2>&1) || estado=$?
    printf '%s\n' "$salida" | sangrar
    if [ "$estado" != 0 ]; then
        fallo "No se pudieron aplicar los ajustes; tu settings.json quedó como estaba."
        detalle "Puedes copiarlos a mano: docs/instalacion-manual.md"
        FALLOS=$((FALLOS + 1))
    elif [ "$SIMULAR" = 0 ]; then
        bien "Ajustes en $SETTINGS"
    fi
}

paso_extensiones() {
    local deseadas total instaladas faltan n_faltan fallidas n_fallidas nuevas id
    local -a argumentos

    deseadas=$(leer_lista "$RAIZ/extensiones.txt")
    if [ "$CON_FONDO" = 1 ]; then
        deseadas="$deseadas
$(leer_lista "$RAIZ/extensiones-fondo.txt")"
    fi
    total=$(contar "$deseadas")
    instaladas=$(listar_instaladas)
    faltan=$(las_que_faltan "$deseadas" "$instaladas")
    n_faltan=$(contar "$faltan")

    if [ "$n_faltan" = 0 ]; then
        bien "Las $total extensiones ya estaban instaladas"
        return 0
    fi
    if [ "$SIMULAR" = 1 ]; then
        paso "Extensiones que se instalarían: $n_faltan (ya instaladas: $((total - n_faltan)))"
        printf '%s\n' "$faltan" | sangrar
        return 0
    fi

    paso "Extensiones por instalar: $n_faltan (ya instaladas: $((total - n_faltan))). Puede tardar unos minutos..."
    argumentos=()
    while IFS= read -r id; do
        argumentos+=(--install-extension "$id")
    done <<EOF
$faltan
EOF
    # El resultado no se juzga por lo que diga el editor, sino comprobando
    # después qué quedó instalado de verdad.
    "$EDITOR_BIN" "${argumentos[@]}" 2>&1 | quitar_ruido | sangrar || true

    instaladas=$(listar_instaladas)
    fallidas=$(las_que_faltan "$faltan" "$instaladas")
    n_fallidas=$(contar "$fallidas")
    nuevas=$(las_que_faltan "$faltan" "$(printf '%s\n' "$fallidas" | en_minusculas)")

    # Se apunta qué instaló este script para que uninstall.sh quite solo eso
    # y no las extensiones que la persona ya tenía.
    if [ -n "$nuevas" ]; then
        mkdir -p "$CARPETA_ESTADO"
        touch "$ESTADO_EXTENSIONES"
        printf '%s\n' "$nuevas" | while IFS= read -r id; do
            grep -Fxqi "$id" "$ESTADO_EXTENSIONES" || printf '%s\n' "$id" >> "$ESTADO_EXTENSIONES"
        done
    fi

    if [ "$n_fallidas" = 0 ]; then
        bien "Extensiones nuevas: $n_faltan. Ya están las $total."
    else
        bien "Extensiones nuevas: $((n_faltan - n_fallidas))"
        fallo "Extensiones que no se pudieron instalar: $n_fallidas"
        printf '%s\n' "$fallidas" | sangrar
        detalle "Revisa tu conexión y vuelve a ejecutar el instalador: solo reintentará estas."
        FALLOS=$((FALLOS + 1))
    fi
}

paso_fuente() {
    if fuente_instalada; then
        bien "La fuente JetBrainsMono Nerd Font está instalada"
    else
        aviso "No encuentro la fuente JetBrainsMono Nerd Font."
        detalle "Todo funciona sin ella, pero no verás las ligaduras ni los iconos de la terminal."
        sugerir_fuente
    fi
}

terminal_starship() {
    local origen="$RAIZ/terminal/starship.toml" destino copia
    destino="${STARSHIP_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml}"

    command -v starship >/dev/null 2>&1 || FALTAN_HERRAMIENTAS="$FALTAN_HERRAMIENTAS starship"
    if cmp -s "$origen" "$destino"; then
        bien "Starship ya tenía este tema"
        return 0
    fi
    if [ "$SIMULAR" = 1 ]; then
        paso "Se copiaría el tema de Starship a $destino"
        return 0
    fi
    if [ -f "$destino" ]; then
        copia=$(respaldar "$destino" starship.toml)
        detalle "Tu configuración anterior de Starship: $copia"
        # Solo se recuerda la primera copia: es la configuración original.
        if [ -z "$(leer_estado_terminal starship)" ]; then
            guardar_estado_terminal starship reemplazado
            guardar_estado_terminal starship_copia "$copia"
        fi
    elif [ -z "$(leer_estado_terminal starship)" ]; then
        guardar_estado_terminal starship creado
    fi
    mkdir -p "$(dirname "$destino")"
    cp "$origen" "$destino"
    guardar_estado_terminal starship_ruta "$destino"
    guardar_estado_terminal starship_huella "$(huella "$destino")"
    HAY_CAMBIOS_DE_TERMINAL=1
    bien "Tema de Starship en $destino"
}

terminal_bat() {
    local bat="" temas destino copia linea="--theme=\"$TEMA_BAT\""

    if command -v bat >/dev/null 2>&1; then
        bat=bat
    elif command -v batcat >/dev/null 2>&1; then
        bat=batcat
    else
        FALTAN_HERRAMIENTAS="$FALTAN_HERRAMIENTAS bat"
        return 0
    fi

    temas=$("$bat" --list-themes --color=never 2>/dev/null || true)
    if ! grep -Fq "$TEMA_BAT" <<<"$temas"; then
        aviso "Tu versión de bat no trae el tema $TEMA_BAT (llegó en bat 0.25); lo dejo como está."
        return 0
    fi

    destino=$("$bat" --config-file 2>/dev/null || true)
    [ -n "$destino" ] || destino="${XDG_CONFIG_HOME:-$HOME/.config}/bat/config"
    if [ -f "$destino" ] && grep -Fxq -e "$linea" "$destino"; then
        bien "bat ya usaba el tema $TEMA_BAT"
        return 0
    fi
    if [ "$SIMULAR" = 1 ]; then
        paso "Se pondría el tema $TEMA_BAT en $destino"
        return 0
    fi
    if [ -f "$destino" ]; then
        copia=$(respaldar "$destino" bat-config)
        detalle "Tu configuración anterior de bat: $copia"
        if [ -z "$(leer_estado_terminal bat)" ]; then
            guardar_estado_terminal bat modificado
            guardar_estado_terminal bat_copia "$copia"
        fi
        # Se cambia solo la línea del tema; el resto de sus opciones se queda.
        # Se escribe con cat y no con mv para no romper un enlace simbólico.
        grep -v -e '^--theme[= ]' "$destino" > "$destino.tmp" || true
        printf '%s\n' "$linea" >> "$destino.tmp"
        cat "$destino.tmp" > "$destino"
        rm -f "$destino.tmp"
    else
        if [ -z "$(leer_estado_terminal bat)" ]; then
            guardar_estado_terminal bat creado
        fi
        mkdir -p "$(dirname "$destino")"
        cp "$RAIZ/terminal/bat.conf" "$destino"
    fi
    guardar_estado_terminal bat_ruta "$destino"
    guardar_estado_terminal bat_huella "$(huella "$destino")"
    HAY_CAMBIOS_DE_TERMINAL=1
    bien "bat con el tema $TEMA_BAT"
}

terminal_alias() {
    local shell rc lineas="" copia
    shell=$(basename "${SHELL:-desconocido}")
    case "$shell" in
        zsh)  rc="${ZDOTDIR:-$HOME}/.zshrc" ;;
        bash) rc="$HOME/.bashrc" ;;
        *)
            aviso "No sé configurar tu shell ($shell) automáticamente."
            detalle "En docs/terminal.md están las líneas para añadirlas a mano."
            return 0 ;;
    esac

    command -v eza >/dev/null 2>&1 || FALTAN_HERRAMIENTAS="$FALTAN_HERRAMIENTAS eza"
    if [ -f "$rc" ] && grep -Fxq -e "$MARCA_INICIO" "$rc"; then
        bien "$rc ya tenía el bloque de vscode-setup"
        return 0
    fi

    # Cada línea se añade solo si la persona no tiene ya algo equivalente, y
    # lleva su propia comprobación para no dar errores si falta la herramienta.
    if ! { [ -f "$rc" ] && grep -q 'starship init' "$rc"; }; then
        lineas="${lineas}command -v starship >/dev/null 2>&1 && eval \"\$(starship init $shell)\"
"
    fi
    if ! { [ -f "$rc" ] && grep -Eq '^[[:space:]]*alias[[:space:]]+ls=' "$rc"; }; then
        lineas="${lineas}command -v eza >/dev/null 2>&1 && alias ls='eza --icons=auto' ll='eza -la --icons=auto'
"
    fi
    if ! { [ -f "$rc" ] && grep -Eq '^[[:space:]]*alias[[:space:]]+cat=' "$rc"; }; then
        lineas="${lineas}if command -v bat >/dev/null 2>&1; then alias cat='bat'; elif command -v batcat >/dev/null 2>&1; then alias cat='batcat'; fi
"
    fi

    if [ -z "$lineas" ]; then
        bien "$rc ya tenía Starship y los alias"
        return 0
    fi
    if [ "$SIMULAR" = 1 ]; then
        paso "Se añadiría este bloque al final de $rc:"
        printf '%s' "$lineas" | sangrar
        return 0
    fi
    if [ -f "$rc" ]; then
        copia=$(respaldar "$rc" "$(basename "$rc" | tr -d .)")
        detalle "Copia de tu $(basename "$rc"): $copia"
    fi
    {
        printf '\n%s\n' "$MARCA_INICIO"
        printf '%s\n' "# Añadido por vscode-setup. Para quitarlo: ./uninstall.sh"
        printf '%s' "$lineas"
        printf '%s\n' "$MARCA_FIN"
    } >> "$rc"
    guardar_estado_terminal rc "$rc"
    HAY_CAMBIOS_DE_TERMINAL=1
    bien "Starship y alias añadidos a $rc"
}

paso_terminal() {
    terminal_starship
    terminal_bat
    terminal_alias

    if [ -n "$FALTAN_HERRAMIENTAS" ]; then
        aviso "La configuración queda lista, pero faltan por instalar:$FALTAN_HERRAMIENTAS"
        if command -v pacman >/dev/null 2>&1; then
            detalle "sudo pacman -S$FALTAN_HERRAMIENTAS"
        elif command -v brew >/dev/null 2>&1; then
            detalle "brew install$FALTAN_HERRAMIENTAS"
        else
            detalle "Cómo instalarlas en tu sistema: docs/terminal.md"
        fi
    fi
}

que_sigue() {
    local carpeta n=1

    if [ "$SIMULAR" = 1 ]; then
        titulo "Simulación terminada: no se cambió nada."
        return 0
    fi

    if [ "$FALLOS" = 0 ]; then
        titulo "Listo. Qué sigue:"
    else
        titulo "Terminado con problemas (los marcados con ✗). Qué sigue:"
    fi

    detalle "$n. En VS Code pulsa $TECLA+Shift+P y ejecuta \"Developer: Reload Window\"."
    n=$((n + 1))

    if [ "$HAY_CAMBIOS_DE_TERMINAL" = 1 ]; then
        detalle "$n. Abre una terminal nueva para ver el nuevo aspecto."
        n=$((n + 1))
    fi

    if [ "$CON_FONDO" = 1 ]; then
        carpeta=$(carpeta_instalacion)
        detalle "$n. Para activar el fondo y la fuente de la interfaz:"
        if [ -n "$carpeta" ] && instalacion_modificable "$carpeta"; then
            detalle "   · En VS Code: $TECLA+Shift+P → \"Custom UI Style: Reload\" y acepta el reinicio."
        else
            detalle "   · Cierra VS Code por completo."
            if [ -n "$carpeta" ]; then
                detalle "   · Ejecuta:  sudo chown -R \"\$(whoami)\" \"$carpeta\""
            else
                detalle "   · Da permiso de escritura a tu usuario sobre la carpeta donde está"
                detalle "     instalado VS Code (mira docs/fondo-y-fuente.md)."
            fi
            detalle "   · Abre VS Code: $TECLA+Shift+P → \"Custom UI Style: Reload\" y acepta el reinicio."
        fi
        detalle "   VS Code avisará de que la instalación \"parece dañada\": es lo esperado."
        detalle "   Hay que repetirlo tras cada actualización de VS Code. Más en docs/fondo-y-fuente.md"
        n=$((n + 1))
    fi

    detalle "$n. Si quieres volver atrás: ./uninstall.sh"
}

# ── Programa ─────────────────────────────────────────────────────────────────

detectar_sistema
detectar_editor
detectar_carpeta_usuario
exigir_python

TOTAL=3
if [ "$CON_TERMINAL" = 1 ]; then
    TOTAL=4
fi

printf '%svscode-setup%s · instalador\n' "$NEGRITA" "$NORMAL"
detalle "Editor:  $EDITOR_BIN"
detalle "Ajustes: $SETTINGS"
if [ "$SIMULAR" = 1 ]; then
    detalle "Modo simulación: no se cambia nada."
fi

# Los ajustes van antes que las extensiones: así, cuando una extensión se
# activa por primera vez, ya encuentra su configuración (por ejemplo,
# Background nace apagada en vez de ofrecer aplicar sus imágenes de muestra).
titulo "[1/$TOTAL] Ajustes de VS Code"
paso_ajustes

titulo "[2/$TOTAL] Extensiones"
paso_extensiones

titulo "[3/$TOTAL] Fuente"
paso_fuente

if [ "$CON_TERMINAL" = 1 ]; then
    titulo "[4/$TOTAL] Terminal"
    paso_terminal
fi

que_sigue

if [ "$FALLOS" != 0 ]; then
    exit 1
fi

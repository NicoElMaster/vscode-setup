# shellcheck shell=bash
# shellcheck disable=SC2034  # las variables de aquí las usan install.sh y uninstall.sh
#
# Funciones compartidas por install.sh y uninstall.sh. No se ejecuta solo.
#
# Está escrito para funcionar también con el bash 3.2 que trae macOS: nada de
# arreglos asociativos, mapfile ni ${variable,,}.

MARCA_INICIO="# >>> vscode-setup >>>"
MARCA_FIN="# <<< vscode-setup <<<"
TEMA_BAT="Catppuccin Mocha"
EXTENSION_FONDO="subframe7536.custom-ui-style"

# ── Mensajes ─────────────────────────────────────────────────────────────────
# Todo se escribe en la salida normal, también los errores: así quedan en
# orden cuando alguien guarda el registro. Los fallos se señalan con el código
# de salida.

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    NEGRITA=$'\033[1m' TENUE=$'\033[2m' NORMAL=$'\033[0m'
    VERDE=$'\033[32m' AMARILLO=$'\033[33m' ROJO=$'\033[31m' AZUL=$'\033[36m'
else
    NEGRITA="" TENUE="" NORMAL="" VERDE="" AMARILLO="" ROJO="" AZUL=""
fi

titulo()  { printf '\n%s%s%s\n' "$NEGRITA" "$1" "$NORMAL"; }
bien()    { printf '  %s✓%s %s\n' "$VERDE" "$NORMAL" "$1"; }
aviso()   { printf '  %s!%s %s\n' "$AMARILLO" "$NORMAL" "$1"; }
fallo()   { printf '  %s✗%s %s\n' "$ROJO" "$NORMAL" "$1"; }
paso()    { printf '  %s→%s %s\n' "$AZUL" "$NORMAL" "$1"; }
detalle() { printf '    %s\n' "$1"; }
morir()   { fallo "$1"; exit 1; }

# Sangra lo que recibe por la entrada, línea a línea y sin esperar al final
# (sed lo guardaría en un búfer y no se vería el progreso).
sangrar() {
    local linea
    while IFS= read -r linea || [ -n "$linea" ]; do
        printf '    %s%s%s\n' "$TENUE" "$linea" "$NORMAL"
    done
}

# ── Detección del sistema y del editor ───────────────────────────────────────

detectar_sistema() {
    case "$(uname -s)" in
        Linux)  SISTEMA=linux; TECLA="Ctrl" ;;
        Darwin) SISTEMA=macos; TECLA="Cmd" ;;
        MINGW*|MSYS*|CYGWIN*)
            morir "En Windows usa install.ps1 desde PowerShell (está explicado en el README)." ;;
        *)
            morir "Sistema no compatible: $(uname -s)" ;;
    esac
}

detectar_editor() {
    local en_app="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
    EDITOR_BIN="${VSCODE_BIN:-}"
    if [ -n "$EDITOR_BIN" ]; then
        command -v "$EDITOR_BIN" >/dev/null 2>&1 ||
            morir "No encuentro el comando '$EDITOR_BIN' (lo indicaste en VSCODE_BIN)."
    elif command -v code >/dev/null 2>&1; then
        EDITOR_BIN=code
    elif [ "$SISTEMA" = macos ] && [ -x "$en_app" ]; then
        EDITOR_BIN=$en_app
    else
        fallo "No encuentro el comando 'code'."
        if [ "$SISTEMA" = macos ]; then
            detalle "Abre VS Code, pulsa Cmd+Shift+P y ejecuta:"
            detalle "  Shell Command: Install 'code' command in PATH"
        else
            detalle "Comprueba que VS Code está instalado y que 'code --version' funciona en esta terminal."
        fi
        detalle "Si usas otro editor (VSCodium, Cursor...), indícalo: VSCODE_BIN=codium ./install.sh"
        exit 1
    fi
}

detectar_carpeta_usuario() {
    local nombre
    if [ -n "${VSCODE_USER_DIR:-}" ]; then
        CARPETA_USUARIO=$VSCODE_USER_DIR
    else
        case "$(basename "$EDITOR_BIN")" in
            code)            nombre="Code" ;;
            code-insiders)   nombre="Code - Insiders" ;;
            codium|vscodium) nombre="VSCodium" ;;
            code-oss)        nombre="Code - OSS" ;;
            cursor)          nombre="Cursor" ;;
            *)
                fallo "No sé dónde guarda sus ajustes '$EDITOR_BIN'."
                detalle "Indícalo así: VSCODE_USER_DIR=/ruta/a/la/carpeta/User ./install.sh"
                exit 1 ;;
        esac
        if [ "$SISTEMA" = macos ]; then
            CARPETA_USUARIO="$HOME/Library/Application Support/$nombre/User"
        else
            CARPETA_USUARIO="${XDG_CONFIG_HOME:-$HOME/.config}/$nombre/User"
        fi
    fi
    SETTINGS="$CARPETA_USUARIO/settings.json"
    # Todo lo que el instalador necesita recordar vive aquí, junto a los ajustes.
    CARPETA_ESTADO="$CARPETA_USUARIO/vscode-setup"
    CARPETA_COPIAS="$CARPETA_ESTADO/copias"
    ESTADO_AJUSTES="$CARPETA_ESTADO/ajustes-anteriores.json"
    ESTADO_EXTENSIONES="$CARPETA_ESTADO/extensiones-instaladas.txt"
    ESTADO_TERMINAL="$CARPETA_ESTADO/terminal.estado"
}

exigir_python() {
    python3 -c 'import json' >/dev/null 2>&1 ||
        morir "Hace falta python3 para modificar settings.json sin romperlo. Instálalo y vuelve a intentarlo."
}

ajustes_py() { python3 "$RAIZ/scripts/settings.py" "$@"; }

# ── Extensiones ──────────────────────────────────────────────────────────────

en_minusculas() { tr '[:upper:]' '[:lower:]'; }

# Cuenta las líneas no vacías de un texto.
contar() { printf '%s\n' "$1" | grep -c . || true; }

# Identificadores de una lista de extensiones: sin comentarios ni espacios.
leer_lista() {
    sed -e 's/#.*//' -e 's/[[:space:]]//g' "$1" | grep -v '^$' || true
}

# Extensiones instaladas ahora mismo, en minúsculas.
listar_instaladas() {
    "$EDITOR_BIN" --list-extensions 2>/dev/null | en_minusculas |
        grep -E '^[a-z0-9][a-z0-9-]*\.[a-z0-9._-]+$' || true
}

# Imprime los identificadores de $1 que no aparecen en $2 (que va en minúsculas).
las_que_faltan() {
    local id
    printf '%s\n' "$1" | while IFS= read -r id; do
        [ -n "$id" ] || continue
        printf '%s\n' "$2" | grep -Fxq "$(printf '%s' "$id" | en_minusculas)" ||
            printf '%s\n' "$id"
    done
}

# Imprime los identificadores de $1 que sí aparecen en $2 (que va en minúsculas).
las_que_estan() {
    local id
    printf '%s\n' "$1" | while IFS= read -r id; do
        [ -n "$id" ] || continue
        if printf '%s\n' "$2" | grep -Fxq "$(printf '%s' "$id" | en_minusculas)"; then
            printf '%s\n' "$id"
        fi
    done
}

# Quita los avisos internos de Node y el eco de cada instalación que empieza.
quitar_ruido() {
    grep --line-buffered -v \
        -e 'DeprecationWarning' -e 'trace-deprecation' \
        -e '^Installing extension' -e '^Uninstalling ' || true
}

# ── Fuente ───────────────────────────────────────────────────────────────────

fuente_instalada() {
    local fuentes=""
    if command -v fc-list >/dev/null 2>&1; then
        fuentes=$(fc-list : family 2>/dev/null || true)
    fi
    if [ "$SISTEMA" = macos ]; then
        fuentes="$fuentes
$(ls "$HOME/Library/Fonts" /Library/Fonts 2>/dev/null || true)"
    fi
    # Según el sistema aparece como "JetBrainsMono Nerd Font", "JetBrainsMono NF"
    # o como archivo JetBrainsMonoNerdFont-*.ttf.
    case "$fuentes" in
        *"JetBrainsMono N"*|*JetBrainsMonoNerdFont*) return 0 ;;
    esac
    return 1
}

sugerir_fuente() {
    if command -v pacman >/dev/null 2>&1; then
        detalle "Para instalarla: sudo pacman -S ttf-jetbrains-mono-nerd"
    elif command -v brew >/dev/null 2>&1; then
        detalle "Para instalarla: brew install --cask font-jetbrains-mono-nerd-font"
    else
        detalle "Descarga \"JetBrainsMono\" de https://www.nerdfonts.com/font-downloads e instálala."
    fi
}

# ── Estado de la parte de terminal (pares clave=valor) ───────────────────────

leer_estado_terminal() {
    [ -f "$ESTADO_TERMINAL" ] || return 0
    sed -n "s/^$1=//p" "$ESTADO_TERMINAL" | tail -n 1
}

guardar_estado_terminal() {
    mkdir -p "$CARPETA_ESTADO"
    if [ -f "$ESTADO_TERMINAL" ]; then
        grep -v "^$1=" "$ESTADO_TERMINAL" > "$ESTADO_TERMINAL.tmp" || true
        mv "$ESTADO_TERMINAL.tmp" "$ESTADO_TERMINAL"
    fi
    printf '%s=%s\n' "$1" "$2" >> "$ESTADO_TERMINAL"
}

# Huella de un archivo, para saber después si la persona lo cambió.
huella() { cksum < "$1" | tr -s ' \t' ' '; }

# Copia $1 a la carpeta de copias con el nombre $2 y la fecha; imprime la ruta.
respaldar() {
    local destino
    mkdir -p "$CARPETA_COPIAS"
    destino="$CARPETA_COPIAS/$2-$(date +%Y%m%d-%H%M%S)"
    cp -p "$1" "$destino"
    printf '%s\n' "$destino"
}

# ── Instalación del editor (para Custom UI Style) ────────────────────────────

# Imprime la carpeta donde está instalado el editor, o nada si no la encuentra.
carpeta_instalacion() {
    local real candidato
    real=$(python3 -c 'import os, shutil, sys
ruta = shutil.which(sys.argv[1]) or sys.argv[1]
print(os.path.realpath(ruta))' "$EDITOR_BIN" 2>/dev/null || true)
    case "$real" in
        *.app/Contents/*)
            printf '%s\n' "${real%%/Contents/*}"
            return 0 ;;
        */bin/*)
            if [ -d "${real%/bin/*}/resources/app" ]; then
                printf '%s\n' "${real%/bin/*}"
                return 0
            fi ;;
    esac
    # Algunas distribuciones ponen en el PATH un lanzador que no es un enlace.
    if [ "$(basename "$EDITOR_BIN")" = code ]; then
        for candidato in /usr/share/code /opt/visual-studio-code /usr/lib/code /opt/VSCode-linux-x64; do
            if [ -d "$candidato/resources/app" ]; then
                printf '%s\n' "$candidato"
                return 0
            fi
        done
    fi
    return 0
}

# ¿Puede el usuario actual modificar los archivos de esa instalación?
instalacion_modificable() {
    local app="$1/resources/app"
    [ -d "$app" ] || app="$1/Contents/Resources/app"
    [ -w "$app/out" ]
}

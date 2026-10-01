#!/usr/bin/env bash
#
# vscode-setup · desinstalador para Linux y macOS
#
# Deshace lo que hizo install.sh y nada más:
#   · cada ajuste vuelve al valor que tenía antes (los que hayas cambiado
#     después de instalar se quedan como los dejaste);
#   · se desinstalan solo las extensiones que instaló el instalador, no las
#     que ya tenías;
#   · la terminal vuelve a la configuración anterior.
# Las copias de seguridad no se borran.

if [ -z "${BASH_VERSION:-}" ]; then
    echo "Este desinstalador necesita bash. Ejecútalo así: bash uninstall.sh" >&2
    exit 1
fi

set -eu

RAIZ=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/lib.sh
. "$RAIZ/scripts/lib.sh"

ayuda() {
    cat <<'EOF'
vscode-setup · desinstalador para Linux y macOS

Uso: ./uninstall.sh [opciones]

Devuelve los ajustes a como estaban, desinstala las extensiones que puso el
instalador (las que ya tenías se quedan) y restaura la terminal.

Opciones:
  --simular     Muestra lo que haría, sin cambiar nada.
  -h, --ayuda   Muestra esta ayuda.

Usa las mismas variables VSCODE_BIN y VSCODE_USER_DIR que el instalador.
EOF
}

SIMULAR=0
while [ $# -gt 0 ]; do
    case "$1" in
        --simular) SIMULAR=1 ;;
        -h|--ayuda|--help) ayuda; exit 0 ;;
        *)
            fallo "Opción desconocida: $1"
            detalle "Ejecuta ./uninstall.sh --ayuda para ver las opciones."
            exit 2 ;;
    esac
    shift
done

FALLOS=0

# ── Pasos ────────────────────────────────────────────────────────────────────

paso_ajustes() {
    local salida estado=0
    local -a argumentos
    argumentos=(revertir "$SETTINGS" "$ESTADO_AJUSTES" --copias "$CARPETA_COPIAS")
    if [ "$SIMULAR" = 1 ]; then
        argumentos+=(--simular)
    fi
    salida=$(ajustes_py "${argumentos[@]}" 2>&1) || estado=$?
    printf '%s\n' "$salida" | sangrar
    if [ "$estado" != 0 ]; then
        fallo "No se pudieron revertir los ajustes; tu settings.json quedó como estaba."
        FALLOS=$((FALLOS + 1))
    elif [ "$SIMULAR" = 0 ]; then
        bien "Ajustes en $SETTINGS"
    fi
}

paso_extensiones() {
    local nuestras instaladas quitar n_quitar restantes n_restantes id
    local -a argumentos

    if [ ! -f "$ESTADO_EXTENSIONES" ]; then
        bien "El instalador no había añadido ninguna extensión"
        return 0
    fi

    nuestras=$(leer_lista "$ESTADO_EXTENSIONES")
    if [ "$TENIA_FONDO" = 1 ]; then
        # Custom UI Style hace falta para devolver VS Code a su estado
        # original, así que no se desinstala aquí (se explica al final).
        nuestras=$(printf '%s\n' "$nuestras" | grep -Fxiv "$EXTENSION_FONDO" || true)
    fi
    instaladas=$(listar_instaladas)
    quitar=$(las_que_estan "$nuestras" "$instaladas")
    n_quitar=$(contar "$quitar")

    if [ "$n_quitar" = 0 ]; then
        bien "No queda instalada ninguna extensión de las que añadió el instalador"
        return 0
    fi
    if [ "$SIMULAR" = 1 ]; then
        paso "Extensiones que se desinstalarían: $n_quitar"
        printf '%s\n' "$quitar" | sangrar
        return 0
    fi

    paso "Extensiones por desinstalar: $n_quitar"
    argumentos=()
    while IFS= read -r id; do
        argumentos+=(--uninstall-extension "$id")
    done <<EOF
$quitar
EOF
    "$EDITOR_BIN" "${argumentos[@]}" 2>&1 | quitar_ruido | sangrar || true

    instaladas=$(listar_instaladas)
    restantes=$(las_que_estan "$quitar" "$instaladas")
    n_restantes=$(contar "$restantes")
    if [ "$n_restantes" = 0 ]; then
        bien "Extensiones desinstaladas: $n_quitar"
        rm -f "$ESTADO_EXTENSIONES"
    else
        bien "Extensiones desinstaladas: $((n_quitar - n_restantes))"
        fallo "Extensiones que no se pudieron desinstalar: $n_restantes"
        printf '%s\n' "$restantes" | sangrar
        detalle "Quítalas desde el panel de extensiones o vuelve a ejecutar ./uninstall.sh"
        # Se deja apuntado lo que falta para que un segundo intento lo retome.
        printf '%s\n' "$restantes" > "$ESTADO_EXTENSIONES"
        FALLOS=$((FALLOS + 1))
    fi
}

# Devuelve un archivo de la terminal a como estaba. $1 = starship | bat
restaurar_archivo() {
    local nombre=$1 estado ruta guardada copia
    estado=$(leer_estado_terminal "$nombre")
    if [ -z "$estado" ]; then
        return 0
    fi
    ruta=$(leer_estado_terminal "${nombre}_ruta")
    guardada=$(leer_estado_terminal "${nombre}_huella")
    copia=$(leer_estado_terminal "${nombre}_copia")

    if [ ! -f "$ruta" ]; then
        return 0
    fi
    # Si la huella no coincide, la persona editó el archivo después de
    # instalar: restaurarlo le borraría esos cambios.
    if [ "$(huella "$ruta")" != "$guardada" ]; then
        aviso "Cambiaste $ruta después de instalar; se queda como está."
        if [ -n "$copia" ]; then
            detalle "La versión que tenías antes de instalar sigue en $copia"
        fi
        return 0
    fi
    if [ "$estado" = creado ]; then
        if [ "$SIMULAR" = 1 ]; then
            paso "Se borraría $ruta (lo creó el instalador)"
        else
            rm -f "$ruta"
            bien "Borrado $ruta (lo había creado el instalador)"
        fi
    elif [ -n "$copia" ] && [ -f "$copia" ]; then
        if [ "$SIMULAR" = 1 ]; then
            paso "Se restauraría $ruta desde $copia"
        else
            cat "$copia" > "$ruta"
            bien "Restaurado $ruta"
        fi
    else
        aviso "No encuentro la copia de $ruta; se queda como está."
    fi
}

paso_terminal() {
    local rc salida estado=0
    if [ ! -f "$ESTADO_TERMINAL" ]; then
        bien "El instalador no había tocado la terminal"
        return 0
    fi

    rc=$(leer_estado_terminal rc)
    if [ -n "$rc" ] && [ -f "$rc" ]; then
        if [ "$SIMULAR" = 1 ]; then
            paso "Se quitaría el bloque de vscode-setup de $rc"
        else
            salida=$(ajustes_py quitar-bloque "$rc" "$MARCA_INICIO" "$MARCA_FIN" 2>&1) || estado=$?
            if [ "$estado" = 0 ]; then
                bien "Alias y Starship quitados de $rc"
            else
                printf '%s\n' "$salida" | sangrar
                fallo "No pude quitar el bloque de $rc; bórralo a mano (está entre las marcas vscode-setup)."
                FALLOS=$((FALLOS + 1))
            fi
        fi
    fi

    restaurar_archivo starship
    restaurar_archivo bat

    if [ "$SIMULAR" = 0 ]; then
        rm -f "$ESTADO_TERMINAL"
    fi
}

# ── Programa ─────────────────────────────────────────────────────────────────

detectar_sistema
detectar_editor
detectar_carpeta_usuario
exigir_python

printf '%svscode-setup%s · desinstalador\n' "$NEGRITA" "$NORMAL"
detalle "Editor:  $EDITOR_BIN"
detalle "Ajustes: $SETTINGS"
if [ "$SIMULAR" = 1 ]; then
    detalle "Modo simulación: no se cambia nada."
fi

if [ ! -d "$CARPETA_ESTADO" ]; then
    titulo "No hay nada que desinstalar."
    detalle "No encuentro una instalación de vscode-setup en $CARPETA_USUARIO"
    exit 0
fi

# ¿Se llegó a configurar el fondo? Entonces Custom UI Style pudo modificar los
# archivos de VS Code y hay que tratarla aparte.
TENIA_FONDO=0
if [ -f "$ESTADO_AJUSTES" ] && grep -q 'custom-ui-style' "$ESTADO_AJUSTES"; then
    TENIA_FONDO=1
fi
if [ -f "$ESTADO_EXTENSIONES" ] && grep -Fxqi "$EXTENSION_FONDO" "$ESTADO_EXTENSIONES"; then
    TENIA_FONDO=1
fi

titulo "[1/3] Ajustes de VS Code"
paso_ajustes

titulo "[2/3] Extensiones"
paso_extensiones

titulo "[3/3] Terminal"
paso_terminal

if [ "$SIMULAR" = 1 ]; then
    titulo "Simulación terminada: no se cambió nada."
    exit 0
fi

rm -rf "$CARPETA_ESTADO/fondos"
rmdir "$CARPETA_ESTADO" 2>/dev/null || true

if [ "$FALLOS" = 0 ]; then
    titulo "Listo. Qué sigue:"
else
    titulo "Terminado con problemas (los marcados con ✗). Qué sigue:"
fi
detalle "· En VS Code pulsa $TECLA+Shift+P y ejecuta \"Developer: Reload Window\"."
if [ "$TENIA_FONDO" = 1 ]; then
    detalle "· La extensión Custom UI Style sigue instalada a propósito. Si llegaste a activar"
    detalle "  el fondo, ejecuta primero \"Custom UI Style: Rollback\" en VS Code para devolverlo"
    detalle "  a su estado original, y después desinstálala desde el panel de extensiones."
fi
if [ -d "$CARPETA_COPIAS" ]; then
    detalle "· Las copias de seguridad siguen en $CARPETA_COPIAS"
fi

if [ "$FALLOS" != 0 ]; then
    exit 1
fi

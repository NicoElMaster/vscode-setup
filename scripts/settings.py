#!/usr/bin/env python3
"""Aplica y revierte los ajustes de vscode-setup en el settings.json de VS Code.

VS Code admite comentarios y comas finales en settings.json, así que no se
puede leer con json.loads directamente. Este script los tolera, pone los
ajustes de este repositorio encima de los que ya había y recuerda el valor
anterior de cada uno para poder deshacerlo sin tocar nada más.

Lo llaman install.sh y uninstall.sh; no hace falta ejecutarlo a mano.

    settings.py aplicar  SETTINGS ESTADO AJUSTES.json [...] [--cadena CLAVE VALOR]
                         [--copias DIR] [--simular]
    settings.py revertir SETTINGS ESTADO [--copias DIR] [--simular]
    settings.py uri RUTA
    settings.py quitar-bloque ARCHIVO INICIO FIN
"""

import argparse
import json
import os
import shutil
import sys
import tempfile
import time
from pathlib import Path

VERSION_ESTADO = 1


class ErrorDeLectura(Exception):
    pass


# ── Lectura tolerante de JSON con comentarios ────────────────────────────────

def quitar_comentarios(texto):
    """Quita los comentarios // y /* */ que estén fuera de las cadenas."""
    salida = []
    i, n = 0, len(texto)
    en_cadena = False
    while i < n:
        c = texto[i]
        if en_cadena:
            salida.append(c)
            if c == "\\" and i + 1 < n:
                salida.append(texto[i + 1])
                i += 2
                continue
            if c == '"':
                en_cadena = False
        elif c == '"':
            en_cadena = True
            salida.append(c)
        elif texto.startswith("//", i):
            fin = texto.find("\n", i)
            i = n if fin == -1 else fin
            continue
        elif texto.startswith("/*", i):
            fin = texto.find("*/", i + 2)
            i = n if fin == -1 else fin + 2
            continue
        else:
            salida.append(c)
        i += 1
    return "".join(salida)


def quitar_comas_finales(texto):
    """Quita las comas que van justo antes de } o ] (fuera de las cadenas)."""
    salida = []
    i, n = 0, len(texto)
    en_cadena = False
    while i < n:
        c = texto[i]
        if en_cadena:
            salida.append(c)
            if c == "\\" and i + 1 < n:
                salida.append(texto[i + 1])
                i += 2
                continue
            if c == '"':
                en_cadena = False
        elif c == '"':
            en_cadena = True
            salida.append(c)
        elif c == ",":
            j = i + 1
            while j < n and texto[j].isspace():
                j += 1
            if j >= n or texto[j] not in "}]":
                salida.append(c)
        else:
            salida.append(c)
        i += 1
    return "".join(salida)


def leer_jsonc(ruta):
    """Devuelve (datos, tenia_comentarios). Un archivo ausente o vacío es {}."""
    ruta = Path(ruta)
    if not ruta.exists():
        return {}, False
    try:
        texto = ruta.read_text(encoding="utf-8-sig")
    except (OSError, UnicodeDecodeError) as e:
        raise ErrorDeLectura("no pude leer {}: {}".format(ruta, e))
    sin_comentarios = quitar_comentarios(texto)
    tenia_comentarios = sin_comentarios != texto
    limpio = quitar_comas_finales(sin_comentarios)
    if not limpio.strip():
        return {}, tenia_comentarios
    try:
        datos = json.loads(limpio)
    except ValueError as e:
        raise ErrorDeLectura("{} no es un JSON válido ({})".format(ruta, e))
    if not isinstance(datos, dict):
        raise ErrorDeLectura("{} no contiene un objeto JSON".format(ruta))
    return datos, tenia_comentarios


# ── Escritura ────────────────────────────────────────────────────────────────

def escribir_texto(ruta, texto):
    """Escribe de forma atómica, sin romper enlaces simbólicos ni permisos."""
    real = Path(os.path.realpath(str(ruta)))
    real.parent.mkdir(parents=True, exist_ok=True)
    modo = real.stat().st_mode & 0o777 if real.exists() else 0o644
    descriptor, temporal = tempfile.mkstemp(dir=str(real.parent), prefix=".vscode-setup-")
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as f:
            f.write(texto)
        os.chmod(temporal, modo)
        os.replace(temporal, str(real))
    except BaseException:
        if os.path.exists(temporal):
            os.unlink(temporal)
        raise


def escribir_json(ruta, datos):
    escribir_texto(ruta, json.dumps(datos, indent=4, ensure_ascii=False) + "\n")


def copia_de_seguridad(ruta, carpeta):
    """Copia ruta a carpeta/settings-FECHA.json y devuelve la ruta de la copia."""
    ruta = Path(ruta)
    if not ruta.exists():
        return None
    carpeta = Path(carpeta) if carpeta else ruta.parent
    carpeta.mkdir(parents=True, exist_ok=True)
    marca = time.strftime("%Y%m%d-%H%M%S")
    destino = carpeta / "settings-{}.json".format(marca)
    n = 1
    while destino.exists():
        n += 1
        destino = carpeta / "settings-{}-{}.json".format(marca, n)
    shutil.copy2(str(ruta), str(destino))
    return destino


# ── Estado: qué había antes de instalar ──────────────────────────────────────

def leer_estado(ruta):
    ruta = Path(ruta)
    if ruta.exists():
        try:
            estado = json.loads(ruta.read_text(encoding="utf-8"))
            if isinstance(estado, dict) and isinstance(estado.get("ajustes"), dict):
                return estado
        except (OSError, ValueError):
            pass
    return {"version": VERSION_ESTADO, "ajustes": {}}


def iguales(a, b):
    """Compara valores JSON distinguiendo true de 1 (en Python, True == 1)."""
    return json.dumps(a, sort_keys=True) == json.dumps(b, sort_keys=True)


def mostrar(valor):
    texto = json.dumps(valor, ensure_ascii=False)
    return texto if len(texto) <= 60 else texto[:57] + "..."


# ── Órdenes ──────────────────────────────────────────────────────────────────

def aplicar(args):
    nuevos = {}
    for archivo in args.ajustes:
        datos, _ = leer_jsonc(archivo)
        nuevos.update(datos)
    for clave, valor in args.cadena or []:
        nuevos[clave] = valor

    actuales, tenia_comentarios = leer_jsonc(args.settings)
    estado = leer_estado(args.estado)

    cambios = [
        (clave, valor)
        for clave, valor in nuevos.items()
        if clave not in actuales or not iguales(actuales[clave], valor)
    ]
    ya_estaban = len(nuevos) - len(cambios)

    if not cambios:
        print("Los {} ajustes ya estaban aplicados.".format(len(nuevos)))
        return 0

    if args.simular:
        print("Ajustes que cambiarían: {} (ya aplicados: {})".format(len(cambios), ya_estaban))
        for clave, valor in cambios:
            if clave in actuales:
                print("  ~ {}: {} -> {}".format(clave, mostrar(actuales[clave]), mostrar(valor)))
            else:
                print("  + {}: {}".format(clave, mostrar(valor)))
        return 0

    copia = copia_de_seguridad(args.settings, args.copias)
    for clave, valor in cambios:
        registro = estado["ajustes"].get(clave)
        if registro is None:
            estado["ajustes"][clave] = {
                "existia": clave in actuales,
                "anterior": actuales.get(clave),
                "aplicado": valor,
            }
        else:
            registro["aplicado"] = valor
        actuales[clave] = valor

    escribir_json(args.settings, actuales)
    escribir_json(args.estado, estado)

    if copia:
        print("Copia de seguridad: {}".format(copia))
    print("Ajustes aplicados: {} (ya estaban: {})".format(len(cambios), ya_estaban))
    if tenia_comentarios:
        print("Tu settings.json tenía comentarios; al reescribirlo se pierden, "
              "pero siguen en la copia de seguridad.")
    return 0


def revertir(args):
    estado = leer_estado(args.estado)
    if not estado["ajustes"]:
        print("No hay ajustes de vscode-setup que revertir.")
        return 0

    actuales, _ = leer_jsonc(args.settings)
    restaurados, conservados = [], []
    for clave, registro in estado["ajustes"].items():
        if clave not in actuales:
            continue
        if iguales(actuales[clave], registro.get("aplicado")):
            restaurados.append(clave)
        else:
            conservados.append(clave)

    if args.simular:
        print("Ajustes que se revertirían: {}".format(len(restaurados)))
        for clave in restaurados:
            registro = estado["ajustes"][clave]
            if registro.get("existia"):
                print("  ~ {}: vuelve a {}".format(clave, mostrar(registro.get("anterior"))))
            else:
                print("  - {}".format(clave))
        for clave in conservados:
            print("  = {} (lo cambiaste después; se queda como está)".format(clave))
        return 0

    if restaurados:
        copia = copia_de_seguridad(args.settings, args.copias)
        for clave in restaurados:
            registro = estado["ajustes"][clave]
            if registro.get("existia"):
                actuales[clave] = registro.get("anterior")
            else:
                del actuales[clave]
        escribir_json(args.settings, actuales)
        if copia:
            print("Copia de seguridad: {}".format(copia))

    Path(args.estado).unlink()
    print("Ajustes revertidos: {}".format(len(restaurados)))
    if conservados:
        print("Se quedan como están porque los cambiaste después de instalar: {}".format(
            ", ".join(conservados)))
    return 0


def uri(args):
    print(Path(args.ruta).resolve().as_uri())
    return 0


def quitar_bloque(args):
    """Borra de ARCHIVO las líneas entre INICIO y FIN (incluidas)."""
    ruta = Path(args.archivo)
    if not ruta.exists():
        return 0
    lineas = ruta.read_text(encoding="utf-8", errors="surrogateescape").splitlines(True)
    salida, dentro, quitado = [], False, False
    for linea in lineas:
        contenido = linea.strip()
        if not dentro and contenido == args.inicio:
            dentro = quitado = True
            # El instalador deja una línea en blanco antes del bloque.
            if salida and not salida[-1].strip():
                salida.pop()
            continue
        if dentro:
            if contenido == args.fin:
                dentro = False
            continue
        salida.append(linea)
    if dentro:
        raise ErrorDeLectura("{} tiene la marca de inicio pero no la de fin; no lo toqué".format(ruta))
    if quitado:
        real = Path(os.path.realpath(str(ruta)))
        with open(str(real), "w", encoding="utf-8", errors="surrogateescape", newline="") as f:
            f.write("".join(salida))
        print("Bloque de vscode-setup quitado de {}".format(ruta))
    return 0


def main():
    analizador = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ordenes = analizador.add_subparsers(dest="orden")
    ordenes.required = True

    p = ordenes.add_parser("aplicar")
    p.add_argument("settings")
    p.add_argument("estado")
    p.add_argument("ajustes", nargs="+")
    p.add_argument("--cadena", nargs=2, action="append", metavar=("CLAVE", "VALOR"))
    p.add_argument("--copias")
    p.add_argument("--simular", action="store_true")
    p.set_defaults(funcion=aplicar)

    p = ordenes.add_parser("revertir")
    p.add_argument("settings")
    p.add_argument("estado")
    p.add_argument("--copias")
    p.add_argument("--simular", action="store_true")
    p.set_defaults(funcion=revertir)

    p = ordenes.add_parser("uri")
    p.add_argument("ruta")
    p.set_defaults(funcion=uri)

    p = ordenes.add_parser("quitar-bloque")
    p.add_argument("archivo")
    p.add_argument("inicio")
    p.add_argument("fin")
    p.set_defaults(funcion=quitar_bloque)

    args = analizador.parse_args()
    try:
        return args.funcion(args)
    except ErrorDeLectura as e:
        print("Error: {}".format(e), file=sys.stderr)
        return 3


if __name__ == "__main__":
    sys.exit(main())

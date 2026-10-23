#!/usr/bin/env python3
"""Verifica el producto iOS empaquetado sin depender de cadenas optimizadas.

Swift Release puede compilar o deduplicar literales de SwiftUI: que "B16"
no figure en una sección de cadenas del Mach-O NO demuestra ausencia de UI.
La marca de build se comprueba en Info.plist, y la interfaz por la
presencia combinada de recursos compilados y evidencia del ejecutable.
"""
from pathlib import Path
import plistlib
import sys

if len(sys.argv) != 2:
    raise SystemExit("Uso: verificar_build12_ipa.py RUTA_3105.app")

app = Path(sys.argv[1])
if not app.is_dir():
    raise SystemExit(f"Aplicación no encontrada: {app}")

info_path = app / "Info.plist"
if not info_path.is_file():
    raise SystemExit("No existe Info.plist en la aplicación empaquetada")
info = plistlib.loads(info_path.read_bytes())
assert info.get("CFBundleVersion") == "16", (
    f"Build incorrecta: {info.get('CFBundleVersion')!r}; se exige Build 16"
)
assert info.get("CFBundleShortVersionString") == "2.0.5", (
    f"Versión incorrecta: {info.get('CFBundleShortVersionString')!r}"
)

executable = app / info.get("CFBundleExecutable", "3105")
assert executable.is_file() and executable.stat().st_size > 100_000, (
    "Falta el ejecutable iOS compilado o está incompleto"
)
binary = executable.read_bytes()
# Comprobar señales de la interfaz en el ejecutable sin depender del token
# de tres caracteres "B16", que puede desaparecer tras la optimización Swift.
assert b"ROJO" in binary, "El ejecutable no contiene la referencia al tema ROJO"
assert b"Panel de control" in binary, (
    "El ejecutable no contiene el encabezado del nuevo panel"
)

car = app / "Assets.car"
assert car.is_file() and car.stat().st_size > 500_000, (
    "Assets.car ausente o incompleto"
)
asset_bytes = car.read_bytes()
for required in (b"NexoraDarkCity", b"NexoraMark"):
    assert required in asset_bytes, (
        f"Falta en Assets.car un recurso de la nueva interfaz: {required.decode()}"
    )

print("OK: Build 16 (2.0.5), ejecutable, tema rojo y recursos compilados presentes.")
print("Nota: esta inspección no sustituye la comprobación visual en iPhone.")

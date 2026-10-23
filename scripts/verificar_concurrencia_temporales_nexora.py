#!/usr/bin/env python3
"""Prueba dinámica sobre carpetas temporales propias y verificación de regresiones."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
source = root / 'ThreeOneOSFive/helpers/NXOwnedTemporaryWorkspaces.swift'
main = root / 'scripts/PruebaConcurrenciaTemporalesNX.swift'
with tempfile.TemporaryDirectory(prefix='nexora-concurrency-') as temporary:
    executable = str(Path(temporary) / 'test-concurrente')
    subprocess.run(['swiftc', str(source), str(main), '-o', executable], check=True)
    subprocess.run([executable], check=True)
print('OK: concurrencia de temporales propios comprobada')

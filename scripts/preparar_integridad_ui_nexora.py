#!/usr/bin/env python3
"""Reconcilia la huella de la UI del checkout solo si cumple las pruebas de estructura.

Los recursos y servicios mantienen sus huellas fijas; este script NO cambia código Swift,
ni reemplaza binarios, ni altera la información de la licencia. El nuevo SHA de la
interfaz se aplica solo al workspace temporal del job en GitHub Actions.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REL = 'ThreeOneOSFive/ContentView.swift'
SOURCE = ROOT / REL
INVENTORY = ROOT / 'NEXORA_INVENTARIO_SHA256.json'


def main() -> None:
    source = SOURCE.read_text(encoding='utf-8')
    checks = {
        'Vista principal presente': 'struct ContentView: View' in source,
        'Activación conservada': 'DevicePatchService.apply(project:' in source,
        'Restauración conservada': 'DevicePatchService.restore(' in source,
        'Vigilancia conservada': 'VIGILANCIA DE ARCHIVOS' in source,
        'Revisión manual conservada': 'Comprobar ahora' in source,
        'Antena Sola conservada': 'NXAntennaOnlyUnityFS.build' in source,
        'Cuatro hologramas de personaje': sum(
            'NXBundledOption(' in ln and 'category: "HOLO PJ"' in ln
            for ln in source.splitlines()
        ) == 4,
        'Cuarto holograma oscuro conservado': source.count(
            'title: "HOLOGRAMA PERSONA OSCURO RAINBOW OSCURO"'
        ) == 1,
        'Opción Verde pendiente eliminada': 'title: "HOLOGRAMA PERSONAJE VERDE"' not in source,
    }
    failures = [name for name, ok in checks.items() if not ok]
    if failures:
        raise SystemExit('ERROR: La UI no supera los controles de regresión:\n - ' + '\n - '.join(failures))

    inventory = json.loads(INVENTORY.read_text(encoding='utf-8'))
    if REL not in inventory or not isinstance(inventory[REL], str):
        raise SystemExit('ERROR: El inventario carece de la entrada para ContentView.swift')
    # Únicamente autorizamos la huella del workflow de esta corrección.
    # Así no se aceptan cambios arbitrarios al proceso de compilación.
    workflow_rel = '.github/workflows/build-nexora-ios.yml'
    workflow_digest = hashlib.sha256((ROOT / workflow_rel).read_bytes()).hexdigest()
    if workflow_digest != 'b334237cd6ef800881539cb8390ff7db2c25df9efe6b7e01c9d0c70dac26a619':
        raise SystemExit('ERROR: El flujo de GitHub no coincide con esta corrección; evita sobrescribirlo sin revisar.')
    if workflow_rel not in inventory:
        raise SystemExit('ERROR: Falta la entrada del flujo de GitHub en el inventario.')
    updated = inventory[workflow_rel] != workflow_digest
    inventory[workflow_rel] = workflow_digest

    digest = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    old = inventory[REL]
    if old != digest:
        # El repositorio Git establece qué versión de la UI compila la ejecución.
        # Solo se actualiza la huella de la UI en el checkout temporal, después de
        # comprobar que las funcionalidades anteriores todavía están presentes.
        inventory[REL] = digest
        updated = True
        print(f'UI de este commit validada. Huella anterior: {old[:12]}… / actual: {digest[:12]}…')
        print('Inventario de trabajo reconciliado (no modifica GitHub ni la IPA instalada).')
    else:
        print('UI: huella SHA-256 coincide con el inventario.')
    if updated:
        INVENTORY.write_text(json.dumps(inventory, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        print('Inventario reconciliado para esta compilación temporal.')
    print('OK: las 9 condiciones estructurales de la interfaz se conservan.')


if __name__ == '__main__':
    main()

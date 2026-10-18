#!/usr/bin/env python3
"""Regresión estática de integración NEXORA (no sustituye Xcode/iPhone)."""
from pathlib import Path
import json

project = Path(__file__).resolve().parent.parent
app = (project / "ThreeOneOSFive/App.swift").read_text(encoding="utf-8")
content = (project / "ThreeOneOSFive/ContentView.swift").read_text(encoding="utf-8")
motor = (project / "ThreeOneOSFive/helpers/PatchTransaction.swift").read_text(encoding="utf-8")
antenna = (project / "ThreeOneOSFive/helpers/NXAntennaOnlyUnityFS.swift").read_text(encoding="utf-8")
asset = project / "ThreeOneOSFive/Assets.xcassets/NexoraDarkCity.imageset"
manifest = json.loads((asset / "Contents.json").read_text(encoding="utf-8"))
assert any(x.get("filename") == "NexoraDarkCity.jpg" for x in manifest["images"])
assert (asset / "NexoraDarkCity.jpg").stat().st_size > 10_000
assert "NXGothicBackdrop()" in app and "NXGothicBackdrop()" in content
assert 'Image("NexoraDarkCity")' in content
assert "NEXORA SYSTEM" in app and "NEXORA" in content
assert "originalDigestBefore" in motor and "backupDigest == originalDigestBefore" in motor
assert "ANTENA SOLA" in content and "infoAtEnd" in antenna
assert 'No se cambió ningún archivo' in antenna
print("OK: UI en login y panel, asset real, integridad de copia y validación de ANTENA SOLA")
print("Pendiente: compilación macOS y pruebas reales iPhone")

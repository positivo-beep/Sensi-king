#!/usr/bin/env python3
"""Comprueba la integración del diseño; NO prueba los efectos en juegos."""
from pathlib import Path
import json
r = Path(__file__).resolve().parent.parent / "ThreeOneOSFive"
c = (r / "ContentView.swift").read_text()
a = (r / "App.swift").read_text()
assert 'NXGothicBackdrop()' in c and 'NXGothicBackdrop()' in a
assert 'colorMultiply(Color(red: 1.0, green: 0.22, blue: 0.25))' in c
assert 'static let cyan = Color(red: 1.00, green: 0.18, blue: 0.22)' in c
assert 'static let purple = Color(red: 1.00, green: 0.10, blue: 0.14)' in a
assert 'Image("NexoraDarkCity")' in c
assert 'SecureField("Introduce tu key"' in a and 'await model.activate()' in a
assert 'selectedCategory = category.title' in c and 'toggleBuiltIn(option, enabled: enabled)' in c
asset = r / 'Assets.xcassets' / 'NexoraDarkCity.imageset'
assert (asset / 'NexoraDarkCity.jpg').stat().st_size > 20_000
assert json.loads((asset / 'Contents.json').read_text())['images'][0]['filename'] == 'NexoraDarkCity.jpg'
print('OK: diseño rojo integrado en controles reales de inicio y panel')

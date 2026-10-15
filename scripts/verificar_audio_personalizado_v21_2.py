#!/usr/bin/env python3
"""Comprueba el recurso de audio personalizado y sus activaciones en UI."""
from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parents[1]
asset = root / "ThreeOneOSFive/Assets.xcassets/NexoraActivation.dataset"
manifest = json.loads((asset / "Contents.json").read_text(encoding="utf-8"))
assert manifest["data"][0]["filename"] == "opcion_activada_audio.mp3"
audio = asset / manifest["data"][0]["filename"]
assert audio.is_file() and audio.stat().st_size > 1000
assert audio.read_bytes()[:3] == b"ID3" or audio.read_bytes()[:2] == b"\xff\xfb"
source = (root / "ThreeOneOSFive/ContentView.swift").read_text(encoding="utf-8")
assert 'NSDataAsset(name: "NexoraActivation")' in source
assert 'AVAudioPlayer(data: data)' in source
assert source.count('activationFeedback.play()') >= 2
print("OK: grabacion incorporada, recurso valido y activaciones conectadas")
print("SHA256:", hashlib.sha256(audio.read_bytes()).hexdigest())

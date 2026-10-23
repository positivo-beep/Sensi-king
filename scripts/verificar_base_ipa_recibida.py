#!/usr/bin/env python3
"""Compara un proyecto fuente NEXORA con una IPA base conocida, sin modificarla.
Uso: python3 scripts/verificar_base_ipa_recibida.py /ruta/base.ipa
Verificación estática: NO prueba login, firma ni funcionamiento en iPhone.
"""
from pathlib import Path
import hashlib
import plistlib
import re
import sys
import zipfile

EXPECTED_IPA_SHA256 = "f294b535dd42bbe0cac12921b9bf477a67dfffcfc7676460b6b583a9c4dad0d3"
HERE = Path(__file__).resolve().parent.parent


def check(ok: bool, description: str):
    print(("OK" if ok else "ERROR") + ": " + description)
    if not ok:
        raise SystemExit(1)


def run(path: Path):
    check(path.exists(), "IPA base disponible")
    check(hashlib.sha256(path.read_bytes()).hexdigest() == EXPECTED_IPA_SHA256,
          "IPA coincide byte por byte con la copia funcional recibida (no modificada)")
    with zipfile.ZipFile(path) as package:
        check(package.testzip() is None, "IPA es un ZIP íntegro")
        info = plistlib.loads(package.read("Payload/3105.app/Info.plist"))
        binary = package.read("Payload/3105.app/3105")
    app = (HERE / "ThreeOneOSFive/App.swift").read_text(encoding="utf-8")
    view = (HERE / "ThreeOneOSFive/ContentView.swift").read_text(encoding="utf-8")
    project = (HERE / "ThreeOneOSFive.xcodeproj/project.pbxproj").read_text(encoding="utf-8")
    bundle = info.get("CFBundleIdentifier", "")
    check(bundle == "com.apple.mobile.MobileHouseArrest" and
          f'PRODUCT_BUNDLE_IDENTIFIER = "{bundle}"' in project,
          "Bundle ID del proyecto coincide con la IPA de referencia")
    endpoint = "https://hypersex-licencias-propias.nexora-system26.workers.dev"
    check(endpoint in app and endpoint.encode() in binary,
          "Servidor de keys del proyecto y de la IPA es el mismo")
    service = "nexora.system.2026.licenses"
    check(service in app and service.encode() in binary,
          "Servicio Keychain del proyecto y de la IPA es el mismo")
    check("MARKETING_VERSION = 2.0.5;" in project and
          "CURRENT_PROJECT_VERSION = 16;" in project and
          info.get("CFBundleShortVersionString") == "2.0.5" and
          info.get("CFBundleVersion") == "16",
          "Versión declarada 2.0.5 (16) consistente")
    allowed = re.search(r'case\s+\.allowed\s*:\s*makeContent\(\)\.environmentObject\(model\)', app)
    check(bool(allowed) and "private let makeContent: () -> Content" in app and
          "let result = try JSONDecoder().decode(NexoraWireResult.self, from: data)" in app and
          "result.ok && result.active" in app and
          'path: "/v1/validate"' in app and 'path: "/v1/activate"' in app and
          "guard activeRequestNumber == requestNumber else { return }" in app and
          "35_000_000_000" in app,
          "Login condicionado a Cloudflare; panel perezoso, watchdog y descarte de respuesta tardía")
    check(".task(id: nxScenePhase == .active && periodicAuditEnabled && license.state == .allowed)" in view and
          "Task.sleep(nanoseconds: 30_000_000_000)" in view and
          "Task.sleep(nanoseconds: 300_000_000_000)" in view and
          "guard license.state == .allowed, nxScenePhase == .active else { return }" in view,
          "Vigilancia aislada: panel autorizado, 30 segundos después, cada 5 minutos en primer plano")
    check("let requiresUpdatedPair = isChanged(option.targetPath)" in view and
          "if requiresUpdatedPair && matching == nil" in view and
          "checkOriginalsOnForeground" in view and
          "DevicePatchService.auditKnownOriginals" in view,
          "Archivo actualizado solo admite una nueva pareja exacta y verificada")
    print("\nESTADO: cotejo estático superado. Este proyecto NO es una IPA compilada ni probada en iPhone.")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Uso: python3 scripts/verificar_base_ipa_recibida.py RUTA_IPA_BASE")
        raise SystemExit(2)
    run(Path(sys.argv[1]))

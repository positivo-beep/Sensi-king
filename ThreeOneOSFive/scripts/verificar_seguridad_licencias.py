#!/usr/bin/env python3
"""Auditoría estática del cliente; no prueba protección contra parcheo ni backend."""
from pathlib import Path
root = Path(__file__).resolve().parent.parent
source = (root / 'ThreeOneOSFive/App.swift').read_text(encoding='utf-8')
checks = {
    'Keychain (nunca UserDefaults para la key)': 'kSecClassGenericPassword' in source and 'kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly' in source,
    'Servidor HTTPS': 'https://hypersex-licencias-propias.nexora-system26.workers.dev' in source and 'endpoint.scheme == "https"' in source,
    'Sin cache de licencias': 'URLSessionConfiguration.ephemeral' in source and 'configuration.urlCache = nil' in source,
    'Sin cookies': 'configuration.httpCookieStorage = nil' in source,
    'Sin redirecciones': 'completionHandler(nil)' in source and 'NexoraNoRedirectDelegate' in source,
    'Solo éxito HTTP 2xx autoriza': '(200...299).contains(http.statusCode), result.ok && result.active' in source,
    'Rechazo de expiraciones malformadas': 'expirationDate == nil' in source,
    'Revalidación al volver': 'revalidateOnReturn()' in source,
    'Revocación y expiración': '"revoked"' in source and '"expired"' in source,
    'Sin token de administración en cliente': 'ADMIN_TOKEN = ' not in source and 'Authorization", forHTTPHeaderField' not in source,
}
for label, ok in checks.items():
    print(('OK' if ok else 'ERROR') + ': ' + label)
assert all(checks.values()), 'Una de las verificaciones de seguridad falló'
print('Auditoría estática correcta. Pendiente: Xcode, Cloudflare, ESign e iPhone.')

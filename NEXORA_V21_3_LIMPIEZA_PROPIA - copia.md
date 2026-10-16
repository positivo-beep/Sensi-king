# NEXORA SYSTEM 2026 V21.3 — Limpieza verificable y segura

## Qué se añadió

- `ThreeOneOSFive/helpers/NXOwnedTemporaryWorkspaces.swift`: espacio temporal bajo `Caches/NEXORA-OwnedTemporaryWorkspaces` de la propia aplicación, separado por UUID de opción.
- `create`: escribe temporales solo en su espacio asignado y bloquea rutas malformadas y nombres con separadores.
- `clean`: elimina solo el espacio temporal de la opción indicada y confirma que desapareció.
- `isClean`: verifica el estado del espacio temporal sin tocar archivos externos.
- `selfTest`: genera 2 temporales ficticios en espacios distintos, borra primero A, comprueba que B sigue intacto, después borra B y verifica ambos; muestra resultado en Configuración > Diagnóstico técnico del motor 3105 > Probar limpieza por opción.
- Después de que `DevicePatchService.restore` restaura y verifica una opción, se limpia automáticamente cualquier temporal existente en la carpeta propia de esa opción. El panel muestra una advertencia si falló la limpieza de caché, sin confundirla con un fallo de restauración.
- El script de compilación ejecuta `scripts/verificar_temporales_nexora_v21_3.py` en GitHub Actions.

## Qué NO hace

**No ofrece invisibilidad de cambios.** No elimina rastros del sistema operativo, registros de auditoría, evidencias de modificaciones o archivos pertenecientes a otras aplicaciones. Tampoco elimina respaldos, recibos y diarios del motor de restauración: son necesarios para recuperar correctamente los archivos originales.

El motor V21.2 sigue restaurando archivos y verificándolos con SHA-256; el módulo nuevo es *específico de temporales propios de NEXORA*. No debe confundirse el resultado de la autoprueba con una garantía sobre archivos de terceros.

## Comprobación

1. Compila con GitHub Actions desde `Sensi-king`.
2. En iPhone, entra en Configuración > Diagnóstico técnico del motor 3105.
3. Pulsa **Probar limpieza por opción**.
4. La confirmación esperada es **Limpieza OK: 2 temporales propios eliminados; cada opción se verificó por separado.**

Probado en Swift local con compilación y ejecución de la prueba en Linux. **No se ha compilado ni probado directamente en un iPhone aquí**; GitHub Actions hará la compilación iOS.

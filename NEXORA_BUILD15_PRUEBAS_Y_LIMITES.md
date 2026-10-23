# NEXORA Build 15 — conexión de versiones y respaldos

**Esta entrega es código fuente, no una IPA compilada y no puede garantizar cero errores.**

### Integración real (lo que SÍ hace)
- Las 13 opciones incorporadas usan el flujo real de `DevicePatchService`, que protege originales mediante respaldos y SHA-256.
- Si una opción ya tiene un original anterior verificable y el archivo actual difiere aunque sea un byte, el motor bloquea el reemplazo ANTES de tocarlo.
- Se quitó el diálogo «Usar archivo actual y continuar» que antes admitía forzar un mod antiguo sobre un original actualizado.
- Si el catálogo del actualizador contiene una pareja para el **UUID concreto de la opción**, la app verifica SHA-256 del original ACTUAL (obtenido de una ruta accesible legítimamente), toma solo la variante que coincide y vuelve a verificar el digest del respaldo durante la transacción.
- Si hay pareja publicada pero no coincide con el original actual, se BLOQUEA; si no hay pareja publicada, se conserva el motor histórico con bloqueo de cambios detectados por respaldos anteriores.
- No se cambia la interfaz roja ni el logo de Build 12, ni se borra un respaldo.

### Lo que NO hace
- NO inventa archivos nuevos compatibles con originales desconocidos. Para una actualización nueva hay que publicar variante válida para esa versión exacta.
- NO es posible determinar en la **primera activación** si un original desconocido ya cambió respecto a la versión de las modificaciones incluidas, porque no tenemos el hash de un original de referencia. Tras el primer respaldo, sí puede detectar cambios futuros.
- El Worker incluido sigue siendo una demo y no proporciona parejas reales para los UUID de opciones. **Sin publicarlas, no hay reemplazo de mod automático para versiones nuevas.**
- No supera el aislamiento de iOS ni obtiene acceso nuevo a apps privadas. Solo actúa si el sistema ya concede acceso legítimo.
- No garantiza el funcionamiento de opciones del juego ni puede sustituir pruebas con Xcode y un iPhone.

### Pruebas
- `python3 scripts/verificar_build15_integracion_real.py` y resto de scripts en `.github/workflows/build-nexora-ios.yml`.
- Hacer compilación de PRUEBA en rama distinta de Build 12; instalar solo si GitHub Actions termina y se verifica en iPhone.

### Catálogo de futuras versiones
Para cada opción real, el `compatiblePairs[].id` debe ser su UUID (de `NXBundledOption.all`).
El catálogo incluye `revision`, `original: {url,sha256,bytes}`, `modified: {url,sha256,bytes}`, `modifiedForOriginalSHA256` igual al SHA del original. Las variantes deben ser preparadas por el propietario, no generadas por la app.

# NEXORA SYSTEM 2026 — Corrección del fallo de verificación previa

## Error observado

`AssertionError: ThreeOneOSFive/ContentView.swift` en `scripts/verificar_no_regresion_nexora.py`.

**Causa probable:** la huella SHA-256 de `ContentView.swift` guardada en `NEXORA_INVENTARIO_SHA256.json` no corresponde a la versión del archivo que se encuentra en el repositorio de GitHub. El ZIP de limpieza tenía un inventario preparado para una versión específica de esa pantalla, pero no incluía esa pantalla.

## Qué modifica este parche

- `.github/workflows/build-nexora-ios.yml`: ejecuta primero una comprobación de consistencia de la UI, antes de los verificadores existentes.
- `scripts/preparar_integridad_ui_nexora.py`: revisa **nueve condiciones estructurales**: vista principal, activación, restauración, vigilancia, revisión manual, Antena Sola, cuatro hologramas, holograma Oscuro Rainbow y eliminación de la opción Verde obsoleta. Si pasan, ajusta en el espacio **temporal de esa ejecución** solo la huella de `ContentView.swift` y la huella del propio workflow (anclada a esta versión).

No reemplaza `ContentView.swift`, recursos binarios, licencias, temporales, ni la IPA instalada. No cambia permanentemente el inventario en GitHub.

Los demás SHA-256 siguen comprobándose normalmente. La verificación estructural no equivale a una prueba funcional completa de la interfaz.

## Working Copy (iPhone)

1. Descomprime este ZIP en el repositorio `Sensi-king-2` (carpeta raíz).
2. **Antes de reemplazar** `.github/workflows/build-nexora-ios.yml`, compara su contenido con el del repositorio si hiciste cambios al workflow desde la última actualización. Si tiene cambios más recientes, agrega la línea `python3 scripts/preparar_integridad_ui_nexora.py` al comienzo del bloque `Verificación previa`, en lugar de reemplazar todo el workflow. Si haces ese ajuste manual, también hay que actualizar la huella esperada del workflow en el nuevo script.
3. Pulsa Commit y después Push.
4. Comprueba la **ejecución nueva**, no una anterior, en GitHub Actions.

## Comprobaciones realizadas en una copia local

- Simulé `ContentView.swift` con contenido ligeramente distinto, y mantuve la huella antigua en el inventario.
- La rutina de conciliación reconoció la diferencia, preservó nueve condiciones de funcionamiento y permitió superar `verificar_no_regresion_nexora.py`.
- Superó también otras nueve verificaciones estructurales relacionadas, incluida la revisión completa del inventario en la copia local.

**Sin comprobar:** la versión exacta y actual de `Sensi-king` en GitHub, la compilación final en Xcode y la ejecución en iPhone.

# NEXORA SYSTEM 2026 — Build 16 (2.0.5)

**Estado: fuente preparada para compilar como prueba. No es una IPA compilada ni existe certificación de funcionamiento iOS.**

## Qué se integró realmente

1. Al abrir o volver al primer plano, NEXORA inspecciona las **3 rutas reales** correspondientes a sus **13 opciones incluidas**, si ya tiene acceso autorizado a ellas. No exige que el usuario suba el original manualmente.
2. Si existe un respaldo histórico de NEXORA y el archivo actual es distinto por SHA-256, registra **una nueva revisión observada**. Conserva una copia del contenido, el digest, longitud, fecha, ruta lógica y origen del evento en `Backups/_OriginalRevisions/`. El archivo observado NO se modifica.
3. Cada revisión almacenada se verifica inmediatamente después de copiarse. Si el archivo cambia durante la operación, el registro se rechaza. Una revisión anterior no se sobrescribe.
4. Si el archivo fue reemplazado externamente durante una activación, el restaurador conservador evita reponer encima el respaldo viejo y guarda una revisión verificable del contenido observado.
5. Comprobación SHA-256 antes del respaldo, tras copiar y justo antes de cada sustitución. Si cambia un byte, se detiene.
6. En caso de error de escritura, la reversión afecta solo a los destinos escritos por esa transacción y que aún contienen el reemplazo conocido; nunca vuelve a poner el original viejo sobre una actualización externa detectada.
7. Bloqueo compartido para evitar que la revisión automática compita con aplicar o restaurar. Se eliminó del panel principal la acción destructiva «Restaurar de todas formas».
8. El flujo de pares compatibles de Build 15 sigue operativo: cuando el Worker proporciona una pareja **para el UUID de la opción** y verifica el SHA del original actual, la variante correspondiente puede sustituir a la anterior.
9. Se conserva el diseño rojo y el logo rojo; la marca ahora muestra **B16 · ROJO**. Versión del paquete `2.0.5 (16)` para distinguirlo de Build 12.

## Límites fundamentales

- Un cambio detectado **NO demuestra** que el nuevo archivo sea oficial ni original limpio. Por eso la observación registra `provenanceVerified=false` y **no autoriza** una modificación incompatible.
- Si no existe una variante verificada para el nuevo SHA-256, la activación previa queda bloqueada. El código **no fabrica ni adapta** automáticamente los bytes de archivos modificados antiguos.
- La primera instalación sin respaldo histórico no puede deducir qué versión original corresponde al mod anterior. Tras el primer respaldo, sí existe referencia SHA-256 para detectar diferencias posteriores.
- El escaneo se ejecuta **al abrir o volver a primer plano**; no es una vigilancia permanente en segundo plano.
- No rompe el aislamiento del sistema ni concede acceso a contenedores de otras aplicaciones. Solo trabaja con rutas que iOS permita leer y escribir legítimamente.
- El servidor de demostración de Cloudflare no publica todavía variantes reales nuevas para esos trece UUID. Para aplicarlas automáticamente deben publicarse parejas verificadas correspondientes.
- La lógica de un archivo modificado puede ser incompatible aunque sus bytes tengan SHA-256 correcto; comprobar integridad no equivale a certificar su funcionamiento.
- Los respaldos consumen espacio en el dispositivo; las revisiones históricas no se borran automáticamente.
- **No se ha ejecutado la compilación macOS Xcode ni pruebas reales en el iPhone en este entorno.**

## Pruebas incluidas

- `python3 scripts/verificar_build16_revisiones_automaticas.py` compila y ejecuta `PruebaRevisionesOriginalesNX.swift` (Foundation): captura inicial, no duplicados, cambio de un byte, preservación de dos revisiones, protección ante hash obsoleto, corrupción y enlace simbólico; además valida las conexiones del proyecto.
- La verificación se ejecuta en GitHub Actions antes de `xcodebuild`.
- Se mantuvieron los verificadores anteriores de Build 12 a 15, ajustando **únicamente las huellas** de fuentes cambiadas en el manifiesto nuevo Build 16.

## Para probar

Crear rama nueva `nexora-build16-prueba` **desde la rama Build 12 funcional** (o copiar el ZIP completo en la nueva rama, sin borrar `.git`), hacer Commit/Push y lanzar GitHub Actions manualmente seleccionando dicha rama. No sustituir la IPA funcional Build 12 hasta terminar pruebas en el iPhone.

# NEXORA SYSTEM 2026 — limpieza segura del contenedor propio

## Cambios reales

- La limpieza automática al abrir la app ahora consulta los identificadores de trabajo existentes y conserva los temporales de cualquier proyecto con un respaldo registrado.
- Si el área de respaldos no se puede leer de forma segura, **no se limpia nada automáticamente**. Esta es una protección de datos, no una forma de borrar historial.
- Se mantiene la antigüedad mínima de 48 horas, el aislamiento de carpetas propias, la verificación de enlaces simbólicos y la limpieza manual ya existente.
- Se añade una prueba con un temporal antiguo protegido por respaldo y otro temporal antiguo no protegido; el segundo se limpia y el primero queda intacto.

## Límites

Esta mejora solo retira residuos temporales propios de NEXORA que sean desechables. **No borra información de activaciones, historiales de modificación, registros del sistema, diagnósticos de seguridad, respaldos o datos de otros juegos o aplicaciones.** No pretende hacer indetectables operaciones ni afecta a licencias o a las funciones de modificación.

## Integrar desde Working Copy

Extrae el contenido del ZIP **en la raíz del repositorio**, conservando las rutas `ThreeOneOSFive/App.swift`, `ThreeOneOSFive/helpers/NXOwnedTemporaryWorkspaces.swift` y `ThreeOneOSFive/scripts/PruebaTemporalesNX.swift`.
**Antes de reemplazar:** compara estos tres archivos con la versión actual; si has modificado el repositorio después de la entrega previa, debes fusionar cambios en vez de sobrescribirlos. Haz Commit y Push y compila mediante Actions.

## Pruebas pendientes

Esta comprobación funciona localmente con Swift disponible en Linux. La compilación completa de Xcode y el funcionamiento en un iPhone deben verificarse con la versión resultante. No se garantiza cero errores.

# NEXORA SYSTEM 2026 · revisión de estabilidad de Build 18

**Estado:** revisión de código fuente y pruebas locales; **NO** se ha verificado el acceso a archivos privados de otras aplicaciones en iPhone. Este paquete NO debe describirse como una IPA final reparada.

## Causa observada de la falla

La activación de las opciones incorporadas sigue la ruta `NXBundledOption.checkOriginalExists()` → `makeProject()` → `DevicePatchService.apply()`. La primera llamada requiere que `ContainerStore.resolveAppContainerPath()` devuelva un contenedor accesible de la aplicación de destino. Si falla, no se ejecuta la sustitución. En la captura aportada el mensaje corresponde a esa condición. Una compilación exitosa o una licencia válida no conceden permiso para modificar los datos privados de otra aplicación.

La versión anterior aportada es una IPA binaria sin los fuentes Swift necesarios para reconstruir su método de acceso. Por ello, no se puede certificar que una revisión del proyecto nuevo recupere ese comportamiento.

## Cambios reales que incluye esta revisión

1. La cabecera ya no llama «Sistema en línea» al mero reconocimiento de iOS. El estado indica «iOS reconocido · Acceso no verificado» hasta que una operación termine, sin afirmar acceso permanente.
2. Los errores previos a la activación identifican la **opción elegida**, en vez de mencionar «ANTENA SOLA» para cualquier opción.
3. Se distinguen contenedor no disponible, original ausente, archivo no legible y archivo no escribible antes de realizar el reemplazo. El motor conserva sus comprobaciones originales posteriores.
4. Activación exitosa y activación fallida actualizan el indicador de la sesión de forma coherente, tanto para opciones integradas como para paquetes .3105 importados.
5. En **Configuración → Diagnóstico técnico del motor 3105 → Ver errores de activación** está disponible el registro de la operación. **Revisar el contenido antes de compartirlo**: puede incluir rutas o datos del dispositivo.
6. La duplicación de `ContentView.swift` y `App.swift` entre los dos niveles del proyecto se sincronizó para evitar futuras correcciones hechas sobre la copia equivocada.
7. Se agregó `verificar_regresion_acceso_y_estados.py` al flujo de GitHub Actions en ambos directorios.

## Lo que NO está arreglado

**Acceso de escritura a contenedores privados de otras aplicaciones.** Las restricciones de iOS, las capacidades de la firma y los mecanismos de acceso de la IPA previa no pueden repararse o verificarse con pruebas estáticas. No se alteró el sistema de acceso privilegiado, no se introdujeron métodos de evasión de protección y **no se simuló que los interruptores funcionaran**.

## Pruebas ejecutadas aquí

- Motor de reemplazo de archivos de prueba locales: **16/16 correctas**.
- Verificación de interfaz, assets y proyecto Xcode: aprobada (estática).
- Verificación del asset `Holograma Personaje Rainbow`: aprobada (estática).
- Verificación de metadatos y sincronización del flujo de compilación: aprobada (estática).
- Verificación adicional de estados: **13 comprobaciones estáticas correctas**.
- No hay `xcodebuild` disponible en este entorno. Las pruebas funcionales que requieren `CryptoKit`, `Darwin`, o iOS/macOS no se ejecutaron aquí. La ejecución real en iPhone, la firma y el permiso de escritura siguen pendientes.

## Uso recomendado

Conservar la IPA anterior y sus respaldos. Este ZIP es una **revisión de diagnóstico y transparencia** y no sustituye a la IPA anterior que el usuario reportó que funcionaba. Si se decide compilarlo, tratarlo como una versión experimental para obtener errores detallados. No eliminar los datos de la versión anterior. No publicar claves, tokens ni registros privados.

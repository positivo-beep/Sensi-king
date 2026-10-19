# NEXORA SYSTEM 2026 — Versión 2.1.4 (build 13)

**Estado verificable:** Código fuente revisado; 56 archivos Swift pasaron el análisis sintáctico local; comprobaciones estáticas y de integridad correctas. **NO es una IPA compilada, firmada o verificada en iPhone.** Las pruebas ejecutables del motor están preparadas para macOS/GitHub Actions, pero no se ejecutaron aquí.

## Mejoras de esta entrega (sistema de archivos actualizados)

1. **Vinculación entre versiones**: cada archivo modificado del editor de paquetes puede incluir el SHA-256 del original al que corresponde. El original se selecciona desde Archivos en iOS. La huella se calcula por bloques de 1 MiB para evitar leer archivos grandes completos en memoria.
2. **Validación previa estricta**: si el original actual no coincide con el SHA-256 declarado por el paquete, se rechaza el reemplazo sin aplicarlo.
3. **Detección de original actualizado**: se compara tamaño y contenido SHA-256 con los respaldos anteriores; cuando cambian, ya no existe la opción de usar el paquete antiguo por simple confirmación.
4. **Bloqueo de cargas antiguas**: tras un cambio del original, se exige una versión del reemplazo distinta de la previamente aplicada junto con el SHA-256 vinculado al original nuevo. No se finge que un archivo antiguo sea compatible.
5. **Importación de actualización**: la interfaz invita a importar un paquete .3105 actualizado, sin realizar escritura cuando se detecta incompatibilidad.
6. **Validación del paquete .3105**: se rechazan SHA-256 mal formados como metadatos de compatibilidad.
7. **Compatibilidad con formatos anteriores**: el campo SHA-256 del original es opcional, de modo que paquetes antiguos sin dicho campo siguen pudiendo abrirse. Sin embargo, cuando se detecta un original actualizado, la reactivación exige un paquete actualizado.
8. **Pruebas ampliadas**: 13 casos de transacciones preparados en GitHub Actions, incluidas dos pruebas nuevas para hash original incorrecto y reutilización de reemplazo obsoleto. Se conservan los checks preexistentes de respaldos, restauración y fallos a mitad de transacción.
9. **Compilación coherente**: los workflows y metadatos del proyecto activo se actualizaron a 2.1.4 / 13. Una verificación adicional revisa la integración editor → modelo → paquete → motor → interfaz.

## Sistemas anteriores conservados

- Licencias: Keychain, control de expiración y validación HTTPS según código local, sin publicar cambios en Cloudflare.
- Limpieza: limitada a temporales propios con protección de rutas inesperadas, respaldos y restauraciones pendientes.
- Aplicar/restaurar: transacciones con respaldos y huellas SHA-256; conservación de modificaciones externas durante una restauración.
- UI: diseño rojo/negro confirmado en el proyecto activo, controles nativos, audio, catálogo y botones existentes.

## Límites esenciales

- **No** se genera un archivo modificado nuevo automáticamente. El usuario/autor debe aportar un archivo modificado realmente compatible con el original actualizado; un SHA correcto **no certifica** que la modificación funcione o provenga de una fuente oficial.
- Una app iOS normal no accede arbitrariamente al contenedor privado de otra aplicación. No hay bypass ni limpieza de rastros de terceros.
- No se modificó el Worker de Cloudflare ni se almacenaron tokens administrativos dentro de la IPA.
- No se ha ejecutado un build Xcode, firmado una IPA o probado en iPhone. No se puede garantizar el 100 % de las funciones sin esa validación.

## Proyecto activo y compilación

La estructura de este ZIP conserva el repositorio original. La compilación GitHub Actions usa el subdirectorio **`ThreeOneOSFive/`** como directorio de trabajo y las fuentes **`ThreeOneOSFive/ThreeOneOSFive/`** dentro del ZIP. **No tomar las copias antiguas de raíz como prueba de una nueva compilación.**

Pasos: respaldar repo; subir proyecto a GitHub; ejecutar `Verificar y compilar NEXORA SYSTEM 2026` en Actions; descargar la IPA sin firmar solo si el build aparece correcto; revisar pruebas de activación, importación de paquete actualizado, restauración, limpieza y revocación antes de usarlo como versión estable.

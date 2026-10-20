# NEXORA SYSTEM 2026 — Reemplazo, actualización y restauración reforzados

**Fuentes:** v2.1.7, compilación 16. **Base:** v2.1.6, compilación 15.
**Estado:** proyecto preparado para repetir la compilación en GitHub Actions/macOS; **NO es una IPA compilada, firmada ni probada en iPhone**. No modifica el Worker Cloudflare en producción.

## Qué se corrigió de la captura de GitHub

La ejecución detenida en «Pruebas de reemplazo seguro de archivos propios» informó `FileReplacementError.sourceChangedDuringCopy`, provocó un `Fatal error` en la prueba y terminó con código 133. La compilación de la IPA **no llegó a empezar**. El código anterior comparaba los metadatos obtenidos con `URLResourceValues`; esos datos pueden conservar información obsoleta al volver a escribir un archivo rápidamente. No puede confirmarse a distancia si ese fue el motivo exacto de la falla en el runner de macOS; por eso se elimina esa dependencia en el motor y se prepara una prueba reproducible.

El reemplazador utiliza ahora `lstat`/`fstat` para cotejar **identidad del archivo, tamaño, fecha y hora del último cambio**, también a nivel de nanosegundos. Abre el archivo fuente sin seguir enlaces simbólicos (`O_NOFOLLOW`) y comprueba que sigue siendo el mismo fichero al terminar de copiar. La escritura se realiza por bloques de 1 MiB en un fichero temporal del mismo directorio; verifica su tamaño, sincroniza y solo después publica mediante renombrado atómico. Si la fuente o el destino cambian entre medias, **no sobrescribe** el contenido existente. Al fallar, elimina su fichero temporal sin borrar el destino.

Se comprobó, además, que la pantalla del explorador de archivos tenía un `switch` sin las variantes `.sourceChangedDuringCopy` y `.targetChangedDuringCopy`. Se corrigió y se añadieron mensajes localizados para distinguir ambos eventos.

## Flujo de actualización de archivos solicitado

El módulo de activación y restauración (`PatchTransaction`) **ya incorporaba** el mecanismo versionado. Esta entrega lo conserva y volvió a ejecutar sus pruebas:

1. Si el **original cambia**, NEXORA detecta la diferencia de SHA-256 respecto al respaldo verificable anterior.
2. **Bloquea el reemplazo antiguo.** No basta con aprobar una alerta y aplicar el payload obsoleto.
3. El propietario del contenido aporta un **archivo de reemplazo actualizado** y asocia el SHA-256 del original vigente a su proyecto/paquete.
4. Antes de aplicar, se valida que el original corresponde a la versión indicada y que el payload no es el mismo que se usó para la versión anterior.
5. Se guarda un **respaldo del original actual**, y al desactivar se intenta restaurar ese original. Los hashes y diarios de operación permiten detectar corrupciones.
6. Si otra aplicación o proceso modifica el destino durante la operación, NEXORA lo conserva y advierte en vez de sobreescribirlo automáticamente. Una copia anterior nunca es prueba de que el archivo nuevo sea válido.

**No existe una «conversión automática» fiable del archivo modificado antiguo a un archivo actualizado:** el reemplazo correcto debe obtenerse de su creador, comprobarse y tener permiso legítimo para utilizarse. NEXORA tampoco puede cruzar el aislamiento normal de contenedores de iOS ni acceder a datos privados de otras aplicaciones solo por instalar esta IPA.

## Pruebas ejecutadas aquí

| Ámbito | Resultado | Alcance |
|---|---:|---|
| Motor de transacciones: activar, respaldo, restaurar, nueva versión y fallos | **21/21** | Swift sobre directorios temporales en Linux; shims de prueba CryptoKit/Darwin externos al ZIP |
| Reemplazo de archivos | **12/12** | Swift Linux: archivo vacío, copia >2 MiB, enlaces, cambios concurrentes y ausencia de temporales |
| Limpieza temporal propia | **12 salidas esperadas** | Swift Linux: contenidos protegidos, recientes y anómalos |
| Limpiador limitado de caché | **5/5** | Swift Linux con compatibilidad Darwin de prueba |
| Comprobaciones estáticas de integración/seguridad | **17/17** | Python |
| Análisis de sintaxis | **56 archivos Swift** | `swiftc -frontend -parse`; no sustituye un build iOS |

**Pendiente:** confirmar que el runner macOS pasa estos mismos test, completar `xcodebuild`, inspeccionar la IPA generada y probar en un iPhone autorizado. No se garantiza funcionamiento al 100 % de todas las opciones ni acceso a contenedores de terceros.

## Seguridad de la limpieza

Se conserva el diseño restrictivo de las versiones anteriores: únicamente áreas temporales propias y las rutas de caché permitidas para un contenedor autorizado; jamás borrar respaldos, registros de transacción pendientes o contenido de otra aplicación. Ningún componente intenta ocultar modificaciones o suprimir registros del sistema.

## Cómo continuar en GitHub

El ZIP completo se extrae en la raíz del repositorio que compila NEXORA y **se conservan también las carpetas ocultas `.github`**. El workflow `.github/workflows/build-nexora-ios.yml` ahora exige `REEMPLAZO: 12/12 comprobaciones correctas` antes de `xcodebuild`.

La IPA que aparezca en `Actions > build > Artifacts` seguirá **sin firmar**; es necesario probarla y firmarla por los medios autorizados. No reemplaces una instalación funcional hasta comprobar el resultado.

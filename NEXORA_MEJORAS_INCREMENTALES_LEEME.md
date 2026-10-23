# NEXORA SYSTEM 2026 — Base Build 9 reforzada (revisión de limpieza)

Esta revisión **no es una nueva IPA final verificada**. Parte directamente del ZIP del Build 9 con Rainbow.

## Mejoras añadidas realmente

- Limpieza de temporales propios: evita borrar directorios inesperados, enlaces simbólicos, subcarpetas anómalas y archivos recientes aunque la carpeta sea antigua.
- Limpieza automática: conserva datos de trabajo recientes y permite excluir explícitamente IDs de opciones protegidas. Un fallo de una carpeta no fuerza borrar otras.
- Limpieza de cachés: protección de desbordamientos de tamaños y tope de profundidad de directorios. Las carpetas fuera de la lista de permitidas no se inspeccionan.
- Comprobación de regresiones antes de compilar: hashes del motor anterior no modificado y hashes específicos de dos módulos de limpieza revisados.
- Rainbow/Amarillo/Azul, panel Cloudflare, historial de versiones, respaldos y actualización con confirmación son los de Build 9 sin cambios.

## Lo que NO cambia

NO se trasladan desde Build 18 KernelExploit, ContainerStore, DevicePatchService, FileReplacementService, PatchTransaction, App.swift, ContentView.swift ni permisos/identificador de aplicación. No hay modo nuevo para saltar protecciones del sistema.

## Límites reales de verificación

- El funcionamiento con archivos privados de otras aplicaciones **no está confirmado**; el control de acceso de iOS puede impedirlo. Las pruebas de limpiador no validan permisos ni sustitución de esos archivos.
- Se necesita compilación Xcode/macOS y comprobación en dispositivo con operaciones autorizadas antes de reemplazar una instalación funcional.
- Se conserva Build 9 y la IPA antigua como copia estable; no instalar sobre ellas sin respaldo.

# NEXORA SYSTEM 2026 — version 2.1.4, build 13

## Actualizacion segura de archivos y respaldo

- Al aplicar una opcion, NEXORA verifica el SHA-256 del original si el paquete tiene una version vinculada.
- Si el original cambia desde la ultima activacion, **NO reutiliza** el archivo modificado anterior.
- El autor debe importar un paquete actualizado con un reemplazo nuevo y asociarlo al **original actual** desde el editor, seleccionando ese original en Archivos. NEXORA calcula su huella SHA-256 por bloques de 1 MiB, sin cargar todo el archivo grande en memoria.
- Si la version actual no coincide con la huella indicada en el paquete, la aplicacion cancela sin aplicar cambios.
- Si el reemplazo presentado es identico a la ultima version ya aplicada al archivo cambiado, se cancela y pide uno actualizado.
- La aplicacion **nunca genera automaticamente** archivos modificados compatibles; estos deben aportarse y verificarse. El SHA comprueba identidad de archivos, no si un reemplazo funciona, no certifica procedencia oficial.
- Se conservan los respaldos, diarios y mecanismos de restauracion actuales. Si otro proceso cambia el destino, la restauracion conservadora lo preserva y avisa.
- La limpieza permanece limitada a temporales propios y no elimina archivos de aplicaciones ajenas, registros ni copias de recuperacion.

## Flujo en el iPhone

1. Si un original cambia, NEXORA muestra un aviso en lugar de aplicar el archivo antiguo.
2. Importa un paquete `.3105` actualizado y, si editas un proyecto propio, selecciona en el editor el archivo **original actualizado** y el **archivo modificado actualizado**.
3. Guarda y vuelve a intentar aplicar. NEXORA compara los SHA-256, comprueba que el reemplazo es nuevo y respalda el original vigente antes de cualquier modificacion.
4. Al desactivar, restaura el original vigente solo si el destino sigue siendo el modificado por NEXORA; si ha cambiado externamente, lo conserva.

## Estado de las pruebas

- Nuevos casos agregados para rechazar el hash incorrecto y el payload obsoleto.
- Nuevas comprobaciones integradas en GitHub Actions en macOS. **No hay comprobacion de instalacion en un iPhone en este entorno**.
- iOS mantiene su aislamiento de datos entre aplicaciones. NEXORA no garantiza acceso a carpetas de terceros.

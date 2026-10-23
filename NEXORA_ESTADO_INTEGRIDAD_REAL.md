# NEXORA — Integridad del catálogo de recursos

## Verificación automática incorporada al flujo de compilación

- Recursos reales inventariados: **13**. Se verifica ruta en Assets.xcassets, registro en ContentView.swift, tamaño y SHA-256.
- Opciones sin archivo aportado: **8**. Se mantienen pendientes, sin generar recursos falsos.
- En GitHub Actions se ejecuta el verificador antes de compilar y se conserva el motor de acceso original sin alteraciones.

## Recursos que todavía NO existen en los archivos enviados

- BALAS MÁGICAS
- AIM CABEZA ANTENA
- TEXTURA PERSONALIZADA
- WALK HACK
- HOLO ARM PERSONALIZADO 2
- HOLOGRAMA PERSONAJE VERDE
- TEXTURA CLARA
- TEXTURA OSCURA

## Limitación importante

Este proyecto NO está completo en esas ocho opciones. Tampoco hay prueba de instalación/activación en iPhone ni de acceso a datos privados de otra aplicación. Se necesitan archivos reales y compatibles para incorporarlas. Nunca reemplazar un botón pendiente con datos de otra variante.

## Cambios en esta revisión

- Agregado `scripts/verificar_catalogo_y_assets.py`.
- GitHub Actions verifica el catálogo y el inventario antes de compilar.
- Actualizada la referencia de integridad del flujo.
- No se modificaron ContentView.swift, ContainerStore.swift, el motor de activación ni el catálogo de opciones.

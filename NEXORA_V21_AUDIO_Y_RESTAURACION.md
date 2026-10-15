# NEXORA SYSTEM 2026 — V21 (audio de activación)

Esta actualización parte de V19 e incluye un aviso audible cuando una activación se COMPLETA con éxito. No suena si la activación falla ni al desactivar. Se aplica a las opciones incorporadas, opciones importadas y la prueba local. V21 mantiene los enlaces de WhatsApp y Discord, la autenticación Cloudflare y la funcionalidad de restauración de la versión anterior.

## Sonido

En ausencia del audio personalizado utiliza la voz integrada de iOS (es-ES) para decir «Opción activada». Para incorporar un audio original del propietario posteriormente, añadirlo como recurso **Data Set** en `ThreeOneOSFive/Assets.xcassets/NexoraActivation.dataset` con el nombre `NexoraActivation`, apuntando al archivo de audio proporcionado (WAV, M4A o MP3 compatible). La opción de voz se usa solo cuando no existe o no se puede reproducir el recurso.

## Restauración

Se conserva el motor de transacciones y los respaldos de V19. Se añadió una **verificación posterior a la restauración**: se coteja el SHA-256 de cada archivo restaurado con el original y se comprueba la ausencia de los archivos creados por la opción. Si la verificación falla, se intenta volver al estado previo a la restauración y se notifica un error; no se marca la restauración como exitosa. No se añadieron mecanismos para eliminar evidencias de modificación, manipular registros del sistema o eludir detección de seguridad. Una restauración de contenido no implica ausencia de registros de otras aplicaciones o de iOS.

## Validaciones

Se ejecutaron los cuatro scripts de pre-verificación del proyecto y un análisis de sintaxis Swift. No se ha compilado con Xcode/macOS ni probado el audio en un iPhone; esa comprobación debe hacerse mediante GitHub Actions y en el dispositivo.

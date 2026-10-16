# NEXORA SYSTEM 2026 - V21.2 Audio personalizado

Este paquete incorpora el archivo `opcion_activada_audio.mp3` proporcionado por el propietario dentro de `ThreeOneOSFive/Assets.xcassets/NexoraActivation.dataset`.

- El audio se reproduce al confirmar la aplicación de una opción incorporada o de un paquete.
- Si otra notificación está sonando, se detiene antes de iniciar el nuevo audio.
- No suena al desactivar una opción.
- La voz sintética «Opción activada» permanece como alternativa si falla la grabación.
- Se conserva el resto del proyecto V21.1, incluido su mecanismo de restauración verificable y el panel Cloudflare externo.

## Cómo instalar
Copiar el contenido de este ZIP a la raíz del repositorio GitHub (mantener `.git`), revisar los cambios en GitHub Desktop, hacer Commit y Push. Revisar el resultado de Actions y descargar el artifact IPA sin firmar para firmarlo mediante el procedimiento habitual.

## Validación
`python3 scripts/verificar_audio_personalizado_v21_2.py` y los demás scripts del workflow.
No se puede compilar para iOS en este entorno: la validación final se realiza en GitHub Actions y después en un dispositivo.

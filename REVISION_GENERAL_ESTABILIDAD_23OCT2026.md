# NEXORA SYSTEM 2026 — Auditoría conservadora de estabilidad

## Punto de partida

Se parte del proyecto estable anterior y de la IPA funcional aportada como referencia. Este ZIP es **proyecto fuente completo**, no una IPA nueva ya compilada.

## Auditoría y cambio mínimo de rendimiento

- Se mantuvo **sin modificar** `ThreeOneOSFive/App.swift`: Worker Cloudflare, rutas `/v1/activate` y `/v1/validate`, Keychain, límite de espera de emergencia de 35 s y criterio `ok && active`. **35 segundos es un máximo para una solicitud atascada, NO una demora obligatoria**.
- Se eliminó una llamada duplicada a `store.reload()` en la aparición del panel: `PatchProjectStore` ya hace la carga inicial mediante `Task.detached` y publica su resultado.
- Se pospuso 1 segundo el chequeo de actualizaciones propias al abrir el panel y se condicionó a aplicación activa, licencia autorizada y tarea no cancelada. No se retrasa la verificación de licencias.
- La vigilancia sigue separada, con primer escaneo tras 30 s y revisiones cada 5 min, en primer plano, sin interpretar fallas de lectura como parches.
- Las mejoras existentes (respaldos, restauración, identificación SHA-256, catálogos firmados, compatibilidad por pareja verificable) permanecen incluidas.
- Se incluye `scripts/verificar_panel_entrada_ligera.py` en el flujo de GitHub Actions para prevenir regresiones.

## Qué NO se afirma

- No hay compilación iOS ni prueba sobre iPhone realizadas en este entorno Linux. Las verificaciones son locales y estáticas; algunos motores se prueban en aislamiento, pero no bajo iOS.
- No existe manera técnica de asegurar que cualquier parche desconocido sea compatible o que provenga del proveedor oficial solo por su SHA-256.
- No hay garantía de 0 errores en todos los modelos/iOS ni de conectividad Cloudflare. **Conserva la IPA ya funcional** mientras se prueban nuevas builds.

## Cómo compilar desde Windows/otra PC

1. Extraer ZIP y **subir el contenido de la carpeta**, no el ZIP como archivo, al nivel raíz de un repositorio GitHub. Subir incluso `.github`, `ThreeOneOSFive.xcodeproj`, `ThreeOneOSFive`, `BundledMods`, `scripts` y `deploy`.
2. Ir a *GitHub → Actions → Verificar y compilar NEXORA SYSTEM 2026 → Run workflow*. GitHub usará un runner macOS para `xcodebuild`.
3. Si pasa compilación y empaquetado, descargar el artefacto `NEXORA_SYSTEM_2026_3105_sin_firmar` que produce Actions.
4. Firmar e instalar **solo para pruebas inicialmente**. Probar key válida/incorrecta, sin Internet, reabrir, panel, auditoría, restauración en recursos autorizados, y vuelta de background. Si falla, enviar el artefacto `NEXORA_LOG_COMPILACION` o los mensajes de error; la IPA anterior debe mantenerse intacta.

## Huellas e informes

- `NEXORA_INVENTARIO_SHA256.json` verifica los archivos del proyecto que estaban en el inventario. Incluye los cambios a vista y workflow.
- `INFORME_AUDITORIA_GENERAL.txt` incluye los resultados ejecutados en esta entrega.

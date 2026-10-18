# NEXORA SYSTEM 2026 V21.6 — ANTENA SOLA (experimental)

**Estado:** función programada e integrada al panel, pendiente de compilación con Xcode y prueba real en iPhone. No se ha afirmado que produzca el efecto visual en el juego.

## Cómo funciona

- Se utilizó el espacio deshabilitado **AIM CABEZA ANTENA** en **AIMBOT CON ANTENA** para colocar **ANTENA SOLA**. **No incluye ningún archivo AIMBOT ni reutiliza un AIMBOT como plantilla.**
- Cuando se solicita activar, el motor lee el archivo actualmente presente en el destino autorizado, descomprime su contenido UnityFS, comprueba el perfil analizado (UnityFS v8, revisión 2018.4.12f1, un bloque de 45964 bytes) y exige que dos valores internos todavía estén en 1.0.
- En una copia en memoria cambia únicamente esos dos valores de 1.0 a 300.0 (posiciones 25260 y 38920 en datos descomprimidos), reconstruye el UnityFS y verifica que pueda decodificarse otra vez.
- Si el archivo de origen coincide con alguno de los **seis recursos AIM/AIM+ANTENA conocidos**, rechaza la operación; **no puede descartar modificaciones desconocidas**. La app pide confirmación y exige que la persona compruebe que el archivo actual no está modificado fuera de NEXORA.
- Entrega la copia al mismo `DevicePatchService.apply` y `PatchTransaction` existentes. Este servicio guarda una copia del archivo actual antes de escribir, registra la transacción y permite restaurarla con la lógica V21.6.
- Si otra opción usa el mismo destino, NEXORA bloquea la activación simultánea. No se alteraron los doce recursos preexistentes ni las opciones de hologramas.
- Si hay incompatibilidad de formato, un valor distinto al esperado, falta el archivo o no hay acceso al contenedor, **no se modifica el destino**.

## Límites comprobables

- Las tres comparaciones con recursos AIM y AIM+ANTENA confirmaron que aplicar **solo los dos valores identificados** produce los mismos datos descomprimidos que los ejemplos con antena. Esas comparaciones **no prueban que la antena funcione sin AIMBOT en un original limpio**, porque no se facilitó un original limpio para comparar.
- No se ejecutó Xcode ni una IPA en iPhone en este entorno. La compatibilidad visual del juego y el permiso de escritura sobre sus archivos no están verificados.
- Las actualizaciones pueden cambiar los formatos, tamaños u offsets. En ese caso la función se niega a actuar; no se intenta un reemplazo a ciegas.
- Hay un pequeño intervalo entre leer el archivo actual y la transacción. No se recomienda modificarlo desde otra aplicación al mismo tiempo.
- Solo usar la opción con una copia legítima y sin otras modificaciones del archivo de origen; conserva la versión anterior del proyecto y sus respaldos hasta terminar las pruebas.

## Archivos principales modificados

- `ThreeOneOSFive/ContentView.swift`: nueva opción y confirmación.
- `ThreeOneOSFive/helpers/NXAntennaOnlyUnityFS.swift`: analizador y generador seguro, específico para este perfil UnityFS.
- `ThreeOneOSFive.xcodeproj/project.pbxproj`: inclusión del nuevo Swift en el target.
- `scripts/PruebaAntenaSola.swift`: pruebas de los tres pares de archivos.
- `.github/workflows/build-nexora-ios.yml`: pruebas previas a compilación.
- `scripts/verificar_catalogo_completo_nexora.py`: comprobador ajustado para 12 recursos + 1 opción generada desde el original.

## Compilación

Usa el proyecto ZIP completo en GitHub Desktop, revisa los cambios antes de hacer commit y espera a que GitHub Actions compile. No reemplaces la IPA instalada hasta comprobar el resultado.

## Ubicación solicitada en el panel

- En **AIMBOT CON ANTENA** hay tres filas previas y en el cuarto lugar aparece **ANTENA SOLA** (sin el rótulo «Pendiente de archivo»).
- Interruptor encendido: intenta generar y aplicar únicamente los dos cambios candidatos a antena sobre un original compatible; jamás activa simultáneamente otras opciones que compartan el destino.
- Interruptor apagado: inicia la restauración protegida del original guardado. No enciende automáticamente ninguna otra opción.
- El efecto «solo antena» sigue pendiente de validación visual en un original limpio; no hay garantía de que el resultado sea exactamente el esperado.

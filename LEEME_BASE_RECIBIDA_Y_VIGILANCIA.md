# NEXORA SYSTEM 2026 — BASE FUNCIONAL CONSERVADA / VIGILANCIA AISLADA

**Referencia aportada el 22 de octubre de 2026:** `NEXORA_SYSTEM_2026_3105_sin_firmar(7)(1).ipa`.
**SHA-256 de referencia (IPA):** `f294b535dd42bbe0cac12921b9bf477a67dfffcfc7676460b6b583a9c4dad0d3`.

## El objetivo exacto

Conservar la IPA que el usuario confirmó que valida correctamente su key, sin reemplazarla a ciegas por nuevas compilaciones. Llevar únicamente la mejora de **vigilancia de cambios de archivos originales previamente respaldados** al proyecto fuente más cercano que tenemos disponible.

La vigilancia se ejecuta en `ContentView`, después de que el servidor haya autorizado la sesión. El código original de la pantalla de login se conserva sin cambios y la primera revisión comienza 30 segundos después de que aparezca el panel; se repite cada 5 minutos mientras la app está activa. Cuando se encuentra un SHA-256 diferente del respaldo, queda bloqueada **solo** la opción o las opciones que usan ese destino y se informa del cambio. Los errores de lectura NO se interpretan como cambios. La vigilancia no debe interferir con la entrada de la key.

## Resultado de verificación

- Archivo IPA recibido válido y sin daños en su ZIP.
- Proyecto y ejecutable de la IPA usan exactamente el mismo endpoint de Cloudflare, el mismo servicio Keychain y el mismo Bundle ID, versión 2.0.5 (16).
- Código de vigilancia aislado de la validación de licencias. El SHA-256 completo de App.swift coincide con la referencia original del código fuente anterior a esta mejora.
- Scripts estáticos del proyecto revisados: 24 de 24 comprobaciones ejecutables sin una app de Xcode pasaron; el verificador de `.app` necesita la compilación de macOS, por lo que no se ejecutó aquí.
- `swiftc -frontend -parse` de `ContentView.swift` pasó en el entorno Linux; esto no equivale a compilar y enlazar un binario para iOS.

## Advertencia importante

**Este ZIP contiene código fuente, NO una IPA con la mejora añadida.** Aunque los metadatos y cadenas relevantes coinciden con el ejecutable, **no se puede demostrar que el código fuente corresponda exactamente al ejecutable de la IPA que funciona.** No se puede asegurar que la nueva compilación valide la key hasta probarla en un iPhone contra el servidor real.

**No se ha alterado la IPA aportada.** Consérvala e instala cualquier compilación nueva solo después de comprobar que entra al panel con la misma key. No hagas cambios al sistema de licencias solo para que la vigilancia funcione.

## Verificar esta base desde un ordenador

En la raíz del proyecto, ejecutar:

```sh
python3 scripts/verificar_base_ipa_recibida.py /ruta/a/la/ipa-original.ipa
```

Se comprueban hashes, datos de identificación y que la vigilancia permanezca después del acceso de licencias. El script no modifica ningún archivo.

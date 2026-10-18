# NEXORA V21.6 — Verificación de recursos y archivos reales

Se agregó a **Configuración → Diagnóstico técnico del motor 3105** el botón
**«Comprobar archivos reales (solo lectura)»**.

El diagnóstico:
- comprueba que los 12 recursos de opciones configuradas estén empaquetados;
- localiza el contenedor de destino mediante los métodos ya existentes del proyecto;
- comprueba la presencia y capacidad de lectura de los 3 destinos agrupados, sin cambiar sus archivos;
- informa los resultados por cada grupo de opciones.

**No** realiza escrituras, restauraciones, elusión de permisos o pruebas de integridad en archivos externos. Un resultado de lectura correcta **no demuestra** que el reemplazo o la restauración funcionen. Si iOS no permite acceder, no se deshabilitan ni se fuerzan controles de seguridad.

Antes de lanzar la nueva IPA hay que compilarla en macOS y probar, con copias legítimas y respaldos seguros, las operaciones reales que la aplicación tenga autorización para realizar.

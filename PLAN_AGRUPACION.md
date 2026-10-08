# Plan pendiente: agrupación de registros

**Estado:** pendiente de aclarar las decisiones finales. **Alcance:** maqueta Delphi 7 VCL; datos y configuración solo en memoria. No hay implementación de agrupación todavía.

## Objetivo y experiencia de uso

Añadir **Agrupar…** para elegir columnas visibles y ordenar los niveles de agrupación mediante Agregar, Quitar, Subir y Bajar. Incluir una opción **Sin agrupar** que recupere el grid actual. La propuesta muestra una cabecera por grupo con su valor y recuento, permite expandirla o contraerla y admite varios niveles. El doble clic sobre un registro conserva la edición actual; sobre una cabecera alterna su expansión. Nuevo, Editar y Borrar actuarán siempre sobre registros reales, nunca sobre cabeceras.

## Diseño técnico

`TDBGrid` representa una fila por registro de `TClientDataSet`, por lo que las cabeceras de grupo requieren una vista separada. Mantener cada CDS como fuente de verdad y construir una proyección temporal de las filas que pasan los filtros. La proyección distinguirá cabeceras de grupo y registros, almacenará la ruta del grupo, el recuento y una referencia temporal al registro fuente. Mostrarla mediante un grid VCL dibujado en Pascal cuando haya agrupación; conservar el grid actual para el modo sin agrupar. No insertar registros de cabecera en el CDS.

Ordenar primero por las columnas de agrupación y aplicar los criterios de orden actuales dentro de cada grupo. Reconstruir la proyección tras cambiar de CDS, filtros, orden, visibilidad, búsqueda en modo Filtrar o datos guardados y borrados. Conservar, cuando sea posible, los grupos expandidos y el registro seleccionado. Mantener la configuración de agrupación por CDS durante la sesión; al ocultar una columna agrupadora, quitar ese nivel. La búsqueda en modo resaltado marcará coincidencias únicamente en las filas de datos.

## Verificación prevista

Compilar con Delphi 7. Revisar los cuatro CDS de 100 registros, uno y varios niveles, grupos vacíos, expansión, cambio de CDS y combinación con búsqueda, filtros, ordenación y columnas ocultas. Comprobar alta, edición, cancelación y borrado mientras hay agrupación, además del retorno a **Sin agrupar** sin cambios en los datos fuente.

## Decisiones pendientes del usuario

1. Confirmar varios niveles, cabeceras expandibles con recuento y ausencia de sumas u otros agregados por ahora.
2. Confirmar fechas agrupadas por valor exacto y valores nulos o vacíos bajo **Sin valor**.
3. Confirmar que el campo agrupador siga visible como columna de datos.

No comenzar la implementación hasta resolver estas decisiones.

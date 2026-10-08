# Maqueta de gestión de ClientDataSet (Delphi 7)

Aplicación VCL para probar un formulario genérico de gestión de `TClientDataSet` (CDS). Funciona sin archivos DFM, componentes de terceros ni base de datos. Los datos viven en memoria.

## Datos de ejemplo

El selector superior permite cambiar entre cuatro CDS. Cada uno carga **100 registros** (400 en total) al iniciar la aplicación.

| CDS | Campos |
| --- | --- |
| Usuarios | Nombre, Edad, Alta, Activo, Notas |
| Pacientes | Nombre, PesoKg, Nacimiento, Seguimiento, Alergias |
| Tareas | Titulo, Prioridad, Vencimiento, Completada, Descripcion |
| Medicamentos | Nombre, DosisMg, Inicio, Disponible, Indicaciones |

Los dos primeros registros de cada CDS son ejemplos identificables; el resto se genera de forma determinista. Al iniciar o cambiar de CDS queda seleccionado **el primer registro**.

## Funcionalidades

- **Grid de solo lectura:** permite navegar sin modificar datos directamente. Resalta la fila completa del registro actual, incluso cuando el foco pasa a otro control.
- **Buscar y filtrar:** abre un frame dentro de la ventana, sin bloquear el grid. Al teclear, las celdas cuyo valor visible contiene el texto se marcan en amarillo, sin distinguir mayúsculas y minúsculas. La casilla **Filtrar** sustituye el resaltado por un filtro en vivo: muestra los registros con coincidencias en cualquier columna visible. Desmarcarla, borrar el texto o cerrar el frame elimina el filtro general y las marcas; los filtros de columna siguen activos.
- **Ordenar columnas:** el icono a la izquierda del título es gris cuando no hay orden. Al pulsarlo recorre ascendente (flecha arriba), descendente (flecha abajo) y sin orden. Solo el icono activa la ordenación. Un clic normal sustituye los criterios previos; **Mayús + clic en el icono** añade o cambia un criterio secundario. Las columnas de texto largo no tienen icono de orden. Los criterios se guardan por CDS y se recuperan al volver a abrir la aplicación.
- **Filtros por columna:** el embudo gris de cada cabecera abre un diálogo para añadir tantas condiciones como se necesiten. Texto: contiene, no contiene, igual o distinto; números y fechas: igual, distinto, mayor o menor; booleanos: verdadero o falso. Cada condición se une con **Y** u **O**; **Y** tiene prioridad sobre **O**. Los filtros de distintas columnas se combinan con **Y**, igual que la búsqueda general cuando está en modo **Filtrar**. El embudo se vuelve verde cuando hay un filtro activo. **Limpiar filtro** o aplicar con todas las condiciones de texto vacías lo elimina. Los filtros se guardan por CDS y se restauran al cambiar de CDS o reiniciar. Las fechas se introducen con el formato regional de Windows.
- **Ver u ocultar columnas:** el botón **Columnas...** abre una lista de campos del CDS actual. Debe quedar visible al menos una columna de datos. La selección y el orden se guardan por CDS. Puede reordenar arrastrando las cabeceras o con **Subir/Bajar** en este diálogo. Al ocultar una columna se eliminan sus filtros y criterios de orden; si se vuelve a mostrar, estos no reaparecen. La búsqueda general examina solo las columnas visibles y la columna final vacía sigue ajustándose al espacio disponible.
- **Configuración persistente:** la visibilidad, posición y anchura de las columnas, los criterios de orden y los filtros de cada CDS se guardan automáticamente en `DelphiCDSDemo.ini`, junto al ejecutable. También se conserva el texto de búsqueda general cuando está marcada **Filtrar**. Los cambios se recuperan al cambiar de CDS y al reiniciar. El archivo es local y no se versiona; eliminarlo devuelve la configuración inicial.
- **Anchura de columnas:** un doble clic en el separador de cabeceras ajusta la columna al título y al contenido de los registros, con un máximo de 600 píxeles. Una columna final vacía ocupa el espacio sobrante y cambia de ancho al redimensionar la ventana o las otras columnas.
- **Editar:** un doble clic sobre una celda de datos, o el botón **Editar**, abre el registro seleccionado en un formulario modal. Los dobles clics sobre la cabecera o la columna vacía no abren el editor.
- **Nuevo:** abre el mismo formulario con un registro vacío.
- **Formulario genérico:** crea controles según los campos del CDS: edición de texto, números y fechas, casillas para booleanos y áreas de texto para memos. Marca los campos obligatorios con `*`; las fechas siguen el formato regional de Windows.
- **Guardar y cancelar:** **Guardar** valida mediante `Post`. **Cancelar** o cerrar el formulario descarta la edición en curso. Si falla el guardado, se muestra el error y el formulario permanece abierto.
- **Borrar:** solicita confirmación antes de eliminar el registro seleccionado.

## Compilar y ejecutar

Abra [DelphiCDSDemo.dpr](DelphiCDSDemo.dpr) en Delphi 7 y compile. Si `dcc32` está en `PATH`, puede hacerlo desde la raíz del proyecto:

```powershell
dcc32 -Q DelphiCDSDemo.dpr
.\DelphiCDSDemo.exe
```

El proyecto incluye `MidasLib` para usar el CDS localmente. La compilación genera el ejecutable en la raíz; el archivo `.exe` no se versiona.

## Alcance y archivos

Los cambios en los registros se pierden al cerrar la aplicación; solo se guarda la configuración del grid. No se llama a `SaveToFile` ni a `ApplyUpdates`, y no hay proveedor de base de datos. El editor no incluye controles para BLOB binarios, campos anidados ni `lookup`.

- [DemoData.pas](DemoData.pas): define y carga los cuatro CDS.
- [MainForm.pas](MainForm.pas): selector, grid, búsqueda, filtros, ordenación y acciones.
- [ColumnFilter.pas](ColumnFilter.pas): condiciones y diálogo de filtro por columna.
- [ColumnChooser.pas](ColumnChooser.pas): diálogo para mostrar, ocultar y reordenar columnas.
- [RecordEditor.pas](RecordEditor.pas): formulario modal generado a partir de los campos.
- [DelphiCDSDemo.dpr](DelphiCDSDemo.dpr): entrada del proyecto.

No hay pruebas automatizadas versionadas. Para comprobar los cambios, recorra los cuatro CDS y pruebe selección, alta, edición, cancelación, borrado, búsqueda en vivo, filtros de columna combinados, orden simple y múltiple, visibilidad y orden por CDS, autoajuste, redimensionamiento y restauración de la configuración tras reiniciar.

## Trabajo pendiente

La propuesta de agrupación de registros está documentada en [PLAN_AGRUPACION.md](PLAN_AGRUPACION.md). Quedan decisiones de comportamiento por confirmar antes de implementarla.

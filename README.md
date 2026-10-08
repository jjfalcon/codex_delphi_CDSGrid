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

Los cambios se pierden al cerrar la aplicación. No se llama a `SaveToFile` ni a `ApplyUpdates`, y no hay proveedor de base de datos. El editor no incluye controles para BLOB binarios, campos anidados ni `lookup`.

- [DemoData.pas](DemoData.pas): define y carga los cuatro CDS.
- [MainForm.pas](MainForm.pas): selector, grid, autoajuste y acciones.
- [RecordEditor.pas](RecordEditor.pas): formulario modal generado a partir de los campos.
- [DelphiCDSDemo.dpr](DelphiCDSDemo.dpr): entrada del proyecto.

No hay pruebas automatizadas versionadas. Para comprobar los cambios, recorra los cuatro CDS y pruebe selección, alta, edición, cancelación, borrado, autoajuste y redimensionamiento.

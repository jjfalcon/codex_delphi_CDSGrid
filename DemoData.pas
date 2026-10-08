unit DemoData;

interface

uses
  Classes, DB, DBClient;

type
  TDemoData = class(TComponent)
  private
    FDataSets: array[0..3] of TClientDataSet;
    function GetDataSet(Index: Integer): TClientDataSet;
    procedure BuildUsers;
    procedure BuildPatients;
    procedure BuildTasks;
    procedure BuildMedicines;
  public
    constructor Create(AOwner: TComponent); override;
    property DataSets[Index: Integer]: TClientDataSet read GetDataSet;
  end;

implementation

uses
  SysUtils;

constructor TDemoData.Create(AOwner: TComponent);
var
  I: Integer;
begin
  inherited Create(AOwner);
  for I := Low(FDataSets) to High(FDataSets) do
    FDataSets[I] := TClientDataSet.Create(Self);
  BuildUsers;
  BuildPatients;
  BuildTasks;
  BuildMedicines;
end;

function TDemoData.GetDataSet(Index: Integer): TClientDataSet;
begin
  if (Index < Low(FDataSets)) or (Index > High(FDataSets)) then
    raise ERangeError.Create('Indice de conjunto de datos no valido');
  Result := FDataSets[Index];
end;

procedure TDemoData.BuildUsers;
var
  C: TClientDataSet;
  I: Integer;
begin
  C := FDataSets[0];
  C.FieldDefs.Add('Nombre', ftString, 60, True);
  C.FieldDefs.Add('Edad', ftInteger, 0, False);
  C.FieldDefs.Add('Alta', ftDate, 0, False);
  C.FieldDefs.Add('Activo', ftBoolean, 0, False);
  C.FieldDefs.Add('Notas', ftMemo, 0, False);
  C.CreateDataSet;
  C.FieldByName('Alta').DisplayLabel := 'Fecha de alta';

  C.Append;
  C.FieldByName('Nombre').AsString := 'Ana Garcia';
  C.FieldByName('Edad').AsInteger := 31;
  C.FieldByName('Alta').AsDateTime := EncodeDate(2024, 2, 12);
  C.FieldByName('Activo').AsBoolean := True;
  C.FieldByName('Notas').AsString := 'Administracion';
  C.Post;

  C.Append;
  C.FieldByName('Nombre').AsString := 'Luis Moreno';
  C.FieldByName('Edad').AsInteger := 44;
  C.FieldByName('Alta').AsDateTime := EncodeDate(2023, 9, 4);
  C.FieldByName('Activo').AsBoolean := False;
  C.FieldByName('Notas').AsString := 'Cuenta de prueba';
  C.Post;

  for I := 3 to 100 do
  begin
    C.Append;
    C.FieldByName('Nombre').AsString := Format('Usuario %d', [I]);
    C.FieldByName('Edad').AsInteger := 18 + (I mod 55);
    C.FieldByName('Alta').AsDateTime :=
      EncodeDate(2020 + (I mod 6), 1 + (I mod 12), 1 + (I mod 28));
    C.FieldByName('Activo').AsBoolean := I mod 3 <> 0;
    C.FieldByName('Notas').AsString :=
      Format('Cuenta de ejemplo numero %d', [I]);
    C.Post;
  end;
end;

procedure TDemoData.BuildPatients;
var
  C: TClientDataSet;
  I: Integer;
begin
  C := FDataSets[1];
  C.FieldDefs.Add('Nombre', ftString, 60, True);
  C.FieldDefs.Add('PesoKg', ftFloat, 0, False);
  C.FieldDefs.Add('Nacimiento', ftDate, 0, False);
  C.FieldDefs.Add('Seguimiento', ftBoolean, 0, False);
  C.FieldDefs.Add('Alergias', ftMemo, 0, False);
  C.CreateDataSet;
  C.FieldByName('PesoKg').DisplayLabel := 'Peso (kg)';
  C.FieldByName('Nacimiento').DisplayLabel := 'Fecha de nacimiento';
  C.FieldByName('Seguimiento').DisplayLabel := 'En seguimiento';

  C.Append;
  C.FieldByName('Nombre').AsString := 'Marta Lopez';
  C.FieldByName('PesoKg').AsFloat := 63.5;
  C.FieldByName('Nacimiento').AsDateTime := EncodeDate(1988, 6, 21);
  C.FieldByName('Seguimiento').AsBoolean := True;
  C.FieldByName('Alergias').AsString := 'Penicilina';
  C.Post;

  C.Append;
  C.FieldByName('Nombre').AsString := 'Pablo Ruiz';
  C.FieldByName('PesoKg').AsFloat := 79.2;
  C.FieldByName('Nacimiento').AsDateTime := EncodeDate(1975, 11, 3);
  C.FieldByName('Seguimiento').AsBoolean := False;
  C.FieldByName('Alergias').AsString := 'Sin alergias conocidas';
  C.Post;

  for I := 3 to 100 do
  begin
    C.Append;
    C.FieldByName('Nombre').AsString := Format('Paciente %d', [I]);
    C.FieldByName('PesoKg').AsFloat :=
      50 + (I mod 45) + (I mod 10) / 10;
    C.FieldByName('Nacimiento').AsDateTime :=
      EncodeDate(1950 + (I mod 55), 1 + (I mod 12), 1 + (I mod 28));
    C.FieldByName('Seguimiento').AsBoolean := I mod 2 = 0;
    C.FieldByName('Alergias').AsString :=
      Format('Ficha de ejemplo numero %d', [I]);
    C.Post;
  end;
end;

procedure TDemoData.BuildTasks;
var
  C: TClientDataSet;
  I: Integer;
begin
  C := FDataSets[2];
  C.FieldDefs.Add('Titulo', ftString, 80, True);
  C.FieldDefs.Add('Prioridad', ftInteger, 0, False);
  C.FieldDefs.Add('Vencimiento', ftDate, 0, False);
  C.FieldDefs.Add('Completada', ftBoolean, 0, False);
  C.FieldDefs.Add('Descripcion', ftMemo, 0, False);
  C.CreateDataSet;
  C.FieldByName('Vencimiento').DisplayLabel := 'Fecha limite';

  C.Append;
  C.FieldByName('Titulo').AsString := 'Revisar agenda';
  C.FieldByName('Prioridad').AsInteger := 1;
  C.FieldByName('Vencimiento').AsDateTime := EncodeDate(2026, 10, 15);
  C.FieldByName('Completada').AsBoolean := False;
  C.FieldByName('Descripcion').AsString := 'Confirmar las citas pendientes';
  C.Post;

  C.Append;
  C.FieldByName('Titulo').AsString := 'Preparar informe';
  C.FieldByName('Prioridad').AsInteger := 2;
  C.FieldByName('Vencimiento').AsDateTime := EncodeDate(2026, 10, 20);
  C.FieldByName('Completada').AsBoolean := True;
  C.FieldByName('Descripcion').AsString := 'Resumen semanal';
  C.Post;

  for I := 3 to 100 do
  begin
    C.Append;
    C.FieldByName('Titulo').AsString := Format('Tarea %d', [I]);
    C.FieldByName('Prioridad').AsInteger := 1 + (I mod 3);
    C.FieldByName('Vencimiento').AsDateTime :=
      EncodeDate(2026, 1 + (I mod 12), 1 + (I mod 28));
    C.FieldByName('Completada').AsBoolean := I mod 4 = 0;
    C.FieldByName('Descripcion').AsString :=
      Format('Descripcion de la tarea de ejemplo %d', [I]);
    C.Post;
  end;
end;

procedure TDemoData.BuildMedicines;
var
  C: TClientDataSet;
  I: Integer;
begin
  C := FDataSets[3];
  C.FieldDefs.Add('Nombre', ftString, 60, True);
  C.FieldDefs.Add('DosisMg', ftFloat, 0, False);
  C.FieldDefs.Add('Inicio', ftDate, 0, False);
  C.FieldDefs.Add('Disponible', ftBoolean, 0, False);
  C.FieldDefs.Add('Indicaciones', ftMemo, 0, False);
  C.CreateDataSet;
  C.FieldByName('DosisMg').DisplayLabel := 'Dosis (mg)';
  C.FieldByName('Inicio').DisplayLabel := 'Fecha de inicio';

  C.Append;
  C.FieldByName('Nombre').AsString := 'Paracetamol';
  C.FieldByName('DosisMg').AsFloat := 500;
  C.FieldByName('Inicio').AsDateTime := EncodeDate(2026, 1, 8);
  C.FieldByName('Disponible').AsBoolean := True;
  C.FieldByName('Indicaciones').AsString := 'Segun indicacion medica';
  C.Post;

  C.Append;
  C.FieldByName('Nombre').AsString := 'Ibuprofeno';
  C.FieldByName('DosisMg').AsFloat := 400;
  C.FieldByName('Inicio').AsDateTime := EncodeDate(2026, 3, 14);
  C.FieldByName('Disponible').AsBoolean := False;
  C.FieldByName('Indicaciones').AsString := 'Ejemplo de inventario';
  C.Post;

  for I := 3 to 100 do
  begin
    C.Append;
    C.FieldByName('Nombre').AsString := Format('Medicamento %d', [I]);
    C.FieldByName('DosisMg').AsFloat := 100 + (I mod 12) * 50;
    C.FieldByName('Inicio').AsDateTime :=
      EncodeDate(2025 + (I mod 2), 1 + (I mod 12), 1 + (I mod 28));
    C.FieldByName('Disponible').AsBoolean := I mod 5 <> 0;
    C.FieldByName('Indicaciones').AsString :=
      Format('Indicaciones de ejemplo para registro %d', [I]);
    C.Post;
  end;
end;

end.

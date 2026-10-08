unit ColumnFilter;

interface

uses
  Classes, DB, Forms, Controls, StdCtrls, ExtCtrls;

type
  TFilterOperator = (foContains, foNotContains, foEqual, foNotEqual,
    foGreater, foLess, foTrue, foFalse);
  TFilterJoin = (fjAnd, fjOr);

  TFilterCondition = class
  public
    Operator: TFilterOperator;
    Join: TFilterJoin;
    Value: string;
    NumberValue: Double;
    DateValue: TDateTime;
    function Matches(Field: TField): Boolean;
  end;

  TColumnFilter = class
  private
    FFieldName: string;
    FConditions: TList;
    function GetCount: Integer;
    function GetCondition(Index: Integer): TFilterCondition;
  public
    constructor Create(const AFieldName: string);
    destructor Destroy; override;
    procedure Add(ACondition: TFilterCondition);
    function Matches(Field: TField): Boolean;
    property FieldName: string read FFieldName;
    property Count: Integer read GetCount;
    property Conditions[Index: Integer]: TFilterCondition read GetCondition;
  end;

  TColumnFilterDialog = class(TForm)
  private
    FField: TField;
    FRows: TList;
    FScroll: TScrollBox;
    FResultFilter: TColumnFilter;
    procedure AddRow(ACondition: TFilterCondition);
    procedure ArrangeRows;
    procedure AddClick(Sender: TObject);
    procedure RemoveClick(Sender: TObject);
    procedure ClearClick(Sender: TObject);
    procedure SaveClick(Sender: TObject);
  public
    constructor CreateForField(AOwner: TComponent; AField: TField;
      AExisting: TColumnFilter);
    destructor Destroy; override;
    function TakeFilter: TColumnFilter;
  end;

implementation

uses
  SysUtils, Dialogs;

type
  TFilterRow = class
  public
    JoinBox: TComboBox;
    OperatorBox: TComboBox;
    ValueEdit: TEdit;
    RemoveButton: TButton;
    constructor Create(AOwner: TComponent; AParent: TWinControl;
      AField: TField);
    destructor Destroy; override;
    procedure PositionAt(Index: Integer);
  end;

function IsNumberField(Field: TField): Boolean;
begin
  Result := Field.DataType in [ftSmallint, ftInteger, ftWord, ftFloat,
    ftCurrency, ftBCD, ftAutoInc, ftLargeint];
end;

function IsDateField(Field: TField): Boolean;
begin
  Result := Field.DataType in [ftDate, ftTime, ftDateTime];
end;

function TFilterCondition.Matches(Field: TField): Boolean;
var
  TextValue: string;
  Number: Double;
  Date: TDateTime;
begin
  Result := False;
  if Field.IsNull then
    Exit;
  if Operator = foTrue then
  begin
    Result := Field.AsBoolean;
    Exit;
  end;
  if Operator = foFalse then
  begin
    Result := not Field.AsBoolean;
    Exit;
  end;
  if IsNumberField(Field) then
  begin
    Number := Field.AsFloat;
    case Operator of
      foEqual: Result := Number = NumberValue;
      foNotEqual: Result := Number <> NumberValue;
      foGreater: Result := Number > NumberValue;
      foLess: Result := Number < NumberValue;
    end;
  end
  else if IsDateField(Field) then
  begin
    Date := Field.AsDateTime;
    case Operator of
      foEqual: Result := Date = DateValue;
      foNotEqual: Result := Date <> DateValue;
      foGreater: Result := Date > DateValue;
      foLess: Result := Date < DateValue;
    end;
  end
  else
  begin
    TextValue := AnsiUpperCase(Field.AsString);
    case Operator of
      foContains: Result := Pos(AnsiUpperCase(Value), TextValue) > 0;
      foNotContains: Result := Pos(AnsiUpperCase(Value), TextValue) = 0;
      foEqual: Result := AnsiCompareText(Field.AsString, Value) = 0;
      foNotEqual: Result := AnsiCompareText(Field.AsString, Value) <> 0;
    end;
  end;
end;

constructor TColumnFilter.Create(const AFieldName: string);
begin
  inherited Create;
  FFieldName := AFieldName;
  FConditions := TList.Create;
end;

destructor TColumnFilter.Destroy;
var
  I: Integer;
begin
  for I := 0 to FConditions.Count - 1 do
    TObject(FConditions[I]).Free;
  FConditions.Free;
  inherited Destroy;
end;

procedure TColumnFilter.Add(ACondition: TFilterCondition);
begin
  FConditions.Add(ACondition);
end;

function TColumnFilter.GetCount: Integer;
begin
  Result := FConditions.Count;
end;

function TColumnFilter.GetCondition(Index: Integer): TFilterCondition;
begin
  Result := TFilterCondition(FConditions[Index]);
end;

function TColumnFilter.Matches(Field: TField): Boolean;
var
  I: Integer;
  GroupResult: Boolean;
begin
  if Count = 0 then
  begin
    Result := True;
    Exit;
  end;
  Result := False;
  GroupResult := Conditions[0].Matches(Field);
  for I := 1 to Count - 1 do
    if Conditions[I].Join = fjAnd then
      GroupResult := GroupResult and Conditions[I].Matches(Field)
    else
    begin
      Result := Result or GroupResult;
      GroupResult := Conditions[I].Matches(Field);
    end;
  Result := Result or GroupResult;
end;

constructor TFilterRow.Create(AOwner: TComponent; AParent: TWinControl;
  AField: TField);
begin
  inherited Create;
  JoinBox := TComboBox.Create(AOwner);
  JoinBox.Parent := AParent;
  JoinBox.Style := csDropDownList;
  JoinBox.Width := 55;
  JoinBox.Items.Add('Y');
  JoinBox.Items.Add('O');
  JoinBox.ItemIndex := 0;

  OperatorBox := TComboBox.Create(AOwner);
  OperatorBox.Parent := AParent;
  OperatorBox.Style := csDropDownList;
  OperatorBox.Width := 150;
  if AField.DataType = ftBoolean then
  begin
    OperatorBox.Items.AddObject('Es verdadero', TObject(Ord(foTrue)));
    OperatorBox.Items.AddObject('Es falso', TObject(Ord(foFalse)));
  end
  else if IsNumberField(AField) or IsDateField(AField) then
  begin
    OperatorBox.Items.AddObject('Igual', TObject(Ord(foEqual)));
    OperatorBox.Items.AddObject('Distinto', TObject(Ord(foNotEqual)));
    OperatorBox.Items.AddObject('Mayor que', TObject(Ord(foGreater)));
    OperatorBox.Items.AddObject('Menor que', TObject(Ord(foLess)));
  end
  else
  begin
    OperatorBox.Items.AddObject('Contiene', TObject(Ord(foContains)));
    OperatorBox.Items.AddObject('No contiene', TObject(Ord(foNotContains)));
    OperatorBox.Items.AddObject('Igual', TObject(Ord(foEqual)));
    OperatorBox.Items.AddObject('Distinto', TObject(Ord(foNotEqual)));
  end;
  OperatorBox.ItemIndex := 0;

  ValueEdit := TEdit.Create(AOwner);
  ValueEdit.Parent := AParent;
  ValueEdit.Width := 160;
  ValueEdit.Visible := AField.DataType <> ftBoolean;

  RemoveButton := TButton.Create(AOwner);
  RemoveButton.Parent := AParent;
  RemoveButton.Width := 68;
  RemoveButton.Caption := 'Quitar';
end;

destructor TFilterRow.Destroy;
begin
  JoinBox.Free;
  OperatorBox.Free;
  ValueEdit.Free;
  RemoveButton.Free;
  inherited Destroy;
end;

procedure TFilterRow.PositionAt(Index: Integer);
var
  Y: Integer;
begin
  Y := 12 + Index * 35;
  JoinBox.Left := 12;
  JoinBox.Top := Y;
  JoinBox.Visible := Index > 0;
  OperatorBox.Left := 72;
  OperatorBox.Top := Y;
  ValueEdit.Left := 232;
  ValueEdit.Top := Y;
  RemoveButton.Left := 404;
  RemoveButton.Top := Y - 1;
  RemoveButton.Tag := Index;
end;

constructor TColumnFilterDialog.CreateForField(AOwner: TComponent;
  AField: TField; AExisting: TColumnFilter);
var
  Bottom: TPanel;
  AddButton, ClearButton, SaveButton, CancelButton: TButton;
  I: Integer;
begin
  inherited CreateNew(AOwner);
  FField := AField;
  FRows := TList.Create;
  Caption := 'Filtro: ' + AField.DisplayLabel;
  Position := poScreenCenter;
  BorderStyle := bsSizeable;
  Width := 510;
  Height := 350;
  Constraints.MinWidth := 510;
  Constraints.MinHeight := 220;

  Bottom := TPanel.Create(Self);
  Bottom.Parent := Self;
  Bottom.Align := alBottom;
  Bottom.Height := 58;
  Bottom.BevelOuter := bvNone;

  AddButton := TButton.Create(Self);
  AddButton.Parent := Bottom;
  AddButton.Left := 12;
  AddButton.Top := 14;
  AddButton.Width := 85;
  AddButton.Caption := 'Agregar';
  AddButton.OnClick := AddClick;

  ClearButton := TButton.Create(Self);
  ClearButton.Parent := Bottom;
  ClearButton.Left := 104;
  ClearButton.Top := 14;
  ClearButton.Width := 100;
  ClearButton.Caption := 'Limpiar filtro';
  ClearButton.OnClick := ClearClick;

  SaveButton := TButton.Create(Self);
  SaveButton.Parent := Bottom;
  SaveButton.Left := 314;
  SaveButton.Top := 14;
  SaveButton.Width := 85;
  SaveButton.Caption := 'Aplicar';
  SaveButton.Default := True;
  SaveButton.OnClick := SaveClick;

  CancelButton := TButton.Create(Self);
  CancelButton.Parent := Bottom;
  CancelButton.Left := 405;
  CancelButton.Top := 14;
  CancelButton.Width := 85;
  CancelButton.Caption := 'Cancelar';
  CancelButton.Cancel := True;
  CancelButton.ModalResult := mrCancel;

  FScroll := TScrollBox.Create(Self);
  FScroll.Parent := Self;
  FScroll.Align := alClient;
  FScroll.BorderStyle := bsNone;
  FScroll.VertScrollBar.Tracking := True;
  if (AExisting <> nil) and (AExisting.Count > 0) then
    for I := 0 to AExisting.Count - 1 do
      AddRow(AExisting.Conditions[I])
  else
    AddRow(nil);
end;

destructor TColumnFilterDialog.Destroy;
var
  I: Integer;
begin
  FResultFilter.Free;
  for I := 0 to FRows.Count - 1 do
    TObject(FRows[I]).Free;
  FRows.Free;
  inherited Destroy;
end;

procedure TColumnFilterDialog.AddRow(ACondition: TFilterCondition);
var
  Row: TFilterRow;
  I: Integer;
begin
  Row := TFilterRow.Create(Self, FScroll, FField);
  Row.RemoveButton.OnClick := RemoveClick;
  if ACondition <> nil then
  begin
    if ACondition.Join = fjOr then
      Row.JoinBox.ItemIndex := 1;
    for I := 0 to Row.OperatorBox.Items.Count - 1 do
      if Integer(Row.OperatorBox.Items.Objects[I]) = Ord(ACondition.Operator) then
        Row.OperatorBox.ItemIndex := I;
    Row.ValueEdit.Text := ACondition.Value;
  end;
  FRows.Add(Row);
  ArrangeRows;
end;

procedure TColumnFilterDialog.ArrangeRows;
var
  I: Integer;
begin
  for I := 0 to FRows.Count - 1 do
    TFilterRow(FRows[I]).PositionAt(I);
end;

procedure TColumnFilterDialog.AddClick(Sender: TObject);
begin
  AddRow(nil);
  FScroll.VertScrollBar.Position := FScroll.VertScrollBar.Range;
end;

procedure TColumnFilterDialog.RemoveClick(Sender: TObject);
var
  Index: Integer;
begin
  Index := TButton(Sender).Tag;
  TFilterRow(FRows[Index]).Free;
  FRows.Delete(Index);
  if FRows.Count = 0 then
    AddRow(nil)
  else
    ArrangeRows;
end;

procedure TColumnFilterDialog.ClearClick(Sender: TObject);
begin
  FResultFilter.Free;
  FResultFilter := nil;
  ModalResult := mrOk;
end;

procedure TColumnFilterDialog.SaveClick(Sender: TObject);
var
  I: Integer;
  Row: TFilterRow;
  Condition: TFilterCondition;
  NewFilter: TColumnFilter;
begin
  NewFilter := TColumnFilter.Create(FField.FieldName);
  try
    for I := 0 to FRows.Count - 1 do
    begin
      Row := TFilterRow(FRows[I]);
      if (FField.DataType <> ftBoolean) and
        (Trim(Row.ValueEdit.Text) = '') then
        Continue;
      Condition := TFilterCondition.Create;
      try
        Condition.Operator := TFilterOperator(Integer(
          Row.OperatorBox.Items.Objects[Row.OperatorBox.ItemIndex]));
        if (NewFilter.Count > 0) and (Row.JoinBox.ItemIndex = 1) then
          Condition.Join := fjOr
        else
          Condition.Join := fjAnd;
        Condition.Value := Trim(Row.ValueEdit.Text);
        if IsNumberField(FField) then
          Condition.NumberValue := StrToFloat(Condition.Value)
        else if IsDateField(FField) then
          case FField.DataType of
            ftDate: Condition.DateValue := StrToDate(Condition.Value);
            ftTime: Condition.DateValue := StrToTime(Condition.Value);
          else
            Condition.DateValue := StrToDateTime(Condition.Value);
          end;
        NewFilter.Add(Condition);
      except
        Condition.Free;
        raise;
      end;
    end;
    FResultFilter.Free;
    if NewFilter.Count = 0 then
    begin
      FResultFilter := nil;
      NewFilter.Free;
      NewFilter := nil;
    end
    else
      FResultFilter := NewFilter;
    ModalResult := mrOk;
  except
    on E: Exception do
    begin
      NewFilter.Free;
      MessageDlg('Valor no valido: ' + E.Message, mtError, [mbOK], 0);
    end;
  end;
end;

function TColumnFilterDialog.TakeFilter: TColumnFilter;
begin
  Result := FResultFilter;
  FResultFilter := nil;
end;

end.

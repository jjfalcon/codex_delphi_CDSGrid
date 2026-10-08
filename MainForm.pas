unit MainForm;

interface

uses
  Classes, DB, DBClient, Forms, Controls, StdCtrls, ExtCtrls, DBGrids,
  DemoData;

type
  TAutoFitDBGrid = class(TDBGrid)
  private
    FStretchInProgress: Boolean;
    FHasBlankColumn: Boolean;
  protected
    procedure ColWidthsChanged; override;
    procedure Resize; override;
  public
    procedure ShowDataSet(ADataSet: TDataSet);
    procedure StretchBlankColumn;
    function SeparatorColumnAt(X, Y: Integer): Integer;
    function IsDataCellAt(X, Y: Integer): Boolean;
    procedure FitColumn(AIndex: Integer);
  end;

  TMainForm = class(TForm)
  private
    FDemo: TDemoData;
    FSource: TDataSource;
    FSelector: TComboBox;
    FGrid: TAutoFitDBGrid;
    FNewButton: TButton;
    FEditButton: TButton;
    FDeleteButton: TButton;
    function SelectedDataSet: TClientDataSet;
    procedure SelectDataSet(Sender: TObject);
    procedure DataChanged(Sender: TObject; Field: TField);
    procedure UpdateButtons;
    procedure OpenEditor(AIsNew: Boolean);
    procedure NewClick(Sender: TObject);
    procedure EditClick(Sender: TObject);
    procedure GridDblClick(Sender: TObject);
    procedure DeleteClick(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
  end;

var
  CDSMainForm: TMainForm;

implementation

uses
  Windows, SysUtils, Graphics, Grids, Dialogs, RecordEditor;

procedure TAutoFitDBGrid.ColWidthsChanged;
begin
  inherited ColWidthsChanged;
  StretchBlankColumn;
end;

procedure TAutoFitDBGrid.Resize;
begin
  inherited Resize;
  StretchBlankColumn;
end;

procedure TAutoFitDBGrid.ShowDataSet(ADataSet: TDataSet);
var
  I: Integer;
  Column: TColumn;
begin
  FHasBlankColumn := False;
  Columns.Clear;
  DataSource.DataSet := ADataSet;
  if ADataSet = nil then
    Exit;
  for I := 0 to ADataSet.FieldCount - 1 do
    if ADataSet.Fields[I].Visible then
    begin
      Column := Columns.Add;
      Column.FieldName := ADataSet.Fields[I].FieldName;
    end;
  Column := Columns.Add;
  Column.Title.Caption := '';
  Column.ReadOnly := True;
  Column.Width := 24;
  FHasBlankColumn := True;
  StretchBlankColumn;
end;

procedure TAutoFitDBGrid.StretchBlankColumn;
var
  Info: TGridDrawInfo;
  I, UsedWidth, NewWidth: Integer;
  BlankColumn: TColumn;
begin
  if FStretchInProgress or not FHasBlankColumn or (Columns.Count = 0)
    or (ClientWidth <= 0) then
    Exit;
  BlankColumn := Columns[Columns.Count - 1];
  CalcFixedInfo(Info);
  UsedWidth := 0;
  for I := 0 to ColCount - 1 do
    Inc(UsedWidth, ColWidths[I] + Info.Horz.EffectiveLineWidth);
  NewWidth := BlankColumn.Width + ClientWidth - UsedWidth;
  if NewWidth < 24 then
    NewWidth := 24;
  if NewWidth = BlankColumn.Width then
    Exit;
  FStretchInProgress := True;
  try
    BlankColumn.Width := NewWidth;
  finally
    FStretchInProgress := False;
  end;
end;
function TAutoFitDBGrid.SeparatorColumnAt(X, Y: Integer): Integer;
var
  Info: TGridDrawInfo;
  State: TGridState;
  RawIndex, SizingPos, SizingOfs: Integer;
begin
  Result := -1;
  if not (dgColumnResize in Options) then
    Exit;
  CalcDrawInfo(Info);
  CalcSizingState(X, Y, State, RawIndex, SizingPos, SizingOfs, Info);
  if (State <> gsColSizing) or (RawIndex < IndicatorOffset) then
    Exit;
  Result := RawToDataColumn(RawIndex);
  if (Result < 0) or (Result >= Columns.Count) then
    Result := -1;
  if (Result >= 0) and (Columns[Result].Field = nil) then
    Result := -1;
end;

function TAutoFitDBGrid.IsDataCellAt(X, Y: Integer): Boolean;
var
  Cell: TGridCoord;
  DataIndex: Integer;
begin
  Cell := MouseCoord(X, Y);
  Result := (Cell.Y >= FixedRows) and (Cell.X >= IndicatorOffset);
  if not Result then
    Exit;
  DataIndex := RawToDataColumn(Cell.X);
  Result := (DataIndex >= 0) and (DataIndex < Columns.Count);
  if Result then
    Result := Columns[DataIndex].Field <> nil;
end;

procedure TAutoFitDBGrid.FitColumn(AIndex: Integer);
var
  C: TDataSet;
  Field: TField;
  Bookmark: TBookmark;
  SavedFont: TFont;
  NewWidth, TextWidth: Integer;
begin
  if (AIndex < 0) or (AIndex >= Columns.Count) then
    Exit;
  Field := Columns[AIndex].Field;
  if Field = nil then
    Exit;
  SavedFont := TFont.Create;
  try
    SavedFont.Assign(Canvas.Font);
    Canvas.Font.Assign(Columns[AIndex].Title.Font);
    NewWidth := Canvas.TextWidth(Columns[AIndex].Title.Caption) + 16;
    if (Field <> nil) and (DataSource <> nil) then
    begin
      C := DataSource.DataSet;
      if (C <> nil) and C.Active and not C.IsEmpty then
      begin
        Canvas.Font.Assign(Columns[AIndex].Font);
        Bookmark := C.GetBookmark;
        C.DisableControls;
        try
          try
            C.First;
            while not C.Eof do
            begin
              TextWidth := Canvas.TextWidth(Field.DisplayText) + 16;
              if TextWidth > NewWidth then
                NewWidth := TextWidth;
              C.Next;
            end;
          finally
            C.GotoBookmark(Bookmark);
          end;
        finally
          C.FreeBookmark(Bookmark);
          C.EnableControls;
        end;
      end;
    end;
    if NewWidth < 40 then
      NewWidth := 40;
    if NewWidth > 600 then
      NewWidth := 600;
    Columns[AIndex].Width := NewWidth;
  finally
    Canvas.Font.Assign(SavedFont);
    SavedFont.Free;
  end;
end;
constructor TMainForm.Create(AOwner: TComponent);
var
  Bar: TPanel;
  SelectorLabel: TLabel;
begin
  inherited CreateNew(AOwner);
  Caption := 'Gestion generica de ClientDataSet';
  Position := poScreenCenter;
  Width := 880;
  Height := 560;

  FDemo := TDemoData.Create(Self);
  FSource := TDataSource.Create(Self);

  Bar := TPanel.Create(Self);
  Bar.Parent := Self;
  Bar.Align := alTop;
  Bar.Height := 75;
  Bar.BevelOuter := bvNone;

  SelectorLabel := TLabel.Create(Self);
  SelectorLabel.Parent := Bar;
  SelectorLabel.Left := 16;
  SelectorLabel.Top := 10;
  SelectorLabel.Caption := 'Conjunto de datos';

  FSelector := TComboBox.Create(Self);
  FSelector.Parent := Bar;
  FSelector.Left := 16;
  FSelector.Top := 29;
  FSelector.Width := 240;
  FSelector.Style := csDropDownList;
  FSelector.Items.Add('Usuarios');
  FSelector.Items.Add('Pacientes');
  FSelector.Items.Add('Tareas');
  FSelector.Items.Add('Medicamentos');
  FSelector.ItemIndex := 0;
  FSelector.OnChange := SelectDataSet;

  FNewButton := TButton.Create(Self);
  FNewButton.Parent := Bar;
  FNewButton.Left := 290;
  FNewButton.Top := 28;
  FNewButton.Width := 90;
  FNewButton.Caption := 'Nuevo';
  FNewButton.OnClick := NewClick;

  FEditButton := TButton.Create(Self);
  FEditButton.Parent := Bar;
  FEditButton.Left := 390;
  FEditButton.Top := 28;
  FEditButton.Width := 90;
  FEditButton.Caption := 'Editar';
  FEditButton.OnClick := EditClick;

  FDeleteButton := TButton.Create(Self);
  FDeleteButton.Parent := Bar;
  FDeleteButton.Left := 490;
  FDeleteButton.Top := 28;
  FDeleteButton.Width := 90;
  FDeleteButton.Caption := 'Borrar';
  FDeleteButton.OnClick := DeleteClick;

  FGrid := TAutoFitDBGrid.Create(Self);
  FGrid.Parent := Self;
  FGrid.Align := alClient;
  FGrid.ReadOnly := True;
  FGrid.Options := (FGrid.Options + [dgRowSelect, dgAlwaysShowSelection]) -
    [dgEditing];
  FGrid.DataSource := FSource;
  FGrid.OnDblClick := GridDblClick;

  FSource.OnDataChange := DataChanged;
  SelectDataSet(nil);
end;

function TMainForm.SelectedDataSet: TClientDataSet;
begin
  Result := nil;
  if FSelector.ItemIndex >= 0 then
    Result := FDemo.DataSets[FSelector.ItemIndex];
end;

procedure TMainForm.SelectDataSet(Sender: TObject);
var
  C: TClientDataSet;
begin
  C := SelectedDataSet;
  if C <> nil then
    if C.Active then
      if not C.IsEmpty then
        C.First;
  FGrid.ShowDataSet(C);
  UpdateButtons;
end;

procedure TMainForm.DataChanged(Sender: TObject; Field: TField);
begin
  UpdateButtons;
end;

procedure TMainForm.UpdateButtons;
var
  C: TClientDataSet;
  CanEdit: Boolean;
begin
  C := SelectedDataSet;
  CanEdit := Assigned(C) and C.Active;
  if CanEdit then
    CanEdit := C.CanModify;
  FNewButton.Enabled := CanEdit;
  if CanEdit then
  begin
    FEditButton.Enabled := not C.IsEmpty;
    FDeleteButton.Enabled := not C.IsEmpty;
  end
  else
  begin
    FEditButton.Enabled := False;
    FDeleteButton.Enabled := False;
  end;
end;

procedure TMainForm.OpenEditor(AIsNew: Boolean);
var
  C: TClientDataSet;
  Editor: TRecordEditorForm;
begin
  C := SelectedDataSet;
  if not Assigned(C) or not C.Active or not C.CanModify then
    Exit;
  if not AIsNew and C.IsEmpty then
    Exit;

  try
    if AIsNew then
      C.Append
    else
      C.Edit;
    try
      Editor := TRecordEditorForm.CreateEditor(Self, C, AIsNew);
      try
        Editor.ShowModal;
      finally
        Editor.Free;
      end;
    finally
      if C.State in [dsEdit, dsInsert] then
        C.Cancel;
    end;
  except
    on E: Exception do
      MessageDlg('No se pudo abrir el registro: ' + E.Message,
        mtError, [mbOK], 0);
  end;
  UpdateButtons;
end;

procedure TMainForm.NewClick(Sender: TObject);
begin
  OpenEditor(True);
end;

procedure TMainForm.EditClick(Sender: TObject);
begin
  OpenEditor(False);
end;

procedure TMainForm.GridDblClick(Sender: TObject);
var
  P: TPoint;
  ColumnIndex: Integer;
begin
  GetCursorPos(P);
  P := FGrid.ScreenToClient(P);
  if not PtInRect(FGrid.ClientRect, P) then
    Exit;
  ColumnIndex := FGrid.SeparatorColumnAt(P.X, P.Y);
  if ColumnIndex >= 0 then
    FGrid.FitColumn(ColumnIndex)
  else if FGrid.IsDataCellAt(P.X, P.Y) then
    OpenEditor(False);
end;
procedure TMainForm.DeleteClick(Sender: TObject);
var
  C: TClientDataSet;
begin
  C := SelectedDataSet;
  if not Assigned(C) or not C.Active or C.IsEmpty then
    Exit;
  if MessageDlg('Borrar el registro seleccionado?', mtConfirmation,
    [mbYes, mbNo], 0) <> mrYes then
    Exit;
  try
    C.Delete;
  except
    on E: Exception do
      MessageDlg('No se pudo borrar: ' + E.Message, mtError, [mbOK], 0);
  end;
  UpdateButtons;
end;

end.

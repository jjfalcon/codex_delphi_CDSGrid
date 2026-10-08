unit MainForm;

interface

uses
  Classes, DB, DBClient, Forms, Controls, StdCtrls, ExtCtrls, DBGrids,
  Windows, Grids,
  DemoData, ColumnFilter;

type
  TFilterStateEvent = function(const FieldName: string): Boolean of object;
  TFilterClickEvent = procedure(Column: TColumn) of object;
  TSortStateEvent = function(const FieldName: string): Integer of object;

  TAutoFitDBGrid = class(TDBGrid)
  private
    FStretchInProgress: Boolean;
    FHasBlankColumn: Boolean;
    FOnFilterState: TFilterStateEvent;
    FOnFilterClick: TFilterClickEvent;
    FOnSortState: TSortStateEvent;
    FOnLayoutChanged: TNotifyEvent;
    function SortIconAt(X, Y: Integer): Integer;
    function FilterIconAt(X, Y: Integer): Integer;
  protected
    procedure ColWidthsChanged; override;
    procedure ColumnMoved(FromIndex, ToIndex: Longint); override;
    procedure Resize; override;
    procedure DrawCell(ACol, ARow: Longint; ARect: TRect;
      AState: TGridDrawState); override;
    procedure TitleClick(Column: TColumn); override;
  public
    procedure ShowDataSet(ADataSet: TDataSet);
    procedure StretchBlankColumn;
    function SeparatorColumnAt(X, Y: Integer): Integer;
    function IsDataCellAt(X, Y: Integer): Boolean;
    procedure FitColumn(AIndex: Integer);
    property OnFilterState: TFilterStateEvent read FOnFilterState
      write FOnFilterState;
    property OnFilterClick: TFilterClickEvent read FOnFilterClick
      write FOnFilterClick;
    property OnSortState: TSortStateEvent read FOnSortState
      write FOnSortState;
    property OnLayoutChanged: TNotifyEvent read FOnLayoutChanged
      write FOnLayoutChanged;
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
    FSearchButton: TButton;
    FColumnsButton: TButton;
    FExportButton: TButton;
    FSearchFrame: TFrame;
    FSearchEdit: TEdit;
    FFilterCheck: TCheckBox;
    FFooterPanel: TPanel;
    FFooterLabel: TLabel;
    FFilteredDataSet: TClientDataSet;
    FSortedDataSet: TClientDataSet;
    FSortFields: TStringList;
    FColumnFilters: TStringList;
    FHiddenColumns: array[0..3] of TStringList;
    FSearchText: string;
    FSettingsPath: string;
    FActiveDataSetIndex: Integer;
    FLoadingConfig: Boolean;
    FSettingsWarningShown: Boolean;
    FConfigSaveTimer: TTimer;
    function SelectedDataSet: TClientDataSet;
    procedure SelectDataSet(Sender: TObject);
    procedure DataChanged(Sender: TObject; Field: TField);
    procedure UpdateButtons;
    procedure UpdateFooter;
    procedure OpenEditor(AIsNew: Boolean);
    procedure NewClick(Sender: TObject);
    procedure EditClick(Sender: TObject);
    procedure GridDblClick(Sender: TObject);
    procedure DeleteClick(Sender: TObject);
    procedure SearchClick(Sender: TObject);
    procedure ColumnsClick(Sender: TObject);
    procedure ExportClick(Sender: TObject);
    procedure ApplyColumnVisibility;
    procedure CloseSearchClick(Sender: TObject);
    procedure SearchChanged(Sender: TObject);
    procedure ApplySearch;
    procedure SearchFilterRecord(DataSet: TDataSet; var Accept: Boolean);
    procedure GridTitleClick(Column: TColumn);
    procedure GridColumnMoved(Sender: TObject;
      FromIndex, ToIndex: Integer);
    procedure GridLayoutChanged(Sender: TObject);
    procedure ConfigSaveTimerTick(Sender: TObject);
    procedure MarkConfigChanged;
    procedure SaveCurrentConfig;
    procedure LoadCurrentConfig;
    function FindGridColumn(const FieldName: string): TColumn;
    procedure ApplySort;
    procedure ClearSort;
    procedure UpdateSortTitles;
    procedure ClearColumnFilters;
    function GridFilterState(const FieldName: string): Boolean;
    procedure GridFilterClick(Column: TColumn);
    function GridSortState(const FieldName: string): Integer;
    procedure GridDrawColumnCell(Sender: TObject; const Rect: TRect;
      DataCol: Integer; Column: TColumn; State: TGridDrawState);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  CDSMainForm: TMainForm;

implementation

uses
  SysUtils, Graphics, Dialogs, IniFiles, RecordEditor, ColumnChooser;

function HexEncode(const Value: string): string;
const
  Digits = '0123456789ABCDEF';
var
  I: Integer;
  B: Byte;
begin
  SetLength(Result, Length(Value) * 2);
  for I := 1 to Length(Value) do
  begin
    B := Ord(Value[I]);
    Result[I * 2 - 1] := Digits[(B shr 4) + 1];
    Result[I * 2] := Digits[(B and $0F) + 1];
  end;
end;

function HexDigit(C: Char): Integer;
begin
  case C of
    '0'..'9': Result := Ord(C) - Ord('0');
    'A'..'F': Result := Ord(C) - Ord('A') + 10;
    'a'..'f': Result := Ord(C) - Ord('a') + 10;
  else
    Result := -1;
  end;
end;

function HexDecode(const Value: string): string;
var
  I, HighDigit, LowDigit: Integer;
begin
  Result := '';
  if (Length(Value) mod 2) <> 0 then
    Exit;
  SetLength(Result, Length(Value) div 2);
  for I := 1 to Length(Result) do
  begin
    HighDigit := HexDigit(Value[I * 2 - 1]);
    LowDigit := HexDigit(Value[I * 2]);
    if (HighDigit < 0) or (LowDigit < 0) then
    begin
      Result := '';
      Exit;
    end;
    Result[I] := Char(HighDigit * 16 + LowDigit);
  end;
end;

function EscapeCsvField(const Value: string): string;
begin
  if (Pos(';', Value) > 0) or (Pos('"', Value) > 0) or
    (Pos(#13, Value) > 0) or (Pos(#10, Value) > 0) then
    Result := '"' + StringReplace(Value, '"', '""', [rfReplaceAll]) + '"'
  else
    Result := Value;
end;

function FilterOperatorAllowed(Field: TField;
  AOperator: TFilterOperator): Boolean;
begin
  if Field.DataType = ftBoolean then
    Result := AOperator in [foTrue, foFalse]
  else if Field.DataType in [ftSmallint, ftInteger, ftWord, ftFloat,
    ftCurrency, ftBCD, ftAutoInc, ftLargeint, ftDate, ftTime, ftDateTime] then
    Result := AOperator in [foEqual, foNotEqual, foGreater, foLess]
  else
    Result := AOperator in [foContains, foNotContains, foEqual, foNotEqual];
end;

procedure TAutoFitDBGrid.ColWidthsChanged;
begin
  inherited ColWidthsChanged;
  StretchBlankColumn;
  if Assigned(FOnLayoutChanged) then
    FOnLayoutChanged(Self);
end;

procedure TAutoFitDBGrid.ColumnMoved(FromIndex, ToIndex: Longint);
var
  I: Integer;
begin
  inherited ColumnMoved(FromIndex, ToIndex);
  if FHasBlankColumn then
    for I := 0 to Columns.Count - 1 do
      if Columns[I].Field = nil then
      begin
        if I <> Columns.Count - 1 then
          Columns[I].Index := Columns.Count - 1;
        Break;
      end;
  StretchBlankColumn;
end;

procedure TAutoFitDBGrid.Resize;
begin
  inherited Resize;
  StretchBlankColumn;
end;

function TAutoFitDBGrid.SortIconAt(X, Y: Integer): Integer;
var
  Cell: TGridCoord;
  R: TRect;
begin
  Result := -1;
  if not PtInRect(ClientRect, Point(X, Y)) then
    Exit;
  Cell := MouseCoord(X, Y);
  if (Cell.Y <> FixedRows - 1) or (Cell.X < IndicatorOffset) then
    Exit;
  Result := RawToDataColumn(Cell.X);
  if (Result < 0) or (Result >= Columns.Count) then
  begin
    Result := -1;
    Exit;
  end;
  if (Columns[Result].Field = nil) or Columns[Result].Field.IsBlob then
  begin
    Result := -1;
    Exit;
  end;
  R := CellRect(Cell.X, Cell.Y);
  if (X < R.Left + 2) or (X >= R.Left + 22) then
    Result := -1;
end;

function TAutoFitDBGrid.FilterIconAt(X, Y: Integer): Integer;
var
  Cell: TGridCoord;
  R: TRect;
begin
  Result := -1;
  if not PtInRect(ClientRect, Point(X, Y)) then
    Exit;
  Cell := MouseCoord(X, Y);
  if (Cell.Y <> FixedRows - 1) or (Cell.X < IndicatorOffset) then
    Exit;
  Result := RawToDataColumn(Cell.X);
  if (Result < 0) or (Result >= Columns.Count) then
  begin
    Result := -1;
    Exit;
  end;
  if Columns[Result].Field = nil then
  begin
    Result := -1;
    Exit;
  end;
  R := CellRect(Cell.X, Cell.Y);
  if (X < R.Right - 23) or (X >= R.Right - 5) then
    Result := -1;
end;

procedure TAutoFitDBGrid.DrawCell(ACol, ARow: Longint; ARect: TRect;
  AState: TGridDrawState);
var
  DataIndex, X, Y, Direction: Integer;
  Active: Boolean;
  P: array[0..5] of TPoint;
  Arrow: array[0..2] of TPoint;
  R: TRect;
begin
  inherited DrawCell(ACol, ARow, ARect, AState);
  if (ARow <> FixedRows - 1) or (ACol < IndicatorOffset) then
    Exit;
  DataIndex := RawToDataColumn(ACol);
  if (DataIndex < 0) or (DataIndex >= Columns.Count) then
    Exit;
  if Columns[DataIndex].Field = nil then
    Exit;
  if not Columns[DataIndex].Field.IsBlob then
  begin
    Direction := 0;
    if Assigned(FOnSortState) then
      Direction := FOnSortState(Columns[DataIndex].FieldName);
    R := ARect;
    Inc(R.Left, 2);
    R.Right := R.Left + 18;
    Canvas.Brush.Color := clBtnFace;
    Canvas.FillRect(R);
    X := R.Left + 8;
    Y := (R.Top + R.Bottom) div 2;
    if Direction = 0 then
    begin
      Canvas.Pen.Color := clGrayText;
      Canvas.Brush.Color := clBtnFace;
      Arrow[0] := Point(X - 4, Y - 1);
      Arrow[1] := Point(X + 4, Y - 1);
      Arrow[2] := Point(X, Y - 5);
      Canvas.Polygon(Arrow);
      Arrow[0] := Point(X - 4, Y + 1);
      Arrow[1] := Point(X + 4, Y + 1);
      Arrow[2] := Point(X, Y + 5);
      Canvas.Polygon(Arrow);
    end
    else
    begin
      Canvas.Pen.Color := clBlack;
      Canvas.Brush.Color := clBlack;
      if Direction = 1 then
      begin
        Arrow[0] := Point(X - 4, Y + 3);
        Arrow[1] := Point(X + 4, Y + 3);
        Arrow[2] := Point(X, Y - 4);
      end
      else
      begin
        Arrow[0] := Point(X - 4, Y - 3);
        Arrow[1] := Point(X + 4, Y - 3);
        Arrow[2] := Point(X, Y + 4);
      end;
      Canvas.Polygon(Arrow);
    end;
  end;
  Active := Assigned(FOnFilterState) and
    FOnFilterState(Columns[DataIndex].FieldName);
  R := ARect;
  R.Left := R.Right - 23;
  Dec(R.Right, 5);
  Canvas.Brush.Color := clBtnFace;
  Canvas.FillRect(R);
  X := (R.Left + R.Right) div 2;
  Y := (R.Top + R.Bottom) div 2;
  P[0] := Point(X - 6, Y - 4);
  P[1] := Point(X + 6, Y - 4);
  P[2] := Point(X + 2, Y);
  P[3] := Point(X + 2, Y + 5);
  P[4] := Point(X - 1, Y + 3);
  P[5] := Point(X - 1, Y);
  if Active then
  begin
    R.Left := X - 8;
    R.Right := X + 8;
    R.Top := Y - 8;
    R.Bottom := Y + 8;
    Canvas.Brush.Color := RGB(55, 115, 55);
    Canvas.FillRect(R);
    Canvas.Pen.Color := clWhite;
    Canvas.Brush.Color := clWhite;
  end
  else
  begin
    Canvas.Pen.Color := clGrayText;
    Canvas.Brush.Color := clBtnFace;
  end;
  Canvas.Polygon(P);
end;

procedure TAutoFitDBGrid.TitleClick(Column: TColumn);
var
  P: TPoint;
begin
  GetCursorPos(P);
  P := ScreenToClient(P);
  if (FilterIconAt(P.X, P.Y) = Column.Index) and
    Assigned(FOnFilterClick) then
    FOnFilterClick(Column)
  else if SortIconAt(P.X, P.Y) = Column.Index then
    inherited TitleClick(Column);
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
      Column.Width := Column.Width + 24;
      if not Column.Field.IsBlob then
      begin
        Column.Title.Caption := '         ' + Column.Field.DisplayLabel;
        Column.Width := Column.Width + 30;
      end;    end;
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
    NewWidth := Canvas.TextWidth(Columns[AIndex].Title.Caption) + 40;
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
  SearchLabel: TLabel;
  CloseSearchButton: TButton;
  I: Integer;
begin
  inherited CreateNew(AOwner);
  FLoadingConfig := True;
  FActiveDataSetIndex := -1;
  FSettingsPath := ExtractFilePath(ParamStr(0)) + 'DelphiCDSDemo.ini';
  Caption := 'Gestion generica de ClientDataSet';
  Position := poScreenCenter;
  Width := 980;
  Height := 560;
  Constraints.MinWidth := 910;

  FDemo := TDemoData.Create(Self);
  FSource := TDataSource.Create(Self);
  FSortFields := TStringList.Create;
  FColumnFilters := TStringList.Create;
  for I := Low(FHiddenColumns) to High(FHiddenColumns) do
    FHiddenColumns[I] := TStringList.Create;
  FConfigSaveTimer := TTimer.Create(Self);
  FConfigSaveTimer.Enabled := False;
  FConfigSaveTimer.Interval := 350;
  FConfigSaveTimer.OnTimer := ConfigSaveTimerTick;

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

  FSearchButton := TButton.Create(Self);
  FSearchButton.Parent := Bar;
  FSearchButton.Left := 590;
  FSearchButton.Top := 28;
  FSearchButton.Width := 90;
  FSearchButton.Caption := 'Buscar';
  FSearchButton.OnClick := SearchClick;

  FColumnsButton := TButton.Create(Self);
  FColumnsButton.Parent := Bar;
  FColumnsButton.Left := 690;
  FColumnsButton.Top := 28;
  FColumnsButton.Width := 90;
  FColumnsButton.Caption := 'Columnas...';
  FColumnsButton.OnClick := ColumnsClick;

  FExportButton := TButton.Create(Self);
  FExportButton.Parent := Bar;
  FExportButton.Left := 790;
  FExportButton.Top := 28;
  FExportButton.Width := 90;
  FExportButton.Caption := 'Exportar...';
  FExportButton.OnClick := ExportClick;

  FSearchFrame := TFrame.Create(Self);
  FSearchFrame.Parent := Self;
  FSearchFrame.Align := alTop;
  FSearchFrame.Height := 44;
  FSearchFrame.Visible := False;

  SearchLabel := TLabel.Create(Self);
  SearchLabel.Parent := FSearchFrame;
  SearchLabel.Left := 16;
  SearchLabel.Top := 14;
  SearchLabel.Caption := 'Buscar texto:';

  FSearchEdit := TEdit.Create(Self);
  FSearchEdit.Parent := FSearchFrame;
  FSearchEdit.Left := 105;
  FSearchEdit.Top := 10;
  FSearchEdit.Width := FSearchFrame.Width - 305;
  FSearchEdit.Anchors := [akLeft, akTop, akRight];
  FSearchEdit.OnChange := SearchChanged;

  FFilterCheck := TCheckBox.Create(Self);
  FFilterCheck.Parent := FSearchFrame;
  FFilterCheck.Left := FSearchFrame.Width - 190;
  FFilterCheck.Top := 12;
  FFilterCheck.Width := 85;
  FFilterCheck.Caption := 'Filtrar';
  FFilterCheck.Anchors := [akTop, akRight];
  FFilterCheck.OnClick := SearchChanged;

  CloseSearchButton := TButton.Create(Self);
  CloseSearchButton.Parent := FSearchFrame;
  CloseSearchButton.Left := FSearchFrame.Width - 91;
  CloseSearchButton.Top := 9;
  CloseSearchButton.Width := 75;
  CloseSearchButton.Caption := 'Cerrar';
  CloseSearchButton.Anchors := [akTop, akRight];
  CloseSearchButton.OnClick := CloseSearchClick;

  FGrid := TAutoFitDBGrid.Create(Self);
  FGrid.Parent := Self;
  FGrid.Align := alClient;
  FGrid.ReadOnly := True;
  FGrid.Options := (FGrid.Options +
    [dgRowSelect, dgAlwaysShowSelection]) -
    [dgEditing];
  FGrid.DataSource := FSource;
  FGrid.OnDblClick := GridDblClick;
  FGrid.Hint := 'Flechas: ordenar; Mayus + clic: combinar; embudo: filtrar.';
  FGrid.ShowHint := True;
  FGrid.OnDrawColumnCell := GridDrawColumnCell;
  FGrid.OnTitleClick := GridTitleClick;
  FGrid.OnFilterState := GridFilterState;
  FGrid.OnFilterClick := GridFilterClick;
  FGrid.OnSortState := GridSortState;
  FGrid.OnColumnMoved := GridColumnMoved;
  FGrid.OnLayoutChanged := GridLayoutChanged;

  FFooterPanel := TPanel.Create(Self);
  FFooterPanel.Parent := Self;
  FFooterPanel.Align := alBottom;
  FFooterPanel.Height := 24;
  FFooterPanel.BevelOuter := bvNone;

  FFooterLabel := TLabel.Create(Self);
  FFooterLabel.Parent := FFooterPanel;
  FFooterLabel.Align := alRight;
  FFooterLabel.Alignment := taRightJustify;
  FFooterLabel.Layout := tlCenter;
  FFooterLabel.AutoSize := False;
  FFooterLabel.Width := 258;
  FFooterLabel.Caption := 'Registro 0 de 0 ';

  FSource.OnDataChange := DataChanged;
  SelectDataSet(nil);
end;

destructor TMainForm.Destroy;
var
  I: Integer;
begin
  FConfigSaveTimer.Enabled := False;
  SaveCurrentConfig;
  FGrid.OnFilterState := nil;
  FGrid.OnFilterClick := nil;
  FGrid.OnSortState := nil;
  FGrid.OnLayoutChanged := nil;
  ClearColumnFilters;
  FColumnFilters.Free;
  FSortFields.Free;
  for I := Low(FHiddenColumns) to High(FHiddenColumns) do
    FHiddenColumns[I].Free;
  inherited Destroy;
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
  FConfigSaveTimer.Enabled := False;
  SaveCurrentConfig;
  FLoadingConfig := True;
  try
    if FFilteredDataSet <> nil then
    begin
      FFilteredDataSet.Filtered := False;
      FFilteredDataSet.OnFilterRecord := nil;
      FFilteredDataSet := nil;
    end;
    ClearSort;
    ClearColumnFilters;
    FActiveDataSetIndex := FSelector.ItemIndex;
    C := SelectedDataSet;
    if C <> nil then
      if C.Active then
        if not C.IsEmpty then
          C.First;
    FGrid.ShowDataSet(C);
    LoadCurrentConfig;
    ApplySearch;
    UpdateButtons;
  finally
    FLoadingConfig := False;
  end;
end;

function TMainForm.FindGridColumn(const FieldName: string): TColumn;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to FGrid.Columns.Count - 1 do
    if (FGrid.Columns[I].Field <> nil) and
      (AnsiCompareText(FGrid.Columns[I].FieldName, FieldName) = 0) then
    begin
      Result := FGrid.Columns[I];
      Exit;
    end;
end;

procedure TMainForm.MarkConfigChanged;
begin
  if FLoadingConfig or (FActiveDataSetIndex < 0) then
    Exit;
  FConfigSaveTimer.Enabled := False;
  FConfigSaveTimer.Enabled := True;
end;

procedure TMainForm.GridLayoutChanged(Sender: TObject);
begin
  MarkConfigChanged;
end;

procedure TMainForm.GridColumnMoved(Sender: TObject;
  FromIndex, ToIndex: Integer);
begin
  MarkConfigChanged;
end;

procedure TMainForm.ConfigSaveTimerTick(Sender: TObject);
begin
  FConfigSaveTimer.Enabled := False;
  SaveCurrentConfig;
end;

procedure TMainForm.SaveCurrentConfig;
var
  Ini: TMemIniFile;
  Section, Key, Suffix: string;
  I, J, Count, WidthValue: Integer;
  OldWidths: array of Integer;
  Column: TColumn;
  Filter: TColumnFilter;
  Condition: TFilterCondition;
begin
  if FLoadingConfig or (FActiveDataSetIndex < 0) or
    (FActiveDataSetIndex >= FSelector.Items.Count) then
    Exit;
  if FGrid.DataSource.DataSet <> FDemo.DataSets[FActiveDataSetIndex] then
    Exit;
  Section := FSelector.Items[FActiveDataSetIndex];
  Ini := nil;
  try
    Ini := TMemIniFile.Create(FSettingsPath);
    SetLength(OldWidths, FGrid.Columns.Count);
    for I := 0 to FGrid.Columns.Count - 1 do
      if FGrid.Columns[I].Field <> nil then
        OldWidths[I] := Ini.ReadInteger(Section,
          'Width_' + FGrid.Columns[I].FieldName, 80);
    Ini.EraseSection(Section);
    Ini.WriteInteger(Section, 'Version', 1);
    Count := 0;
    for I := 0 to FGrid.Columns.Count - 1 do
    begin
      Column := FGrid.Columns[I];
      if Column.Field = nil then
        Continue;
      Inc(Count);
      Ini.WriteString(Section, 'Column' + IntToStr(Count),
        Column.FieldName);
      WidthValue := Column.Width;
      if WidthValue < 40 then
        WidthValue := OldWidths[I];
      Ini.WriteInteger(Section, 'Width_' + Column.FieldName, WidthValue);
      Ini.WriteBool(Section, 'Visible_' + Column.FieldName, Column.Visible);
    end;
    Ini.WriteInteger(Section, 'ColumnCount', Count);

    Ini.WriteInteger(Section, 'SortCount', FSortFields.Count);
    for I := 0 to FSortFields.Count - 1 do
    begin
      Key := IntToStr(I + 1);
      Ini.WriteString(Section, 'SortField' + Key, FSortFields[I]);
      Ini.WriteInteger(Section, 'SortDirection' + Key,
        Integer(FSortFields.Objects[I]));
    end;

    Ini.WriteInteger(Section, 'FilterCount', FColumnFilters.Count);
    for I := 0 to FColumnFilters.Count - 1 do
    begin
      Filter := TColumnFilter(FColumnFilters.Objects[I]);
      Key := IntToStr(I + 1);
      Ini.WriteString(Section, 'FilterField' + Key, Filter.FieldName);
      Ini.WriteInteger(Section, 'ConditionCount' + Key, Filter.Count);
      for J := 0 to Filter.Count - 1 do
      begin
        Condition := Filter.Conditions[J];
        Suffix := Key + '_' + IntToStr(J + 1);
        Ini.WriteInteger(Section, 'Operator' + Suffix,
          Ord(Condition.Operator));
        Ini.WriteInteger(Section, 'Join' + Suffix, Ord(Condition.Join));
        Ini.WriteString(Section, 'Value' + Suffix,
          HexEncode(Condition.Value));
      end;
    end;
    Ini.WriteBool(Section, 'GlobalFilterEnabled',
      FFilterCheck.Checked and (FSearchEdit.Text <> ''));
    if FFilterCheck.Checked and (FSearchEdit.Text <> '') then
      Ini.WriteString(Section, 'GlobalFilterText',
        HexEncode(FSearchEdit.Text));
    Ini.UpdateFile;
  except
    on E: Exception do
      if not FSettingsWarningShown then
      begin
        FSettingsWarningShown := True;
        MessageDlg('No se pudo guardar la configuracion en ' +
          FSettingsPath + ': ' + E.Message, mtWarning, [mbOK], 0);
      end;
  end;
  Ini.Free;
end;

procedure TMainForm.LoadCurrentConfig;
var
  Ini: TMemIniFile;
  Section, FieldName, Key, Suffix, Value: string;
  I, J, Count, Position, WidthValue, Direction, OpValue, JoinValue: Integer;
  VisibleCount: Integer;
  Column: TColumn;
  Filter: TColumnFilter;
  Condition: TFilterCondition;
  Seen: TStringList;
begin
  if (FActiveDataSetIndex < 0) or
    (FActiveDataSetIndex >= FSelector.Items.Count) then
    Exit;
  FHiddenColumns[FActiveDataSetIndex].Clear;
  FSearchEdit.Text := '';
  FFilterCheck.Checked := False;
  FSearchText := '';
  if not FileExists(FSettingsPath) then
    Exit;
  Section := FSelector.Items[FActiveDataSetIndex];
  Ini := TMemIniFile.Create(FSettingsPath);
  Seen := TStringList.Create;
  try
    if Ini.ReadInteger(Section, 'Version', 0) <> 1 then
      Exit;
    Count := Ini.ReadInteger(Section, 'ColumnCount', 0);
    if Count > FGrid.Columns.Count then
      Count := FGrid.Columns.Count;
    Position := 0;
    for I := 1 to Count do
    begin
      FieldName := Ini.ReadString(Section, 'Column' + IntToStr(I), '');
      Column := FindGridColumn(FieldName);
      if (Column <> nil) and (Seen.IndexOf(FieldName) < 0) then
      begin
        Column.Index := Position;
        Seen.Add(FieldName);
        Inc(Position);
      end;
    end;

    VisibleCount := 0;
    for I := 0 to FGrid.Columns.Count - 1 do
    begin
      Column := FGrid.Columns[I];
      if Column.Field = nil then
        Continue;
      if Ini.ReadBool(Section, 'Visible_' + Column.FieldName, True) then
        Inc(VisibleCount)
      else
        FHiddenColumns[FActiveDataSetIndex].Add(Column.FieldName);
    end;
    if (VisibleCount = 0) and (FGrid.Columns.Count > 1) and
      (FGrid.Columns[0].Field <> nil) then
    begin
      J := FHiddenColumns[FActiveDataSetIndex].IndexOf(
        FGrid.Columns[0].FieldName);
      if J >= 0 then
        FHiddenColumns[FActiveDataSetIndex].Delete(J);
    end;
    ApplyColumnVisibility;

    Count := Ini.ReadInteger(Section, 'SortCount', 0);
    if Count > 16 then
      Count := 16;
    for I := 1 to Count do
    begin
      Key := IntToStr(I);
      FieldName := Ini.ReadString(Section, 'SortField' + Key, '');
      Direction := Ini.ReadInteger(Section, 'SortDirection' + Key, 0);
      Column := FindGridColumn(FieldName);
      if (Column <> nil) and Column.Visible and
        not Column.Field.IsBlob and (Direction in [1, 2]) and
        (FSortFields.IndexOf(FieldName) < 0) then
        FSortFields.AddObject(FieldName, TObject(Direction));
    end;
    if FSortFields.Count > 0 then
      ApplySort;

    Count := Ini.ReadInteger(Section, 'FilterCount', 0);
    if Count > 1000 then
      Count := 1000;
    for I := 1 to Count do
    begin
      Key := IntToStr(I);
      FieldName := Ini.ReadString(Section, 'FilterField' + Key, '');
      Column := FindGridColumn(FieldName);
      if (Column = nil) or not Column.Visible or
        (FColumnFilters.IndexOf(FieldName) >= 0) then
        Continue;
      Filter := TColumnFilter.Create(FieldName);
      try
        J := Ini.ReadInteger(Section, 'ConditionCount' + Key, 0);
        if J > 1000 then
          J := 1000;
        for Position := 1 to J do
        begin
          Suffix := Key + '_' + IntToStr(Position);
          OpValue := Ini.ReadInteger(Section, 'Operator' + Suffix, -1);
          JoinValue := Ini.ReadInteger(Section, 'Join' + Suffix, -1);
          if (OpValue < Ord(Low(TFilterOperator))) or
            (OpValue > Ord(High(TFilterOperator))) or
            (JoinValue < Ord(Low(TFilterJoin))) or
            (JoinValue > Ord(High(TFilterJoin))) then
            Continue;
          if not FilterOperatorAllowed(Column.Field,
            TFilterOperator(OpValue)) then
            Continue;
          Value := HexDecode(Ini.ReadString(Section,
            'Value' + Suffix, ''));
          if (Value = '') and not
            (TFilterOperator(OpValue) in [foTrue, foFalse]) then
            Continue;
          Condition := TFilterCondition.Create;
          try
            Condition.Operator := TFilterOperator(OpValue);
            Condition.Join := TFilterJoin(JoinValue);
            Condition.SetValueForField(Column.Field, Value);
            Filter.Add(Condition);
          except
            Condition.Free;
          end;
        end;
        if Filter.Count > 0 then
        begin
          FColumnFilters.AddObject(FieldName, Filter);
          Filter := nil;
        end;
      finally
        Filter.Free;
      end;
    end;

    if Ini.ReadBool(Section, 'GlobalFilterEnabled', False) then
    begin
      Value := HexDecode(Ini.ReadString(Section,
        'GlobalFilterText', ''));
      if Value <> '' then
      begin
        FSearchEdit.Text := Value;
        FSearchText := AnsiUpperCase(Value);
        FFilterCheck.Checked := True;
        FSearchFrame.Visible := True;
      end;
    end;

    for I := 0 to FGrid.Columns.Count - 1 do
    begin
      Column := FGrid.Columns[I];
      if Column.Field = nil then
        Continue;
      WidthValue := Ini.ReadInteger(Section,
        'Width_' + Column.FieldName, Column.Width);
      if (WidthValue >= 40) and (WidthValue <= 2000) then
        Column.Width := WidthValue;
    end;
    FGrid.StretchBlankColumn;
  finally
    Seen.Free;
    Ini.Free;
  end;
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
  FExportButton.Enabled := CanEdit;
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
  UpdateFooter;
end;

procedure TMainForm.UpdateFooter;
var
  C: TClientDataSet;
  X, Y: Integer;
begin
  X := 0;
  Y := 0;
  C := SelectedDataSet;
  if Assigned(C) and C.Active and (FGrid.DataSource.DataSet = C) then
    if not C.IsEmpty then
    begin
      Y := C.RecordCount;
      try
        X := C.RecNo;
      except
        X := 0;
      end;
      if X < 1 then
        X := 0
      else if X > Y then
        X := Y;
    end;
  if Assigned(FFooterLabel) then
    FFooterLabel.Caption := Format('Registro %d de %d ', [X, Y]);
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

procedure TMainForm.ApplyColumnVisibility;
var
  I: Integer;
  Hidden: TStringList;
begin
  if (FSelector.ItemIndex < Low(FHiddenColumns)) or
    (FSelector.ItemIndex > High(FHiddenColumns)) then
    Exit;
  Hidden := FHiddenColumns[FSelector.ItemIndex];
  for I := 0 to FGrid.Columns.Count - 1 do
    if FGrid.Columns[I].Field <> nil then
      FGrid.Columns[I].Visible :=
        Hidden.IndexOf(FGrid.Columns[I].FieldName) < 0;
  FGrid.StretchBlankColumn;
end;

procedure TMainForm.ColumnsClick(Sender: TObject);
var
  Chooser: TColumnChooserForm;
  NewHidden: TStringList;
  I: Integer;
  Changed, SortChanged: Boolean;
  Column: TColumn;
begin
  if (FSelector.ItemIndex < Low(FHiddenColumns)) or
    (FSelector.ItemIndex > High(FHiddenColumns)) then
    Exit;
  Chooser := TColumnChooserForm.CreateForGrid(Self, FGrid);
  try
    if Chooser.ShowModal <> mrOk then
      Exit;
    NewHidden := TStringList.Create;
    try
      Changed := False;
      for I := 0 to FGrid.Columns.Count - 1 do
      begin
        Column := FGrid.Columns[I];
        if Column.Field = nil then
          Continue;
        if Column.Visible <> Chooser.ColumnVisible(Column) then
          Changed := True;
        if not Chooser.ColumnVisible(Column) then
          NewHidden.Add(Column.FieldName);
      end;
      for I := 0 to Chooser.ColumnCount - 1 do
        if Chooser.Columns[I].Index <> I then
          Changed := True;
      if not Changed then
        Exit;
      if FFilteredDataSet <> nil then
      begin
        FFilteredDataSet.Filtered := False;
        FFilteredDataSet.OnFilterRecord := nil;
        FFilteredDataSet := nil;
      end;
      for I := FColumnFilters.Count - 1 downto 0 do
        if NewHidden.IndexOf(FColumnFilters[I]) >= 0 then
        begin
          FColumnFilters.Objects[I].Free;
          FColumnFilters.Delete(I);
        end;
      SortChanged := False;
      for I := FSortFields.Count - 1 downto 0 do
        if NewHidden.IndexOf(FSortFields[I]) >= 0 then
        begin
          FSortFields.Delete(I);
          SortChanged := True;
        end;
      for I := 0 to Chooser.ColumnCount - 1 do
        Chooser.Columns[I].Index := I;
      SaveCurrentConfig;
      FHiddenColumns[FSelector.ItemIndex].Assign(NewHidden);
      ApplyColumnVisibility;
      if SortChanged then
        ApplySort;
      ApplySearch;
      MarkConfigChanged;
    finally
      NewHidden.Free;
    end;
  finally
    Chooser.Free;
  end;
end;

procedure TMainForm.ExportClick(Sender: TObject);
var
  C: TClientDataSet;
  Dialog: TSaveDialog;
  Stream: TFileStream;
  Columns: TList;
  I, Exported: Integer;
  Line, Utf8Line: string;
  Utf8Data: UTF8String;
  Bom: array[0..2] of Byte;
  Bookmark: TBookmark;

  procedure WriteLine(const S: string);
  begin
    Utf8Line := S + #13#10;
    Utf8Data := UTF8Encode(Utf8Line);
    if Length(Utf8Data) > 0 then
      Stream.WriteBuffer(PChar(Utf8Data)^, Length(Utf8Data));
  end;

  function BuildLine(Header: Boolean): string;
  var
    J: Integer;
    Column: TColumn;
  begin
    Result := '';
    for J := 0 to Columns.Count - 1 do
    begin
      Column := TColumn(Columns[J]);
      if J > 0 then
        Result := Result + ';';
      if Header then
        Result := Result + EscapeCsvField(Column.Field.DisplayLabel)
      else
        Result := Result + EscapeCsvField(Column.Field.DisplayText);
    end;
  end;

begin
  C := SelectedDataSet;
  if not Assigned(C) or not C.Active then
    Exit;
  Columns := TList.Create;
  try
    try
      for I := 0 to FGrid.Columns.Count - 1 do
        if (FGrid.Columns[I].Field <> nil) and FGrid.Columns[I].Visible then
          Columns.Add(FGrid.Columns[I]);
      if Columns.Count = 0 then
      begin
        MessageDlg('No hay columnas visibles para exportar.',
          mtInformation, [mbOK], 0);
        Exit;
      end;
      if C.IsEmpty then
      begin
        MessageDlg('No hay registros para exportar.',
          mtInformation, [mbOK], 0);
        Exit;
      end;
      Dialog := TSaveDialog.Create(Self);
      try
        Dialog.Filter := 'CSV (*.csv)|*.csv';
        Dialog.DefaultExt := 'csv';
        if (FSelector.ItemIndex >= 0) and
          (FSelector.ItemIndex < FSelector.Items.Count) then
          Dialog.FileName := FSelector.Items[FSelector.ItemIndex] + '.csv'
        else
          Dialog.FileName := 'Datos.csv';
        Dialog.Options := Dialog.Options + [ofOverwritePrompt,
          ofPathMustExist, ofHideReadOnly];
        if not Dialog.Execute then
          Exit;
        Line := Dialog.FileName;
      finally
        Dialog.Free;
      end;
      Stream := TFileStream.Create(Line, fmCreate);
      try
        Bom[0] := $EF;
        Bom[1] := $BB;
        Bom[2] := $BF;
        Stream.WriteBuffer(Bom, SizeOf(Bom));
        Bookmark := C.GetBookmark;
        C.DisableControls;
        try
          try
            C.First;
            WriteLine(BuildLine(True));
            Exported := 0;
            while not C.Eof do
            begin
              WriteLine(BuildLine(False));
              Inc(Exported);
              C.Next;
            end;
          finally
            try
              C.GotoBookmark(Bookmark);
            except
            end;
            C.FreeBookmark(Bookmark);
          end;
        finally
          C.EnableControls;
        end;
      finally
        Stream.Free;
      end;
      MessageDlg(Format('Se exportaron %d registros a %s.',
        [Exported, Line]), mtInformation, [mbOK], 0);
    except
      on E: Exception do
        MessageDlg('No se pudo exportar: ' + E.Message,
          mtError, [mbOK], 0);
    end;
  finally
    Columns.Free;
  end;
end;

procedure TMainForm.SearchClick(Sender: TObject);
begin
  FSearchFrame.Visible := True;
  FSearchEdit.SetFocus;
  FSearchEdit.SelectAll;
end;

procedure TMainForm.CloseSearchClick(Sender: TObject);
begin
  FSearchEdit.Clear;
  FFilterCheck.Checked := False;
  FSearchFrame.Visible := False;
  FGrid.SetFocus;
end;

procedure TMainForm.SearchChanged(Sender: TObject);
begin
  if FLoadingConfig then
    Exit;
  FSearchText := AnsiUpperCase(FSearchEdit.Text);
  ApplySearch;
  MarkConfigChanged;
end;

procedure TMainForm.ApplySearch;
var
  C: TClientDataSet;
begin
  if FFilteredDataSet <> nil then
  begin
    FFilteredDataSet.Filtered := False;
    FFilteredDataSet.OnFilterRecord := nil;
    FFilteredDataSet := nil;
  end;
  C := SelectedDataSet;
  if (C <> nil) and C.Active and
    ((FColumnFilters.Count > 0) or
    (FFilterCheck.Checked and (FSearchText <> ''))) then
  begin
    C.OnFilterRecord := SearchFilterRecord;
    C.Filtered := True;
    FFilteredDataSet := C;
    if not C.IsEmpty then
      C.First;
  end;
  FGrid.Invalidate;
  UpdateButtons;
end;

procedure TMainForm.SearchFilterRecord(DataSet: TDataSet;
  var Accept: Boolean);
var
  I: Integer;
  Field: TField;
  ColumnFilter: TColumnFilter;
begin
  Accept := True;
  for I := 0 to FColumnFilters.Count - 1 do
  begin
    ColumnFilter := TColumnFilter(FColumnFilters.Objects[I]);
    Field := DataSet.FieldByName(ColumnFilter.FieldName);
    if not ColumnFilter.Matches(Field) then
    begin
      Accept := False;
      Exit;
    end;
  end;
  if not FFilterCheck.Checked or (FSearchText = '') then
    Exit;
  Accept := False;
  for I := 0 to FGrid.Columns.Count - 1 do
    if FGrid.Columns[I].Visible then
    begin
      Field := FGrid.Columns[I].Field;
      if (Field <> nil) and
        (Pos(FSearchText, AnsiUpperCase(Field.DisplayText)) > 0) then
      begin
        Accept := True;
        Exit;
      end;
    end;
end;

procedure TMainForm.ClearColumnFilters;
var
  I: Integer;
begin
  for I := 0 to FColumnFilters.Count - 1 do
    FColumnFilters.Objects[I].Free;
  FColumnFilters.Clear;
end;

function TMainForm.GridFilterState(const FieldName: string): Boolean;
begin
  Result := FColumnFilters.IndexOf(FieldName) >= 0;
end;

function TMainForm.GridSortState(const FieldName: string): Integer;
var
  Index: Integer;
begin
  Result := 0;
  Index := FSortFields.IndexOf(FieldName);
  if Index >= 0 then
    Result := Integer(FSortFields.Objects[Index]);
end;

procedure TMainForm.GridFilterClick(Column: TColumn);
var
  Index: Integer;
  Existing, NewFilter: TColumnFilter;
  Editor: TColumnFilterDialog;
begin
  if Column.Field = nil then
    Exit;
  Index := FColumnFilters.IndexOf(Column.FieldName);
  Existing := nil;
  if Index >= 0 then
    Existing := TColumnFilter(FColumnFilters.Objects[Index]);
  Editor := TColumnFilterDialog.CreateForField(Self, Column.Field, Existing);
  try
    if Editor.ShowModal <> mrOk then
      Exit;
    NewFilter := Editor.TakeFilter;
  finally
    Editor.Free;
  end;
  if Index >= 0 then
  begin
    Existing.Free;
    FColumnFilters.Delete(Index);
  end;
  if NewFilter <> nil then
    FColumnFilters.AddObject(Column.FieldName, NewFilter);
  ApplySearch;
  MarkConfigChanged;
end;

procedure TMainForm.GridTitleClick(Column: TColumn);
var
  P: TPoint;
  OldIndex, NextDirection: Integer;
  FieldName: string;
  AddSecondary: Boolean;
begin
  if (Column.Field = nil) or Column.Field.IsBlob then
    Exit;
  GetCursorPos(P);
  P := FGrid.ScreenToClient(P);
  if FGrid.SeparatorColumnAt(P.X, P.Y) >= 0 then
    Exit;
  FieldName := Column.FieldName;
  OldIndex := FSortFields.IndexOf(FieldName);
  if OldIndex < 0 then
    NextDirection := 1
  else
    NextDirection := (Integer(FSortFields.Objects[OldIndex]) + 1) mod 3;
  AddSecondary := GetKeyState(VK_SHIFT) < 0;
  if AddSecondary then
  begin
    if OldIndex >= 0 then
      FSortFields.Delete(OldIndex);
  end
  else
    FSortFields.Clear;
  if NextDirection <> 0 then
  begin
    if AddSecondary and (OldIndex >= 0) then
      FSortFields.InsertObject(OldIndex, FieldName, TObject(NextDirection))
    else
      FSortFields.AddObject(FieldName, TObject(NextDirection));
  end;
  ApplySort;
  MarkConfigChanged;
end;

procedure TMainForm.ClearSort;
begin
  if FSortedDataSet <> nil then
  begin
    FSortedDataSet.IndexName := '';
    FSortedDataSet.DeleteIndex('GridSort');
    FSortedDataSet := nil;
  end;
  FSortFields.Clear;
end;

procedure TMainForm.ApplySort;
var
  C: TClientDataSet;
  I: Integer;
  Fields, DescFields: string;
begin
  if FSortedDataSet <> nil then
  begin
    FSortedDataSet.IndexName := '';
    FSortedDataSet.DeleteIndex('GridSort');
    FSortedDataSet := nil;
  end;
  C := SelectedDataSet;
  if (C <> nil) and C.Active and (FSortFields.Count > 0) then
  begin
    Fields := '';
    DescFields := '';
    for I := 0 to FSortFields.Count - 1 do
    begin
      if Fields <> '' then
        Fields := Fields + ';';
      Fields := Fields + FSortFields[I];
      if Integer(FSortFields.Objects[I]) = 2 then
      begin
        if DescFields <> '' then
          DescFields := DescFields + ';';
        DescFields := DescFields + FSortFields[I];
      end;
    end;
    C.AddIndex('GridSort', Fields, [], DescFields);
    C.IndexName := 'GridSort';
    FSortedDataSet := C;
  end;
  if (C <> nil) and C.Active and not C.IsEmpty then
    C.First;
  UpdateSortTitles;
  UpdateFooter;
end;

procedure TMainForm.UpdateSortTitles;
var
  I, SortIndex, MinWidth: Integer;
  Column: TColumn;
  SavedFont: TFont;
begin
  SavedFont := TFont.Create;
  try
    SavedFont.Assign(FGrid.Canvas.Font);
    for I := 0 to FGrid.Columns.Count - 1 do
    begin
      Column := FGrid.Columns[I];
      if Column.Field = nil then
        Continue;
      if Column.Field.IsBlob then
        Column.Title.Caption := Column.Field.DisplayLabel
      else
        Column.Title.Caption := '         ' + Column.Field.DisplayLabel;
      SortIndex := FSortFields.IndexOf(Column.FieldName);
      if SortIndex >= 0 then
      begin
        FGrid.Canvas.Font.Assign(Column.Title.Font);
        MinWidth := FGrid.Canvas.TextWidth(Column.Title.Caption) + 36;
        if Column.Width < MinWidth then
          Column.Width := MinWidth;
      end;
    end;
  finally
    FGrid.Canvas.Font.Assign(SavedFont);
    SavedFont.Free;
  end;
  FGrid.Invalidate;
end;

procedure TMainForm.GridDrawColumnCell(Sender: TObject; const Rect: TRect;
  DataCol: Integer; Column: TColumn; State: TGridDrawState);
begin
  if FFilterCheck.Checked or (FSearchText = '') or (Column.Field = nil) then
    Exit;
  if Pos(FSearchText, AnsiUpperCase(Column.Field.DisplayText)) = 0 then
    Exit;
  FGrid.Canvas.Brush.Color := clYellow;
  FGrid.Canvas.Font.Color := clBlack;
  FGrid.DefaultDrawColumnCell(Rect, DataCol, Column, State);
end;

end.

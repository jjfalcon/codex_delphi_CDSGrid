unit RecordEditor;

interface

uses
  Classes, DB, DBClient, Forms, Controls, ExtCtrls, StdCtrls;

type
  TEditorMode = (emGroups, emTabs, emAccordion);

  TEditorGroup = class
  public
    Name: string;
    Fields: TStringList;
    constructor Create(const AName: string);
    destructor Destroy; override;
  end;

  TRecordEditorForm = class(TForm)
  private
    FDataSet: TClientDataSet;
    FSource: TDataSource;
    FCDSName: string;
    FSettingsPath: string;
    FMode: TEditorMode;
    FGroups: TList;
    FExpanded: array of Boolean;
    FTopPanel: TPanel;
    FModeBox: TComboBox;
    FClient: TPanel;
    FScroll: TScrollBox;
    FPages: TControl;
    FLoadingMode: Boolean;
    FHasGroupConfig: Boolean;
    FSavedScrollPos: Integer;
    procedure LoadGroups;
    procedure SaveMode;
    procedure BuildContent;
    procedure ClearContent;
    procedure BuildFlatView;
    procedure BuildGroupsView;
    procedure BuildTabsView;
    procedure BuildAccordionView;
    procedure AddFieldControls(Parent: TWinControl; var Y: Integer;
      Field: TField);
    function FindField(const FieldName: string): TField;
    procedure ModeChanged(Sender: TObject);
    procedure AccordionToggle(Sender: TObject);
    procedure SaveClick(Sender: TObject);
    procedure CancelClick(Sender: TObject);
  public
    constructor CreateEditor(AOwner: TComponent; ADataSet: TClientDataSet;
      AIsNew: Boolean; const CDSName: string);
    destructor Destroy; override;
  end;

implementation

uses
  SysUtils, Dialogs, DBCtrls, ComCtrls, IniFiles;

const
  EditorModeNames: array[TEditorMode] of string =
    ('Groups', 'Tabs', 'Accordion');

constructor TEditorGroup.Create(const AName: string);
begin
  inherited Create;
  Name := AName;
  Fields := TStringList.Create;
end;

destructor TEditorGroup.Destroy;
begin
  Fields.Free;
  inherited Destroy;
end;

function EditorModeFromName(const Value: string): TEditorMode;
begin
  if AnsiCompareText(Value, 'Tabs') = 0 then
    Result := emTabs
  else if AnsiCompareText(Value, 'Accordion') = 0 then
    Result := emAccordion
  else
    Result := emGroups;
end;

function DecodeIniText(const Value: string): string;
var
  Wide: WideString;
begin
  Result := Value;
  if Value = '' then
    Exit;
  Wide := UTF8Decode(Value);
  if Wide = '' then
    Exit;
  if UTF8Encode(Wide) <> Value then
    Exit;
  Result := Wide;
end;

constructor TRecordEditorForm.CreateEditor(AOwner: TComponent;
  ADataSet: TClientDataSet; AIsNew: Boolean; const CDSName: string);
var
  Bottom: TPanel;
  SaveButton: TButton;
  CancelButton: TButton;
  ModeLabel: TLabel;
begin
  inherited CreateNew(AOwner);
  FDataSet := ADataSet;
  FCDSName := Trim(CDSName);
  if FCDSName = '' then
    FCDSName := 'Datos';
  FSettingsPath := ExtractFilePath(ParamStr(0)) + 'DelphiCDSDemo.ini';
  FGroups := TList.Create;
  BorderStyle := bsDialog;
  Position := poScreenCenter;
  Width := 440;
  Height := 520;
  if AIsNew then
    Caption := 'Nuevo registro'
  else
    Caption := 'Editar registro';

  FSource := TDataSource.Create(Self);
  FSource.DataSet := FDataSet;

  Bottom := TPanel.Create(Self);
  Bottom.Parent := Self;
  Bottom.Align := alBottom;
  Bottom.Height := 54;
  Bottom.BevelOuter := bvNone;

  SaveButton := TButton.Create(Self);
  SaveButton.Parent := Bottom;
  SaveButton.Left := 236;
  SaveButton.Top := 14;
  SaveButton.Width := 82;
  SaveButton.Caption := 'Guardar';
  SaveButton.Default := True;
  SaveButton.OnClick := SaveClick;

  CancelButton := TButton.Create(Self);
  CancelButton.Parent := Bottom;
  CancelButton.Left := 326;
  CancelButton.Top := 14;
  CancelButton.Width := 82;
  CancelButton.Caption := 'Cancelar';
  CancelButton.Cancel := True;
  CancelButton.OnClick := CancelClick;

  FTopPanel := TPanel.Create(Self);
  FTopPanel.Parent := Self;
  FTopPanel.Align := alTop;
  FTopPanel.Height := 36;
  FTopPanel.BevelOuter := bvNone;

  ModeLabel := TLabel.Create(Self);
  ModeLabel.Parent := FTopPanel;
  ModeLabel.Left := 16;
  ModeLabel.Top := 11;
  ModeLabel.Caption := 'Vista:';

  FModeBox := TComboBox.Create(Self);
  FModeBox.Parent := FTopPanel;
  FModeBox.Left := 64;
  FModeBox.Top := 7;
  FModeBox.Width := 170;
  FModeBox.Style := csDropDownList;
  FModeBox.Items.Add('Grupos');
  FModeBox.Items.Add('Pestañas');
  FModeBox.Items.Add('Acordeón');
  FModeBox.OnChange := ModeChanged;
  FSavedScrollPos := -1;

  FClient := TPanel.Create(Self);
  FClient.Parent := Self;
  FClient.Align := alClient;
  FClient.BevelOuter := bvNone;

  LoadGroups;
  FTopPanel.Visible := FHasGroupConfig;
  FLoadingMode := True;
  try
    FModeBox.ItemIndex := Ord(FMode);
  finally
    FLoadingMode := False;
  end;
  BuildContent;
end;

destructor TRecordEditorForm.Destroy;
var
  I: Integer;
begin
  for I := 0 to FGroups.Count - 1 do
    TObject(FGroups[I]).Free;
  FGroups.Free;
  inherited Destroy;
end;

function TRecordEditorForm.FindField(const FieldName: string): TField;
begin
  Result := FDataSet.FindField(FieldName);
end;

procedure TRecordEditorForm.LoadGroups;
var
  Ini: TMemIniFile;
  Section, GroupName, FieldsStr: string;
  I, GroupCount: Integer;
  Field: TField;
  Group: TEditorGroup;
  Placed: TStringList;

  function ParseAndKeep(const List: string; Group: TEditorGroup): Boolean;
  var
    Rest, Item: string;
    Sep: Integer;
    F: TField;
  begin
    Result := False;
    Rest := List;
    while True do
    begin
      Sep := Pos(',', Rest);
      if Sep > 0 then
      begin
        Item := Trim(Copy(Rest, 1, Sep - 1));
        Rest := Copy(Rest, Sep + 1, Length(Rest));
      end
      else
      begin
        Item := Trim(Rest);
        Rest := '';
      end;
      if Item <> '' then
      begin
        F := FindField(Item);
        if (F <> nil) and (F.FieldKind = fkData) and F.Visible and
          (Placed.IndexOf(F.FieldName) < 0) then
        begin
          Group.Fields.Add(F.FieldName);
          Placed.Add(F.FieldName);
          Result := True;
        end;
      end;
      if Rest = '' then
        Break;
    end;
  end;

begin
  for I := 0 to FGroups.Count - 1 do
    TObject(FGroups[I]).Free;
  FGroups.Clear;
  FHasGroupConfig := False;
  FMode := emGroups;
  if not FileExists(FSettingsPath) then
    Exit;
  Section := FCDSName + '_Editor';
  Ini := TMemIniFile.Create(FSettingsPath);
  Placed := TStringList.Create;
  try
    if not Ini.SectionExists(Section) then
      Exit;
    GroupCount := Ini.ReadInteger(Section, 'GroupCount', 0);
    if GroupCount <= 0 then
      Exit;
    FHasGroupConfig := True;
    FMode := EditorModeFromName(Ini.ReadString(Section, 'Mode', 'Groups'));
    for I := 1 to GroupCount do
    begin
      GroupName := Trim(DecodeIniText(Ini.ReadString(Section,
        'Group' + IntToStr(I) + '_Name', '')));
      FieldsStr := Ini.ReadString(Section,
        'Group' + IntToStr(I) + '_Fields', '');
      if GroupName = '' then
        GroupName := 'Grupo ' + IntToStr(I);
      Group := TEditorGroup.Create(GroupName);
      try
        ParseAndKeep(FieldsStr, Group);
        if Group.Fields.Count = 0 then
        begin
          Group.Free;
          Group := nil;
        end
        else
          FGroups.Add(Group);
      except
        Group.Free;
      end;
    end;
    for I := 0 to FDataSet.FieldCount - 1 do
    begin
      Field := FDataSet.Fields[I];
      if (Field.FieldKind <> fkData) or not Field.Visible then
        Continue;
      if Placed.IndexOf(Field.FieldName) < 0 then
      begin
        Group := nil;
        if FGroups.Count > 0 then
          Group := TEditorGroup(FGroups[FGroups.Count - 1]);
        if (Group <> nil) and (AnsiCompareText(Group.Name, 'Otros') = 0) then
        begin
          Group.Fields.Add(Field.FieldName);
          Placed.Add(Field.FieldName);
        end
        else
        begin
          Group := TEditorGroup.Create('Otros');
          Group.Fields.Add(Field.FieldName);
          Placed.Add(Field.FieldName);
          FGroups.Add(Group);
        end;
      end;
    end;
    if FGroups.Count = 0 then
    begin
      Group := TEditorGroup.Create('Datos');
      for I := 0 to FDataSet.FieldCount - 1 do
      begin
        Field := FDataSet.Fields[I];
        if (Field.FieldKind <> fkData) or not Field.Visible then
          Continue;
        Group.Fields.Add(Field.FieldName);
      end;
      if Group.Fields.Count > 0 then
        FGroups.Add(Group)
      else
        Group.Free;
    end;
    SetLength(FExpanded, FGroups.Count);
    for I := 0 to FGroups.Count - 1 do
      FExpanded[I] := True;
  finally
    Placed.Free;
    Ini.Free;
  end;
end;

procedure TRecordEditorForm.SaveMode;
var
  Ini: TMemIniFile;
begin
  if not FHasGroupConfig then
    Exit;
  Ini := TMemIniFile.Create(FSettingsPath);
  try
    Ini.WriteString(FCDSName + '_Editor', 'Mode', EditorModeNames[FMode]);
    try
      Ini.UpdateFile;
    except
      on E: Exception do
        MessageDlg('No se pudo guardar la vista en ' + FSettingsPath +
          ': ' + E.Message, mtWarning, [mbOK], 0);
    end;
  finally
    Ini.Free;
  end;
end;

procedure TRecordEditorForm.ModeChanged(Sender: TObject);
begin
  if FLoadingMode then
    Exit;
  if (FModeBox.ItemIndex < Ord(Low(TEditorMode))) or
    (FModeBox.ItemIndex > Ord(High(TEditorMode))) then
    Exit;
  FMode := TEditorMode(FModeBox.ItemIndex);
  SaveMode;
  FSavedScrollPos := -1;
  BuildContent;
end;

procedure TRecordEditorForm.ClearContent;
begin
  if FScroll <> nil then
  begin
    FScroll.Free;
    FScroll := nil;
  end;
  if FPages <> nil then
  begin
    FPages.Free;
    FPages := nil;
  end;
end;

procedure TRecordEditorForm.AddFieldControls(Parent: TWinControl;
  var Y: Integer; Field: TField);
var
  LabelControl: TLabel;
  EditControl: TDBEdit;
  MemoControl: TDBMemo;
  CheckControl: TDBCheckBox;
begin
  if Field.DataType = ftBoolean then
  begin
    CheckControl := TDBCheckBox.Create(Self);
    CheckControl.Parent := Parent;
    CheckControl.Left := 14;
    CheckControl.Top := Y;
    CheckControl.Width := 360;
    CheckControl.Caption := Field.DisplayLabel;
    CheckControl.DataSource := FSource;
    CheckControl.DataField := Field.FieldName;
    CheckControl.Enabled := not Field.ReadOnly;
    Inc(Y, 42);
    Exit;
  end;

  LabelControl := TLabel.Create(Self);
  LabelControl.Parent := Parent;
  LabelControl.Left := 14;
  LabelControl.Top := Y;
  LabelControl.Caption := Field.DisplayLabel;
  if Field.Required then
    LabelControl.Caption := LabelControl.Caption + ' *';
  Inc(Y, 18);

  if Field.DataType = ftMemo then
  begin
    MemoControl := TDBMemo.Create(Self);
    MemoControl.Parent := Parent;
    MemoControl.Left := 14;
    MemoControl.Top := Y;
    MemoControl.Width := 360;
    MemoControl.Height := 82;
    MemoControl.DataSource := FSource;
    MemoControl.DataField := Field.FieldName;
    MemoControl.ReadOnly := Field.ReadOnly;
    Inc(Y, 94);
  end
  else
  begin
    case Field.DataType of
      ftString, ftSmallint, ftInteger, ftWord, ftFloat, ftCurrency,
      ftDate, ftTime, ftDateTime, ftBCD:
        begin
          EditControl := TDBEdit.Create(Self);
          EditControl.Parent := Parent;
          EditControl.Left := 14;
          EditControl.Top := Y;
          EditControl.Width := 360;
          EditControl.DataSource := FSource;
          EditControl.DataField := Field.FieldName;
          EditControl.ReadOnly := Field.ReadOnly;
          Inc(Y, 36);
        end;
    else
      raise Exception.CreateFmt('Tipo de campo no admitido: %s',
        [Field.FieldName]);
    end;
  end;
end;

procedure TRecordEditorForm.BuildFlatView;
var
  I, Y: Integer;
  Field: TField;
begin
  FScroll := TScrollBox.Create(Self);
  FScroll.Parent := FClient;
  FScroll.Align := alClient;
  FScroll.BorderStyle := bsNone;
  Y := 16;
  for I := 0 to FDataSet.FieldCount - 1 do
  begin
    Field := FDataSet.Fields[I];
    if (Field.FieldKind = fkData) and Field.Visible then
      AddFieldControls(FScroll, Y, Field);
  end;
end;

procedure TRecordEditorForm.BuildGroupsView;
var
  I, K, InnerY, Y: Integer;
  Group: TEditorGroup;
  Box: TGroupBox;
begin
  FScroll := TScrollBox.Create(Self);
  FScroll.Parent := FClient;
  FScroll.Align := alClient;
  FScroll.BorderStyle := bsNone;
  Y := 12;
  for I := 0 to FGroups.Count - 1 do
  begin
    Group := TEditorGroup(FGroups[I]);
    Box := TGroupBox.Create(Self);
    Box.Parent := FScroll;
    Box.Left := 12;
    Box.Top := Y;
    Box.Width := 396;
    Box.Caption := Group.Name;
    InnerY := 20;
    for K := 0 to Group.Fields.Count - 1 do
      AddFieldControls(Box, InnerY, FindField(Group.Fields[K]));
    Box.Height := InnerY + 12;
    Y := Box.Top + Box.Height + 10;
  end;
end;

procedure TRecordEditorForm.BuildTabsView;
var
  I, J, Y: Integer;
  Group: TEditorGroup;
  Pages: TPageControl;
  Sheet: TTabSheet;
  Inner: TScrollBox;
begin
  Pages := TPageControl.Create(Self);
  Pages.Parent := FClient;
  Pages.Align := alClient;
  FPages := Pages;
  for I := 0 to FGroups.Count - 1 do
  begin
    Group := TEditorGroup(FGroups[I]);
    Sheet := TTabSheet.Create(Self);
    Sheet.PageControl := Pages;
    Sheet.Caption := Group.Name;
    Inner := TScrollBox.Create(Self);
    Inner.Parent := Sheet;
    Inner.Align := alClient;
    Inner.BorderStyle := bsNone;
    Y := 16;
    for J := 0 to Group.Fields.Count - 1 do
      AddFieldControls(Inner, Y, FindField(Group.Fields[J]));
  end;
  if Pages.PageCount > 0 then
    Pages.ActivePage := Pages.Pages[0];
end;

procedure TRecordEditorForm.BuildAccordionView;
var
  I, K, InnerY, Y, SavedPos: Integer;
  Group: TEditorGroup;
  Header: TPanel;
  Toggle: TButton;
  Title: TLabel;
  Body: TPanel;
begin
  SavedPos := FSavedScrollPos;
  FSavedScrollPos := -1;
  FScroll := TScrollBox.Create(Self);
  FScroll.Parent := FClient;
  FScroll.Align := alClient;
  FScroll.BorderStyle := bsNone;
  Y := 12;
  for I := 0 to FGroups.Count - 1 do
  begin
    Group := TEditorGroup(FGroups[I]);
    Header := TPanel.Create(Self);
    Header.Parent := FScroll;
    Header.Left := 12;
    Header.Top := Y;
    Header.Width := 396;
    Header.Height := 26;
    Header.BevelOuter := bvRaised;
    Toggle := TButton.Create(Self);
    Toggle.Parent := Header;
    Toggle.Left := 6;
    Toggle.Top := 3;
    Toggle.Width := 22;
    Toggle.Height := 20;
    Toggle.Tag := I;
    Toggle.OnClick := AccordionToggle;
    if FExpanded[I] then
      Toggle.Caption := '-'
    else
      Toggle.Caption := '+';
    Title := TLabel.Create(Self);
    Title.Parent := Header;
    Title.Left := 36;
    Title.Top := 6;
    Title.Caption := Group.Name;
    Title.Tag := I;
    Title.OnClick := AccordionToggle;
    Inc(Y, 26);
    if FExpanded[I] then
    begin
      Body := TPanel.Create(Self);
      Body.Parent := FScroll;
      Body.Left := 12;
      Body.Top := Y;
      Body.Width := 396;
      Body.BevelOuter := bvLowered;
      Body.BevelInner := bvNone;
      InnerY := 10;
      for K := 0 to Group.Fields.Count - 1 do
        AddFieldControls(Body, InnerY, FindField(Group.Fields[K]));
      Body.Height := InnerY + 10;
      Inc(Y, Body.Height + 8);
    end;
  end;
  if SavedPos >= 0 then
    try
      FScroll.VertScrollBar.Position := SavedPos;
    except
    end;
end;

procedure TRecordEditorForm.BuildContent;
begin
  ClearContent;
  if not FHasGroupConfig then
  begin
    BuildFlatView;
    Exit;
  end;
  case FMode of
    emTabs: BuildTabsView;
    emAccordion: BuildAccordionView;
  else
    BuildGroupsView;
  end;
end;

procedure TRecordEditorForm.AccordionToggle(Sender: TObject);
var
  Index: Integer;
begin
  Index := TControl(Sender).Tag;
  if (Index < 0) or (Index >= Length(FExpanded)) then
    Exit;
  if FScroll <> nil then
    FSavedScrollPos := FScroll.VertScrollBar.Position
  else
    FSavedScrollPos := -1;
  FExpanded[Index] := not FExpanded[Index];
  BuildContent;
end;

procedure TRecordEditorForm.SaveClick(Sender: TObject);
begin
  try
    FDataSet.Post;
    ModalResult := mrOk;
  except
    on E: Exception do
      MessageDlg('No se pudo guardar: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TRecordEditorForm.CancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

end.

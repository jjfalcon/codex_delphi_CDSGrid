unit ColumnChooser;

interface

uses
  Classes, Forms, Controls, StdCtrls, ExtCtrls, CheckLst, DBGrids;

type
  TColumnChooserForm = class(TForm)
  private
    FList: TCheckListBox;
    procedure ApplyClick(Sender: TObject);
    procedure UpClick(Sender: TObject);
    procedure DownClick(Sender: TObject);
    function GetColumnCount: Integer;
    function GetColumn(Index: Integer): TColumn;
  public
    constructor CreateForGrid(AOwner: TComponent; AGrid: TDBGrid);
    function ColumnVisible(AColumn: TColumn): Boolean;
    property ColumnCount: Integer read GetColumnCount;
    property Columns[Index: Integer]: TColumn read GetColumn;
  end;

implementation

uses
  Dialogs;

constructor TColumnChooserForm.CreateForGrid(AOwner: TComponent;
  AGrid: TDBGrid);
var
  I, ListIndex: Integer;
  Bottom: TPanel;
  ApplyButton, CancelButton, UpButton, DownButton: TButton;
begin
  inherited CreateNew(AOwner);
  Caption := 'Columnas visibles y orden';
  Position := poScreenCenter;
  BorderStyle := bsDialog;
  Width := 440;
  Height := 330;

  Bottom := TPanel.Create(Self);
  Bottom.Parent := Self;
  Bottom.Align := alBottom;
  Bottom.Height := 54;
  Bottom.BevelOuter := bvNone;

  ApplyButton := TButton.Create(Self);
  ApplyButton.Parent := Bottom;
  ApplyButton.Left := 240;
  ApplyButton.Top := 13;
  ApplyButton.Width := 82;
  ApplyButton.Caption := 'Aplicar';
  ApplyButton.Default := True;
  ApplyButton.OnClick := ApplyClick;

  CancelButton := TButton.Create(Self);
  CancelButton.Parent := Bottom;
  CancelButton.Left := 331;
  CancelButton.Top := 13;
  CancelButton.Width := 82;
  CancelButton.Caption := 'Cancelar';
  CancelButton.Cancel := True;
  CancelButton.ModalResult := mrCancel;

  FList := TCheckListBox.Create(Self);
  FList.Parent := Self;
  FList.Align := alLeft;
  FList.Width := 315;
  FList.BorderStyle := bsNone;
  for I := 0 to AGrid.Columns.Count - 1 do
    if AGrid.Columns[I].Field <> nil then
    begin
      ListIndex := FList.Items.AddObject(
        AGrid.Columns[I].Field.DisplayLabel, AGrid.Columns[I]);
      FList.Checked[ListIndex] := AGrid.Columns[I].Visible;
    end;
  if FList.Items.Count > 0 then
    FList.ItemIndex := 0;

  UpButton := TButton.Create(Self);
  UpButton.Parent := Self;
  UpButton.Left := 324;
  UpButton.Top := 20;
  UpButton.Width := 90;
  UpButton.Caption := 'Subir';
  UpButton.OnClick := UpClick;

  DownButton := TButton.Create(Self);
  DownButton.Parent := Self;
  DownButton.Left := 324;
  DownButton.Top := 56;
  DownButton.Width := 90;
  DownButton.Caption := 'Bajar';
  DownButton.OnClick := DownClick;
end;

function TColumnChooserForm.ColumnVisible(AColumn: TColumn): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to FList.Items.Count - 1 do
    if FList.Items.Objects[I] = AColumn then
    begin
      Result := FList.Checked[I];
      Exit;
    end;
end;

function TColumnChooserForm.GetColumnCount: Integer;
begin
  Result := FList.Items.Count;
end;

function TColumnChooserForm.GetColumn(Index: Integer): TColumn;
begin
  Result := TColumn(FList.Items.Objects[Index]);
end;

procedure TColumnChooserForm.UpClick(Sender: TObject);
var
  Index: Integer;
begin
  Index := FList.ItemIndex;
  if Index <= 0 then
    Exit;
  FList.Items.Exchange(Index, Index - 1);
  FList.ItemIndex := Index - 1;
end;

procedure TColumnChooserForm.DownClick(Sender: TObject);
var
  Index: Integer;
begin
  Index := FList.ItemIndex;
  if (Index < 0) or (Index >= FList.Items.Count - 1) then
    Exit;
  FList.Items.Exchange(Index, Index + 1);
  FList.ItemIndex := Index + 1;
end;

procedure TColumnChooserForm.ApplyClick(Sender: TObject);
var
  I: Integer;
begin
  for I := 0 to FList.Items.Count - 1 do
    if FList.Checked[I] then
    begin
      ModalResult := mrOk;
      Exit;
    end;
  MessageDlg('Debe quedar visible al menos una columna de datos.',
    mtWarning, [mbOK], 0);
end;

end.

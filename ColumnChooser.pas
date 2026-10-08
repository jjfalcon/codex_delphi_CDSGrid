unit ColumnChooser;

interface

uses
  Classes, Forms, Controls, StdCtrls, ExtCtrls, CheckLst, DBGrids;

type
  TColumnChooserForm = class(TForm)
  private
    FList: TCheckListBox;
    procedure ApplyClick(Sender: TObject);
  public
    constructor CreateForGrid(AOwner: TComponent; AGrid: TDBGrid);
    function ColumnVisible(AColumn: TColumn): Boolean;
  end;

implementation

uses
  Dialogs;

constructor TColumnChooserForm.CreateForGrid(AOwner: TComponent;
  AGrid: TDBGrid);
var
  I, ListIndex: Integer;
  Bottom: TPanel;
  ApplyButton, CancelButton: TButton;
begin
  inherited CreateNew(AOwner);
  Caption := 'Columnas visibles';
  Position := poScreenCenter;
  BorderStyle := bsDialog;
  Width := 350;
  Height := 330;

  Bottom := TPanel.Create(Self);
  Bottom.Parent := Self;
  Bottom.Align := alBottom;
  Bottom.Height := 54;
  Bottom.BevelOuter := bvNone;

  ApplyButton := TButton.Create(Self);
  ApplyButton.Parent := Bottom;
  ApplyButton.Left := 150;
  ApplyButton.Top := 13;
  ApplyButton.Width := 82;
  ApplyButton.Caption := 'Aplicar';
  ApplyButton.Default := True;
  ApplyButton.OnClick := ApplyClick;

  CancelButton := TButton.Create(Self);
  CancelButton.Parent := Bottom;
  CancelButton.Left := 241;
  CancelButton.Top := 13;
  CancelButton.Width := 82;
  CancelButton.Caption := 'Cancelar';
  CancelButton.Cancel := True;
  CancelButton.ModalResult := mrCancel;

  FList := TCheckListBox.Create(Self);
  FList.Parent := Self;
  FList.Align := alClient;
  FList.BorderStyle := bsNone;
  for I := 0 to AGrid.Columns.Count - 1 do
    if AGrid.Columns[I].Field <> nil then
    begin
      ListIndex := FList.Items.AddObject(
        AGrid.Columns[I].Field.DisplayLabel, AGrid.Columns[I]);
      FList.Checked[ListIndex] := AGrid.Columns[I].Visible;
    end;
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

unit RecordEditor;

interface

uses
  Classes, DB, DBClient, Forms, Controls, ExtCtrls, StdCtrls;

type
  TRecordEditorForm = class(TForm)
  private
    FDataSet: TClientDataSet;
    FSource: TDataSource;
    FScroll: TScrollBox;
    procedure BuildFields;
    procedure SaveClick(Sender: TObject);
    procedure CancelClick(Sender: TObject);
  public
    constructor CreateEditor(AOwner: TComponent; ADataSet: TClientDataSet;
      AIsNew: Boolean);
  end;

implementation

uses
  SysUtils, Dialogs, DBCtrls;

constructor TRecordEditorForm.CreateEditor(AOwner: TComponent;
  ADataSet: TClientDataSet; AIsNew: Boolean);
var
  Bottom: TPanel;
  SaveButton: TButton;
  CancelButton: TButton;
begin
  inherited CreateNew(AOwner);
  FDataSet := ADataSet;
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

  FScroll := TScrollBox.Create(Self);
  FScroll.Parent := Self;
  FScroll.Align := alClient;
  FScroll.BorderStyle := bsNone;
  BuildFields;
end;

procedure TRecordEditorForm.BuildFields;
var
  I, Y: Integer;
  Field: TField;
  LabelControl: TLabel;
  EditControl: TDBEdit;
  MemoControl: TDBMemo;
  CheckControl: TDBCheckBox;
begin
  Y := 16;
  for I := 0 to FDataSet.FieldCount - 1 do
  begin
    Field := FDataSet.Fields[I];
    if (Field.FieldKind <> fkData) or not Field.Visible then
      Continue;

    if Field.DataType = ftBoolean then
    begin
      CheckControl := TDBCheckBox.Create(Self);
      CheckControl.Parent := FScroll;
      CheckControl.Left := 18;
      CheckControl.Top := Y;
      CheckControl.Width := 370;
      CheckControl.Caption := Field.DisplayLabel;
      CheckControl.DataSource := FSource;
      CheckControl.DataField := Field.FieldName;
      CheckControl.Enabled := not Field.ReadOnly;
      Inc(Y, 42);
      Continue;
    end;

    LabelControl := TLabel.Create(Self);
    LabelControl.Parent := FScroll;
    LabelControl.Left := 18;
    LabelControl.Top := Y;
    LabelControl.Caption := Field.DisplayLabel;
    if Field.Required then
      LabelControl.Caption := LabelControl.Caption + ' *';
    Inc(Y, 18);

    if Field.DataType = ftMemo then
    begin
      MemoControl := TDBMemo.Create(Self);
      MemoControl.Parent := FScroll;
      MemoControl.Left := 18;
      MemoControl.Top := Y;
      MemoControl.Width := 390;
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
            EditControl.Parent := FScroll;
            EditControl.Left := 18;
            EditControl.Top := Y;
            EditControl.Width := 390;
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

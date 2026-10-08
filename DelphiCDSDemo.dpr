program DelphiCDSDemo;

uses
  Forms,
  MidasLib,
  MainForm in 'MainForm.pas',
  DemoData in 'DemoData.pas',
  RecordEditor in 'RecordEditor.pas',
  ColumnFilter in 'ColumnFilter.pas',
  ColumnChooser in 'ColumnChooser.pas';

begin
  Application.Initialize;
  Application.Title := 'Maqueta CDS';
  Application.CreateForm(TMainForm, CDSMainForm);
  Application.Run;
end.

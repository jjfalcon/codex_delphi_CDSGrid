program DelphiCDSDemo;

uses
  Forms,
  MidasLib,
  MainForm in 'MainForm.pas',
  DemoData in 'DemoData.pas',
  RecordEditor in 'RecordEditor.pas';

begin
  Application.Initialize;
  Application.Title := 'Maqueta CDS';
  Application.CreateForm(TMainForm, CDSMainForm);
  Application.Run;
end.

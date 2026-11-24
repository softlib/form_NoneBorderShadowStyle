program NoneBorderShadowDemo;

uses
  Vcl.Forms,
  uMain in 'uMain.pas' {frmMain},
  uNbss.NoneBorderForm in 'uNbss.NoneBorderForm.pas',
  GDIPAPI in 'GDIPAPI.pas',
  GDIPOBJ in 'GDIPOBJ.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'NoneBorderShadowStyle Demo';
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.

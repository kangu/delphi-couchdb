program Delphi_CouchDB;

uses
  Vcl.Forms,
  form_main in 'form_main.pas' {Form1},
  Couch in 'Couch.pas',
  superobject in 'Vendor\superobject.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.

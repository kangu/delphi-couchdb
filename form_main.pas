unit form_main;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls;

type
  TForm1 = class(TForm)
    btn1: TButton;
    procedure btn1Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

uses Couch;

procedure TForm1.btn1Click(Sender: TObject);
var
  c: TCouchDB;
  doc: TSampleDoc;
begin
  c := TCouchDB.Create;
  try
    doc := c.GetDocument<TSampleDoc>('test', 'sample');
    ShowMessage(doc._id);
  finally
    c.Free;
  end;
end;

end.

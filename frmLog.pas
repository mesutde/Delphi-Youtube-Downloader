unit frmLog;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls;

type
  TfrmLogMemo = class(TForm)
    mmLog: TMemo;
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  frmLogMemo: TfrmLogMemo;

implementation

{$R *.dfm}

end.

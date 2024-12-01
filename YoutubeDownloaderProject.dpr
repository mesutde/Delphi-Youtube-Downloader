program YoutubeDownloaderProject;

uses
  Vcl.Forms,
  frmMain in 'frmMain.pas' {frmMainForm},
  frmLog in 'frmLog.pas' {frmLogMemo},
  YTDownloader in 'YTDownloader.pas',
  frmUpdateControl in 'frmUpdateControl.pas' {frmUpdate};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmMainForm, frmMainForm);
  Application.Run;
end.

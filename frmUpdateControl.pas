unit frmUpdateControl;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls, YTDownloader,
  Vcl.StdCtrls, ShellAPI,IdHTTP,System.Net.HttpClient, System.Net.URLClient,WinInet;


type
  TfrmUpdate = class(TForm)
    Panel1: TPanel;
    pnlUpdateButton: TPanel;
    btnUpdateControl: TButton;
    btnUpdate: TButton;
    grpUpdate: TGroupBox;
    lblLocalYtdlp: TLabel;
    lblUpdateYtdlp: TLabel;
    lnkYTDLPCurrentDownloadUrl: TLinkLabel;
    procedure btnUpdateControlClick(Sender: TObject);
    function GetYTDLPVersion(const ExePath: string): string;
    procedure btnUpdateClick(Sender: TObject);

  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  frmUpdate: TfrmUpdate;

implementation

{$R *.dfm}

function TfrmUpdate.GetYTDLPVersion(const ExePath: string): string;
var
  StartInfo: TStartupInfo;
  ProcInfo: TProcessInformation;
  SecurityAttrs: TSecurityAttributes;
  hReadPipe, hWritePipe: THandle;
  Buffer: array [0 .. 4096] of Byte;
  BytesRead: DWORD;
  WorkingDir: string;
  TempStr: UTF8String;
begin
  Result := '';

  FillChar(SecurityAttrs, SizeOf(SecurityAttrs), 0);
  SecurityAttrs.nLength := SizeOf(SecurityAttrs);
  SecurityAttrs.bInheritHandle := True;

  if not CreatePipe(hReadPipe, hWritePipe, @SecurityAttrs, 0) then
    Exit;

  try
    FillChar(StartInfo, SizeOf(StartInfo), 0);
    StartInfo.cb := SizeOf(StartInfo);
    StartInfo.dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
    StartInfo.wShowWindow := SW_HIDE;
    StartInfo.hStdOutput := hWritePipe;
    StartInfo.hStdError := hWritePipe;

    WorkingDir := ExtractFilePath(ExePath);

    if CreateProcess(nil, PChar(ExePath + ' --version'), nil, nil, True,
      CREATE_NO_WINDOW, nil, PChar(WorkingDir), StartInfo, ProcInfo) then
    begin
      try
        WaitForSingleObject(ProcInfo.hProcess, 5000);

        if ReadFile(hReadPipe, Buffer, SizeOf(Buffer) - 1, BytesRead, nil) then
        begin
          // UTF-8 dizisini stringe çevir ve temizle
          SetLength(TempStr, BytesRead);
          Move(Buffer[0], TempStr[1], BytesRead);

          // Yalnýzca rakamlarý, nokta ve tire karakterlerini tut
          Result := '';
          for var i := 1 to Length(TempStr) do
          begin
            if (TempStr[i] in ['0' .. '9', '.', '-']) then
              Result := Result + Char(TempStr[i]);
          end;
          Result := Trim(Result);
        end;
      finally
        CloseHandle(ProcInfo.hProcess);
        CloseHandle(ProcInfo.hThread);
      end;
    end
    else
    begin
      Result := 'Versiyon alýnamadý: ' + IntToStr(GetLastError);
    end;
  finally
    CloseHandle(hReadPipe);
    CloseHandle(hWritePipe);
  end;
end;

procedure ShellOpen(const Url: string; const Params: string = '');
begin
  ShellExecute(0, 'Open', PChar(Url), PChar(Params), nil, SW_SHOWNORMAL);
end;

function DownloadFile(const Url, Destination: string): Boolean;
var
  hSession, hConnect: HINTERNET;
  Buffer: array[0..1023] of Byte;
  BytesRead: DWORD;
  FileStream: TFileStream;
begin
  Result := False;
  hSession := InternetOpen('DelphiApp', INTERNET_OPEN_TYPE_PRECONFIG, nil, nil, 0);
  if Assigned(hSession) then
  try
    hConnect := InternetOpenUrl(hSession, PChar(Url), nil, 0, INTERNET_FLAG_RELOAD, 0);
    if Assigned(hConnect) then
    try
      FileStream := TFileStream.Create(Destination, fmCreate);
      try
        repeat
          InternetReadFile(hConnect, @Buffer, SizeOf(Buffer), BytesRead);
          if BytesRead > 0 then
            FileStream.Write(Buffer, BytesRead);
        until BytesRead = 0;
        Result := True;
      finally
        FileStream.Free;
      end;
    finally
      InternetCloseHandle(hConnect);
    end;
  finally
    InternetCloseHandle(hSession);
  end;
end;



procedure TfrmUpdate.btnUpdateClick(Sender: TObject);
var
  DownloaderUrl, ToolsPath, OldYtDlpPath, NewYtDlpPath: string;
  DownloadSuccess: Boolean;
  YTDownloader: TYTDownloader;
begin
  // Ýndirme linkini alýn
  DownloaderUrl := YTDownloader.GetNewUrl;

  ShowMessage(DownloaderUrl);
  ShowMessage(IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName) + 'Tools'));

  // Uygulamanýn bulunduðu Tools klasörü
  ToolsPath := IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName) + 'Tools');
  OldYtDlpPath := ToolsPath + 'yt-dlp.exe';
  NewYtDlpPath := ToolsPath + 'yt-dlp_new.exe';

  // Tools klasörünün mevcut olup olmadýðýný kontrol et
  if not DirectoryExists(ToolsPath) then
  begin
    ShowMessage('Tools klasörü bulunamadý: ' + ToolsPath);
    Exit;
  end;

  try
    // Yeni yt-dlp.exe'yi Tools klasörüne indirme
    DownloadSuccess := DownloadFile(DownloaderUrl, NewYtDlpPath);

    if DownloadSuccess then
    begin
      // Eski yt-dlp.exe'nin yedeðini oluþturun
      if FileExists(OldYtDlpPath) then
      begin
        DeleteFile(OldYtDlpPath); // Eski dosyayý sil
      end;

      // Yeni dosyayý eski dosyanýn yerine taþý
      RenameFile(NewYtDlpPath, OldYtDlpPath);
      ShowMessage('Yeni yt-dlp.exe baþarýyla güncellendi.');
    end
    else
    begin
      ShowMessage('Yeni yt-dlp.exe indirilirken bir hata oluþtu.');
      if FileExists(NewYtDlpPath) then
        DeleteFile(NewYtDlpPath); // Geçici indirmeyi sil
    end;
  except
    on E: Exception do
      ShowMessage('Bir hata oluþtu: ' + E.Message);
  end;

end;

procedure TfrmUpdate.btnUpdateControlClick(Sender: TObject);
var
  LocalYTDLPVersion, CurrentYTDLPVersion: String;
  YTDownloader: TYTDownloader;
begin
  LocalYTDLPVersion := GetYTDLPVersion('Tools\yt-dlp.exe');
  CurrentYTDLPVersion := YTDownloader.GetReleaseVersion2
    ('https://github.com/yt-dlp/yt-dlp/releases');
  lblLocalYtdlp.Caption := 'Sisteminizdeki Sürüm : ' + LocalYTDLPVersion;
  lblUpdateYtdlp.Caption := 'Release Sürüm : ' + CurrentYTDLPVersion;
  lnkYTDLPCurrentDownloadUrl.Caption := YTDownloader.GetNewUrl;

end;

end.

unit YTDownloader;

interface

uses
  System.SysUtils, System.Classes, System.Net.HttpClient,
  System.Net.HttpClientComponent, RegularExpressions, dprocess, Winapi.Windows,
  IdHTTP;

type
  TYTDownloader = class
  private
    FHttpClient: TNetHTTPClient;
  public
    constructor Create;
    destructor Destroy; override;
    function GetReleaseVersion1(const URL: string): string;
    function GetNewUrl: string;
    function GetYTDLPVersion(const ExePath: string): string;
    function GetReleaseVersion2(const URL: string): string;
  end;

implementation

constructor TYTDownloader.Create;
begin
  FHttpClient := TNetHTTPClient.Create(nil);
end;

destructor TYTDownloader.Destroy;
begin
  FHttpClient.Free;
  inherited;
end;

function TYTDownloader.GetYTDLPVersion(const ExePath: string): string;
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

function TYTDownloader.GetNewUrl: string;
begin
  // Yeni URL'yi oluþtur
  Result := 'https://github.com/yt-dlp/yt-dlp/releases/download/' +
    GetReleaseVersion2('https://github.com/yt-dlp/yt-dlp/releases') +
    '/yt-dlp.exe';
end;

function TYTDownloader.GetReleaseVersion2(const URL: string): string;
var
  HTMLContent: string;
  StartPos, EndPos, ClassPos: Integer;
  TempStr: string;
begin
  Result := '';

  try
    HTMLContent := TNetHTTPClient.Create(nil).Get(URL).ContentAsString;
  except
    on E: Exception do
    begin
      Result := 'Að Hatasý: ' + E.Message;
      Exit;
    end;
  end;

  try
    // class="Link--primary Link" ifadesini bul
    ClassPos := Pos('class="Link--primary Link"', HTMLContent);
    if ClassPos > 0 then
    begin
      // Sonraki > karakterini bul
      StartPos := Pos('>', HTMLContent, ClassPos) + 1;
      // Sonraki < karakterini bul
      EndPos := Pos('<', HTMLContent, StartPos);

      if (StartPos > 0) and (EndPos > StartPos) then
      begin
        TempStr := Copy(HTMLContent, StartPos, EndPos - StartPos);
        // 'yt-dlp' ifadesini çýkar
        TempStr := StringReplace(TempStr, 'yt-dlp', '', [rfReplaceAll]);
        Result := Trim(TempStr);
      end
      else
        Result := 'Sürüm bulunamadý';
    end
    else
      Result := 'Sürüm bulunamadý';
  except
    on E: Exception do
    begin
      Result := 'Ayrýþtýrma Hatasý: ' + E.Message;
    end;
  end;
end;

function TYTDownloader.GetReleaseVersion1(const URL: string): string;
var
  HTMLContent: string;
  Regex: TRegEx;
  Match: TMatch;
begin
  try
    try
      // GitHub sayfasýnýn içeriðini al
      HTMLContent := FHttpClient.Get(URL).ContentAsString;
    except
      on E: Exception do
        Result := 'Hata: ' + E.Message;
    end;
    // Regex ile <a> etiketinden class="Link--primary Link" olaný bul
    Regex := TRegEx.Create('<a [^>]*class="Link--primary Link"[^>]*>(.*?)</a>');
    Match := Regex.Match(HTMLContent);

    if Match.Success then
    begin
      // Result := Match.Groups[1].Value // Bulunan deðeri döndür
      Result := Match.Groups[1].Value.Replace('yt-dlp', '').Trim();
    end
    else
      Result := 'Sürüm bulunamadý';
  except
    on E: Exception do
      Result := 'Hata: ' + E.Message;
  end;
end;

end.

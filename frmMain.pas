unit frmMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ComCtrls, Vcl.ExtCtrls,
  Vcl.StdCtrls,
  System.ImageList, Vcl.ImgList, Vcl.Buttons, Winapi.ShellAPI, JSON, dprocess,
  System.Net.HttpClient,
  Vcl.Imaging.PngImage, System.IOUtils, IdHTTP, Threading, RegularExpressions,
  System.Generics.Collections, frmLog, TlHelp32, YTDownloader, frmUpdateControl,
  Vcl.ToolWin, Vcl.ActnMan, Vcl.ActnCtrls, Vcl.ActnMenus, Vcl.Menus;

type
  TfrmMainForm = class(TForm)
    stbBar: TStatusBar;
    pnlVideo: TPanel;
    pnlAudio: TPanel;
    pnlTop: TPanel;
    pgbBar: TProgressBar;
    edtYoutubeUrl: TEdit;
    btn4320pMP4: TBitBtn;
    btn2160pMP4: TBitBtn;
    btn1440pMP4: TBitBtn;
    btn1080pMP4: TBitBtn;
    btn720pMP4: TBitBtn;
    btn480pMP4: TBitBtn;
    btn360pMP4: TBitBtn;
    Label1: TLabel;
    Label2: TLabel;
    btnMp3: TBitBtn;
    btnFlac: TBitBtn;
    btnM4a: TBitBtn;
    btnYoutubeSearch: TBitBtn;
    btnPasteYoutubeUrl: TBitBtn;
    mmInformation: TMemo;
    btnUpdate: TBitBtn;
    procedure btnYoutubeSearchClick(Sender: TObject);
    procedure btnPasteYoutubeUrlClick(Sender: TObject);
    procedure btn480pMP4Click(Sender: TObject);
    procedure btn720pMP4Click(Sender: TObject);
    procedure btn4320pMP4Click(Sender: TObject);
    procedure btn2160pMP4Click(Sender: TObject);
    procedure btn1440pMP4Click(Sender: TObject);
    procedure btn1080pMP4Click(Sender: TObject);
    procedure btn360pMP4Click(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure btnMp3Click(Sender: TObject);
    procedure btnFlacClick(Sender: TObject);
    procedure btnM4aClick(Sender: TObject);
    procedure mtUpdateFormClick(Sender: TObject);
    procedure btnUpdateClick(Sender: TObject);

  private
    FStartTime: TDateTime;
    FProcess: TProcess;
    FProcessInfo: TProcessInformation;
    FReadPipe: THandle;
    FWritePipe: THandle;
    FTask: ITask;
    OutputList: TStringList;
    { Private declarations }
    function GetYouTubeFormats(const URL: string): TStringList;
    procedure StartDownload(const URL, FormatCode: string);
    procedure FinalizeDownload;
    procedure StartDownloadAudio(const URL, FileType: string);

  public
    { Public declarations }
  end;

var
  frmMainForm: TfrmMainForm;

implementation

{$R *.dfm}

procedure KillProcessByName(const AProcessName: string);
var
  hSnapshot: THandle;
  ProcEntry: TProcessEntry32;
  hProcess: THandle;
begin
  hSnapshot := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if hSnapshot = INVALID_HANDLE_VALUE then
    Exit;
  try
    ProcEntry.dwSize := SizeOf(TProcessEntry32);
    if Process32First(hSnapshot, ProcEntry) then
    begin
      repeat
        if SameText(ExtractFileName(ProcEntry.szExeFile), AProcessName) then
        begin
          hProcess := OpenProcess(PROCESS_TERMINATE, False,
            ProcEntry.th32ProcessID);
          if hProcess <> 0 then
          begin
            TerminateProcess(hProcess, 0);
            CloseHandle(hProcess);
          end;
        end;
      until not Process32Next(hSnapshot, ProcEntry);
    end;
  finally
    CloseHandle(hSnapshot);
  end;
end;

procedure OpenDownloadsFolder;
var
  DownloadsFolder: string;
begin
  // Downloads klas�r�n�n yolunu belirleyin (uygulaman�n bulundu�u dizinin alt�ndaki Downloads klas�r�)
  DownloadsFolder := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)))
    + 'Downloads\';
  // Downloads klas�r�n� a�ma
  ShellExecute(0, 'open', PChar(DownloadsFolder), nil, nil, SW_SHOW);
end;

function ExtractPercentage(const Text: string): Integer;
var
  PercentPos: Integer;
  PercentStr: string;
begin
  // % i�aretinin konumunu bul
  PercentPos := Pos('%', Text);

  // Son i�lem i�in 100% kontrol�
  if (Pos('[download]', Text) > 0) and (PercentPos > 0) then
  begin
    // % i�aretinden �nceki k�sm� al
    PercentStr := Copy(Text, 1, PercentPos - 1);
    // Son bo�luklardan sonraki k�sm� al
    PercentStr := Trim(Copy(PercentStr, LastDelimiter(' ', PercentStr) + 1));
    // Ondal�k nokta varsa onu kullan, yoksa t�m stringi kullan
    if Pos('.', PercentStr) > 0 then
      Result := StrToInt(Copy(PercentStr, 1, Pos('.', PercentStr) - 1))
    else
      Result := StrToInt(PercentStr);
    Exit;
  end
  // Son i�lem i�in 100% kontrol�
  else if (Pos('[Merger]', Text) > 0) or (Pos('Deleting', Text) > 0) then
  begin
    Result := 100;
    Exit;
  end;
  // E�er ko�ullar sa�lanmazsa -1 d�nd�r
  Result := -1;
end;

procedure TfrmMainForm.StartDownloadAudio(const URL, FileType: string);
var
  Security: TSecurityAttributes;
  StartupInfo: TStartupInfo;
  Command: string;
  DownloadFolder: string;
  LogForm: TfrmLogMemo; // TfrmUpdate s�n�f�ndan bir de�i�ken tan�ml�yoruz
begin

 LogForm := TfrmLogMemo.Create(Self);

  KillProcessByName('yt-dlp.exe');
  KillProcessByName('ffmpeg.exe');

  pgbBar.Visible := true;
  pgbBar.Position := 0;

  pnlAudio.Enabled := False;
  pnlVideo.Enabled := False;

  // Downloads klas�r�n�n yolunu belirle (uygulaman�n bulundu�u dizinin alt�na Downloads)
  DownloadFolder := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) +
    'Downloads\';

  // E�er Downloads klas�r� yoksa, olu�tur
  if not DirectoryExists(DownloadFolder) then
    ForceDirectories(DownloadFolder);

  ZeroMemory(@Security, SizeOf(TSecurityAttributes));
  Security.nLength := SizeOf(TSecurityAttributes);
  Security.bInheritHandle := true;

  if not CreatePipe(FReadPipe, FWritePipe, @Security, 0) then
  begin
    ShowMessage('Pipe olu�turulamad�.');
    Exit;
  end;

  ZeroMemory(@StartupInfo, SizeOf(TStartupInfo));
  ZeroMemory(@FProcessInfo, SizeOf(TProcessInformation));

  StartupInfo.cb := SizeOf(TStartupInfo);
  StartupInfo.dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
  StartupInfo.hStdOutput := FWritePipe;
  StartupInfo.hStdError := FWritePipe;
  StartupInfo.wShowWindow := SW_HIDE;

  // Adjust format and bitrate based on 'FileType' parameter
  if FileType = 'mp3' then
    Command :=
      Format('Tools/yt-dlp.exe --extract-audio --audio-format mp3 --audio-quality 0 --newline -o "%s%%(title)s.%%(ext)s" "%s"',
      [DownloadFolder, URL])
  else if FileType = 'flac' then
    Command :=
      Format('Tools/yt-dlp.exe --extract-audio --audio-format flac --newline -o "%s%%(title)s.%%(ext)s" "%s"',
      [DownloadFolder, URL])

  else if FileType = 'm4a' then
    Command :=
      Format('Tools/yt-dlp.exe --extract-audio --audio-format m4a --audio-quality 128k --newline -o "%s%%(title)s.%%(ext)s" "%s"',
      [DownloadFolder, URL])
  else
  begin
    ShowMessage('Ge�ersiz format tipi!');
    Exit;
  end;

  // Start the download process
  if not CreateProcess(nil, PChar(Command), nil, nil, true, 0, nil, nil,
    StartupInfo, FProcessInfo) then
  begin
    ShowMessage('�ndirme i�lemi ba�lat�lamad�.');
    CloseHandle(FReadPipe);
    CloseHandle(FWritePipe);
    Exit;
  end;

  FTask := TTask.Run(
    procedure
    var
      Buffer: array [0 .. 1023] of AnsiChar;
      BytesRead: DWORD;
      Line: string;
    begin
      while true do
      begin
        if not ReadFile(FReadPipe, Buffer, SizeOf(Buffer) - 1, BytesRead, nil)
          or (BytesRead = 0) then
          Break;

        Buffer[BytesRead] := #0;
        Line := string(Buffer);

        TThread.Synchronize(nil,
          procedure
          begin
            // Dinamik olarak form olu�turuluyor

            try
              // Modal olarak g�steriliyor
              LogForm.Show;
              LogForm.mmLog.Lines.Add(Line);
            finally
              // Form bellekten serbest b�rak�l�yor
              //LogForm.Free;
            end;

           // frmLogMemo.Show;
           // frmLogMemo.mmLog.Lines.Add(Line);
            var
              Position: Integer := ExtractPercentage(Line);
            pgbBar.Position := Position;
            // Convert to integer and set the progress bar position
            // E�er "Deleting original file" metni bulunursa, i�lem yap
            if Pos('Deleting original file', Line) > 0 then
            begin
              // Yap�lacak i�lem
              // ShowMessage('Deleting original file found!');
              OpenDownloadsFolder;
              pgbBar.Position := 0;
              pnlAudio.Enabled := true;
              pnlVideo.Enabled := true;
              pgbBar.Visible := False;

              ShowMessage('�ndirme i�lemi bitti.');
            end;
            // E�er "Deleting original file" metni bulunursa, i�lem yap
            if Pos('has already been downloaded', Line) > 0 then
            begin
              // Yap�lacak i�lem
              // ShowMessage('Deleting original file found!');
              pgbBar.Position := 0;
              pnlAudio.Enabled := true;
              pnlVideo.Enabled := true;
              pgbBar.Visible := False;
              ShowMessage('ayn� video indii�i i�in �zerine yaz�lam�yor.');
            end;
          end);
      end;

      TThread.Synchronize(nil, FinalizeDownload);
    end);
end;

procedure TfrmMainForm.StartDownload(const URL, FormatCode: string);
var
  Security: TSecurityAttributes;
  StartupInfo: TStartupInfo;
  Command: string;
  DownloadFolder: string;
  LogForm: TfrmLogMemo; // TfrmUpdate s�n�f�ndan bir de�i�ken tan�ml�yoruz
begin

  KillProcessByName('yt-dlp.exe');
  KillProcessByName('ffmpeg.exe');

  pgbBar.Visible := true;

  pnlAudio.Enabled := False;
  pnlVideo.Enabled := False;


    // Dinamik olarak form olu�turuluyor
  LogForm := TfrmLogMemo.Create(Self);
  try
    // Modal olarak g�steriliyor
   // LogForm.Show;
    //LogForm.mmLog.Lines.Add(Line);
  finally
    // Form bellekten serbest b�rak�l�yor
   // LogForm.Free;
  end;




  pgbBar.Position := 0;

  // Downloads klas�r�n�n yolunu belirle (uygulaman�n bulundu�u dizinin alt�na Downloads)
  DownloadFolder := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) +
    'Downloads\';

  // E�er Downloads klas�r� yoksa, olu�tur
  if not DirectoryExists(DownloadFolder) then
    ForceDirectories(DownloadFolder);

  ZeroMemory(@Security, SizeOf(TSecurityAttributes));
  Security.nLength := SizeOf(TSecurityAttributes);
  Security.bInheritHandle := true;

  if not CreatePipe(FReadPipe, FWritePipe, @Security, 0) then
  begin
    ShowMessage('Pipe olu�turulamad�.');
    Exit;
  end;

  ZeroMemory(@StartupInfo, SizeOf(TStartupInfo));
  ZeroMemory(@FProcessInfo, SizeOf(TProcessInformation));

  StartupInfo.cb := SizeOf(TStartupInfo);
  StartupInfo.dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
  StartupInfo.hStdOutput := FWritePipe;
  StartupInfo.hStdError := FWritePipe;
  StartupInfo.wShowWindow := SW_HIDE;

  // Komutu, indirilen dosyan�n Downloads klas�r�ne kaydedilmesi i�in g�ncelle
  Command :=
    Format('Tools/yt-dlp.exe --format "%s[ext=mp4]+bestaudio[ext=m4a]" --newline -o "%s%%(title)s.%%(ext)s" "%s"',
    [FormatCode, DownloadFolder, URL]);

  Command :=
    Format('Tools/yt-dlp.exe --format "%s[ext=mp4]+bestaudio[ext=m4a]" --merge-output-format mp4 --newline -o "%s%%(title)s.%%(ext)s" "%s"',
    [FormatCode, DownloadFolder, URL]);

  // Memo1.Lines.Clear;
  if not CreateProcess(nil, PChar(Command), nil, nil, true, 0, nil, nil,
    StartupInfo, FProcessInfo) then
  begin
    ShowMessage('�ndirme i�lemi ba�lat�lamad�.');
    CloseHandle(FReadPipe);
    CloseHandle(FWritePipe);
    Exit;
  end;

  FTask := TTask.Run(
    procedure
    var
      Buffer: array [0 .. 1023] of AnsiChar;
      BytesRead: DWORD;
      Line: string;
    begin
      while true do
      begin
        if not ReadFile(FReadPipe, Buffer, SizeOf(Buffer) - 1, BytesRead, nil)
          or (BytesRead = 0) then
          Break;

        Buffer[BytesRead] := #0;
        Line := string(Buffer);

        TThread.Synchronize(nil,
          procedure
          begin

           LogForm.Show;
           LogForm.mmLog.Lines.Add(Line);

            var
              Position: Integer := ExtractPercentage(Line);
            pgbBar.Position := Position;
            // Convert to integer and set the progress bar position
            if Pos('Deleting original file', Line) > 0 then
            begin

              OpenDownloadsFolder;
              pgbBar.Position := 0;
              pnlAudio.Enabled := true;
              pnlVideo.Enabled := true;
              pgbBar.Visible := False;
            end;
            if Pos('has already been downloaded', Line) > 0 then
            begin
              pgbBar.Position := 0;
              pnlAudio.Enabled := true;
              pnlVideo.Enabled := true;
              pgbBar.Visible := False;
            end;
          end);

      end;

      TThread.Synchronize(nil, FinalizeDownload);
    end);
end;

procedure TfrmMainForm.FinalizeDownload;
begin
  pgbBar.Position := 0;

  // ��lem temizli�i
  CloseHandle(FReadPipe);
  CloseHandle(FWritePipe);
  CloseHandle(FProcessInfo.hProcess);
  CloseHandle(FProcessInfo.hThread);
end;

procedure TfrmMainForm.FormActivate(Sender: TObject);

var
  DownloadsFolder: string;
begin
  // Downloads klas�r�n�n yolunu belirleyin (uygulaman�n bulundu�u dizinin alt�ndaki Downloads klas�r�)
  DownloadsFolder := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)))
    + 'Downloads\';
  stbBar.SimpleText := 'Download Folder : ' + DownloadsFolder;
end;

function IsValidYouTubeURL(const URL: string): Boolean;
var
  RegEx: TRegEx;
begin
  // YouTube URL'si i�in regex patterni
  RegEx := TRegEx.Create
    ('^(https://www\.youtube\.com/watch\?v=[\w-]+|https://youtu\.be/[\w-]+)$');

  // URL'nin ge�erli olup olmad���n� kontrol et
  Result := RegEx.IsMatch(URL);
end;

function GetResolutionDescription(const Resolution: string): string;
var
  ResolutionDict: TDictionary<string, string>;
begin
  ResolutionDict := TDictionary<string, string>.Create;
  try
    // ��z�n�rl�k - A��klama e�le�tirmeleri
    ResolutionDict.Add('2560x1440', '1440p (Quad HD)');
    ResolutionDict.Add('3840x2160', '2160p (4K UHD)');
    ResolutionDict.Add('7680x4320', '4320p (8K UHD)');
    ResolutionDict.Add('1920x1080', '1080p (Full HD)');
    ResolutionDict.Add('1280x720', '720p (HD)');
    ResolutionDict.Add('854x480', '480p (SD)');
    ResolutionDict.Add('640x360', '360p (Standard Quality)');
    ResolutionDict.Add('426x240', '240p (Low Quality)');
    ResolutionDict.Add('256x144', '144p (Very Low Quality)');

    // �stenen ��z�n�rl���n a��klamas� d�nd�r�l�r
    if ResolutionDict.TryGetValue(Resolution, Result) then
      Exit
    else
      Result := 'Unknown Resolution'; // ��z�n�rl�k bulunamazsa
  finally
    ResolutionDict.Free;
  end;
end;

procedure TfrmMainForm.btn1080pMP4Click(Sender: TObject);
begin
  StartDownload(edtYoutubeUrl.Text, IntToStr(btn1080pMP4.Tag));
end;

procedure TfrmMainForm.btn1440pMP4Click(Sender: TObject);
begin
  StartDownload(edtYoutubeUrl.Text, IntToStr(btn1440pMP4.Tag));
end;

procedure TfrmMainForm.btn2160pMP4Click(Sender: TObject);
begin
  StartDownload(edtYoutubeUrl.Text, IntToStr(btn2160pMP4.Tag));
end;

procedure TfrmMainForm.btn360pMP4Click(Sender: TObject);
begin
  StartDownload(edtYoutubeUrl.Text, IntToStr(btn360pMP4.Tag));
end;

procedure TfrmMainForm.btn4320pMP4Click(Sender: TObject);
begin
  StartDownload(edtYoutubeUrl.Text, IntToStr(btn4320pMP4.Tag));
end;

procedure TfrmMainForm.btn480pMP4Click(Sender: TObject);
begin
  StartDownload(edtYoutubeUrl.Text, IntToStr(btn480pMP4.Tag));
end;

procedure TfrmMainForm.btn720pMP4Click(Sender: TObject);
begin
  StartDownload(edtYoutubeUrl.Text, IntToStr(btn720pMP4.Tag));
end;

procedure TfrmMainForm.btnFlacClick(Sender: TObject);
begin
  StartDownloadAudio(edtYoutubeUrl.Text, 'flac');
end;

procedure TfrmMainForm.btnM4aClick(Sender: TObject);
begin
  StartDownloadAudio(edtYoutubeUrl.Text, 'm4a');
end;

procedure TfrmMainForm.btnMp3Click(Sender: TObject);
begin
  StartDownloadAudio(edtYoutubeUrl.Text, 'mp3');
end;

procedure TfrmMainForm.btnPasteYoutubeUrlClick(Sender: TObject);
begin
  edtYoutubeUrl.Clear;
  edtYoutubeUrl.PasteFromClipboard;
end;

procedure TfrmMainForm.btnUpdateClick(Sender: TObject);
var
  UpdateForm: TfrmUpdate; // TfrmUpdate s�n�f�ndan bir de�i�ken tan�ml�yoruz
begin
  // Dinamik olarak form olu�turuluyor
  UpdateForm := TfrmUpdate.Create(Self);
  try
    // Modal olarak g�steriliyor
    UpdateForm.ShowModal;
  finally
    // Form bellekten serbest b�rak�l�yor
    UpdateForm.Free;
  end;
end;

procedure TfrmMainForm.btnYoutubeSearchClick(Sender: TObject);
var
  Formats: TStringList;
  I: Integer;
  Resolution, Description: string;
begin
  Formats := GetYouTubeFormats(edtYoutubeUrl.Text);
  try
    for I := 0 to Formats.Count - 1 do
    begin
      // Description := GetResolutionDescription(Resolution);
      // Memo1.Lines.Add(Formats[I]); // Listeyi Memo'ya yazd�r
    end;
  finally
    Formats.Free;
  end;
end;

function TfrmMainForm.GetYouTubeFormats(const URL: string): TStringList;
var
  Process: TProcess;
  OutputLines: TStringList;
  OutputString: string;
  I: Integer;
  Match: TMatch;
  RegEx: TRegEx;
  SizeRegex: TRegEx;
  VideoSize: string;
  VideoFormat: string;
  Resolution, Size, File_Type, ResolutionStr: string;
  Format_Code: Integer;
begin

  btnMp3.Enabled := true;
  btnFlac.Enabled := true;
  btnM4a.Enabled := true;

  Result := TStringList.Create;
  Process := TProcess.Create(nil);
  OutputLines := TStringList.Create;
  try
    // Mutlak yol kullanarak yt-dlp.exe'nin do�ru �ekilde �al��t���ndan emin olun
    Process.Executable := IncludeTrailingPathDelimiter
      (ExtractFilePath(ParamStr(0))) + 'Tools\yt-dlp.exe';

    // Parametreleri ekleyelim
    Process.Parameters.Add('-F'); // Format listesini getirir
    Process.Parameters.Add(URL); // Video URL'si
    Process.Options := [poUsePipes, poNoConsole];
    // poNoConsole ile komut penceresini gizle
    Process.ShowWindow := swoHide; // Pencereyi gizlemek i�in kullan�l�r
    // Process'i �al��t�r
    Process.Execute;
    // ��kt�y� oku
    with TStreamReader.Create(Process.Output) do
      try
        OutputString := ReadToEnd;
      finally
        Free;
      end;

    // ��kt�y� sat�rlara b�l
    OutputLines.Text := OutputString;

    // ��z�n�rl�k ID'si ve ��z�n�rl��� ay�klamak i�in regex
    RegEx := TRegEx.Create('^(\d+)\s+\w+\s+(\d+x\d+)', [roMultiLine]);
    // Video boyutunu almak i�in regex
    SizeRegex := TRegEx.Create('(\d+\.?\d*(GiB|MiB))', [roMultiLine]);

    btn4320pMP4.Caption := '';
    btn2160pMP4.Caption := '';
    btn1440pMP4.Caption := '';
    btn1080pMP4.Caption := '';
    btn720pMP4.Caption := '';
    btn480pMP4.Caption := '';
    btn360pMP4.Caption := '';

    for I := 0 to OutputLines.Count - 1 do
    begin
      // ��z�n�rl�k ve ID e�le�mesini kontrol et
      Match := RegEx.Match(OutputLines[I]);
      if Match.Success then
      begin
        // Boyut bilgisini bulmak i�in
        VideoSize := '';
        // Boyut bilgisini arayal�m
        var
        SizeMatch := SizeRegex.Match(OutputLines[I]);
        if SizeMatch.Success then
        begin
          VideoSize := SizeMatch.Value;
        end;

        // Video format�n� belirlemek i�in string i�erisinde 'mp4' veya 'webm' arayal�m
        VideoFormat := '';
        if Pos('mp4', OutputLines[I]) > 0 then
          VideoFormat := 'mp4'
        else if Pos('webm', OutputLines[I]) > 0 then
          VideoFormat := 'webm';

        // E�er ��z�n�rl�k ve boyut bulunduysa, sonucu ekleyelim
        if (Match.Groups.Count > 1) then
        begin
          Format_Code := StrToInt(Match.Groups[1].Value); // Format Code
          Resolution := Match.Groups[2].Value; // 256x144
          Size := VideoSize; // Boyut
          File_Type := VideoFormat; // Format (mp4/webm)
          ResolutionStr := GetResolutionDescription(Match.Groups[2].Value);
          // ��z�n�rl�k a��klamas�

          // �lgili ��z�n�rl�k ve format i�in butonlar� etkinle�tir
          if (Resolution = '7680x4320') and (File_Type = 'mp4') then
          begin
            btn4320pMP4.Enabled := true;
            btn4320pMP4.Tag := Format_Code;
            // btn4320pMP4.Caption:=btn4320pMP4.Caption+' - '+ Size;
            btn4320pMP4.Caption := 'MP4 4320p 8K' + ' - ' + Size;
          end;

          if (Resolution = '3840x2160') and (File_Type = 'mp4') then
          begin
            btn2160pMP4.Enabled := true;
            btn2160pMP4.Tag := Format_Code;
            // btn2160pMP4.Caption:=btn2160pMP4.Caption+' - '+ Size;
            btn2160pMP4.Caption := 'MP4 2160p 4K' + ' - ' + Size;
          end;

          if (Resolution = '2560x1440') and (File_Type = 'mp4') then
          begin
            btn1440pMP4.Enabled := true;
            btn1440pMP4.Tag := Format_Code;
            // btn1440pMP4.Caption:=btn1440pMP4.Caption+' - '+ Size;
            btn1440pMP4.Caption := 'MP4 1440p QHD' + ' - ' + Size;
          end;

          if (Resolution = '1920x1080') and (File_Type = 'mp4') then
          begin
            btn1080pMP4.Enabled := true;
            btn1080pMP4.Tag := Format_Code;
            // btn1080pMP4.Caption:=btn1080pMP4.Caption+' - '+ Size;
            btn1080pMP4.Caption := 'MP4 1080p FHD' + ' - ' + Size;
          end;

          if (Resolution = '1280x720') and (File_Type = 'mp4') then
          begin
            btn720pMP4.Enabled := true;
            btn720pMP4.Tag := Format_Code;
            // btn720pMP4.Caption:=btn720pMP4.Caption+' - '+ Size;
            btn720pMP4.Caption := 'MP4 720p HD' + ' - ' + Size;
          end;

          if (Resolution = '854x480') and (File_Type = 'mp4') then
          begin
            btn480pMP4.Enabled := true;
            btn480pMP4.Tag := Format_Code;
            // btn480pMP4.Caption:=btn480pMP4.Caption+' - '+ Size;
            btn480pMP4.Caption := 'MP4 480p' + ' - ' + Size;
          end;

          if (Resolution = '640x360') and (File_Type = 'mp4') then
          begin
            btn360pMP4.Enabled := true;
            btn360pMP4.Tag := Format_Code;
            // btn360pMP4.Caption:=btn360pMP4.Caption+' - '+ Size;
            btn360pMP4.Caption := 'MP4 360p' + ' - ' + Size;
          end;

          // Sonu�lar� listeye ekleyelim
          Result.Add(Match.Groups[1].Value + ' - ' + Match.Groups[2].Value +
            ' - ' + ResolutionStr + ' - ' + VideoSize + ' - ' + VideoFormat);
        end;

        if (btn4320pMP4.Caption = '') then
        begin
          btn4320pMP4.Enabled := False;
          btn4320pMP4.Caption := 'MP4 4320p 8K';
        end;

        if (btn2160pMP4.Caption = '') then
        begin
          btn2160pMP4.Enabled := False;
          btn2160pMP4.Caption := 'MP4 2160p 4K';
        end;

        if (btn1440pMP4.Caption = '') then
        begin
          btn1440pMP4.Enabled := False;
          btn1440pMP4.Caption := 'MP4 1440p QHD';
        end;

        if (btn1080pMP4.Caption = '') then
        begin
          btn1080pMP4.Enabled := False;
          btn1080pMP4.Caption := 'MP4 1080p FHD';
        end;

        if (btn720pMP4.Caption = '') then
        begin
          btn720pMP4.Enabled := False;
          btn720pMP4.Caption := 'MP4 720p HD';
        end;

        if (btn480pMP4.Caption = '') then
        begin
          btn480pMP4.Enabled := False;
          btn480pMP4.Caption := 'MP4 480p';
        end;

        if (btn360pMP4.Caption = '') then
        begin
          btn360pMP4.Enabled := False;
          btn360pMP4.Caption := 'MP4 360p';
        end;

      end;
    end;

  finally
    Process.Free;
    OutputLines.Free;
  end;
end;

procedure TfrmMainForm.mtUpdateFormClick(Sender: TObject);
var
  UpdateForm: TfrmUpdate; // TfrmUpdate s�n�f�ndan bir de�i�ken tan�ml�yoruz

begin
  // Dinamik olarak form olu�turuluyor
  UpdateForm := TfrmUpdate.Create(Self);
  try
    // Modal olarak g�steriliyor
    UpdateForm.ShowModal;
  finally
    // Form bellekten serbest b�rak�l�yor
    UpdateForm.Free;
  end;
end;

end.

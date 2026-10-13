{$O+,F+,G+,S-,I-,X+}
unit Execute;

interface

function RunProg(Prog, Params: string): Boolean;
function RunWindow(Prog, Params, Title: string): Boolean;
procedure ShowError(Prog: string; Err, Code: Byte);
procedure MovePackWin;
function RunPacker(Prog, Params, Title: string): Boolean;
procedure PackSettings;

implementation

uses Dos, Crt, DXGlob, Buttons, Mouse, Screen, Windows, ScrSave, Dialogs, Status, U0DA0;

type
  TIniRec = record
    Id: string[41];
    Fill1: array[1..$132 - 42] of Byte;
    PackFull: Boolean;
    Fill2: array[1..$70C - $133] of Byte;
    PackY2, PackX2, PackX1, PackY1: Byte;
    Fill3: array[1..$712 - $710] of Byte;
  end;

procedure Int29Handler(Flags, CS, IP, AX, BX, CX, DX, SI, DI, DS, ES, BP: Word); interrupt;
begin
  Write(Chr(Lo(AX)));
end;

function RunProg(Prog, Params: string): Boolean;
var
  R: Registers;
  SaveTop: Pointer;
  Err, Code: Word;
  Path, S2: string;
begin
  Path := FSearch(Prog, GetEnv('PATH') + ';' + HomeDir);
  if Path = '' then
  begin
    MsgBox('Programm ' + Prog + ' nicht gefunden!', 'Es mu'#$E1' im Pfad (Path) vorhanden sein!');
    RunProg := False;
  end
  else
  begin
    Prog := Path;
    R.AH := $3E;
    R.BX := 1;
    MsDos(R);
    R.AH := $3E;
    R.BX := 2;
    MsDos(R);
    R.AH := $3D;
    R.AL := 1;
    R.DS := DSeg;
    R.DX := Ofs(NulName);
    MsDos(R);
    R.AH := $3D;
    R.AL := 1;
    R.DS := DSeg;
    R.DX := Ofs(NulName);
    MsDos(R);
    SaveTop := HeapEnd;
    SetMemTop(HeapPtr);
    SwapVectors;
    Exec(Prog, Params);
    Err := DosError;
    Code := DosExitCode;
    SwapVectors;
    SetMemTop(SaveTop);
    R.AH := $3E;
    R.BX := 1;
    MsDos(R);
    R.AH := $3E;
    R.BX := 2;
    MsDos(R);
    R.AH := $3D;
    R.AL := 1;
    R.DS := DSeg;
    R.DX := Ofs(ConName);
    MsDos(R);
    R.AH := $3D;
    R.AL := 1;
    R.DS := DSeg;
    R.DX := Ofs(ConName);
    MsDos(R);
    Str(Err, Path);
    Str(Code, S2);
    InstallHandler;
    MouseShow;
    MouseYRange(0, ScreenRows - 1);
    if Err + Code <> 0 then
      ShowError(Prog, Err, Code);
    RunProg := Err + Code = 0;
  end;
end;


function RunFull(Prog, Params, Title: string): Boolean;
var
  R: Registers;
  SaveTop: Pointer;
  Err, Code: Word;
  Path, S2: string;
  Key: Word;
  OldMode: Byte;
begin
  Path := FSearch(Prog, GetEnv('PATH') + ';' + HomeDir);
  if Path = '' then
  begin
    MsgBox('Programm ' + Prog + ' nicht gefunden!', 'Es mu'#$E1' im Pfad (Path) vorhanden sein!');
    RunFull := False;
  end
  else
  begin
    Prog := Path;
    OpenDialog;
    Window(1, 1, 80, ScreenRows);
    SetColor(7, 0);
    ClrScr;
    SetBorder(0);
    OldMode := RunMode;
    WriteCenterXYFB(1, 1, 80, 0, 5, Title);
    RunMode := 5;
    ClockHidden := False;
    Idle;
    SaveTop := HeapEnd;
    SetMemTop(HeapPtr);
    SwapVectors;
    CheckBreak := True;
    SetCBreak(True);
    ShowCursor;
    Exec(Prog, Params);
    CheckBreak := False;
    SetCBreak(False);
    Err := DosError;
    Code := DosExitCode;
    SwapVectors;
    SetMemTop(SaveTop);
    Str(Err, Path);
    Str(Code, S2);
    HideCursor;
    ResetMouse;
    InstallHandler;
    MouseYRange(0, ScreenRows - 1);
    WriteLn('Weiter mit einer Taste...');
    NormalCursor;
    MouseShow;
    if Err + Code <> 0 then
      ShowError(Prog, Err, Code);
    repeat
      Idle;
    until GetKey(Key) or (MouseButton <> 0);
    WaitRelease;
    RunFull := Err + Code = 0;
    PopScreen(DlgStack);
    RestoreBorder;
    RunMode := OldMode;
    ClockHidden := False;
    Idle;
  end;
end;

function RunWindow(Prog, Params, Title: string): Boolean;
var
  R: Registers;
  SaveTop: Pointer;
  Err, Code: Word;
  Path, S2: string;
  OldVec: Pointer;
  Key: Word;
begin
  Path := FSearch(Prog, GetEnv('PATH') + ';' + HomeDir);
  if Path = '' then
  begin
    MsgBox('Programm ' + Prog + ' nicht gefunden!', 'Es mu'#$E1' im Pfad (Path) vorhanden sein!');
    RunWindow := False;
  end
  else
  begin
    Prog := Path;
    OpenDialog;
    GetIntVec($29, OldVec);
    SetIntVec($29, @Int29Handler);
    if PackY2 >= ScreenRows then PackY2 := ScreenRows - 1;
    Frame(PackX1, PackY1, PackX2 - PackX1 - 1, 1, 11, 6, 0, 1);
    WriteCenterXY(1, 1, PackX2 - PackX1 - 2, Title);
    Frame(PackX1, PackY1 + 3, PackX2 - PackX1 - 1, PackY2 - PackY1 - 4, 11, 6, 0, 1);
    Window(PackX1 + 2, PackY1 + 4, PackX2 - 2, PackY2 - 1);
    SetColor(7, 0);
    ClrScr;
    SaveTop := HeapEnd;
    SetMemTop(HeapPtr);
    SwapVectors;
    CheckBreak := True;
    SetCBreak(True);
    ShowCursor;
    Exec(Prog, Params);
    CheckBreak := False;
    SetCBreak(False);
    Err := DosError;
    Code := DosExitCode;
    SetIntVec($29, OldVec);
    SwapVectors;
    SetMemTop(SaveTop);
    Str(Err, Path);
    Str(Code, S2);
    HideCursor;
    ResetMouse;
    InstallHandler;
    MouseYRange(0, ScreenRows - 1);
    WriteLn('Weiter mit einer Taste...');
    NormalCursor;
    MouseShow;
    if Err + Code <> 0 then
      ShowError(Prog, Err, Code);
    repeat
      Idle;
    until GetKey(Key) or (MouseButton <> 0);
    WaitRelease;
    RunWindow := Err + Code = 0;
    PopScreen(DlgStack);
  end;
end;

function RunPacker(Prog, Params, Title: string): Boolean;
begin
  if PackFull then
    RunFull(Prog, Params, Title)
  else
    RunWindow(Prog, Params, Title);
end;

procedure ShowError(Prog: string; Err, Code: Byte);
var
  NoMsg: Boolean;
  D: DirStr;
  N: NameStr;
  E: ExtStr;
  PName: string[12];
  NumS: string[12];
begin
  NoMsg := False;
  NormalCursor;
  FSplit(Prog, D, N, E);
  PName := N + E;
  MouseHide;
  PushScreen(DlgStack);
  Frame(13, 6, 55, 11, 15, 4, 0, 1);
  WriteCenterXYF(1, 1, 55, 14, 'Fehler:');
  SetColor(15, 4);
  WriteCenterXY(1, 11, 54, ' Weiter mit beliebiger Taste ...');
  Str(Err, NumS);
  WriteCenterXY(1, 3, 55, 'DOS meldet Fehler Nr.: ' + NumS);
  Str(Code, NumS);
  WriteCenterXY(1, 5, 55, Shorten(UpperStr(Prog), 30) + ' meldet Fehler Nr.: ' + NumS);
  Window(17, 13, 80, 25);
  if PName = 'arj.exe' then
    case Code of
      1: Write('Warning: file not found.');
      2: Write('Fatal error.');
      3: Write('CRC error (header or file CRC error).');
      4:
        begin
          WriteLn('ARJ-SECURITY error or attempt to update an');
          WriteLn('ARJ-SECURED archive.');
        end;
      5: Write('Disk full or write error.');
      6: Write('Can''t open archive or file.');
      7: Write('Simple user error (bad parameters).');
      8: Write('Not enough memory.');
      9: Write('Not an ARJ archive.');
    else
      NoMsg := True;
    end
  else if PName = 'lha.exe' then
    case Code of
      1:
        begin
          WriteLn('CRC error occured or failed to create files');
          WriteLn('because of disk space, or because of files');
          WriteLn('in existence.');
        end;
      2:
        begin
          WriteLn('Fatal error:');
          WriteLn('Process terminated without transactions.');
        end;
      3: Write('Failed to write temporary files in the archive.');
    else
      NoMsg := True;
    end
  else if PName = 'pkzip.exe' then
    case Code of
      1: Write('Bad file name or file specification.');
      2, 3: Write('Error in .ZIP file.');
      4..11: Write('Insufficient Memory.');
      12:
        begin
          WriteLn('No files were found to add to the .ZIP file, or');
          WriteLn('no files were specified for deletion.');
        end;
      13:
        begin
          WriteLn('File not found.  The specified .ZIP file or');
          WriteLn('list file was not found.');
        end;
      14: Write('Disk full.');
      15: Write('.ZIP file is read-only and can not be modified.');
      16: Write('Bad or illegal parameters specified.');
      17: Write('Too many files.');
      18: Write('Could not open file.');
      255: Write('User pressed control-c or control-break');
    else
      NoMsg := True;
    end
  else if PName = 'pkunzip.exe' then
    case Code of
      1: Write('Warning error (such as failed CRC check).');
      2, 3: Write('Error in .ZIP file.');
      4..8: Write('Insufficient Memory.');
      9: Write('File not found.  No .ZIP files found.');
      10: Write('Bad or illegal parameters specified.');
      11: Write('No files found to extract/view etc.');
      50: Write('Disk Full.');
      51: Write('Unexpected EOF in .ZIP file.');
      255: Write('User pressed control-c or control-break');
    else
      NoMsg := True;
    end
  else if PName = 'zip2exe.exe' then
    case Code of
      1: Write('Error in .ZIP file');
      2: Write('Error in .ZIP file, use PKZIPFIX');
      3, 4: Write('Insufficient memory to process file');
      7: Write('Can''t open Source file');
      8: Write('Error in .ZIP file');
      9:
        begin
          WriteLn('Disk full writing target file');
          WriteLn('during EXE to ZIP process.');
        end;
      11:
        begin
          WriteLn('Disk full writing target file');
          WriteLn('during ZIP to EXE process.');
        end;
      12:
        begin
          WriteLn('.ZIP file being converted contains a file');
          WriteLn('compressed with a method not supported by');
          WriteLn('the version of PKSFX being attached by ZIP2EXE');
        end;
    else
      NoMsg := True;
    end
  else
    NoMsg := True;
  if NoMsg then
    WriteLn('    Keine Klarschrift-Fehlermeldung vorhanden.');
  MouseShow;
  WaitInput;
  CloseDialog;
end;


procedure DrawPackWin(Full: Boolean);
var
  I: Byte;
begin
  MouseHide;
  Frame(PackX1, PackY1, PackX2 - PackX1 - 1, 1, 11, 6, Ord(Full = False), Ord(Full));
  if Full then
    WriteCenterXY(1, 1, PackX2 - PackX1 - 4, ' Packer-Fenster:')
  else
    WriteCenterXY(1, 1, PackX2 - PackX1 - 2, ' Packer-Fenster:');
  Frame(PackX1, PackY1 + 3, PackX2 - PackX1 - 1, PackY2 - PackY1 - 4, 11, 6, Ord(Full = False), Ord(Full));
  Window(1, 1, 80, ScreenRows);
  WriteXYFB(PackX1 - 1 + (PackX2 - PackX1) div 2, PackY2, 11, 6, #18);
  for I := 1 to 2 do
    WriteFB(11, 6, #18);
  for I := 1 to 2 do
    WriteXYFB(PackX2, PackY1 + I + (PackY2 - PackY1) div 2, 11, 6, #29);
  WriteXYFB(PackX2, PackY2, 11, 6, '\');
  Window(PackX1 + 2, PackY1 + 4, PackX2 - 2, PackY2 - 1);
  SetColor(7, 0);
  if Full then ClrScr;
  MouseShow;
end;

procedure MovePackWin;
label
  Corner;
var
  Key: Word;
  MX, MY: Byte;
  OldSound: Boolean;

procedure RestoreAround;
begin
  MouseHide;
  RestoreLine(PackY2 + 1, DlgStack.Top);
  RestoreColumn(PackX2 + 1, DlgStack.Top);
  RestoreColumn(PackX2 + 2, DlgStack.Top);
  MouseShow;
end;

begin
  OpenDialog;
  MouseShow;
  OldSound := SoundOn;
  SoundOn := False;
  if PackY2 >= ScreenRows then PackY2 := ScreenRows - 1;
  DrawPackWin(True);
  MouseHide;
  ClrScr;
  Write('Positionieren Sie das Fenster mit der Maus ');
  MouseShow;
  repeat
    GetKey(Key);
    if MouseOn(PackY2, PackX1 + 1, PackX2 - 1) then
    begin
      RestoreAround;
      DrawPackWin(False);
      repeat
        if (PackY2 <> MouseY) and (ScreenRows > MouseY) and (PackY1 + 4 < MouseY) then
        begin
          if PackY2 > MouseY then
          begin
            MouseHide;
            RestoreLine(PackY2, DlgStack.Top);
            MouseShow;
            Dec(PackY2);
          end
          else
            Inc(PackY2);
          DrawPackWin(False);
        end;
        if PackX2 <= MouseX then goto Corner;
      until MouseButton = 0;
      DrawPackWin(True);
    end;
    if (MouseButton = 1) and (PackX2 = MouseX) and (PackY1 < MouseY) and (PackY2 > MouseY) then
    begin
      RestoreAround;
      DrawPackWin(False);
      repeat
        if (PackX2 <> MouseX) and (MouseX <= 78) and (PackX1 + 17 < MouseX) then
        begin
          if PackX2 > MouseX then
          begin
            MouseHide;
            RestoreColumn(PackX2, DlgStack.Top);
            MouseShow;
            Dec(PackX2);
          end
          else
            Inc(PackX2);
          DrawPackWin(False);
        end;
        if PackY2 <= MouseY then goto Corner;
      until MouseButton = 0;
      DrawPackWin(True);
    end;
    if MouseOn(PackY2, PackX2, PackX2) then
    begin
      RestoreAround;
      DrawPackWin(False);
Corner:
      repeat
        if (PackX2 <> MouseX) and (MouseX <= 78) and (PackX1 + 17 < MouseX) then
        begin
          if PackX2 > MouseX then
          begin
            MouseHide;
            RestoreColumn(PackX2, DlgStack.Top);
            MouseShow;
            Dec(PackX2);
          end
          else
            Inc(PackX2);
          DrawPackWin(False);
        end;
        if (PackY2 <> MouseY) and (ScreenRows > MouseY) and (PackY1 + 4 < MouseY) then
        begin
          if PackY2 > MouseY then
          begin
            MouseHide;
            RestoreLine(PackY2, DlgStack.Top);
            MouseShow;
            Dec(PackY2);
          end
          else
            Inc(PackY2);
          DrawPackWin(False);
        end;
      until MouseButton = 0;
      DrawPackWin(True);
    end;
    if MouseOn(PackY1 + 1, PackX1 + 1, PackX2 - 1) then
    begin
      RestoreAround;
      DrawPackWin(False);
      MX := MouseX;
      MY := MouseY;
      repeat
        if MX < MouseX then
          if PackX2 < 78 then
          begin
            MouseHide;
            RestoreColumn(PackX1, DlgStack.Top);
            MouseShow;
            Inc(MX);
            Inc(PackX1);
            Inc(PackX2);
            DrawPackWin(False);
          end
          else
            Inc(MX);
        if MX > MouseX then
          if PackX1 > 1 then
          begin
            MouseHide;
            RestoreColumn(PackX2, DlgStack.Top);
            MouseShow;
            Dec(MX);
            Dec(PackX1);
            Dec(PackX2);
            DrawPackWin(False);
          end
          else
            Dec(MX);
        if MY < MouseY then
          if PackY2 < ScreenRows - 1 then
          begin
            MouseHide;
            RestoreLine(PackY1, DlgStack.Top);
            MouseShow;
            Inc(MY);
            Inc(PackY1);
            Inc(PackY2);
            DrawPackWin(False);
          end
          else
            Inc(MY);
        if MY > MouseY then
          if PackY1 > 1 then
          begin
            MouseHide;
            RestoreLine(PackY2, DlgStack.Top);
            MouseShow;
            Dec(MY);
            Dec(PackY1);
            Dec(PackY2);
            DrawPackWin(False);
          end
          else
            Dec(MY);
      until MouseButton = 0;
      DrawPackWin(True);
    end;
  until IsCancel(Key);
  PopScreen(DlgStack);
  SoundOn := OldSound;
end;

procedure PackSettings;
var
  Key: Word;
  B: TButton2;
  Ok, Cancel: Boolean;

procedure DrawOptions;
begin
  MouseHide;
  WriteXY(18, 3, '[ ] Fenster');
  WriteXYF(22, 3, 14, 'F');
  if not PackFull then WriteXY(19, 3, 'X');
  WriteXY(18, 4, '[ ] Vollbild');
  WriteXYF(22, 4, 14, 'V');
  if PackFull then WriteXY(19, 4, 'X');
  MouseShow;
  WaitRelease;
end;

procedure SaveSettings;
var
  F: file of TIniRec;
  Ini: TIniRec;
  Err: Boolean;
begin
  Assign(F, HomeDir + IniName);
  Reset(F);
  Read(F, Ini);
  Close(F);
  Err := (IOResult <> 0) or (Ini.Id <> IniId);
  if not Err then
  begin
    Ini.PackFull := PackFull;
    Ini.PackX2 := PackX2;
    Ini.PackY2 := PackY2;
    Ini.PackX1 := PackX1;
    Ini.PackY1 := PackY1;
    Rewrite(F);
    Write(F, Ini);
    Close(F);
    Err := IOResult <> 0;
  end;
  if Err then
    MsgBox('Fehler beim Erstellen von ' + IniName + '!', 'Einstellungen konnten nicht gespeichert werden.');
end;

begin
  OpenDialog;
  Frame(17, 8, 44, 9, 15, 5, 0, 1);
  WriteCenterXY(1, 1, 44, 'Packer-Fenster Einstellungen:');
  WriteCenterXY(1, 6, 44, 'Die Fensterposition wird auch gespeichert!');
  Frame(33, 10, 14, 2, 15, 5, 0, 0);
  Window(18, 9, 80, 25);
  InitButton2(True, 3, 7, 25, 7, 14, 0, 15, 5, '   Speichern   ', '      OK      ', B);
  MouseShow;
  DrawOptions;
  repeat
    HandleButton2(Ok, Cancel, Key, B);
    if MouseOn(11, 35, 46) or (LoCaseW(Key) = 'f') or (Key = $430) then
    begin
      PackFull := False;
      DrawOptions;
    end;
    if MouseOn(12, 35, 46) or (LoCaseW(Key) = 'v') or (Key = $438) then
    begin
      PackFull := True;
      DrawOptions;
    end;
  until IsCancel(Key) or Cancel or Ok or MouseOutside(17, 62, 8, 18);
  CloseDialog;
  if Ok then SaveSettings;
end;

end.

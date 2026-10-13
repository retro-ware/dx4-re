{$O+,F+,G+,S-,I-,X+,V-}
unit FileAsk;

interface

uses DXGlob, Dialogs;

function AskNextFit(Drive: Char; var Data: TPanelData; Count: Integer; var Index: Integer; Name: string): Boolean;
function AskDrive: Str128;
function AskDriveAttr(Attr: Byte): Str128;
function AskOverwrite(Name: string; var Over, Skip, All, Never: Boolean): Boolean;
function AskReadOnly(Name: string; var All: Boolean): Boolean;
function AskDelete(Name: string; Auto: Boolean): Boolean;

implementation

uses Dos, Crt, Buttons, Mouse, Screen, Windows, ScrSave;

function AskNextFit(Drive: Char; var Data: TPanelData; Count: Integer; var Index: Integer; Name: string): Boolean;
var
  B: TButton2;
  Ok, Cancel: Boolean;
  Key: Word;
  Dummy: Word;
  Size, Free: Longint;
begin
  NormalCursor;
  Drive := UpCaseC(Drive);
  OpenDialog;
  Frame(13, 6, 55, 12, 11, 3, 0, 1);
  WriteCenterXY(1, 2, 55, 'Diese Datei pa'#$E1't nicht mehr auf die Diskette!');
  WriteCenterXYF(1, 4, 55, 14, Name);
  WriteCenterXY(1, 6, 55, 'Kopiere die n'#$84'chste passende Datei.');
  InitButton2(True, 3, 10, 31, 10, 14, 0, 11, 3, '       Weiter       ', '      Abbruch      ', B);
  MouseShow;
  repeat
    HandleButton2(Ok, Cancel, Key, B);
    if LoCaseW(Key) = 'w' then Ok := True
    else if LoCaseW(Key) = 'a' then Cancel := True
    else if IsCancel(Key) or MouseOutside(13, 69, 6, 19) then Cancel := True;
  until Ok or Cancel;
  AskNextFit := Ok;
  CloseDialog;
  if Ok then
  begin
    ArrowCursor;
    Free := DiskFree(Ord(Drive) - 64);
    repeat
      Inc(Index);
      if Data[Index]^.Marked then
        Size := Data[Index]^.Size
      else
        Size := Free;
    until (Index >= Count) or (Size < Free);
    Dec(Index);
  end;
end;

function AskDrive: Str128;
var
  C: Char;
  S: string[128];
  SR: SearchRec;
begin
  MouseHide;
  Frame(13, 7, 55, 5, 15, 4, 0, 1);
  TextColor(15);
  WriteCenterXYF(1, 2, 55, 14, 'Fehler auf diesem Laufwerk!');
  WriteLn;
  WriteXY(1, 4, '  Bitte einen anderen Laufwerksbuchstaben angeben: ');
  TextColor(0);
  repeat
    WriteXYFB(52, 4, 0, 2, ' :');
    GotoXY(52, 4);
    ShowCursor;
    C := ReadKey;
    WriteFB(0, 2, C);
    HideCursor;
    S := UpCaseC(C) + ':\';
    ChDir(S);
    FindFirst('*.*', $3F, SR);
  until (IOResult = 0) and ((DosError = 0) or (DosError = 18));
  MouseShow;
  GetDir(0, S);
  AskDrive := S;
end;

function AskDriveAttr(Attr: Byte): Str128;
var
  C: Char;
  S: string[128];
  SR: SearchRec;
begin
  OpenDialog;
  Frame(13, 7, 55, 5, 15, 4, 0, 1);
  TextColor(15);
  WriteCenterXYF(1, 2, 55, 14, 'Fehler auf diesem Laufwerk!');
  {$I+} WriteLn; {$I-}
  WriteXY(1, 4, '  Bitte einen anderen Laufwerksbuchstaben angeben: ');
  TextColor(0);
  MouseShow;
  NormalCursor;
  repeat
    MouseHide;
    WriteXYFB(52, 4, 0, 2, ' :');
    GotoXY(52, 4);
    ShowCursor;
    C := ReadKey;
    WriteFB(0, 2, C);
    HideCursor;
    MouseShow;
    S := UpCaseC(C) + ':';
    ChDir(S);
    FindFirst('*.*', Attr, SR);
  until (IOResult = 0) and ((DosError = 0) or (DosError = 18));
  PopScreen(DlgStack);
  ArrowCursor;
  GetDir(0, S);
  AskDriveAttr := S;
end;

function AskOverwrite(Name: string; var Over, Skip, All, Never: Boolean): Boolean;
var
  B: TButton5;
  Key: Word;
  Cancel: Boolean;
begin
  OpenDialog;
  NormalCursor;
  Frame(10, 6, 59, 12, 11, 3, 0, 1);
  WriteCenterXY(1, 2, 59, 'Die Datei existiert bereits!');
  WriteCenterXYF(1, 5, 59, 14, Shorten(Name, 55));
  WriteXYF(9, 12, 0, 'Weiter = Diese Datei nicht '#$81'berschreiben.');
  InitButton5(1, 2, 9, 20, 9, 31, 9, 40, 9, 48, 9, 14, 0, 11, 3, #$9A'berschreiben', 'Weiter', 'Alle', 'Nie', 'Abbruch', B);
  MouseShow;
  repeat
    HandleButton5(Over, Skip, All, Never, Cancel, Key, B);
    if LoCaseW(Key) = #$81 then Over := True;
    if LoCaseW(Key) = 'w' then Skip := True;
    if LoCaseW(Key) = 'n' then Never := True;
    if (Key = 27) or (Key = $42C) then Cancel := True;
  until Over or Skip or All or Never or Cancel;
  CloseDialog;
  ArrowCursor;
  AskOverwrite := Cancel;
end;

function AskReadOnly(Name: string; var All: Boolean): Boolean;
var
  B: TButton3;
  Ok, Cancel: Boolean;
  Key: Word;
begin
  NormalCursor;
  MouseHide;
  Frame(13, 7, 54, 8, 15, 4, 0, 1);
  TextColor(15);
  WriteCenterXY(1, 1, 54, 'Datei hat Nur-Lese-Status!');
  WriteCenterXYF(1, 3, 54, 14, Name);
  WriteCenterXY(1, 5, 54, 'Trotzdem l'#$94'schen ?');
  InitButton3(True, 3, 6, 20, 6, 38, 6, 14, 0, 15, 4, '  L'#$94'schen  ', '    Alle    ', ' Abbrechen ', B);
  MouseShow;
  repeat
    HandleButton3(Ok, All, Cancel, Key, B);
    if IsCancel(Key) then Cancel := True;
  until Ok or Cancel or All;
  if All then Ok := True;
  if Cancel then Ok := False;
  AskReadOnly := Ok;
end;

function AskDelete(Name: string; Auto: Boolean): Boolean;
var
  Ok, Cancel: Boolean;
  Key: Word;
  B: TButton2;
begin
  Frame(13, 8, 54, 7, 11, 3, 0, 1);
  WriteCenterXY(1, 1, 54, 'Soll gel'#$94'scht werden ?');
  WriteCenterXYF(1, 3, 54, 14, Name);
  if G9F5 then WriteCenterXYF(1, 4, 54, 10, 'Rechte Maustaste l'#$94'scht!');
  InitButton2(True, 3, 5, 30, 5, 14, 0, 11, 3, '      L'#$94'schen      ', '      Abbruch      ', B);
  MouseShow;
  repeat
    HandleButton2(Ok, Cancel, Key, B);
    if Auto and not GA07 then Ok := True;
    if LoCaseW(Key) = 'l' then Ok := True;
    if LoCaseW(Key) = 'a' then Cancel := True;
    if (Key = 27) or (Key = $42C) or MouseOutside(13, 68, 8, 16) then Cancel := True;
    if G9F5 then
    begin
      if Mouse.MouseButton = 2 then
      begin
        Ok := True;
        WaitRelease;
      end;
    end
    else if Mouse.MouseButton = 2 then Cancel := True;
  until Ok or Cancel;
  if Cancel then Ok := False;
  AskDelete := Ok;
end;

end.

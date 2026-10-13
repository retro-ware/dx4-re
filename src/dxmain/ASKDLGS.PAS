{$O+,F+,G+,S-,I-,X+,V-}
unit AskDlgs;
{ Overlay 142f: small input dialogs (new file/dir, search text, setup/boot files, redirection) }

interface

uses Dialogs;

type
  Str12 = string[12];
  Str79 = string[79];
  Str80 = string[80];

procedure AskNewFile(var S: string);
function AskNewDir(var S: string): Boolean;
procedure AskSearchText(var S: Str128; N: Integer; Def: string);
function AskSaveName: Str12;
function LoadSetupName: Str12;
function LoadBootName: Str12;
function AskRedirect(var FileName: string; var Pre, Post: Str80): Boolean;
function AskContinue(Msg1, Msg2: string): Boolean;
function AskReplace(Name: Str79): Boolean;

implementation

uses Dos, Crt, DXGlob, Buttons, Mouse, Screen, Windows, Status, ScrSave, Lists;

type
  TNameList = object(TList)
    procedure DrawLine(Line: Integer); virtual;
  end;

procedure TNameList.DrawLine(Line: Integer);
begin
  if (Line + Top <= Count) and (Line + Top > 0) then
    Text := '  ' + NameList^[Line + Top];
  TList.DrawLine(Line);
end;

procedure AskNewFile(var S: string);
var
  B2: TButton2;
  Hit1, Hit2: Boolean;
  Key, Ret: Word;
begin
  S := '';
  if Length(CfgStr932) = 0 then
    ErrorBox('Es wurde noch kein Editor angegeben!', 'Die Einstellung mit Strg-F5 vornehmen.')
  else
  begin
    MouseHide;
    PushScreen(DlgStack);
    Frame(13, 8, 54, 7, 15, 5, 0, 1);
    WriteCenterXY(1, 1, 54, 'Welche Datei erzeugen?');
    Window(1, 1, 80, 25);
    InitButton2(True, 15, 13, 42, 13, 14, 0, 15, 5, '       Erzeugen       ', '      Abbrechen      ', B2);
    MouseShow;
    Key := $3F9;
    repeat
      if (Key = $3F9) or (Key = $430) or (Key = 9) or (Key = $3F7) or MouseOn(11, 16, 65) then
        Ret := InputLine(16, 11, 15, 66, S, 48, 128, #$D8, False)
      else
        Ret := 99;
      HandleButton2(Hit1, Hit2, Key, B2);
      if (Ret = 13) and (MouseButton = 0) then
      begin
        if B2[1].Focused then Hit1 := True
        else if B2[2].Focused then Hit2 := True;
      end;
      if LoCaseW(Key) = 'e' then Hit1 := True
      else if LoCaseW(Key) = 'a' then Hit2 := True
      else if Ret = 0 then Hit2 := True;
      if IsCancel(Key) or MouseOutside(13, 68, 8, 16) then Hit2 := True;
    until Hit1 or Hit2;
    if Hit2 then S := '';
    PopScreen(DlgStack);
    repeat
      Idle;
    until MouseButton = 0;
  end;
end;

function AskNewDir(var S: string): Boolean;
var
  B2: TButton2;
  Hit1, Hit2: Boolean;
  Key, Ret: Word;
  Dummy: array[1..$792] of Byte;
begin
  S := '';
  OpenDialog;
  Frame(13, 8, 54, 7, 15, 5, 0, 1);
  WriteCenterXY(1, 1, 54, ' Welches Verzeichnis erzeugen?');
  Window(1, 1, 80, 25);
  InitButton2(True, 15, 13, 42, 13, 14, 0, 15, 5, '       Erzeugen       ', '      Abbrechen      ', B2);
  MouseShow;
  Key := $3F9;
  repeat
    if (Key = $3F9) or (Key = $430) or (Key = 9) or (Key = $3F7) or MouseOn(11, 16, 65) then
      Ret := InputLine(16, 11, 15, 66, S, 48, 128, #$D8, False)
    else
      Ret := 99;
    HandleButton2(Hit1, Hit2, Key, B2);
    if (Ret = 13) and (MouseButton = 0) then
    begin
      if B2[1].Focused then Hit1 := True
      else if B2[2].Focused then Hit2 := True;
    end;
    if LoCaseW(Key) = 'e' then Hit1 := True
    else if LoCaseW(Key) = 'a' then Hit2 := True
    else if Ret = 0 then Hit2 := True;
    if IsCancel(Key) or MouseOutside(13, 68, 8, 16) then Hit2 := True;
  until Hit1 or Hit2;
  S := Trim(S);
  AskNewDir := not Hit2 and (Length(S) <> 0);
  CloseDialog;
end;

procedure AskSearchText(var S: Str128; N: Integer; Def: string);
var
  B2: TButton2;
  Hit1, Hit2: Boolean;
  Key, Ret: Word;
begin
  OpenDialog;
  Frame(13, 8, 54, 7, 15, 5, 0, 1);
  if N = 0 then
  begin
    WriteXY(3, 1, 'Textsuche in der Datei: ');
    WriteF(14, Shorten(S, 26));
  end
  else
  begin
    Str(N, S);
    WriteXY(16, 1, 'Textsuche in ');
    WriteF(14, S);
    Writeln(' Dateien');
  end;
  MouseShow;
  S := LastSearch;
  if Length(Def) <> 0 then S := Def;
  Window(1, 1, 80, 25);
  InitButton2(True, 15, 13, 42, 13, 14, 0, 15, 5, '        Suchen        ', '      Abbrechen      ', B2);
  MouseShow;
  Key := $3F9;
  repeat
    if (Key = $3F9) or (Key = $430) or (Key = 9) or (Key = $3F7) or MouseOn(11, 16, 65) then
      Ret := InputLine(16, 11, 15, 66, S, 48, 128, #$D8, False)
    else
      Ret := 99;
    HandleButton2(Hit1, Hit2, Key, B2);
    if (Ret = 13) and (MouseButton = 0) then
    begin
      if B2[1].Focused then Hit1 := True
      else if B2[2].Focused then Hit2 := True;
    end;
    if LoCaseW(Key) = 'e' then Hit1 := True
    else if LoCaseW(Key) = 'a' then Hit2 := True
    else if Ret = 0 then Hit2 := True;
    if IsCancel(Key) or MouseOutside(13, 68, 8, 16) then Hit2 := True;
  until Hit1 or Hit2;
  if Hit2 then S := ''
  else LastSearch := S;
  CloseDialog;
end;

function AskSaveName: Str12;
var
  B2: TButton2;
  Hit1, Hit2: Boolean;
  Key, Ret: Word;
begin
  MouseHide;
  PushScreen(DlgStack);
  Frame(13, 7, 53, 9, 15, 5, 0, 1);
  WriteCenterXY(1, 1, 54, 'Speichern der Einstellungen unter:');
  WriteCenterXYF(1, 3, 54, 4, Shorten(HomeDir, 50));
  Window(1, 1, 80, 25);
  InitButton2(True, 15, 14, 41, 14, 14, 0, 15, 5, '      Speichern      ', '      Abbrechen      ', B2);
  MouseShow;
  Key := $407;
  repeat
    if (Key = $407) or (Key = $430) or (Key = 9) or (Key = $3F7) or MouseOn(12, 34, 47) then
      Ret := InputLine(34, 12, 33, 48, SetupName, 12, 12, #$D8, False)
    else
      Ret := 99;
    HandleButton2(Hit1, Hit2, Key, B2);
    if (Ret = 13) and (MouseButton = 0) then
    begin
      if B2[1].Focused then Hit1 := True
      else if B2[2].Focused then Hit2 := True;
    end;
    if LoCaseW(Key) = 's' then Hit1 := True
    else if LoCaseW(Key) = 'a' then Hit2 := True
    else if Ret = 0 then Hit2 := True;
    if IsCancel(Key) or MouseOutside(13, 67, 7, 17) then Hit2 := True;
    if Hit1 then
      if FSearch(HomeDir + SetupName, '') <> '' then
        if not AskReplace(HomeDir + SetupName) then Hit1 := False;
  until Hit1 or Hit2;
  CloseDialog;
  if Hit2 then AskSaveName := ''
  else AskSaveName := SetupName;
end;

function LoadSetupName: Str12;
var
  X: Byte;
  List: TNameList;
  Key: Word;
  Dummy: array[1..8] of Byte;
  Name: Str12;
  Count: Integer;
  Ok, Cancel: Boolean;

  procedure ReadList;
  var
    SR: SearchRec;
    I: Integer;
  begin
    Count := 0;
    FindFirst(HomeDir + '*.ini', $25, SR);
    if DosError = 0 then
    repeat
      Inc(Count);
      NameList^[Count] := SR.Name;
      FindNext(SR);
    until DosError <> 0;
    for I := Count + 1 to 255 do NameList^[I] := '';
    if Count < 11 then Count := 11;
  end;

begin
  Ok := False;
  Cancel := False;
  Name := '*.ini';
  LoadSetupName := '';
  GetMem(NameList, SizeOf(TNameArr));
  ReadList;
  OpenDialog;
  Frame(26, 4, 27, 1, 11, 6, 0, 1);
  WriteXY(4, 1, 'Einstellungen laden:');
  Frame(26, 7, 27, 14, 11, 6, 0, 1);
  WriteCenterXY(1, 1, 27, Shorten(HomeDir + Name, 22));
  OpenFrame(31, 9, 17, 11, 11, 6);
  List.Init(0, 3, 0, 2, 32, 10, 11, Count, 16, True);
  MouseShow;
  repeat
    GetKey(Key);
    X := List.Handle(Key);
    Name := NameList^[List.Cur + List.Top];
    if IsCancel(Key) or MouseOutside(26, 54, 4, 22) then Cancel := True;
    if Key = 13 then Ok := True;
  until Ok or Cancel;
  FreeMem(NameList, SizeOf(TNameArr));
  if Ok then
  begin
    LoadSetupName := Name;
    SetupName := Name;
  end;
  CloseDialog;
end;

function LoadBootName: Str12;
var
  X: Byte;
  List: TNameList;
  Key: Word;
  Dummy: array[1..8] of Byte;
  Name: Str12;
  Count: Integer;
  Ok, Cancel: Boolean;

  procedure ReadList;
  var
    SR: SearchRec;
    I: Integer;
  begin
    Count := 0;
    FindFirst(HomeDir + '*.bot', $25, SR);
    if DosError = 0 then
    repeat
      Inc(Count);
      NameList^[Count] := SR.Name;
      FindNext(SR);
    until DosError <> 0;
    for I := Count + 1 to 255 do NameList^[I] := '';
    if Count < 11 then Count := 11;
  end;

begin
  Ok := False;
  Cancel := False;
  Name := '*.bot';
  LoadBootName := '';
  GetMem(NameList, SizeOf(TNameArr));
  ReadList;
  OpenDialog;
  Frame(26, 4, 27, 1, 15, 5, 0, 1);
  WriteXY(7, 1, 'Boottext laden:');
  Frame(26, 7, 27, 14, 15, 5, 0, 1);
  WriteCenterXY(3, 1, 24, Shorten(HomeDir + Name, 22));
  Window(32, 10, 47, 21);
  OpenFrame(31, 9, 17, 11, 15, 5);
  List.Init(0, 5, 0, 2, 32, 10, 11, Count, 16, True);
  MouseShow;
  repeat
    GetKey(Key);
    X := List.Handle(Key);
    Name := NameList^[List.Cur + List.Top];
    if IsCancel(Key) or MouseOutside(26, 54, 4, 22) then Cancel := True;
    if Key = 13 then Ok := True;
  until Ok or Cancel;
  FreeMem(NameList, SizeOf(TNameArr));
  if Ok then LoadBootName := Name;
  CloseDialog;
end;

function AskRedirect(var FileName: string; var Pre, Post: Str80): Boolean;
label
  Input1;
var
  Cmd: string;
  Key: Word;
  Dummy: Word;
  B2: TButton2;
  Hit1, Hit2: Boolean;
begin
  MouseHide;
  PushScreen(DlgStack);
  FileName := '';
  Pre := '';
  Post := '';
  Cmd := '*';
  AskRedirect := False;
  Frame(10, 6, 60, 13, 15, 5, 0, 1);
  WriteCenterXYF(1, 1, 60, 4, 'Ausgabe der Suche in eine Datei umleiten:');
  WriteXY(4, 6, 'Das * steht f'#$81'r den jeweiligen gefundenen Dateinamen.');
  WriteXY(4, 7, 'Sie k'#$94'nnen davor und danach weiteren Text angeben.');
  WriteXYF(4, 4, 14, 'D');
  WriteXY(5, 4, 'ateiname');
  WriteXYF(4, 10, 14, 'B');
  WriteXY(5, 10, 'efehl f'#$81'r jede Zeile der Ausgabe');
  InputLine(14, 9, 13, 68, FileName, 52, 0, #$D8, False);
  InputLine(14, 15, 13, 68, Cmd, 52, 0, #$D8, False);
  InitButton2(True, 13, 17, 42, 17, 14, 0, 15, 5, '          OK           ', '        Abbruch        ', B2);
  MouseShow;
  Key := $408;
  ResetButton2(B2);
  repeat
    if Key = $408 then
    begin
    Input1:
      if InputLine(14, 9, 13, 68, FileName, 52, 80, #$D8, False) = 9 then Key := $418;
    end;
    if Key = $418 then
      if InputLine(14, 15, 13, 68, Cmd, 52, 128, #$D8, False) = $3F7 then goto Input1;
    RestoreButton2(B2);
    repeat
      HandleButton2(Hit1, Hit2, Key, B2);
      if (Key = $3F7) or MouseOn(15, 14, 67) then Key := $418;
      if (Key = $430) or (Key = 9) or MouseOn(9, 14, 67) then Key := $408;
      if IsCancel(Key) or MouseOutside(10, 71, 6, 20) then Hit2 := True;
      if LoCaseW(Key) = 'o' then Hit1 := True;
      if LoCaseW(Key) = 'a' then Hit2 := True;
      if LoCaseW(Key) = 'b' then Key := $418;
      if LoCaseW(Key) = 'd' then Key := $408;
    until Hit1 or Hit2 or (Key = $418) or (Key = $408);
    ResetButton2(B2);
    if Hit1 then
    begin
      if FSearch(FileName, '') <> '' then
        if not AskReplace(FileName) then Hit1 := False;
      if Length(FileName) = 0 then
      begin
        ErrorBox('Wie soll die Datei hei'#$E1'en???', ' Eine Leereingabe w'#$81'rde auf den Bildschirm gehen!');
        Hit1 := False;
      end;
    end;
  until Hit1 or Hit2;
  CloseDialog;
  AskRedirect := Hit1;
  if Hit1 then
  begin
    Pre := Copy(Cmd, 1, Pos('*', Cmd) - 1);
    Post := Copy(Cmd, Pos('*', Cmd) + 1, Length(Cmd));
  end;
end;

function AskContinue(Msg1, Msg2: string): Boolean;
var
  B2: TButton2;
  Hit1, Hit2: Boolean;
  Key: Word;
begin
  OpenDialog;
  Frame(13, 6, 55, 12, 2, 5, 0, 1);
  WriteCenterXYF(1, 3, 55, 4, Msg1);
  WriteCenterXYF(1, 6, 55, 14, Msg2);
  InitButton2(True, 3, 10, 29, 10, 14, 0, 2, 5, '     Wiederholen     ', '      Abbrechen      ', B2);
  MouseShow;
  NormalCursor;
  repeat
    HandleButton2(Hit1, Hit2, Key, B2);
    if LoCaseW(Key) = 'w' then Hit1 := True;
    if LoCaseW(Key) = 'a' then Hit2 := True;
  until Hit2 or Hit1 or IsCancel(Key);
  PopScreen(DlgStack);
  AskContinue := Hit1;
end;

function AskReplace(Name: Str79): Boolean;
var
  B2: TButton2;
  Hit1, Hit2: Boolean;
  Key: Word;
begin
  OpenDialog;
  Frame(13, 7, 55, 8, 11, 3, 0, 1);
  WriteCenterXY(1, 1, 55, 'Die Datei existiert bereits!');
  WriteCenterXYF(1, 3, 55, 14, Name);
  InitButton2(True, 3, 6, 29, 6, 14, 0, 11, 3, '    '#$9A'berschreiben    ', '      Abbrechen      ', B2);
  MouseShow;
  NormalCursor;
  repeat
    HandleButton2(Hit1, Hit2, Key, B2);
    if IsCancel(Key) or MouseOutside(13, 69, 7, 16) then Hit2 := True;
  until Hit1 or Hit2;
  PopScreen(DlgStack);
  if Hit1 then AskReplace := True else AskReplace := False;
  WaitRelease;
end;

end.

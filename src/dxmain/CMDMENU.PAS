{$O+,F+,G+,S-,I-,X+,V-}
unit CmdMenu;
{ Directory info / command menu and the macro recorder }

interface

uses DXGlob;

procedure DirCommandMenu(S: string; Marked: Boolean; Count: Word; var Data: TPanelData; Panel: Byte; var Key: Word);
procedure MacroMenu(Mode: Byte);

implementation

uses Dos, Crt, Buttons, Mouse, Screen, Windows, ScrSave, Dialogs, Status, Help, Lists, LongName, U118C,
  DirTree, U13B0;

type
  TCmdList = object(TList)
    procedure DrawLine(Line: Integer); virtual;
  end;

  TKeys = array[1..100] of TEntry;
  TMacro = record
    Name: string[34];
    Keys: TKeys;
  end;
  TMacros = array[1..50] of TMacro;

  TMacroList = object(TList)
    procedure DrawLine(Line: Integer); virtual;
  end;

const
  LastMacro: Byte = 1;

var
  Macros: ^TMacros;

procedure TCmdList.DrawLine(Line: Integer);
var
  Items: array[1..10] of string[25];
begin
  Items[1] := 'Packen            Strg-F5';
  Items[2] := 'L'#$94'schen                F8';
  Items[3] := 'Kopieren               F5';
  Items[4] := 'Markieren           Einfg';
  Items[5] := 'Umbenennen             F6';
  Items[6] := 'SFX erzeugen      Strg-F6';
  Items[7] := 'Laufwerkswahl   Alt-F1/F2';
  Items[8] := 'Verzeichnisgr'#$94#$E1'en   Alt-V';
  Items[9] := 'Laufwerksstatistik  Alt-S';
  Items[10] := 'Laufwerks'#$81'bersicht  Alt-L';
  Text := ' ' + Items[Line + Top];
  TList.DrawLine(Line);
end;

procedure DirCommandMenu(S: string; Marked: Boolean; Count: Word; var Data: TPanelData; Panel: Byte; var Key: Word);
var
  Total, U1: Longint;
  U2, Dirs, Files, I: Word;
  Err, Ok, Cancel: Boolean;
  SizeS, MBS: string[12];
  Path, Name: string;
  B: TButton2;
  List: TCmdList;
  W: TWinState;
  Y, Sel: Byte;
  MB: Real;
begin
  Dirs := 0;
  Files := 0;
  Total := 0;
  Key := 0;
  OpenDialog;
  Y := 3;
  if ScreenRows = 28 then Y := 5;
  Frame(23, Y, 34, 20, 11, 6, 0, 1);
  Window(1, 1, 80, ScreenRows);
  InitButton2(True, 25, Y + 18, 42, Y + 18, 14, 0, 11, 6, ' Ausf'#$81'hren ', ' Abbrechen ', B);
  OpenFrame(26, Y + 6, 28, 10, 0, 6);
  List.Init(0, 3, 0, 2, 27, Y + 7, 10, 10, 27, True);
  SaveWin(W);
  Window(24, Y + 1, 80, ScreenRows);
  Name := S;
  SetColor(0, 6);
  if LongNames then GetLongName(S, Name, True);
  WriteCenterXYFB(1, 1, 34, 11, 6, Shorten(Name, 32));
  WriteCenterXY(1, 3, 34, 'Lese das Verzeichnis ein ...');
  MouseShow;
  if not Marked then
  begin
    Path := S;
    Err := ScanDirs(Path, Total, Dirs, Files);
    MB := Total / 1024 / 1024;
    if Err then SizeS := '   --------' else SizeS := SizeStr(Total);
    if Err then MBS := '???' else Str(MB: 0: 1, MBS);
  end
  else
  begin
    for I := 1 to Count do
    begin
      Inc(Files);
      Inc(Total, Data[I]^.Size);
    end;
    MB := Total / 1024 / 1024;
    Str(MB: 0: 1, MBS);
    SizeS := SizeStr(Total);
  end;
  MouseHide;
  WriteCenterXY(1, 3, 34, '');
  WriteXYF(2, 3, 14, SizeS);
  Write(' Bytes ');
  if MB > 0.1 then
  begin
    Write('= ');
    WriteF(14, MBS + ' MB ');
  end;
  Write('in ');
  WriteXYF(2, 4, 14, SizeStr(Files));
  Write(' Dateien und');
  Str(Dirs: 12, SizeS);
  WriteXYF(2, 5, 14, SizeS);
  Write(' Unterverzeichnissen');
  MouseShow;
  WaitRelease;
  repeat
    Window(1, 1, 80, ScreenRows);
    HandleButton2(Ok, Cancel, I, B);
    RestoreWin(W);
    Sel := List.Handle(I);
    if I = 13 then Ok := True;
    if IsCancel(I) or MouseOutside(23, 58, Y, Y + 21) then Cancel := True;
  until Ok or Cancel;
  List.Done;
  if Cancel then Ok := False;
  if Ok then
    case Sel of
      1: Key := $44A;
      2: Key := $42A;
      3: Key := $427;
      4: Key := $43A;
      5: Key := $428;
      6: Key := $44B;
      7: if Panel = 1 then Key := $450 else Key := $451;
      8: Key := $417;
      9: Key := $407;
      10: Key := $40E;
    end;
  CloseDialog;
end;

procedure TMacroList.DrawLine(Line: Integer);
var
  Items: array[1..12] of string[32];
begin
  Text := ' ' + Macros^[Line + Top].Name;
  TList.DrawLine(Line);
end;

procedure MacroMenu(Mode: Byte);
var
  Changed: Boolean;
  Key: Word;
  Ok, Cancel, Rec: Boolean;
  B: TButton3;
  List: TMacroList;
  W: TWinState;
  Y: Byte;
  F: file of TMacros;
  I, J, X: Integer;
  P1, P2, P3, P4, P5: T13B0;
  H1, H2, H3, H4, H5: Boolean;

  procedure EditMacro(N: Byte);
  var
    Name: string[128];
    Name2: string[128];
    U: Word;
    I, J: Integer;
    Key: Word;
    B: TButton4;
    Ok, Cancel, New, Append: Boolean;
    Keys: TKeys;
  begin
    OpenDialog;
    Name := Macros^[N].Name;
    Keys := Macros^[N].Keys;
    Frame(21, 9, 45, 7, 11, 3, 0, 1);
    WriteXYF(5, 1, 14, 'N');
    Write('ame des Macros:');
    InputLine(26, 12, 0, 0, Name, 34, 0, #$D8, False);
    WriteXY(37, 13, #$A9' Aufnahme '#$AA);
    InitButton4(True, 23, 14, 32, 14, 42, 14, 55, 14, 14, 0, 11, 3, ' OK ', ' Neu ', 'Anh'#$84'ngen', 'Abbruch', B);
    MouseShow;
    Key := $419;
    WaitRelease;
    repeat
      ResetButton4(B);
      if Key = $419 then InputLine(26, 12, 0, 0, Name, 34, 34, #$D8, False);
      RestoreButton4(B);
      repeat
        HandleButton4(Ok, New, Append, Cancel, Key, B);
        if Key = $423 then ShowHelp($38);
        if (Key = 9) or (Key = $438) or (Key = $430) or (Key = $3F7) or (LoCaseW(Key) = 'n') or MouseOn(12, 26, 61) then
          Key := $419;
        if LoCaseW(Key) = 'o' then Ok := True;
        if LoCaseW(Key) = 'a' then Cancel := True;
        if IsCancel(Key) or MouseOutside(21, 67, 9, 17) then Cancel := True;
        if New or Append then
        begin
          OpenDialog;
          Frame(23, 13, 40, 5, 11, 6, 0, 1);
          WriteCenterXY(1, 1, 40, 'Dr'#$81'cken Sie die Tastenkombinationen,');
          WriteCenterXY(1, 2, 40, 'die bei Anwahl dieses Men'#$81'punktes');
          WriteCenterXY(1, 3, 40, 'ausgef'#$81'hrt werden sollen...');
          WriteCenterXY(1, 4, 40, 'Esc oder rechte Maustaste=Ende');
          WriteXY(14, 5, 'Nr: 0');
          WriteXY(28, 5, '(Max.: 100)');
          MouseShow;
          Ok := False;
          Cancel := False;
          I := 1;
          if Append then
          begin
            I := 0;
            repeat
              Inc(I);
            until (I > 100) or (Keys[I].W = 0);
          end;
          if I > 100 then
            ErrorBox('Das Macro enth'#$84'lt bereits 100 Tasten!', '')
          else
          begin
            GotoXY(18, 5);
            Write(I - 1);
          end;
          repeat
            if GetKey(Key) and (Key <> 27) then
            begin
              Keys[I].W := Key;
              Keys[I].Alt := AltDown;
              Keys[I].Shift := ShiftDown;
              Keys[I].Ctrl := CtrlDown;
              Keys[I].Scan := ScanCode;
              GotoXY(18, 5);
              Write(I);
              Sound(3000);
              Delay(100);
              NoSound;
              Inc(I);
            end;
            if (Key = 27) or (Mouse.MouseButton = 2) then Cancel := True;
          until Cancel or (I > 100);
          Ok := False;
          Cancel := False;
          Key := 0;
          CloseDialog;
          for J := I to 100 do
          begin
            Keys[J].W := 0;
            Keys[J].Alt := False;
            Keys[J].Shift := False;
            Keys[J].Ctrl := False;
            Keys[J].Scan := 0;
          end;
        end;
      until Ok or Cancel or (Key = $419);
    until Ok or Cancel;
    if Cancel then
      CloseDialog
    else
    begin
      PopScreen(DlgStack);
      Macros^[N].Name := Name;
      Macros^[N].Keys := Keys;
      Changed := True;
    end;
  end;

begin
  GetMem(Macros, SizeOf(TMacros));
  if Macros = nil then Exit;
  X := 0;
  Changed := False;
  Assign(F, HomeDir + 'dxmacro.dat');
  Reset(F);
  Read(F, Macros^);
  if (IOResult <> 0) or (FSearch(HomeDir + 'dxmacro.dat', '') = '') then
  begin
    Rewrite(F);
    for I := 1 to 50 do
    begin
      Macros^[I].Name := '';
      for J := 1 to 100 do
      begin
        Macros^[I].Keys[J].W := 0;
        Macros^[I].Keys[J].Alt := False;
        Macros^[I].Keys[J].Shift := False;
        Macros^[I].Keys[J].Ctrl := False;
        Macros^[I].Keys[J].Scan := 0;
      end;
    end;
    Macros^[1].Name := 'Laufwerksstatistik           Alt-S';
    Macros^[1].Keys[1].W := $407;
    Macros^[1].Keys[1].Alt := True;
    Macros^[2].Name := 'Laufwerks'#$81'bersicht           Alt-L';
    Macros^[2].Keys[1].W := $40E;
    Macros^[2].Keys[1].Alt := True;
    Macros^[3].Name := 'Verzeichnisinfo           Strg-Ret';
    Macros^[3].Keys[1].W := 10;
    Macros^[3].Keys[1].Ctrl := True;
    Macros^[3].Keys[1].Scan := $1C;
    Macros^[4].Name := 'Dateisuche                  Alt-F7';
    Macros^[4].Keys[1].W := $456;
    Macros^[4].Keys[1].Alt := True;
    Macros^[5].Name := 'Asciitabelle                 Alt-A';
    Macros^[5].Keys[1].W := $406;
    Macros^[5].Keys[1].Alt := True;
    Macros^[6].Name := 'Taschenrechner               Alt-R';
    Macros^[6].Keys[1].W := $3FB;
    Macros^[6].Keys[1].Alt := True;
    Macros^[7].Name := 'Verzeichnisgr'#$94#$E1'en            Alt-V';
    Macros^[7].Keys[1].W := $417;
    Macros^[7].Keys[1].Alt := True;
    Macros^[8].Name := 'Suche im Verzeichnis         Space';
    Macros^[8].Keys[1].W := $20;
    Macros^[9].Name := 'Men'#$81'befehl wiederholen      Alt-F6';
    Macros^[9].Keys[1].W := $455;
    Macros^[9].Keys[1].Alt := True;
    Macros^[10].Name := 'Verzeichnisse vergleichen   Alt-F9';
    Macros^[10].Keys[1].W := $458;
    Macros^[10].Keys[1].Alt := True;
    Write(F, Macros^);
  end;
  Close(F);
  InOutRes := 0;
  OpenDialog;
  Y := 5;
  if ScreenRows = 28 then Y := 8;
  if Mode = 1 then Y := 2;
  Frame(2, Y, 41, 18, 11, 6, 0, 1);
  WriteCenterXY(1, 1, 41, 'Macrorecorder');
  Window(1, 1, 80, ScreenRows);
  InitButton3(True, 4, Y + 16, 18, Y + 16, 32, Y + 16, 14, 0, 11, 6, 'Ausf'#$81'hren', 'Aufnehmen', 'Abbruch', B);
  OpenFrame(4, Y + 2, 37, 10, 0, 6);
  List.Init(0, 3, 0, 2, 5, Y + 3, 10, 50, 36, True);
  List.SetPos(LastMacro, 12);
  P1.Init(1, 12, 0, 2, 6, ' 1 ');
  P2.Init(9, 12, 0, 2, 6, ' 2 ');
  P3.Init(17, 12, 0, 2, 6, ' 3 ');
  P4.Init(25, 12, 0, 2, 6, ' 4 ');
  P5.Init(33, 12, 0, 2, 6, ' 5 ');
  MouseShow;
  WaitRelease;
  repeat
    SaveWin(W);
    HandleButton3(Ok, Rec, Cancel, Key, B);
    if Key = $423 then ShowHelp($38);
    RestoreWin(W);
    LastMacro := List.Handle(Key);
    if (Key = 13) and B[1].Focused then Ok := True;
    H1 := P1.Clicked;
    H2 := P2.Clicked;
    H3 := P3.Clicked;
    H4 := P4.Clicked;
    H5 := P5.Clicked;
    if H1 then Key := $460;
    if H2 then Key := $461;
    if H3 then Key := $462;
    if H4 then Key := $463;
    if H5 then Key := $464;
    case Key of
      $460: List.SetPos(1, 1);
      $461: List.SetPos(11, 1);
      $462: List.SetPos(21, 1);
      $463: List.SetPos(31, 1);
      $464: List.SetPos(41, 1);
    end;
    if IsCancel(Key) or MouseOutside(2, 44, Y, Y + 19) then Cancel := True;
    if Rec then
    begin
      EditMacro(LastMacro);
      List.DrawAll;
    end;
    if Ok then
      if Length(Macros^[LastMacro].Name) = 0 then Ok := False;
  until Ok or Cancel;
  List.Done;
  if Cancel then Ok := False;
  CloseDialog;
  if Changed then
  begin
    Rewrite(F);
    Write(F, Macros^);
    Close(F);
    InOutRes := 0;
  end;
  FreeMem(Macros, SizeOf(TMacros));
  if Ok then
  begin
    Replay := True;
    TKeys(Entries) := Macros^[LastMacro].Keys;
  end;
end;

end.

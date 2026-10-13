{$O+,F+,G+,S-,I-,X+,V-}
unit Pas;

interface

type
  Str128 = string[128];
  TAssoc = record
    Ext: string[3];
    Prog: string[79];
    Prefix: string[20];
  end;
  TAssocList = array[1..50] of TAssoc;
  PAssocList = ^TAssocList;

procedure PointAndShoot(Name, Other: Str128);

implementation

uses Dos, Crt, DXGlob, Buttons, Mouse, Screen, Windows, ScrSave, Dialogs, Status, Help, Lists, AddProg;

type
  TAssocView = object(TList)
    procedure DrawLine(Line: Integer); virtual;
  end;

var
  Assoc: PAssocList;

procedure TAssocView.DrawLine(Line: Integer);
var
  S: string[5];
begin
  Str(Line + Top: 3, S);
  S := S + '. ';
  Text := S;
  S := Assoc^[Line + Top].Ext;
  while Length(S) < 3 do S := S + ' ';
  if (Line + Top > 0) and (Line + Top <= Count) and (Assoc^[Line + Top].Ext <> '') then
    Text := Text + S + ': ' + Assoc^[Line + Top].Prog + ' ' + Assoc^[Line].Prefix;
  TList.DrawLine(Line);
end;

procedure PointAndShoot(Name, Other: Str128);
var
  F: file of TAssocList;
  I: Byte;
  Dummy1: Byte;
  B3: TButton3;
  B2: TButton2;
  Edit, Del, Done, No: Boolean;
  Key: Word;
  Dummy2: string[254];
  List: TAssocView;
  N: Byte;
  Ext: string[4];
  Rows: Byte;
  W: TWinState;
  B3b: TButton3;
  Hit: Boolean;
  S: string;

procedure EditEntry(Edit: Boolean);
label
  L1, L2;
var
  AExt, AProg, APrefix, S: string;
  I, J: Integer;
  Key: Word;
  B3: TButton3;
  Ok, FileHit, Cancel: Boolean;
begin
  OpenDialog;
  AExt := '';
  AProg := '';
  APrefix := '!.!';
  if Edit then
  begin
    AExt := Assoc^[List.Cur + List.Top].Ext;
    AProg := Assoc^[List.Cur + List.Top].Prog;
    APrefix := Assoc^[List.Cur + List.Top].Prefix;
  end;
  Frame(21, 6, 46, 13, 11, 6, 0, 1);
  WriteXYF(4, 3, 14, 'E');
  WriteF(11, 'xtension');
  WriteXY(9, 2, '-Dateien sollen gestartet werden mit');
  WriteXYF(4, 6, 11, 'Auszuf'#$81'hrendes Programm');
  Write('(. = Betrachter)');
  WriteXYF(5, 6, 14, 'u');
  WriteXYF(4, 9, 14, 'P');
  WriteF(11, 'r'#$84'fix (siehe Hilfe)');
  InputLine(25, 11, 19, 60, AProg, 38, 0, #216, False);
  InputLine(25, 14, 19, 51, APrefix, 20, 0, #216, False);
  InitButton3(True, 23, 17, 38, 17, 52, 17, 14, 0, 11, 6, '    OK    ', '  Datei  ', '  Abbruch  ', B3);
  MouseShow;
  Key := $3FA;
  repeat until MouseButton = 0;
  repeat
    ResetButton3(B3);
    if Key = $3FA then
    begin
L1:
      if InputLine(25, 8, 24, 48, AExt, 3, 3, #216, False) = 9 then Key := $3FE;
    end;
    if Key = $3FE then
    begin
L2:
      Key := InputLine(25, 11, 24, 65, AProg, 38, 79, #216, False);
      if Key = 9 then Key := $401;
      if Key = $3F7 then goto L1;
    end;
    if Key = $401 then
    begin
      Key := InputLine(25, 14, 24, 56, APrefix, 20, 20, #216, False);
      if Key = $3F7 then goto L2;
    end;
    RestoreButton3(B3);
    repeat
      HandleButton3(Ok, FileHit, Cancel, Key, B3);
      if Key = $423 then ShowHelp(70);
      if FileHit then
      begin
        S := SelectProgram;
        if S <> '' then
        begin
          AProg := S;
          InputLine(25, 11, 19, 60, AProg, 38, 0, #216, False);
        end;
      end;
      if (Key = 9) or (Key = $438) or (LoCaseW(Key) = 'e') or MouseOn(8, 25, 29) then Key := $3FA;
      if MouseOn(11, 25, 64) or (LoCaseW(Key) = 'u') then Key := $3FE;
      if (Key = $3F7) or (Key = $430) or MouseOn(14, 25, 46) or (LoCaseW(Key) = 'p') then Key := $401;
      if LoCaseW(Key) = 'o' then Ok := True;
      if LoCaseW(Key) = 'a' then Cancel := True;
      if IsCancel(Key) or MouseOutside(21, 68, 6, 20) then Cancel := True;
      if ((AExt = '') or (AProg = '')) and Ok then
      begin
        Ok := False;
        ErrorBox('Eintrag vornehmen:', 'Extension und Programm m'#$81'ssen angegeben werden!');
      end;
    until Ok or Cancel or (Key = $3FA) or (Key = $3FE) or (Key = $401);
  until Ok or Cancel;
  if Cancel then
  begin
    PopScreen(DlgStack);
    repeat until MouseButton = 0;
  end
  else
  begin
    if Edit then
    begin
      Assoc^[List.Cur + List.Top].Ext := AExt;
      Assoc^[List.Cur + List.Top].Prog := AProg;
      Assoc^[List.Cur + List.Top].Prefix := APrefix;
    end
    else
    begin
      Inc(N);
      Assoc^[N].Ext := AExt;
      Assoc^[N].Prog := AProg;
      Assoc^[N].Prefix := APrefix;
    end;
    PopScreen(DlgStack);
    if Edit then
      List.SetData(50, Rows, List.Cur, List.Top)
    else
    begin
      I := N;
      J := 0;
      while Rows < I do
      begin
        Dec(I);
        Inc(J);
      end;
      List.SetData(50, Rows, I, J);
    end;
  end;
end;

procedure DeleteEntry;
var
  D1, D2: Word;
  I: Word;
  D3: Word;
  Yes, No: Boolean;
  B2: TButton2;
  Key: Word;
  Row: Byte;
begin
  if List.Cur + List.Top > N then
  begin
    MsgBox('Eintrag entfernen:', 'Diesen Eintrag gibt es doch gar nicht!');
    Exit;
  end;
  OpenDialog;
  Row := List.Cur + 4;
  Frame(16, Row + 1, 29, 4, 11, 6, 0, 1);
  WriteF(11, '  Diesen Eintrag entfernen?');
  InitButton2(True, 3, 2, 16, 2, 14, 0, 11, 6, '   Ja   ', '  Nein  ', B2);
  MouseShow;
  repeat
    HandleButton2(Yes, No, Key, B2);
    if LoCaseW(Key) = 'j' then Yes := True;
    if LoCaseW(Key) = 'n' then No := True;
  until Yes or No or (Key = 27) or (MouseButton = 2) or MouseOutside(16, 46, Row + 1, Row + 6);
  PopScreen(DlgStack);
  if Yes then
    if N > 0 then
    begin
      Dec(N);
      for I := List.Cur + List.Top to 49 do
        Move(Assoc^[I + 1], Assoc^[I], SizeOf(TAssoc));
      Assoc^[N + 1].Ext := '';
      Assoc^[N + 1].Prog := '';
      Assoc^[N + 1].Prefix := '';
      if List.Cur + List.Top = N + 1 then
        if List.Cur > 1 then Dec(List.Cur) else Dec(List.Top);
      if List.Top < 0 then List.Top := 0;
      List.SetData(50, Rows, List.Cur, List.Top);
    end;
  repeat until MouseButton = 0;
end;

begin
  OpenDialog;
  if Name <> '' then
  begin
    Frame(10, 6, 60, 9, 11, 6, 0, 1);
    WriteCenterXY(1, 1, 60, 'Diese Datei kann nicht gestartet werden:');
    WriteCenterXYF(1, 3, 60, 14, Shorten(Name, 58));
    WriteCenterXY(1, 5, 60, 'Soll sie mit einer ausf'#$81'hrbaren Datei verkn'#$81'pft werden?');
    InitButton2(True, 26, 7, 43, 7, 14, 0, 11, 6, '     Ja     ', '    Nein    ', B2);
    FSplit(Name, Name, Name, Ext);
    if Ext[1] = '.' then Delete(Ext, 1, 1);
    WriteXYF(3, 8, 11, 'Verkn'#$81'pfen von *.' + Ext);
    MouseShow;
    repeat
      HandleButton2(Done, No, Key, B2);
      if LoCaseW(Key) = 'j' then Done := True;
      if LoCaseW(Key) = 'n' then No := True;
      if IsCancel(Key) or MouseOutside(10, 71, 6, 16) then No := True;
    until Done or No;
    if No then
    begin
      CloseDialog;
      Exit;
    end;
    MouseHide;
  end;
  GetMem(Assoc, SizeOf(TAssocList));
  Rows := 14;
  if BigCursor then Rows := 17;
  Frame(4, 2, 72, ScreenRows - 5, 11, 6, 0, 1);
  SetColor(0, 6);
  OpenFrame(7, 4, 66, Rows, 11, 6);
  SetColor(0, 6);
  Window(5, 3, 76, 22);
  WriteCenterXYF(1, 1, 72, 11, 'Point-And-Shoot-Verwaltung (Verkn'#$81'pfungen)');
  Window(1, 1, 80, ScreenRows);
  InitButton3(True, 7, ScreenRows - 5, 33, ScreenRows - 5, 59, ScreenRows - 5, 14, 0, 11, 6,
    '  '#$8E'ndern + Einf'#$81'gen  ', '  Eintrag entfernen  ', '   Fertig   ', B3);
  Assign(F, HomeDir + 'dxpas.dat');
  Reset(F);
  Read(F, Assoc^);
  Close(F);
  N := 99;
  if IOResult <> 0 then
  begin
    for I := 1 to 50 do
    begin
      Assoc^[I].Prefix := '';
      Assoc^[I].Prog := '';
      Assoc^[I].Ext := '';
    end;
    N := 0;
  end
  else
    for I := 1 to 50 do
      if (N = 99) and (Assoc^[I].Ext = '') then N := I - 1;
  if N = 99 then N := 1;
  MouseShow;
  SetColor(0, 3);
  Done := False;
  if Name <> '' then
  begin
    if N < 50 then
    begin
      ResetButton3(B3);
      if Ext = '' then Ext := '*';
      if Other[4] = '\' then Delete(Other, 4, 1);
      Inc(N);
      Assoc^[N].Ext := Ext;
      Assoc^[N].Prefix := '!.!';
      OpenDialog;
      Frame(11, 6, 58, 12, 11, 3, 0, 1);
      WriteCenterXY(1, 1, 58, 'Geben Sie hier das Programm incl. Pfad an, mit dem');
      if Ext = '*' then Ext := '';
      WriteCenterXYF(1, 3, 58, 14, '*.' + Ext);
      WriteCenterXY(1, 5, 58, 'Dateien verkn'#$81'pft werden sollen:');
      WriteCenterXY(1, 9, 58, 'Geben Sie f'#$81'r den internen Betrachter einen Punkt ein.');
      WriteCenterXY(1, 8, 58, 'Vorgabe = Aktuelle Datei des anderen Fensters.');
      Assoc^[N].Prog := Other;
      InputLine(20, 13, 0, 0, Assoc^[N].Prog, 40, 0, #216, False);
      InitButton3(True, 14, 16, 33, 16, 51, 16, 14, 0, 11, 3, '  Verkn'#$81'pfen  ', '    Datei    ', '   Abbruch   ', B3b);
      MouseShow;
      Key := $430;
      repeat
        if (Key = $430) or (Key = 9) or (Key = $3F7) or (Key = $438) or MouseOn(13, 20, 61) then
          InputLine(20, 13, 19, 62, Assoc^[N].Prog, 40, 79, #216, False);
        HandleButton3(Done, Hit, No, Key, B3b);
        if LoCaseW(Key) = 'v' then Done := True;
        if LoCaseW(Key) = 'd' then Hit := True;
        if LoCaseW(Key) = 'a' then No := True;
        if IsCancel(Key) or MouseOutside(11, 70, 6, 19) then No := True;
        if Hit then
        begin
          S := SelectProgram;
          if S <> '' then Assoc^[N].Prog := S;
          InputLine(20, 13, 19, 62, Assoc^[N].Prog, 40, 0, #216, False);
        end;
      until Done or No;
      if No then
      begin
        Assoc^[N].Prog := '';
        Assoc^[N].Ext := '';
        Dec(N);
      end;
      CloseDialog;
      RestoreButton3(B3);
    end
    else
      ErrorBox('Es k'#$94'nnen keine weiteren Eintragungen', 'mehr vorgenomen werden!');
  end;
  List.Init(0, 3, 0, 2, 8, 5, Rows, 50, 65, True);
  if Done then List.SetPos(N, 8);
  Key := 0;
  repeat
    repeat
      List.Handle(Key);
      if (Key = 13) and (B3[1].Focused or B3[2].Focused) then
      begin
        if B3[1].Focused then Edit := True;
        if B3[2].Focused then Del := True;
      end
      else
      begin
        SaveWin(W);
        HandleButton3(Edit, Del, Done, Key, B3);
        RestoreWin(W);
      end;
      if Key = $423 then ShowHelp(70);
      if IsCancel(Key) or MouseOutside(4, 77, 2, ScreenRows - 2) then Done := True;
      if LoCaseW(Key) = #$84 then Edit := True;
      if (LoCaseW(Key) = 'e') or (Key = $43B) then Del := True;
      if LoCaseW(Key) = 'f' then Done := True;
    until Edit or Del or Done;
    if not Done then Key := 0;
    if Edit then
    begin
      if List.Cur + List.Top > N then
      begin
        SaveWin(W);
        ResetButton3(B3);
        RestoreWin(W);
        EditEntry(False);
        SaveWin(W);
        RestoreButton3(B3);
        RestoreWin(W);
      end
      else
      begin
        SaveWin(W);
        ResetButton3(B3);
        RestoreWin(W);
        EditEntry(True);
        SaveWin(W);
        RestoreButton3(B3);
        RestoreWin(W);
      end;
    end;
    if Del then
    begin
      SaveWin(W);
      ResetButton3(B3);
      RestoreWin(W);
      DeleteEntry;
      SaveWin(W);
      RestoreButton3(B3);
      RestoreWin(W);
    end;
  until Done;
  Rewrite(F);
  Write(F, Assoc^);
  Close(F);
  if IOResult <> 0 then;
  FreeMem(Assoc, SizeOf(TAssocList));
  CloseDialog;
end;

end.

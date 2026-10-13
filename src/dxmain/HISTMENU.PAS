{$O+,F+,G+,S-,I-,X+,V-}
unit HistMenu;

interface

type
  Str12 = string[12];

function ConfirmExit: Boolean;
function HistoryMenu(var Sel: Integer): Byte;
procedure PickHistory(X, Y, Rows: Byte; var N: Byte);
function SelectNote: Char;
procedure ToggleHidden;
function SelectPacker(Title: string; var Packer: Str12): Boolean;

implementation

uses Crt, DXGlob, Buttons, Mouse, Screen, Windows, Status, Dialogs, ScrSave, Lists, Help, U142A;

type
  THistList = object(TList)
    procedure DrawLine(Line: Integer); virtual;
  end;

procedure THistList.DrawLine(Line: Integer);
var
  S: string[5];
begin
  Str(Line + Top: 2, S);
  S := ' ' + S + '. ';
  Text := '';
  if Line + Top <= 25 then Text := S + History^[Line + Top];
  TList.DrawLine(Line);
end;

function ConfirmExit: Boolean;
var
  B2: TButton2;
  Hit1, Hit2: Boolean;
  Key: Word;
begin
  if CfgColors[43] = 0 then
    ConfirmExit := True
  else
  begin
    OpenDialog;
    ConfirmExit := False;
    Frame(20, 7, 39, 6, 15, 5, 0, 1);
    WriteCenterXYF(1, 2, 39, 4, 'Wirklich beenden?');
    Window(21, 8, 80, 25);
    InitButton2(True, 2, 4, 21, 4, 14, 0, 15, 5, '      Ja      ', '     Nein     ', B2);
    MouseShow;
    repeat
      HandleButton2(Hit1, Hit2, Key, B2);
      if LoCaseW(Key) = 'j' then Hit1 := True;
      if LoCaseW(Key) = 'n' then Hit2 := True;
      if (Key = $42C) or (Key = 27) or MouseOutside(20, 60, 7, 14) then Hit2 := True;
    until Hit1 or Hit2;
    ConfirmExit := Hit1;
    CloseDialog;
  end;
end;

function HistoryMenu(var Sel: Integer): Byte;
var
  List: THistList;
  Key: Word;
  Dummy: TButton2;
  D1, D2, D3: Boolean;

  procedure DeleteEntry(N: Byte);
  var
    I: Integer;
  begin
    if (N >= HistCount) or (HistCount < 1) then Exit;
    for I := N to 25 do History^[I] := History^[I + 1];
    History^[HistCount] := '';
    if List.Cur + List.Top = HistCount then
      if List.Cur > 1 then Dec(List.Cur)
      else Dec(List.Top);
    Dec(HistCount);
    if List.Top < 0 then List.Top := 0;
    List.SetData(25, ScreenRows - 11, List.Cur, List.Top);
  end;

begin
  OpenDialog;
  Window(1, ScreenRows, 80, ScreenRows);
  SetColor(0, 7);
  ClrEol;
  WriteXYF(3, 1, 4, 'Return ');
  Write('Befehl ausf'#$81'hren  ');
  WriteF(4, 'Strg-Return ');
  Write('Editieren  ');
  WriteF(4, 'F2 ');
  Write('Speichern  ');
  WriteF(4, 'Entf ');
  Write('Entfernen');
  Frame(14, 4, 51, 1, 15, 7, 0, 1);
  WriteCenter(50, ' Befehlszeilenstapel');
  Frame(14, 7, 51, ScreenRows - 11, 15, 7, 0, 1);
  List.Init(0, 7, 0, 3, 15, 8, ScreenRows - 11, 25, 50, True);
  MouseShow;
  repeat
    GetKey(Key);
    if Key = $423 then ShowHelp(39);
    if Key = $424 then P142A_3103;
    Sel := List.Handle(Key);
    if Key = $43B then DeleteEntry(List.Cur + List.Top);
  until (Key = 27) or (Key = 13) or (Key = 10) or (Key = $42C) or (MouseButton = 2) or
    MouseOutside(14, 66, 4, ScreenRows - 3);
  Sel := List.Cur + List.Top;
  if Key = 13 then HistoryMenu := 1
  else if Key = 10 then HistoryMenu := 2
  else HistoryMenu := 0;
  CloseDialog;
end;

procedure PickHistory(X, Y, Rows: Byte; var N: Byte);
var
  List: THistList;
  Key: Word;
begin
  OpenDialog;
  HideCursor;
  N := 0;
  Frame(X - 1, Y - 1, 38, Rows, 11, 3, 0, 1);
  List.Init(11, 3, 11, 0, X, Y, Rows, 25, 37, True);
  MouseShow;
  WaitRelease;
  repeat
    GetKey(Key);
    List.Handle(Key);
  until IsCancel(Key) or (Key = 13) or MouseOutside(X - 1, X + 38, Y - 1, Y + Rows);
  PopScreen(DlgStack);
  if Key = 13 then N := List.Cur + List.Top;
  List.Done;
  ShowCursor;
end;

function SelectNote: Char;
var
  B1, B2, B3, B4, B5, B6, B7, B8, B9: TButton;
  H1, H2, H3, H4, H5, H6, H7, H8, H9, Cancel: Boolean;
  Key: Word;
begin
  OpenDialog;
  Cancel := False;
  SelectNote := #27;
  Frame(26, 7, 27, 10, 15, 5, 0, 1);
  WriteXY(5, 1, 'Welche Notiz-Datei?');
  InitButton(True, 3, 2, 0, 0, 15, 5, ' 1 ', B1);
  InitButton(True, 11, 2, 0, 0, 15, 5, ' 2 ', B2);
  InitButton(True, 19, 2, 0, 0, 15, 5, ' 3 ', B3);
  InitButton(True, 3, 5, 0, 0, 15, 5, ' 4 ', B4);
  InitButton(True, 11, 5, 0, 0, 15, 5, ' 5 ', B5);
  InitButton(True, 19, 5, 0, 0, 15, 5, ' 6 ', B6);
  InitButton(True, 3, 8, 0, 0, 15, 5, ' 7 ', B7);
  InitButton(True, 11, 8, 0, 0, 15, 5, ' 8 ', B8);
  InitButton(True, 19, 8, 0, 0, 15, 5, ' 9 ', B9);
  MouseShow;
  repeat
    H1 := Buttons.MouseButton(B1);
    H2 := Buttons.MouseButton(B2);
    H3 := Buttons.MouseButton(B3);
    H4 := Buttons.MouseButton(B4);
    H5 := Buttons.MouseButton(B5);
    H6 := Buttons.MouseButton(B6);
    H7 := Buttons.MouseButton(B7);
    H8 := Buttons.MouseButton(B8);
    H9 := Buttons.MouseButton(B9);
    GetKey(Key);
    if IsCancel(Key) or MouseOutside(26, 54, 7, 18) then Cancel := True;
    case Key of
      $31: H1 := True;
      $32: H2 := True;
      $33: H3 := True;
      $34: H4 := True;
      $35: H5 := True;
      $36: H6 := True;
      $37: H7 := True;
      $38: H8 := True;
      $39: H9 := True;
    end;
  until H1 or H2 or H3 or H4 or H5 or H6 or H7 or H8 or H9 or Cancel;
  CloseDialog;
  if H1 then SelectNote := '1';
  if H2 then SelectNote := '2';
  if H3 then SelectNote := '3';
  if H4 then SelectNote := '4';
  if H5 then SelectNote := '5';
  if H6 then SelectNote := '6';
  if H7 then SelectNote := '7';
  if H8 then SelectNote := '8';
  if H9 then SelectNote := '9';
end;

procedure ToggleHidden;
begin
  Boolean(CfgColors[12]) := not Boolean(CfgColors[12]);
  if CfgColors[12] <> 0 then
    ErrorBox('Versteckte Dateien und Verzeichnisse werden', 'angezeigt!')
  else
    ErrorBox('Versteckte Dateien und Verzeichnisse werden', 'nicht angezeigt!');
end;

function SelectPacker(Title: string; var Packer: Str12): Boolean;
var
  B4: TButton4;
  A, L, P, Cancel: Boolean;
  Key: Word;
  Disp: Str12;
  C: Char;
  Old: Str12;
  Sel: Byte;
begin
  OpenDialog;
  Old := Packer;
  Frame(10, 6, 59, 9, 15, 5, 0, 1);
  WriteCenterXYF(1, 1, 59, 14, Title);
  if SingleFrame then WriteCenterXYF(1, 2, 59, 0, FillStr(#$DF, Length(Title)))
  else WriteCenterXYF(1, 2, 59, 0, FillStr(#$DD, Length(Title)));
  WriteCenterXYF(1, 3, 59, 4, 'Welcher Packer soll benutzt werden?');
  WriteXY(8, 5, 'Aktuelles Komprimierungsprogramm: ');
  if Packer <> 'pkzip.exe' then Disp := Packer + '  ' else Disp := Packer;
  WriteFB(0, 2, ' ' + Disp + ' ');
  if SingleFrame then C := ' ' else C := #$D8;
  GotoXY(42, 4);
  for Key := 1 to 11 do Write(C);
  SetColor(0, 2);
  if SingleFrame then C := ' ' else C := #$D0;
  WriteXY(42, 5, C);
  InitButton4(True, 3, 7, 17, 7, 31, 7, 45, 7, 14, 0, 15, 5, '   LHA   ', '   ARJ   ', '  PKZIP  ',
    ' Abbruch ', B4);
  MouseShow;
  Sel := 1;
  if Packer = 'pkzip.exe' then Sel := 3;
  if Packer = 'arj.exe' then Sel := 2;
  SetButton4(Sel, B4);
  repeat
    HandleButton4(L, A, P, Cancel, Key, B4);
    if LoCaseW(Key) = 'l' then L := True;
    if LoCaseW(Key) = 'a' then A := True;
    if LoCaseW(Key) = 'p' then P := True;
    if L then Packer := 'lha.exe';
    if A then Packer := 'arj.exe';
    if P then Packer := 'pkzip.exe';
    if A or L or P then
    begin
      if Packer <> 'pkzip.exe' then Disp := Packer + '  ' else Disp := Packer;
      WriteXYFB(44, 5, 0, 2, Disp + ' ');
    end;
    if IsCancel(Key) or MouseOutside(10, 70, 6, 16) then Cancel := True;
  until L or A or P or Cancel;
  if Cancel then
  begin
    Packer := Old;
    SelectPacker := False;
  end
  else
    SelectPacker := True;
  CloseDialog;
end;

end.

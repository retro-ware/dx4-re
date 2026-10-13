{$O+,F+,G+,S-,I-,X+,V-}
unit Passwd;

interface

type
  Str12 = string[12];

function ReadPassword(X, Y: Byte): Str12;
procedure ChangePassword;
procedure SelectDrives;

implementation

uses Crt, DXGlob, Buttons, Mouse, Screen, Windows, Dialogs, Toggle;

function ReadPassword(X, Y: Byte): Str12;
var
  N, A: Byte;
  Key: Word;
  S: Str12;
begin
  GotoXY(X, Y);
  ShowCursor;
  A := TextAttr;
  G36E := 0;
  N := 0;
  SetColor(0, 2);
  S := '';
  Key := 0;
  repeat until MouseButton = 0;
  repeat
    if (Key <> 8) and (N < 12) and (Key <> 0) then
    begin
      S := S + LoCaseW(Key);
      Inc(N);
      MouseHide;
      Write('*');
      MouseShow;
    end;
    if (Key = 8) and (N > 0) then
    begin
      GotoXY(WhereX - 1, WhereY);
      MouseHide;
      Write(' ');
      MouseShow;
      GotoXY(WhereX - 1, WhereY);
      Dec(N);
      Delete(S, Length(S), 1);
    end;
    repeat
      GetKey(Key);
      if MouseOutside(X - 15, X + 26, Y - 6, Y + 2) then Key := 27;
      if (Key = 1068) or (MouseButton = 2) then Key := 27;
    until (Lo(Key) in [8, 13, 27, 33..165]) and (Key < 256);
  until (Key = 13) or (Key = 27);
  if Key = 27 then S := '';
  TextAttr := A;
  ReadPassword := S;
  HideCursor;
end;

procedure ChangePassword;
label
  Abort;
var
  Old, New: Str12;
  Dummy: Boolean;
begin
  OpenDialog;
  Old := '';
  New := '';
  Frame(20, 7, 40, 7, 15, 5, 0, 1);
  WriteCenterXY(1, 2, 40, 'Pa'#$E1'wort '#$84'ndern:');
  WriteCenterXY(1, 4, 40, 'Bitte geben Sie das alte Pa'#$E1'wort ein:');
  InputLine(34, 13, 1, 1, Old, 12, 0, #216, False);
  MouseShow;
  Old := ReadPassword(35, 13);
  if Old = '' then
  begin
    CloseDialog;
    Exit;
  end;
  if Old <> Password then
  begin
    MsgBox('Falsches Pa'#$E1'wort eingegeben!', 'Das Pa'#$E1'wort wird nicht ge'#$84'ndert!');
    CloseDialog;
    Exit;
  end;
  MouseHide;
  Frame(22, 8, 40, 7, 15, 5, 0, 1);
  WriteCenterXY(1, 2, 40, 'Pa'#$E1'wort '#$84'ndern:');
  WriteCenterXY(1, 4, 40, 'Bitte geben Sie das neue Pa'#$E1'wort ein:');
  InputLine(36, 14, 1, 1, New, 12, 0, #216, False);
  MouseShow;
  Old := ReadPassword(37, 14);
  if Old = '' then goto Abort;
  MouseHide;
  Frame(24, 9, 40, 7, 15, 5, 0, 1);
  WriteCenterXY(1, 2, 40, 'Pa'#$E1'wort '#$84'ndern:');
  WriteCenterXY(1, 4, 40, 'Bitte die Eingabe wiederholen:');
  InputLine(38, 15, 1, 1, New, 12, 0, #216, False);
  MouseShow;
  New := ReadPassword(39, 15);
  if New = '' then goto Abort;
  if New <> Old then
    ErrorBox('Die beiden Pa'#$E1'w'#$94'rter stimmen nicht '#$81'berein!', 'Wiederholen Sie den Vorgang.')
  else
  begin
    Password := Old;
    ErrorBox('Das Pa'#$E1'wort wurde ge'#$84'ndert!', 'F'#$81'r bleibende '#$8E'nderung: Einstellungen speichern!');
  end;
  CloseDialog;
  Exit;
Abort:
  CloseDialog;
  ErrorBox('Der Vorgang wurde abgebrochen!', 'Das Pa'#$E1'wort wurde nicht ge'#$84'ndert!');
end;

procedure SelectDrives;
var
  Drives: array[1..26] of TToggle;
  I: Word;
  B: TButton2;
  Ok, Cancel: Boolean;
  Key: Word;
begin
  OpenDialog;
  Frame(8, 3, 62, 19, 15, 7, 0, 1);
  WriteCenterXY(1, 1, 62, 'Anzuzeigende Laufwerksnamen bei der Laufwerkswahl:');
  for I := 1 to 5 do
    Drives[I].Init(DriveFlag[I], (I - 1) * 12 + 3, 2, 15, 0, 15, 7, Chr(I + 64) + ': Ein', Chr(I + 64) + ': Aus');
  for I := 6 to 10 do
    Drives[I].Init(DriveFlag[I], (I - 6) * 12 + 3, 5, 15, 0, 15, 7, Chr(I + 64) + ': Ein', Chr(I + 64) + ': Aus');
  for I := 11 to 15 do
    Drives[I].Init(DriveFlag[I], (I - 11) * 12 + 3, 8, 15, 0, 15, 7, Chr(I + 64) + ': Ein', Chr(I + 64) + ': Aus');
  for I := 16 to 20 do
    Drives[I].Init(DriveFlag[I], (I - 16) * 12 + 3, 11, 15, 0, 15, 7, Chr(I + 64) + ': Ein', Chr(I + 64) + ': Aus');
  for I := 21 to 25 do
    Drives[I].Init(DriveFlag[I], (I - 21) * 12 + 3, 14, 15, 0, 15, 7, Chr(I + 64) + ': Ein', Chr(I + 64) + ': Aus');
  Drives[26].Init(DriveFlag[26], 3, 17, 15, 0, 15, 7, 'Z: Ein', 'Z: Aus');
  InitButton2(True, 15, 17, 39, 17, 14, 0, 15, 7, '    '#$9A'bernehmen    ', '     Abbrechen    ', B);
  MouseShow;
  repeat
    HandleButton2(Ok, Cancel, Key, B);
    for I := 1 to 26 do
      Drives[I].Clicked;
    if LoCaseW(Key) in ['a'..'z'] then
      Drives[Ord(LoCaseW(Key)) - $60].Toggle;
    if IsCancel(Key) or MouseOutside(8, 71, 3, 23) then Cancel := True;
  until Ok or Cancel;
  if Ok then
    for I := 1 to 26 do
      DriveFlag[I] := Drives[I].Checked;
  CloseDialog;
end;

end.

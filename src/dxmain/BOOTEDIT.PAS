{$O+,F+,G+,S-,I-,X+,V-}
unit BootEdit;
{ Overlay 1097: boot sector text editor (3 lines shown when booting a non-system floppy) }

interface

type
  Str77 = string[77];

procedure BootEditor(var L1, L2, L3: Str77);
procedure LoadBootDefault(var L1, L2, L3: Str77);

implementation

uses Dos, Crt, DXGlob, Buttons, Mouse, Screen, Windows, Status, Dialogs, ScrSave, AskDlgs, U1F7B;

const
  Spaces =
    '                                                                                                    ' +
    '                                                                                                    ' +
    '                                                       ';

type
  TBootCode = record
    Hdr: TBootHdr;
    L1: array[1..77] of Char;
    CR1, LF1: Char;
    L2: array[1..77] of Char;
    CR2, LF2: Char;
    L3: array[1..77] of Char;
    CR3, LF3: Char;
    Tail: TBootTail;
  end;
  TColors = array[0..64] of Byte;
  TBlk26 = array[0..25] of Byte;
  TBlk32 = array[0..31] of Byte;
  TBlk48 = array[0..47] of Byte;
  TProg = record
    W: Word;
    S: string[20];
  end;
  TConfig = record
    Id: string;
    Colors: TColors;
    Colors2: TColors;
    S182, S203: string[128];
    W284: Word;
    S286, S2D6: string[79];
    S326: string[12];
    B333: Byte;
    W334: Word;
    Drives: array[1..26] of Boolean;
    Progs: array[1..9] of TProg;
    B41F: Byte;
    S420, S470: string[79];
    S4C0, S511: string[80];
    Blk562: TBlk32;
    B582, B583: Byte;
    L584, L588, L58C, L590: Longint;
    B594: Byte;
    Blk595: TBlk48;
    Pw: string[11];
    S1, S2, S3: string[77];
    Prn1, Prn2: string[12];
    B6D5, B6D6, B6D7, B6D8, B6D9, B6DA, B6DB, B6DC, B6DD, B6DE, B6DF: Byte;
    W6E0: Word;
    Blk6E2: TBlk26;
    S6FC: string[12];
    B709, B70A, B70B: Byte;
    B70C, B70D, B70E, B70F, B710, B711: Byte;
  end;

procedure WriteBoot(L1, L2, L3: Str77);
label
  Again;
var
  Sector: array[0..511] of Byte;
  Code: TBootCode;
  Unk: array[1..$D2] of Byte;
  Drive: Byte;
  Cancel, HitA, HitB: Boolean;
  B3: TButton3;
  Key: Word;
  Res: Byte;
begin
  while Length(L1) < 77 do L1 := L1 + ' ';
  while Length(L2) < 77 do L2 := L2 + ' ';
  while Length(L3) < 77 do L3 := L3 + ' ';
  Code.Hdr := BootHdr;
  Move(L1[1], Code.L1, 77);
  Move(L2[1], Code.L2, 77);
  Move(L3[1], Code.L3, 77);
  Code.CR1 := #13;
  Code.LF1 := #10;
  Code.CR2 := #13;
  Code.LF2 := #10;
  Code.CR3 := #13;
  Code.LF3 := #10;
  Code.Tail := BootTail;
Again:
  OpenDialog;
  Frame(13, 8, 55, 9, 15, 5, 0, 1);
  WriteCenterXY(1, 1, 55, 'Bootsektor auf formatierte Diskette schreiben:');
  WriteCenterXY(1, 2, 55, 'Nicht auf Systemdisketten benutzen!');
  WriteCenterXY(1, 3, 55, 'Die Disk ist anschlie'#$E1'end nicht bootf'#$84'hig.');
  WriteCenterXY(1, 4, 55, 'Diskette mu'#$E1' schon formatiert sein.');
  WriteCenterXY(1, 5, 55, 'S'#$84'mtliche Daten bleiben erhalten.');
  WriteCenterXY(1, 6, 55, 'Bitte die Diskette einlegen ...');
  InitButton3(True, 3, 7, 21, 7, 39, 7, 14, 0, 15, 5, ' Laufwerk A ', ' Laufwerk B ', '  Abbruch  ', B3);
  MouseShow;
  repeat
    HandleButton3(HitA, HitB, Cancel, Key, B3);
    if IsCancel(Key) then Cancel := True;
  until HitA or HitB or Cancel;
  CloseDialog;
  if Cancel then Exit;
  ArrowCursor;
  if HitA then Drive := 0 else Drive := 1;
  if ReadSector(Drive, 0, 0, 1, Sector) then
  begin
    MsgBox('Fehler beim Lesen des Original-Bootsektors!', '');
    goto Again;
  end;
  Sector[0] := $EB;
  Sector[1] := $3C;
  Sector[2] := $90;
  Sector[$26] := $29;
  FillChar(Sector[$3E], $1C2, 0);
  Move(Code, Sector[$3E], $1C2);
  Res := WriteSectors(Drive, 0, 0, 1, 1, Sector, 1);
  if Res = 0 then
    ErrorBox('Der Bootsektor wurde erfolgreich geschrieben!', '')
  else if Res = 3 then
    MsgBox('Fehler beim Schreiben des Bootsektors!', 'Diskette ist schreibgesch'#$81'tzt.')
  else
    MsgBox('Fehler beim Schreiben des Bootsektors!', '');
  NormalCursor;
  if not Cancel then goto Again;
end;

procedure SaveBootDefault(L1, L2, L3: Str77);
var
  F: file of TConfig;
  Rec: TConfig;
  Err: Boolean;
begin
  Err := False;
  Assign(F, HomeDir + IniName);
  Reset(F);
  Read(F, Rec);
  Close(F);
  if (IOResult = 0) and (Rec.Id = IniId) then
  begin
    Rec.S1 := L1;
    Rec.S2 := L2;
    Rec.S3 := L3;
    Rec.Colors[31] := CfgColors[31];
    Rewrite(F);
    Write(F, Rec);
    Close(F);
    if IOResult <> 0 then Err := True;
  end
  else
    Err := True;
  if Err then
    MsgBox('Der Boottext kann nicht gespeichert werden!', IniName + ' ist fehlerhaft oder nicht vorhanden!')
  else if CfgColors[4] <> 0 then
    ErrorBox('Der Boottext wurde gespeichert!', HomeDir + IniName);
end;

procedure LoadBootDefault(var L1, L2, L3: Str77);
var
  F: file of TConfig;
  Rec: TConfig;
begin
  Assign(F, HomeDir + IniName);
  Reset(F);
  Read(F, Rec);
  Close(F);
  if (IOResult = 0) and (Rec.Id = IniId) then
  begin
    L1 := Rec.S1;
    L2 := Rec.S2;
    L3 := Rec.S3;
  end
  else
  begin
    MsgBox('Der Boottext kann nicht geladen werden!', IniName + ' ist fehlerhaft oder nicht vorhanden!');
    L1 := '';
    L2 := '';
    L3 := '';
  end;
end;

procedure LoadBootDlg(var L1, L2, L3: Str77);
var
  T: Text;
  Key: Word;
  B3: TButton3;
  H1, H2, H3: Boolean;
  Name: string[12];
begin
  OpenDialog;
  Frame(11, 9, 58, 6, 15, 5, 0, 1);
  WriteCenterXY(1, 1, 58, 'Boottext laden:');
  if not SingleFrame then
    WriteCenterXY(1, 2, 58, #$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD);
  InitButton3(True, 3, 4, 22, 4, 40, 4, 14, 0, 15, 5, ' Standardtext ', '    Datei    ', '  Abbrechen  ', B3);
  MouseShow;
  repeat
    HandleButton3(H1, H2, H3, Key, B3);
    if LoCaseW(Key) = 's' then H1 := True;
    if LoCaseW(Key) = 'd' then H2 := True;
    if LoCaseW(Key) = 'a' then H3 := True;
    if IsCancel(Key) or MouseOutside(11, 70, 9, 16) then H3 := True;
  until H1 or H2 or H3;
  CloseDialog;
  if H1 then LoadBootDefault(L1, L2, L3);
  if H2 then
  begin
    Name := LoadBootName;
    if Length(Name) <> 0 then
    begin
      Assign(T, HomeDir + Name);
      Reset(T);
      GB90 := 0;
      Readln(T, L1);
      GB90 := 0;
      Readln(T, L2);
      GB90 := 0;
      Readln(T, L3);
      GB90 := 0;
      Close(T);
      GB90 := 0;
    end;
  end;
end;

procedure SaveBootDlg(L1, L2, L3: Str77);
var
  T: Text;
  Name: string;
  Unk: Word;
  B2: TButton2;
  H1, H2: Boolean;
  Key: Word;
begin
  OpenDialog;
  Name := '';
  Frame(15, 8, 49, 9, 15, 5, 0, 1);
  WriteCenterXY(1, 1, 49, 'Boottext speichern');
  WriteCenterXY(1, 2, 49, Name);
  WriteCenterXYF(1, 3, 49, 4, 'Im Verzeichnis ' + Shorten(HomeDir, 30));
  WriteXY(12, 5, 'Dateiname: ');
  Name := '';
  Window(1, 1, 80, ScreenRows);
  WriteXYFB(49, 12, 0, 5, #$D8#$D8#$D8#$D8);
  WriteXYFB(49, 13, 0, 2, '.bot');
  InitButton2(True, 17, 15, 41, 15, 14, 0, 15, 5, '     Speichern     ', '      Abbruch      ', B2);
  MouseShow;
  Key := $430;
  repeat
    if (Key = $430) or (Key = 9) or (Key = $408) or (LoCaseW(Key) = 'd') or MouseOn(15, 39, 52) then
      InputLine(39, 13, 38, 48, Name, 8, 8, #$D8, False);
    HandleButton2(H1, H2, Key, B2);
    if IsCancel(Key) or MouseOutside(15, 65, 8, 18) then H2 := True;
    if LoCaseW(Key) = 's' then H1 := True;
    if LoCaseW(Key) = 'a' then H2 := True;
  until H1 or H2;
  CloseDialog;
  if (Length(Name) = 0) or H2 then Exit;
  Name := HomeDir + Name + '.bot';
  if FSearch(Name, '') <> '' then
    if not AskReplace(Name) then Exit;
  Assign(T, Name);
  Rewrite(T);
  if IOResult <> 0 then
  begin
    MsgBox('Fehler beim Schreiben des Textes!', Name);
    Exit;
  end;
  Writeln(T, L1);
  Writeln(T, L2);
  Writeln(T, L3);
  Close(T);
  if IOResult = 0 then ErrorBox('Der Boottext wurde gespeichert', Name);
end;

procedure SaveBootMenu(L1, L2, L3: Str77);
var
  Unused: string;
  Key: Word;
  B3: TButton3;
  H1, H2, H3: Boolean;
begin
  OpenDialog;
  Frame(11, 9, 58, 6, 15, 5, 0, 1);
  WriteCenterXY(1, 1, 58, 'Boottext speichern:');
  if not SingleFrame then
    WriteCenterXY(1, 2, 58, #$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD);
  InitButton3(True, 3, 4, 22, 4, 40, 4, 14, 0, 15, 5, ' Standardtext ', '    Datei    ', '  Abbrechen  ', B3);
  MouseShow;
  repeat
    HandleButton3(H1, H2, H3, Key, B3);
    if LoCaseW(Key) = 's' then H1 := True;
    if LoCaseW(Key) = 'd' then H2 := True;
    if LoCaseW(Key) = 'a' then H3 := True;
    if IsCancel(Key) or MouseOutside(11, 70, 9, 16) then H3 := True;
  until H1 or H2 or H3;
  CloseDialog;
  if H1 then SaveBootDefault(L1, L2, L3);
  if H2 then SaveBootDlg(L1, L2, L3);
end;

procedure BootEditor(var L1, L2, L3: Str77);
label
  Edit1, Edit2;
var
  Key: Word;
  B5: TButton5;
  BS, BD: TButton;
  E1, E2, E3: Str77;
  H1, H2, H3, H4, H5: Boolean;
  Saved: Byte;

  procedure Preview;
  begin
    InputLine(6, 9, 16, 65, E1, 70, 0, #$D8, False);
    InputLine(6, 11, 16, 65, E2, 70, 0, #$D8, False);
    InputLine(6, 13, 16, 65, E3, 70, 0, #$D8, False);
    MouseHide;
    WriteXYFB(1, ScreenRows - 4, 7, 0, Copy(E1 + Spaces, 1, 77));
    WriteXYFB(1, ScreenRows - 3, 7, 0, Copy(E2 + Spaces, 1, 77));
    WriteXYFB(1, ScreenRows - 2, 7, 0, Copy(E3 + Spaces, 1, 77));
    MouseShow;
  end;

begin
  OpenDialog;
  E1 := L1;
  E2 := L2;
  E3 := L3;
  Saved := CfgB809;
  CfgB809 := 0;
  RestoreBorder;
  ClockOff;
  Window(1, 1, 80, ScreenRows);
  SetColor(7, 0);
  ClrScr;
  Frame(1, 6, 78, 13, 11, 3, 0, 0);
  WriteCenterXY(1, 1, 78, 'Bootsektor-Editor: 3 Zeilen Starttext auf der Diskette');
  WriteXYF(3, 3, 14, '1');
  WriteXYF(3, 5, 14, '2');
  WriteXYF(3, 7, 14, '3');
  WriteXY(3, 9, '[ ] Text beim Formatieren benutzen');
  WriteXYF(7, 9, 14, 'T');
  if CfgColors[31] <> 0 then WriteXY(4, 9, 'X');
  Window(1, 1, 80, ScreenRows);
  WriteXYFB(1, ScreenRows - 1, 7, 0, 'Keine Systemdiskette! Formatiert mit: DOS-Expander.');
  WriteXYFB(1, ScreenRows, 7, 0, '[Return] = Wiederholen  [ESC] = Von der Festplatte booten.');
  InitButton(False, 38, 14, 0, 0, 11, 3, 'Einfacher Rahmen', BS);
  InitButton(False, 59, 14, 0, 0, 11, 3, 'Doppelter Rahmen', BD);
  InitButton5(1, 3, 17, 16, 17, 34, 17, 50, 17, 64, 17, 14, 0, 11, 3, '   OK   ', ' Beschreiben ',
    ' Speichern ', '  Laden  ', ' Abbrechen ', B5);
  MouseShow;
  Preview;
  repeat
    HandleButton5(H1, H2, H3, H4, H5, Key, B5);
    if LoCaseW(Key) = 'o' then H1 := True;
    if LoCaseW(Key) = 'b' then H2 := True;
    if LoCaseW(Key) = 's' then H3 := True;
    if LoCaseW(Key) = 'l' then H4 := True;
    if LoCaseW(Key) = 'a' then H5 := True;
    if H2 then WriteBoot(E1, E2, E3);
    if MouseOn(15, 4, 21) or (Key = $3FC) or (Key = 32) or (LoCaseW(Key) = 't') then
    begin
      Boolean(CfgColors[31]) := not Boolean(CfgColors[31]);
      MouseHide;
      if CfgColors[31] <> 0 then WriteXY(5, 15, 'X')
      else WriteXY(5, 15, ' ');
      MouseShow;
      WaitRelease;
    end;
    if Buttons.MouseButton(BS) or (LoCaseW(Key) = 'e') then
    begin
      E1 := #$DA;
      for Key := 1 to 75 do E1 := E1 + #$C4;
      E1 := E1 + #$BF;
      E2 := #$B3;
      for Key := 1 to 75 do E2 := E2 + ' ';
      E2 := E2 + #$B3;
      E3 := #$C0;
      for Key := 1 to 75 do E3 := E3 + #$C4;
      E3 := E3 + #$D9;
      Preview;
    end;
    if Buttons.MouseButton(BD) or (LoCaseW(Key) = 'd') then
    begin
      E1 := #$C9;
      for Key := 1 to 75 do E1 := E1 + #$CD;
      E1 := E1 + #$BB;
      E2 := #$BA;
      for Key := 1 to 75 do E2 := E2 + ' ';
      E2 := E2 + #$BA;
      E3 := #$C8;
      for Key := 1 to 75 do E3 := E3 + #$CD;
      E3 := E3 + #$BC;
      Preview;
    end;
    if (Key = $31) or (Key = 9) or (Key = $438) or MouseOn(9, 6, 77) then
    begin
    Edit1:
      Key := InputLine(6, 9, 5, 78, E1, 70, 77, #$D8, False);
      Preview;
      if Key = 9 then Key := $32;
    end;
    if (Key = $32) or MouseOn(11, 6, 77) then
    begin
    Edit2:
      Key := InputLine(6, 11, 5, 78, E2, 70, 77, #$D8, False);
      Preview;
      if Key = 9 then Key := $33;
      if Key = $3F7 then goto Edit1;
    end;
    if (Key = $33) or (Key = $430) or (Key = $3F7) or MouseOn(13, 6, 77) then
    begin
      Key := InputLine(6, 13, 5, 78, E3, 70, 77, #$D8, False);
      Preview;
      if Key = $3F7 then goto Edit2;
    end;
    if IsCancel(Key) then H5 := True;
    if H3 then SaveBootMenu(E1, E2, E3);
    if H4 then
    begin
      LoadBootDlg(E1, E2, E3);
      Preview;
    end;
  until H1 or H5;
  CloseDialog;
  if H1 then
  begin
    L1 := E1;
    L2 := E2;
    L3 := E3;
    while Length(L1) < 77 do L1 := L1 + ' ';
    while Length(L2) < 77 do L2 := L2 + ' ';
    while Length(L3) < 77 do L3 := L3 + ' ';
  end;
  CfgB809 := Saved;
  RestoreBorder;
  ClockOn;
end;

end.

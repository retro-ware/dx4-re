{$O+,F+,G+,S-,I-,X+,V-}
unit LongName;
{ Overlay 156f: Windows 95 long filename (int 21h/71xxh) helpers }

interface

type
  Str12 = string[12];

function WinRunning: Boolean;
function LfnSupported: Boolean;
function LfnRename(Old, New: string): Boolean;
function ShowLongName(Name: Str12): Word;
function LfnMkDir(Path: string): Boolean;
procedure SplitPath(Path: string; var Dir, Name, Ext: string);
function ApplyMask(Mask, Name: string): string;
function LfnFileExists(Path: string): Boolean;
function LfnDirExists(Path: string): Boolean;
function LfnCreate(Path: string): Boolean;
function GetLongName(Short: string; var Long: string; FullPath: Boolean): Boolean;
function GetShortName(Long: string; var Short: string; FullPath: Boolean): Boolean;
function LfnMkDirTree(Path: string): Boolean;

implementation

uses Dos, Crt, Strings, DXGlob, Mouse, Screen, Status, Dialogs, ScrSave;

const
  Spaces =
    '                                                                                                    ' +
    '                                                                                                    ' +
    '                                                       ';

type
  TFindData = record
    Attr: Longint;
    Rest: array[4..317] of Byte;
  end;

procedure LfnSetAttr(Path: string; Attr: Word); forward;

function WinRunning: Boolean;
var
  Regs: Registers;
begin
  WinRunning := True;
  Regs.AX := $1600;
  Intr($2F, Regs);
  if (Regs.AL = 1) or (Regs.AL = $FF) then
    WinRunning := True
  else if (Regs.AL <> 0) or (Regs.AL <> $80) then
    WinRunning := True
  else
  begin
    Regs.AX := $4680;
    Intr($2F, Regs);
    if Regs.AL = $80 then
      WinRunning := False
    else
    begin
      Regs.AX := $1605;
      Intr($2F, Regs);
      if Regs.CX = 0 then
      begin
        WinRunning := True;
        Exit;
      end;
    end;
  end;
end;

function LfnSupported: Boolean;
var
  Buf2: string[128];
  Buf: string[128];
  Regs: Registers;
  R: Boolean;
begin
  R := False;
  LfnSupported := False;
  if not WinRunning then Exit;
  Regs.AH := $30;
  MsDos(Regs);
  if (Regs.AL < 7) or (Regs.AL > 15) then Exit;
  Buf := 'C:\'#0;
  Buf2[0] := #0;
  Regs.ES := SSeg;
  Regs.DI := Ofs(Buf2[1]);
  Regs.DS := SSeg;
  Regs.DX := Ofs(Buf[1]);
  Regs.SI := Regs.DX;
  Regs.CX := $80;
  Regs.AX := $71A0;
  MsDos(Regs);
  R := (Regs.Flags and 1 = 0) and (Regs.AX <> $7100);
  LfnSupported := R;
end;

function LfnFindClose(Handle: Word): Boolean;
var
  Regs: Registers;
begin
  Regs.AX := $71A1;
  Regs.BX := Handle;
  MsDos(Regs);
  LfnFindClose := Regs.Flags and 1 = 0;
end;

function LfnRename(Old, New: string): Boolean;
var
  Regs: Registers;
begin
  Old := Old + #0;
  New := New + #0;
  Regs.AX := $7156;
  Regs.DS := SSeg;
  Regs.DX := Ofs(Old[1]);
  Regs.ES := SSeg;
  Regs.DI := Ofs(New[1]);
  MsDos(Regs);
  LfnRename := Regs.Flags and 1 = 0;
end;

function ShowLongName(Name: Str12): Word;
var
  S: string;
  Key: Word;
  P: Byte;
begin
  if CfgColors[56] = 0 then
    S := 'Die Unterst'#$81'tzung langer Dateinamen ist nicht aktiv!'
  else
    GetLongName(Name, S, True);
  OpenDialog;
  P := 1;
  Window(1, ScreenRows, 80, ScreenRows);
  SetColor(0, 7);
  ClrScr;
  Write(#$1B);
  Mem[$B800:ScreenRows * 160 - 2] := $1A;
  Write(Copy(S, P, 78));
  MouseShow;
  repeat
    GetKey(Key);
    if (Key = $435) or MouseOn(ScreenRows, 80, 80) then
      if Length(S) - P + 1 > 78 then
      begin
        Inc(P);
        MouseHide;
        WriteXY(2, 1, Copy(S + Spaces, P, 78));
        MouseShow;
        if Key <> $435 then Delay(50);
      end;
    if (Key = $433) or MouseOn(ScreenRows, 1, 1) then
      if (Length(S) > 78) and (P > 1) then
      begin
        Dec(P);
        MouseHide;
        WriteXY(2, 1, Copy(S + Spaces, P, 78));
        MouseShow;
        if Key <> $433 then Delay(50);
      end;
    if (Key = $433) or (Key = $435) then Key := 0;
  until IsCancel(Key) or (Key <> 0) or MouseOutside(1, 80, ScreenRows, ScreenRows);
  PopScreen(DlgStack);
  ShowLongName := Key;
end;

function LfnMkDir(Path: string): Boolean;
var
  Regs: Registers;
begin
  Regs.AX := $7139;
  Path := Path + #0;
  Regs.DS := SSeg;
  Regs.DX := Ofs(Path[1]);
  MsDos(Regs);
  LfnMkDir := Regs.Flags and 1 = 0;
end;

procedure SplitPath(Path: string; var Dir, Name, Ext: string);
var
  I, DotPos: Integer;
  Sep: Char;
  D, N, E: string;
begin
  Sep := '\';
  if Pos('\', Path) = 0 then Sep := ':';
  D := '';
  N := '';
  E := '';
  if Length(Path) = 0 then Exit;
  I := Length(Path);
  DotPos := 0;
  while (I > 0) and (Path[I] <> Sep) do
  begin
    if (DotPos = 0) and (Path[I] = '.') then DotPos := I;
    Dec(I);
  end;
  D := Copy(Path, 1, I);
  if DotPos > 0 then
  begin
    N := Copy(Path, I + 1, DotPos - (I + 1));
    E := Copy(Path, DotPos + 1, Length(Path));
    if E <> '' then E := '.' + E;
  end
  else
    N := Copy(Path, I + 1, Length(Path));
  Dir := D;
  Name := N;
  Ext := E;
end;

function ApplyMask(Mask, Name: string): string;
var
  R, MDir, MName, MExt, NName, NDir, NExt, RN, RE: string;
  I: Integer;
begin
  SplitPath(Mask, MDir, MName, MExt);
  SplitPath(Name, NDir, NName, NExt);
  I := 0;
  RN := '';
  while (Length(MName) > I) and (MName[I] <> '*') do
  begin
    Inc(I);
    if MName[I] = '?' then
    begin
      if Length(NName) >= I then RN := RN + NName[I];
    end
    else if MName[I] = '*' then
      RN := Copy(RN, 1, I - 1) + Copy(NName, I, Length(NName))
    else
      RN := RN + MName[I];
  end;
  I := 0;
  RE := '';
  while (Length(MExt) > I) and (MExt[I] <> '*') do
  begin
    Inc(I);
    if MExt[I] = '?' then
    begin
      if Length(NExt) >= I then RE := RE + NExt[I];
    end
    else if MExt[I] = '*' then
      RE := Copy(RE, 1, I - 1) + Copy(NExt, I, Length(NExt))
    else
      RE := RE + MExt[I];
  end;
  R := MDir + RN;
  if RE <> '.' then R := R + RE;
  ApplyMask := R;
end;

function LfnFileExists(Path: string): Boolean;
var
  Regs: Registers;
  S: string;
  FD: TFindData;
begin
  Regs.AX := $714E;
  Regs.CX := $17;
  S := Path + #0;
  Regs.DS := SSeg;
  Regs.DX := Ofs(S[1]);
  Regs.ES := SSeg;
  Regs.DI := Ofs(FD);
  Regs.SI := 0;
  MsDos(Regs);
  LfnFileExists := (Regs.Flags and 1 = 0) and (FD.Attr and $10 = 0);
  if Regs.Flags and 1 = 0 then LfnFindClose(Regs.AX);
end;

function LfnDirExists(Path: string): Boolean;
var
  Regs: Registers;
  S: string;
  FD: TFindData;
begin
  LfnDirExists := False;
  if Path[Length(Path)] = '\' then Delete(Path, Length(Path), 1);
  if Copy(Path, Length(Path) - 2, 3) = '*.*' then Exit;
  Regs.AX := $714E;
  Regs.CX := $10;
  S := Path + #0;
  Regs.DS := SSeg;
  Regs.DX := Ofs(S[1]);
  Regs.ES := SSeg;
  Regs.DI := Ofs(FD);
  Regs.SI := 0;
  MsDos(Regs);
  LfnDirExists := (Regs.Flags and 1 = 0) and (FD.Attr and $10 <> 0);
  if Regs.Flags and 1 = 0 then LfnFindClose(Regs.AX);
end;

function LfnCreate(Path: string): Boolean;
var
  Regs: Registers;
  S: string;
begin
  LfnSetAttr(Path, $20);
  LfnCreate := False;
  Regs.AX := $716C;
  S := Path + #0;
  Regs.BX := 2;
  Regs.CX := 0;
  Regs.DX := $12;
  Regs.DS := SSeg;
  Regs.SI := Ofs(S[1]);
  Regs.Flags := 0;
  MsDos(Regs);
  if Regs.Flags and 1 <> 0 then Exit;
  Regs.BX := Regs.AX;
  Regs.AX := $3E00;
  MsDos(Regs);
  LfnCreate := Regs.Flags and 1 = 0;
end;

function GetLongName(Short: string; var Long: string; FullPath: Boolean): Boolean;
var
  Buf: array[0..255] of Char;
  Regs: Registers;
  D, N, E: string;
begin
  GetLongName := False;
  Short := Short + #0;
  Long := '';
  Regs.AX := $7160;
  Regs.CX := 2;
  Regs.DS := SSeg;
  Regs.SI := Ofs(Short[1]);
  Regs.ES := SSeg;
  Regs.DI := Ofs(Buf);
  MsDos(Regs);
  if Regs.Flags and 1 = 0 then
  begin
    GetLongName := True;
    Long := StrPas(Buf);
    if not FullPath then
    begin
      SplitPath(Long, D, N, E);
      Long := N + E;
    end;
  end;
end;

function GetShortName(Long: string; var Short: string; FullPath: Boolean): Boolean;
var
  Buf: array[0..255] of Char;
  Regs: Registers;
  D, N, E: string;
begin
  GetShortName := False;
  Long := Long + #0;
  Short := '';
  Regs.AX := $7160;
  Regs.CX := 1;
  Regs.DS := SSeg;
  Regs.SI := Ofs(Long[1]);
  Regs.ES := SSeg;
  Regs.DI := Ofs(Buf);
  MsDos(Regs);
  if Regs.Flags and 1 = 0 then
  begin
    GetShortName := True;
    Short := StrPas(Buf);
    if not FullPath then
    begin
      FSplit(Short, D, N, E);
      Short := N + E;
    end;
  end;
end;

function LfnMkDirTree(Path: string): Boolean;
var
  Cur, Tmp: string[79];
  I, X: Byte;
begin
  LfnMkDirTree := False;
  if Length(Path) = 0 then Exit;
  Path := Trim(Path);
  X := 0;
  if Pos('\', Path) = 0 then
  begin
    LfnMkDirTree := LfnMkDir(Path);
    Exit;
  end;
  AddBackslash(Path);
  I := 0;
  Cur := '';
  if Path[2] = ':' then
  begin
    Cur := Copy(Path, 1, 3);
    I := 3;
  end;
  repeat
    repeat
      Inc(I);
      Cur := Cur + Path[I];
    until (Path[I] = '\') or (I >= Length(Path));
    if I < Length(Path) then
    begin
      Tmp := Copy(Cur, 1, Length(Cur) - 1);
      LfnMkDir(Copy(Cur, 1, Length(Cur) - 1));
    end;
  until I >= Length(Path);
  DelBackslash(Path);
  LfnMkDirTree := LfnMkDir(Path);
end;

procedure LfnSetAttr(Path: string; Attr: Word);
var
  Regs: Registers;
begin
  Regs.AX := $7143;
  Path := Path + #0;
  Regs.BL := 1;
  Regs.CX := Attr;
  Regs.DS := SSeg;
  Regs.DX := Ofs(Path[1]);
  MsDos(Regs);
end;

end.

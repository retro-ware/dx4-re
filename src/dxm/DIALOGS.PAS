{$F+,G+,S-,I-}
unit Dialogs;

interface

uses Palette, ScrSave;

type
  Str12 = string[12];
  TDrive = record
    Letter: Char;
    Lbl: Str12;
  end;
  TDrives = array[1..26] of TDrive;
  PDrives = ^TDrives;

var
  DlgStack: TScrStack;
  DlgStack2: TScrStack;
  Drives: PDrives;

procedure OpenDialog;
procedure WaitRelease;
procedure CloseDialog;
procedure RestoreBorder;
procedure ArrowCursor;
procedure NormalCursor;
procedure SmallCursor;
procedure LargeCursor;
function IsCancel(Key: Word): Boolean;
procedure SetPal2;
procedure SetPal1;
procedure FormatName(var S: Str12);
function CompressName(S: Str12): Str12;
procedure WaitInput;
function Shorten(S: string; N: Byte): string;
procedure MsgBox(S1, S2: string);
procedure ErrorBox(S1, S2: string);
function InputLine(X, Y, LeftX, RightX: Byte; var S: string; Width, MaxLen: Byte; Ch: Char;
  Flag: Boolean): Word;
function EditLine(X, Y: Byte; var S: string; Width, MaxLen, Attr, LeftX, RightX: Byte;
  Hist: Boolean; S1, S2: string; Flag: Boolean): Word;
function SelectDrive(X, Y: Byte; Drive: Char): Char;

implementation

uses Dos, Crt, DXGlob, Mouse, Screen, Windows, Status, Buttons, Lists, Sounds, U129A;

type
  TDriveList = object(TList)
    procedure DrawLine(Line: Integer); virtual;
  end;

const
  Blanks = '                                                                ' +
    '                                                                ' +
    '                                                                ' +
    '                                                               ';

procedure TDriveList.DrawLine(Line: Integer);
begin
  if (Line + Top <= Count) and (Line + Top > 0) then
    Text := ' ' + Drives^[Line + Top].Letter + ': ';
  if ShowLabels then
    Text := Text + Drives^[Line + Top].Lbl;
  TList.DrawLine(Line);
end;

procedure OpenDialog;
begin
  MouseHide;
  PushScreen(DlgStack);
end;

procedure WaitRelease;
begin
  repeat
    Idle;
  until Mouse.MouseButton = 0;
end;

procedure CloseDialog;
begin
  PopScreen(DlgStack);
  WaitRelease;
end;

procedure RestoreBorder;
begin
  SetBorder(BorderColor);
end;

procedure ArrowCursor;
begin
  ScreenMask := $7000;
  CursorMask := $0E02;
  MouseDefCursor;
end;

procedure NormalCursor;
begin
  ScreenMask := $40FF;
  CursorMask := $4C00;
  MouseDefCursor;
end;

procedure SmallCursor;
var
  R: Registers;
begin
  R.AH := 1;
  R.CH := 8;
  R.CL := 15;
  if BigCursor then
  begin
    R.CH := 6;
    R.CL := 13;
  end;
  Intr($10, R);
end;

procedure LargeCursor;
var
  R: Registers;
begin
  R.AH := 1;
  R.CH := 14;
  R.CL := 15;
  if BigCursor then
  begin
    R.CH := 12;
    R.CL := 13;
  end;
  Intr($10, R);
end;

function IsCancel(Key: Word): Boolean;
begin
  IsCancel := False;
  if (Key = 27) or (Key = $42C) or (Mouse.MouseButton = 2) then
  begin
    IsCancel := True;
    WaitRelease;
  end;
end;

procedure SetPal2;
var
  I: Byte;
begin
  for I := 0 to 15 do
    SetRGB(I, Pal2[I]);
end;

procedure SetPal1;
var
  RGB: TRGB;
  I: Byte;
begin
  for I := 0 to 15 do
    SetRGB(I, Pal1[I]);
  RGB.R := 0;
  RGB.G := 42;
  RGB.B := 0;
  SetRGB(2, RGB);
  RGB.R := 42;
  RGB.G := 0;
  RGB.B := 42;
  SetRGB(5, RGB);
  RGB.R := 42;
  RGB.G := 0;
  RGB.B := 0;
  SetRGB(6, RGB);
end;

procedure FormatName(var S: Str12);
var
  P, I: Byte;
  Ext: string[4];
begin
  if Length(S) = 0 then
    S := Spaces(12)
  else
  begin
    Ext := '';
    P := Length(S);
    if P > 12 then P := 12;
    while (S[P] <> '.') and (P > 1) do
      Dec(P);
    S := PadRight(S, 12);
    if P = 1 then Exit;
    if P >= 10 then Exit;
    if S = '..          ' then Exit;
    for I := P to P + 3 do
    begin
      Ext := Ext + S[I];
      S[I] := ' ';
    end;
    S[10] := Ext[2];
    S[11] := Ext[3];
    S[12] := Ext[4];
  end;
end;

function CompressName(S: Str12): Str12;
var
  I: Byte;
  R: Str12;
begin
  R := '';
  I := 9;
  repeat
    Dec(I);
  until (S[I] <> ' ') or (I = 0);
  R := Copy(S, 1, I);
  I := 13;
  repeat
    Dec(I);
  until S[I] <> ' ';
  if I > 9 then
    R := R + Copy(S, 9, I - 8);
  CompressName := R;
end;

procedure WaitInput;
var
  Key: Word;
begin
  repeat
    Status.GetKey(Key);
  until (Key <> 0) or (Mouse.MouseButton <> 0);
  repeat
  until Mouse.MouseButton <> 2;
end;

function Shorten(S: string; N: Byte): string;
var
  L: Byte;
begin
  L := Length(S);
  if L > N then
    Shorten := Copy(S, 1, 3) + '...' + Copy(S, L - N + 7, N - 6)
  else
    Shorten := S;
end;

procedure MsgBox(S1, S2: string);
var
  Btn: TButton;
  Key: Word;
begin
  OpenDialog;
  NormalCursor;
  Frame(13, 7, 55, 8, 2, 4, 0, 1);
  WriteCenterXYF(1, 2, 55, 2, S1);
  WriteCenterXYF(1, 4, 55, 14, S2);
  InitButton(True, 19, 6, 2, 2, 2, 4, '     Weiter     ', Btn);
  MouseShow;
  repeat
    Status.GetKey(Key);
  until (Key <> 0) or Buttons.MouseButton(Btn) or (Mouse.MouseButton = 2);
  CloseDialog;
end;

procedure ErrorBox(S1, S2: string);
var
  Btn: TButton;
  Key: Word;
begin
  NormalCursor;
  OpenDialog;
  Frame(13, 7, 55, 8, 2, 5, 0, 1);
  WriteCenterXYFB(1, 2, 55, 0, 5, S1);
  WriteCenterXYFB(1, 4, 55, 4, 5, S2);
  InitButton(True, 3, 6, 0, 2, 2, 5, Spaces(23) + 'OK' + Spaces(22), Btn);
  MouseShow;
  WaitRelease;
  repeat
    Status.GetKey(Key);
  until (Key <> 0) or Buttons.MouseButton(Btn) or (Mouse.MouseButton = 2) or
    MouseOutside(13, 69, 7, 16);
  CloseDialog;
end;

function InputLine(X, Y, LeftX, RightX: Byte; var S: string; Width, MaxLen: Byte; Ch: Char;
  Flag: Boolean): Word;
var
  I, SaveAttr: Byte;
  T: string;
begin
  T := S;
  Window(1, 1, 80, ScreenRows);
  SaveAttr := TextAttr;
  if ThinButtons then
    if Ch = #$C6 then Ch := #$C4 else Ch := ' ';
  MouseHide;
  GotoXY(X, Y - 1);
  for I := 1 to Width + 2 do
    Write(Ch);
  SetColor(0, 2);
  if ThinButtons then
    WriteXY(X, Y, ' ')
  else
    WriteXY(X, Y, #$D0);
  WriteXY(X + 1, Y, Spaces(Width + 1));
  if MaxLen = 0 then
  begin
    WriteXY(X + 1, Y, Copy(T, 1, Width));
    MouseShow;
    TextAttr := SaveAttr;
  end
  else
  begin
    MouseShow;
    ShowCursor;
    InputLine := EditLine(X + 1, Y, T, Width, MaxLen, SaveAttr, LeftX, RightX, False, '', '', Flag);
    HideCursor;
    S := T;
    TextAttr := SaveAttr;
  end;
end;

function EditLine(X, Y: Byte; var S: string; Width, MaxLen, Attr, LeftX, RightX: Byte;
  Hist: Boolean; S1, S2: string; Flag: Boolean): Word;
var
  Cur, L: Byte;
  C: Char;
  Key: Word;
  J, Ofs, SaveAttr, HistIdx: Byte;
  Buf, Orig: string;
  Done, OkHex, OkDig, OkBin: Boolean;
  Dir: string[79];
  Drv: Char;

  procedure Redraw(From, ToCol: Byte);
  var
    T: string;
  begin
    HideCursor;
    MouseHide;
    if ToCol > Width then ToCol := Width;
    GotoXY(X + From - 1, Y);
    T := Copy(Buf, From + Ofs, ToCol - From + 1);
    Write(T);
    GotoXY(X + Cur - 1, Y);
    ShowCursor;
    MouseShow;
  end;

  procedure LeftArrow(Show: Boolean);
  begin
    if Width = MaxLen then Exit;
    if RightX = 0 then Exit;
    TextAttr := Attr;
    MouseHide;
    if Show then
      WriteXY(LeftX, Y, #27)
    else
      WriteXY(LeftX, Y, ' ');
    MouseShow;
    TextAttr := SaveAttr;
  end;

  procedure RightArrow(Show: Boolean);
  begin
    if Width = MaxLen then Exit;
    if RightX = 0 then Exit;
    TextAttr := Attr;
    if Show then
      WriteXY(RightX, Y, #26)
    else
      WriteXY(RightX, Y, ' ');
    TextAttr := SaveAttr;
  end;

  procedure HistoryKey;
  begin
    if (Key = $430) and (HistIdx > 0) and (History^[HistIdx - 1] <> '') then
    begin
      Dec(HistIdx);
      Buf := History^[HistIdx];
    end
    else if (Key = $438) and (HistIdx <= 25) and (HistIdx > 0) and (History^[HistIdx] <> '') then
    begin
      Inc(HistIdx);
      if HistIdx <= 25 then
        Buf := History^[HistIdx]
      else
        Buf := '';
    end
    else
      Exit;
    Ofs := 0;
    L := Length(Buf);
    Cur := L + 1;
    if Cur > Width + 1 then
    begin
      Cur := Width + 1;
      RightArrow(True);
    end;
    Buf := Buf + Blanks;
    Redraw(1, Width);
  end;

  procedure InsertName;
  var
    N, I: Byte;
    T: string;
    D: DirStr;
    Nm: NameStr;
    E: ExtStr;
  begin
    FSplit(S1, D, Nm, E);
    if Key = 4 then T := Nm + E + ' ';
    if Key = $10 then T := D;
    if Key = 1 then T := S2;
    N := Length(T);
    if N + L >= $80 then Exit;
    for I := L + N downto Cur + Ofs + N do
      Buf[I] := Buf[I - N];
    for I := 1 to N do
      Buf[Cur + Ofs + I - 1] := T[I];
    L := L + N;
    Cur := Cur + N;
    if Cur > Width + 1 then
      repeat
        Dec(Cur);
        Inc(Ofs);
      until Cur = Width + 1;
    Redraw(1, Width);
  end;

  procedure ClearToEnd;
  var
    N, I: Byte;
    T: string;
    D: DirStr;
    Nm: NameStr;
    E: ExtStr;
  begin
    for I := Cur + Ofs to L do
      Buf[I] := ' ';
    L := Cur + Ofs - 1;
    Redraw(1, Width);
  end;

begin
  if InsMode then LargeCursor else SmallCursor;
  MouseHide;
  HistIdx := HistCount;
  EditLine := 0;
  Orig := S;
  Buf := S;
  SaveAttr := TextAttr;
  Ofs := 0;
  Key := 0;
  if Hist and (Buf = #255) then
  begin
    Buf := '';
    Key := $430;
  end;
  L := Length(Buf);
  Cur := L + 1;
  if Cur > Width + 1 then
  begin
    Cur := Width + 1;
    RightArrow(True);
  end;
  WriteXYFB(X, Y, 2, 4, Copy(Buf, 1, Width));
  MouseShow;
  if not Hist then
  begin
    WaitRelease;
    repeat
      Status.GetKey(Key);
    until (Key <> 0) or (Mouse.MouseButton <> 0);
  end;
  if Mouse.MouseButton = 2 then Key := 27;
  if (Mouse.MouseButton = 1) and (X - 1 <= MouseX) and (X + Width >= MouseX) and (Y = MouseY) then
  begin
    WaitRelease;
    Key := $435;
  end;
  MouseHide;
  case Key of
    0, $435, $433, $438, $430, 27, 13, 9, $3F7, 8, $42F, $437, $3FA, $423, $450, $43A:
      WriteXY(X, Y, Copy(Buf, 1, Width));
  else
    WriteXY(X, Y, Spaces(Width));
    Buf := '';
    Cur := 1;
    L := 0;
    GotoXY(X, Y);
  end;
  Buf := Buf + Blanks;
  MouseShow;
  repeat
    C := Chr(Key);
    OkHex := not HexOnly or (LoCase(C) in [' ', '0'..'9', 'a'..'f']);
    OkBin := not BinOnly or (LoCase(C) in ['0'..'1']);
    OkDig := not DigOnly or (LoCase(C) in ['0'..'9']) or MinusOk and (LoCase(C) = '-');
    case Key of
      $3FA:
        if Flag and not Hist then
        begin
          Inc(L);
          Buf[L] := '>';
          Key := 13;
        end;
      $450, $451:
        if Flag and not Hist then
        begin
          Inc(L);
          Buf[L] := ':';
          Key := 13;
        end
        else if Flag and Hist then
        begin
          GetDir(0, Dir);
          HideCursor;
          Drv := SelectDrive(20, 10, Dir[1]);
          if Drv <> ' ' then
          begin
            Buf := Drv + ':';
            Key := 13;
            L := 2;
            ShowCursor;
          end;
        end;
      $435:
        if Cur + Ofs <= L then
          if Cur <= Width then
          begin
            Inc(Cur);
            GotoXY(X + Cur - 1, Y);
          end
          else
          begin
            Inc(Ofs);
            Redraw(1, Width);
          end;
      $433:
        if Cur + Ofs > 1 then
          if Cur > 1 then
          begin
            Dec(Cur);
            GotoXY(X + Cur - 1, Y);
          end
          else
          begin
            Dec(Ofs);
            Redraw(1, Width);
            GotoXY(X, Y);
          end;
      $42F:
        begin
          if L > Width then RightArrow(True);
          Cur := 1;
          Ofs := 0;
          Redraw(1, Width);
          GotoXY(X, Y);
        end;
      $437:
        if L - Ofs > Width then
        begin
          Cur := Width + 1;
          Ofs := L - Width;
          Redraw(1, Width);
        end
        else
          Cur := L - Ofs + 1;
      8:
        if Cur > 1 then
        begin
          if (Cur > L) and (Ofs = 0) then
          begin
            Dec(Cur);
            GotoXY(X + Cur - 1, Y);
            MouseHide;
            Write(' ');
            MouseShow;
            Buf[L] := ' ';
          end
          else
          begin
            for J := Cur + Ofs to L do
              Buf[J - 1] := Buf[J];
            Buf[L] := ' ';
            if Ofs > 0 then
            begin
              Dec(Ofs);
              Redraw(1, Cur);
            end
            else
            begin
              Dec(Cur);
              Redraw(Cur, Width);
            end;
          end;
          Dec(L);
        end;
      $43B:
        if (Cur > 0) and (Cur <= L) then
        begin
          for J := Cur + Ofs to L - 1 do
            Buf[J] := Buf[J + 1];
          Buf[L] := ' ';
          Redraw(Cur, Width);
          GotoXY(X + Cur - 1, Y);
          Dec(L);
        end;
      4, $10, 1:
        if Hist then InsertName;
      $F:
        if Hist then Key := $42C;
      $43A:
        begin
          InsMode := not InsMode;
          if InsMode then LargeCursor else SmallCursor;
        end;
      $423: ;
      13: ;
      27: ;
      $42C: ;
      9: ;
      $3F7: ;
      $45D:
        ClearToEnd;
      $438, $430:
        if Hist and not ShiftDown then
        begin
          HistoryKey;
          Key := 0;
        end
        else
        begin
          if Key = $438 then
            if not ShiftDown then Key := 9 else Key := $C08;
          if Key = $430 then Key := $3F7;
        end;
    else
      if OkHex and OkDig and OkBin and (Key < 1000) and (Key > 0) and (Key <> 10) and (Key <> 13) then
        if (L < MaxLen) or not InsMode and (L <= MaxLen) and (Cur <= Width) then
          if Cur + Ofs <= L then
          begin
            if InsMode then
              for J := L downto Cur + Ofs do
                Buf[J + 1] := Buf[J];
            Buf[Cur + Ofs] := C;
            if InsMode then Inc(L);
            if Cur <= Width then
            begin
              Redraw(Cur, Width);
              Inc(Cur);
            end
            else
            begin
              Inc(Ofs);
              Redraw(1, Width);
            end;
          end
          else if Cur <= Width then
          begin
            Buf[Cur + Ofs] := C;
            MouseHide;
            Write(C);
            MouseShow;
            if Cur > L then L := Cur;
            Inc(Cur);
          end
          else
          begin
            Buf[Cur + Ofs] := C;
            Inc(Ofs);
            Inc(L);
            Redraw(1, Width);
          end;
    end;
    HideCursor;
    MouseHide;
    if Ofs > 0 then LeftArrow(True) else LeftArrow(False);
    if Ofs < L - Width then RightArrow(True) else RightArrow(False);
    ShowCursor;
    MouseShow;
    GotoXY(X + Cur - 1, Y);
    if Mouse.MouseButton = 1 then
      if MouseOn(Y, X - 1, X + Width) then
      begin
        if MouseX - X > L then
          Cur := L + 1
        else if MouseX - X < 1 then
          Cur := 1
        else
          Cur := MouseX - X + 1;
        GotoXY(X + Cur - 1, Y);
        WaitRelease;
      end;
    if (Key <> 13) and (Key <> 27) and (Key <> $42C) and (Key <> 9) and (Key <> $3F7) and (Key <> $C08) then
      repeat
        Status.GetKey(Key);
      until (Key <> 0) or (Mouse.MouseButton = 2) or (Mouse.MouseButton = 1);
    Done := (Key = 9) or (Key = $3F7) or (Key = 27) or (Key = 13) or (Key = $42C) or (Key = $C08) or
      (Mouse.MouseButton = 2) or (Mouse.MouseButton = 1) and MouseOutside(X - 1, X + Width, Y, Y);
  until Done;
  if (Key = 27) or (Key = $42C) or (Mouse.MouseButton = 2) then
  begin
    WaitRelease;
    MouseHide;
    if not Hist then
      WriteXYFB(X, Y, 0, 2, Copy(S + Blanks, 1, Width))
    else
      WriteXYFB(X, Y, 2, 0, Copy(S + Blanks, 1, Width));
    LeftArrow(False);
    RightArrow(False);
    MouseShow;
    S := Orig;
    GotoXY(X, Y);
    if Key = $C08 then EditLine := Key;
  end
  else
  begin
    Buf[0] := Chr(L);
    S := Buf;
    EditLine := 13;
    if Key = 9 then EditLine := Key;
    if Key = $3F7 then EditLine := Key;
    if Key = $C08 then EditLine := Key;
  end;
  if (Key = 13) and Hist and (S = '') then EditLine := 13;
end;

function SelectDrive(X, Y: Byte; Drive: Char): Char;
var
  Sel: Byte;
  L: TDriveList;
  Key: Word;
  C: Char;
  N: Integer;
  Ok, Cancel: Boolean;
  Rows, CurSel, W, MaxRows: Byte;
begin
  if not ShowLabels then W := 5 else W := 17;
  MaxRows := ScreenRows - Y - 2;
  OpenDialog;
  Rows := 1;
  CurSel := 1;
  Drive := UpCase(Drive);
  MouseShow;
  ArrowCursor;
  N := 0;
  GetMem(Drives, SizeOf(TDrives));
  Drives^[1].Lbl := '';
  Drives^[1].Letter := ' ';
  Drives^[2].Lbl := '';
  Drives^[2].Letter := ' ';
  Drives^[3].Lbl := '';
  Drives^[3].Letter := ' ';
  for C := 'A' to 'Z' do
    if DriveValid(C) then
    begin
      Inc(N);
      if C = Drive then CurSel := N;
      Drives^[N].Letter := C;
      if ShowLabels and DriveFlag[Ord(C) - $40] then
        Drives^[N].Lbl := VolumeLabel(C)
      else
        Drives^[N].Lbl := FillStr(#$C4, 11);
    end;
  NormalCursor;
  MouseHide;
  if N < 3 then N := 3;
  Rows := N;
  if Rows > MaxRows then Rows := MaxRows;
  Frame(X, Y, W, Rows, 2, 5, 0, 1);
  Ok := False;
  Cancel := False;
  L.Init(0, 5, 0, 2, X + 1, Y + 1, Rows, N, W - 1, True);
  L.SetPos(CurSel, Rows div 2);
  MouseShow;
  repeat
    Status.GetKey(Key);
    Sel := L.Handle(Key);
    if IsCancel(Key) or MouseOutside(X, X + W + 1, Y, Y + Rows + 1) then Cancel := True;
    if Key = 13 then Ok := True;
    if (LoCaseW(Key) >= 'a') and (LoCaseW(Key) <= 'z') then
      if DriveValid(Chr(UpCaseW(Key))) then
      begin
        Drives^[Sel].Letter := Chr(UpCaseW(Key));
        Ok := True;
      end
      else if SoundOn then
        PlaySound(4);
  until Ok or Cancel;
  if Ok then
    SelectDrive := Drives^[Sel].Letter
  else
    SelectDrive := ' ';
  FreeMem(Drives, SizeOf(TDrives));
  CloseDialog;
end;

end.

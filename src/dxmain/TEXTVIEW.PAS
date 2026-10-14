{$O+,F+,G+,S-,I-,X+,V-}
unit TextView;
{ Internal text file viewer (full screen or in one panel), reads the file in 64 KB blocks }

interface

type
  Str79 = string[79];
  Str80 = string[80];

procedure ViewFile(Name: Str80; Mode: Byte);

implementation

uses Dos, Crt, DXGlob, Mouse, Screen, Windows, ScrSave, Dialogs, Status, Palette, ViewDlgs;

type
  TView = record
    Row: ShortInt;
    Top: Integer;
    Lines: Word;
    Rows: ShortInt;
    Fg, Bg: Byte;
    Col: Byte;
    Mode: Byte;
    X, Y, Width, Height: ShortInt;
  end;
  TCell = record
    Ch: Char;
    At: Byte;
  end;
  TBuf = array[0..65519] of Byte;
  TLineIdx = array[0..$27FF] of Word;
  TBlockPos = array[1..1024] of Longint;
  TBlockLines = array[0..1023] of Longint;

const
  Sp255 = '                                                                                                    ' +
    '                                                                                                    ' +
    '                                                       ';

const
  TextFg: Byte = 0;
  TextBg: Byte = 3;
  CurFg: Byte = 0;
  CurBg: Byte = 2;

var
  Scr: array[0..49, 1..80] of TCell absolute $B800:0;
  F: file;
  MaxSize, FSize: Longint;
  Buf: ^TBuf;
  LineIdx: ^TLineIdx;
  BlockPos: ^TBlockPos;
  BlockLines: ^TBlockLines;
  Block, MaxBlock: Word;
  EofFlag, Quit, AtEnd, AtTop, AllRead: Boolean;
  LastLen: Word;
  V: TView;

function ReadBlock(var Len: Word; var V: TView): Boolean; forward;

procedure LoadNext;
var
  Len: Word;
begin
  ArrowCursor;
  EofFlag := ReadBlock(Len, V);
  if EofFlag then AllRead := True;
  BlockPos^[Block + 1] := BlockPos^[Block] + Len;
  if MaxBlock < Block then MaxBlock := Block;
  NormalCursor;
end;

function InitView(Mode: Byte; Name: Str80; var V: TView): Boolean;
var
  Fill: array[1..$154] of Byte;
begin
  V.Top := 0;
  V.Row := 1;
  V.Bg := TextBg;
  V.Fg := TextFg;
  V.Col := 0;
  V.Width := 38;
  V.Y := 4;
  V.Height := ScreenRows - 7;
  V.Mode := Mode;
  TextFg := 0;
  TextBg := 3;
  CurFg := 0;
  CurBg := 2;
  if V.Mode = 1 then
    V.X := 41
  else if V.Mode = 2 then
    V.X := 1
  else
  begin
    V.X := 0;
    V.Width := 80;
    V.Y := 0;
    V.Height := ScreenRows - 2;
    TextFg := 11;
    TextBg := 1;
    CurFg := 0;
    CurBg := 7;
  end;
  V.Rows := V.Height;
  FSize := FileSize(F);
  MaxSize := FSize;
  if MaxSize > $FFF0 then MaxSize := $FFF0;
  if V.Mode = 0 then
  begin
    Window(1, 1, 80, ScreenRows);
    SetColor(11, 1);
    ClrScr;
    SetColor(0, 3);
    GotoXY(1, 1);
    ClrEol;
    ClockHidden := False;
    Idle;
    Write(' Textbetrachter: ', Shorten(Name, 39));
    GotoXY(60, 1);
    Write(FSize, ' Byte');
  end
  else
  begin
    Frame(V.X, 2, 38, 1, 11, 3, 0, 0);
    WriteXYFB(12, 1, 0, 2, ' Textbetrachter: ');
    Frame(V.X, 5, 38, V.Height, 11, 3, 0, 0);
  end;
  if MaxAvail < MaxSize then
  begin
    InitView := True;
    Exit;
  end
  else
    InitView := False;
  Window(1, 1, 80, ScreenRows);
  GotoXY(1, ScreenRows);
  ClrEol;
  Write('  ', #24#24' '#25#25'  '#27#26'  ^Pos1  ^Ende  Esc Tab        Zeile:          Spalte:');
end;

procedure ShowPos(var V: TView);
var
  A: Byte;
  Pos, Abs: Longint;
  S: string[12];
  Pct: Real;
begin
  A := TextAttr;
  SetColor(14, 3);
  GotoXY(62, ScreenRows);
  Abs := BlockPos^[Block] + LineIdx^[V.Row + V.Top - 1];
  Pos := BlockLines^[Block - 1] + V.Row + V.Top;
  if FSize > 0 then
    Pct := Trunc(Abs * 100 / FSize)
  else
    Pct := 100;
  MouseHide;
  GotoXY(40, ScreenRows);
  Str(Pos, S);
  WriteXYF(50, ScreenRows, 14, Copy(S + Sp255, 1, 8));
  Str(V.Col, S);
  WriteXYF(67, ScreenRows, 14, Copy(S + Sp255, 1, 7));
  Str(Pct: 3: 0, S);
  WriteXYF(76, ScreenRows, 14, Copy(S + Sp255, 1, 3) + '%');
  MouseShow;
  TextAttr := A;
end;

procedure DrawLine(L: Longint; var V: TView);
var
  S, T: string;
  N, I, K, M: Word;
  C: Char;
begin
  C := ' ';
  I := V.Top + L;
  S := Sp255;
  N := LineIdx^[I] - LineIdx^[I - 1];
  if N > 255 then N := 0;
  if N > 0 then Move(Buf^[LineIdx^[I - 1]], S[1], N);
  S[0] := Chr(N);
  T := S;
  I := Pos(#9, S);
  K := 0;
  while I <> 0 do
  begin
    S[I] := ' ';
    M := I mod 8;
    Inc(K);
    if M > 0 then M := 8 - M;
    Insert(FillStr(' ', M), S, I);
    I := Pos(#9, S);
  end;
  I := 1;
  if Length(S) > 160 then S := T;
  MouseHide;
  for I := 1 to V.Width do
  begin
    Scr[V.Y + L, I + V.X].Ch := S[V.Col + I];
    Scr[V.Y + L, I + V.X].At := V.Bg shl 4 + V.Fg;
  end;
  MouseShow;
end;

procedure DrawCurLine(L: Longint; var V: TView);
var
  A: Byte;
  Dummy: string[12];
begin
  A := TextAttr;
  SetColor(CurFg, CurBg);
  V.Fg := CurFg;
  V.Bg := CurBg;
  DrawLine(L, V);
  TextAttr := A;
  V.Fg := TextFg;
  V.Bg := TextBg;
  ShowPos(V);
end;

procedure Redraw(var V: TView);
var
  I: Integer;
begin
  DrawCurLine(V.Row, V);
  for I := 1 to V.Rows do
    if V.Row <> I then DrawLine(I, V);
end;

function ViewLoop(Name: Str79; var V: TView): Boolean;
var
  Key: Word;

  procedure LineDown;
  begin
    if V.Row + V.Top >= V.Lines then
      AtEnd := True
    else
    begin
      V.Row := V.Row + 1;
      if V.Row > V.Rows then
      begin
        V.Row := V.Rows;
        Inc(V.Top);
        MouseHide;
        ScrollUp(V.X, V.Y + 1, V.X + V.Width - 1, V.Y + V.Height - 1, TextBg);
        MouseShow;
        DrawLine(V.Row - 1, V);
      end
      else
        DrawLine(V.Row - 1, V);
      DrawCurLine(V.Row, V);
    end;
  end;

  procedure LineUp;
  begin
    if V.Row + V.Top <= 1 then
      AtTop := True
    else
    begin
      V.Row := V.Row - 1;
      if V.Row = 0 then
      begin
        V.Row := 1;
        V.Top := V.Top - 1;
        MouseHide;
        ScrollDown(V.X, V.Y + 2, V.X + V.Width - 1, V.Y + V.Height, TextBg);
        MouseShow;
        DrawLine(V.Row + 1, V);
      end
      else
        DrawLine(V.Row + 1, V);
      DrawCurLine(V.Row, V);
    end;
  end;

  procedure PageDown;
  begin
    if AtEnd and EofFlag then Exit;
    if V.Rows + V.Top - 1 > V.Lines - V.Rows then
    begin
      if not AllRead or (Block <> MaxBlock) then
      begin
        V.Top := V.Rows * 2 + V.Top - V.Lines - 2;
        Inc(Block);
        LoadNext;
      end
      else
      begin
        AtEnd := True;
        if (V.Top <> V.Lines - V.Rows) or (V.Row <> V.Rows) then
        begin
          V.Top := V.Lines - V.Rows;
          V.Row := V.Rows;
        end
        else
          Exit;
      end;
    end
    else
      V.Top := V.Rows + V.Top - 1;
    if V.Lines = V.Rows then
    begin
      V.Top := 0;
      V.Row := V.Rows;
    end;
    Redraw(V);
  end;

  procedure PageUp;
  begin
    if (V.Top = 0) and (V.Row = 1) and (Block = 1) then
      AtTop := True
    else
    begin
      if V.Top + 1 < V.Rows then
      begin
        if Block > 1 then
        begin
          Dec(Block);
          EofFlag := ReadBlock(LastLen, V);
          V.Top := V.Lines - V.Rows * 2 + V.Top + 2;
          if V.Top < 0 then V.Top := 0;
        end
        else
        begin
          AtTop := True;
          V.Row := 1;
          V.Top := 0;
        end;
      end
      else
        V.Top := V.Top - (V.Rows - 1);
      Redraw(V);
    end;
  end;

  procedure Home;
  begin
    AtTop := True;
    if Block > 1 then
    begin
      Block := 1;
      EofFlag := ReadBlock(LastLen, V);
    end
    else if (V.Row = 1) and (V.Top = 0) and (V.Col = 0) then
      Exit;
    V.Col := 0;
    V.Row := 1;
    V.Top := 0;
    Redraw(V);
  end;

  procedure EndKey;
  var
    Key: Word;
  begin
    AtEnd := True;
    if not AllRead then
    begin
      Key := 0;
      Block := MaxBlock;
      OpenDialog;
      MouseShow;
      DlgFrame(10, 15, 60, 5, 1, 3);
      MouseHide;
      WriteCenterXY(1, 1, 60, 'Das kann leider etwas dauern ...');
      GotoXY(24, 4);
      Write(BlockPos^[Block]: 10, ' Bytes');
      BarLen := $3A;
      ClearBar(2, 3);
      while not AllRead and (Key <> 27) do
      begin
        ShowBar(14, BlockPos^[Block] * 100 div FileSize(F), 2, 3);
        GotoXY(24, 4);
        Write(BlockPos^[Block]: 10);
        Inc(Block);
        LoadNext;
        GetKey(Key);
      end;
      ShowBar(14, 100, 2, 3);
      MouseShow;
      PopScreen(DlgStack);
    end;
    if Block < MaxBlock then
    begin
      Block := MaxBlock;
      EofFlag := ReadBlock(LastLen, V);
    end;
    if (V.Row = V.Rows) and (V.Top = V.Lines - V.Rows) and (V.Col = 0) then Exit;
    V.Col := 0;
    V.Row := V.Rows;
    V.Top := V.Lines - V.Rows;
    Redraw(V);
  end;

begin
  V.Top := 0;
  V.Row := 1;
  if AtTop then V.Top := V.Lines - V.Rows;
  if AtEnd then V.Row := V.Rows;
  AtEnd := False;
  AtTop := False;
  Redraw(V);
  repeat
    GetKey(Key);
    if MouseOn(1, 1, 1) then Key := $42F;
    if MouseOn(ScreenRows, 80, 80) then Key := $437;
    if (MouseButton = 1) and (MouseX = 1) and (MouseY > 1) and (ScreenRows > MouseY) then Key := $433;
    if (MouseButton = 1) and (MouseX = 80) and (MouseY > 1) and (ScreenRows > MouseY) then Key := $435;
    case Key of
      $45F:
        begin
          V.Col := 0;
          Redraw(V);
        end;
      $45D:
        begin
          V.Col := 160 - V.Width;
          Redraw(V);
        end;
      $45C:
        begin
          if V.Col + 20 <= 160 - V.Width then Inc(V.Col, 20) else V.Col := 160 - V.Width;
          Redraw(V);
        end;
      $45B:
        begin
          if V.Col >= 20 then Dec(V.Col, 20) else V.Col := 0;
          Redraw(V);
        end;
      $435:
        begin
          if V.Col < 160 - V.Width then Inc(V.Col);
          Redraw(V);
        end;
      $433:
        begin
          if V.Col > 0 then Dec(V.Col);
          Redraw(V);
        end;
      $430: LineUp;
      $438: LineDown;
      $431: PageUp;
      $439: PageDown;
      $42F: Home;
      $437: EndKey;
      $42C, 9, $2D: Key := 27;
      $46D:
        begin
          V.Row := 1;
          V.Top := 0;
          Redraw(V);
        end;
      $46E:
        begin
          V.Row := V.Rows;
          V.Top := V.Lines - V.Rows;
          Redraw(V);
        end;
    end;
    if (MouseButton = 1) and (MouseY = 1) and (MouseX > 1) then
    begin
      LineUp;
      Delay(ScrollDelay);
    end;
    if (MouseButton = 1) and (ScreenRows = MouseY) and (MouseX < 80) then
    begin
      LineDown;
      Delay(ScrollDelay);
    end;
    if (MouseButton = 1) and (V.Mode = 0) and (MouseX > 1) and (MouseX < 80) and (MouseY > 1) and
      (ScreenRows div 2 > MouseY) then
    begin
      LineUp;
      Delay(ScrollDelay);
    end;
    if (MouseButton = 1) and (V.Mode = 0) and (ScreenRows div 2 < MouseY) and (MouseX < 80) and (MouseX > 1) then
    begin
      LineDown;
      Delay(ScrollDelay);
    end;
    if AllRead and (Block = MaxBlock) then AtEnd := False;
    if Block = 1 then AtTop := False;
  until (Key = 27) or AtEnd or AtTop or (MouseButton = 2);
  if (Key = 27) or (MouseButton = 2) then ViewLoop := True else ViewLoop := False;
end;

function ReadBlock(var Len: Word; var V: TView): Boolean;
var
  N, Size, Got: Word;
  BufSeg, BufOfs, IdxOfs, IdxSeg: Word;
  Short: Boolean;
  Col: Byte;
begin
  N := 0;
  LineIdx^[0] := 0;
  Short := False;
  BufSeg := Seg(Buf^);
  BufOfs := Ofs(Buf^);
  IdxSeg := Seg(LineIdx^);
  IdxOfs := Ofs(LineIdx^);
  Seek(F, BlockPos^[Block]);
  BlockRead(F, Buf^, MaxSize, Got);
  if IOResult <> 0 then InfoBox('Fehler beim Lesen der Datei!', '');
  Size := MaxSize;
  if MaxSize < $FFF0 then
  begin
    Short := True;
    Inc(Size);
  end;
  if Got <> MaxSize then
  begin
    Size := Got;
    Short := True;
  end
  else
    Dec(Size);
  asm
        mov     di, 0
        mov     es, BufSeg
        mov     dx, BufOfs
@@1:    mov     Col, 0
        inc     N
@@2:    mov     bx, dx
        add     bx, di
        mov     ax, Size
        cmp     ax, di
        jbe     @@5
        cmp     Col, 0A0h
        jae     @@3
        mov     al, es:[bx]
        cmp     al, 13
        je      @@3
        cmp     al, 10
        je      @@3
        inc     di
        inc     Col
        jmp     @@2
@@3:    mov     cx, 2
@@4:    mov     bx, dx
        add     bx, di
        mov     ax, Size
        cmp     ax, di
        jbe     @@5
        mov     al, es:[bx]
        cmp     al, 10
        je      @@6
        cmp     al, 13
        jne     @@5
@@6:    mov     al, 20h
        mov     es:[bx], al
        inc     di
        loop    @@4
@@5:    mov     bx, N
        shl     bx, 1
        add     bx, IdxOfs
        push    es
        mov     ax, IdxSeg
        mov     es, ax
        mov     es:[bx], di
        pop     es
        mov     ax, Size
        cmp     ax, di
        jbe     @@7
        jmp     @@1
@@7:
  end;
  if not Short then Dec(N);
  if N > V.Height then Len := LineIdx^[N - (V.Height - 1)];
  V.Lines := N;
  if not Short then
    BlockLines^[Block] := BlockLines^[Block - 1] + V.Lines - (V.Height - 1);
  V.Rows := V.Height;
  if V.Lines <= V.Rows then V.Rows := V.Lines;
  ReadBlock := Short;
end;

procedure ViewFile(Name: Str80; Mode: Byte);
var
  S: string;
  I: Integer;
  L: Longint;
  NoMem: Boolean;
  SaveMap: TMouseMap;
begin
  Quit := False;
  AtTop := False;
  AtEnd := False;
  MaxBlock := 0;
  EofFlag := False;
  Block := 1;
  AllRead := False;
  ArrowCursor;
  Assign(F, Name);
  Reset(F, 1);
  if IOResult <> 0 then
  begin
    MsgBox('Die Datei konnte nicht ge'#$94'ffnet werden!', Name);
    Exit;
  end;
  {$I+}
  if FileSize(F) > $3C00000 then {$I-}
  begin
    MsgBox('Die Datei ist zu gro'#$E1' f'#$81'r den Betrachter!', Name);
    Exit;
  end;
  OpenDialog;
  NoMem := InitView(Mode, Name, V);
  MouseShow;
  if NoMem or (MaxSize + $6000 + $1000 > MaxAvail) then
  begin
    PopScreen(DlgStack);
    MsgBox('Zuwenig Speicher!', Name);
    {$I+} Close(F); {$I-}
    StatBg := 3;
    Exit;
  end;
  GetMem(BlockLines, $1000);
  BlockLines^[0] := 0;
  GetMem(Buf, MaxSize);
  GetMem(LineIdx, $5000);
  GetMem(BlockPos, $1000);
  BlockPos^[1] := 0;
  SaveMap := MouseMap;
  InitMouse;
  FillChar(MouseMap[1], 79, $18);
  FillChar(MouseMap[ScreenRows], 79, $19);
  for I := 2 to ScreenRows - 1 do
  begin
    MouseMap[I, 1] := $1B;
    MouseMap[I, 80] := $1A;
  end;
  MouseMap[1, 1] := $17;
  MouseMap[ScreenRows, 80] := $17;
  MouseMap[1, 80] := $F;
  repeat
    if AtEnd then Inc(Block);
    if AtTop then Dec(Block);
    LoadNext;
    Quit := ViewLoop(Name, V);
  until Quit;
  MouseMap := SaveMap;
  CloseDialog;
  {$I+} Close(F); {$I-}
  FreeMem(BlockPos, $1000);
  FreeMem(LineIdx, $5000);
  FreeMem(Buf, MaxSize);
  FreeMem(BlockLines, $1000);
  StatBg := 3;
  StatFg := 0;
end;

end.

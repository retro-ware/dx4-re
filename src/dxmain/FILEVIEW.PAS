{$O+,F+,G+,S-,I-,X+,V-}
unit FileView;
{ Full-screen file viewer (F3 "Betrachter"): text/hex offset display, column cursor, search (F5/F7), block
  markers + Copy (cut file), print (F2), Hex-Dez toggle (F9); reads the file in 64 KB blocks like TextView }

interface

procedure FileViewer(Name, Search: string);

implementation

uses Dos, Crt, DXGlob, Mouse, Screen, Windows, ScrSave, Dialogs, Status, Palette, Help, Fonts, U1D10,
  ViewDlgs, U13B0, U12CA;

type
  Str79 = string[79];
  Str8 = string[8];
  TView = record
    Name: Str79;
    Row: ShortInt;
    Top: Integer;
    Lines: Word;
    Rows: ShortInt;
    Fg, Bg: Byte;
    Offset: Longint;
  end;
  TCell = record
    Ch: Char;
    At: Byte;
  end;
  TBuf = array[0..65519] of Char;
  TLineIdx = array[0..$27FF] of Word;
  TBlockPos = array[1..1024] of Longint;
  TBlockLines = array[0..1023] of Longint;

const
  Sp255 = '                                                                                                    ' +
    '                                                                                                    ' +
    '                                                       ';

const
  FoundPos: Word = 0;
  CaseSens: Boolean = False;
  HexMode: Boolean = False;

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
  Tail: Word;
  MarkStart, MarkEnd: Longint;
  V: TView;
  Marked, SaveThin: Boolean;

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

function InitView(Name: string; var V: TView): Boolean;
var
  Fill: array[1..$154] of Byte;
begin
  V.Name := Name;
  V.Rows := ScreenRows - 2;
  Window(1, 1, 80, ScreenRows);
  V.Top := 0;
  V.Row := 1;
  V.Bg := 1;
  V.Fg := 14;
  FSize := FileSize(F);
  MaxSize := FSize;
  if MaxSize > $FFF0 then MaxSize := $FFF0;
  if MaxAvail < MaxSize then
  begin
    InitView := True;
    Exit;
  end
  else
    InitView := False;
  MouseHide;
  SetColor(14, 1);
  ClrScr;
  MarkStart := 0;
  MarkEnd := FSize - 1;
  SetColor(0, 3);
  GotoXY(1, 1);
  ClrEol;
  WriteF(4, ' F1'); Write(' Hilfe ');
  WriteF(4, ' F2'); Write(' Druck ');
  WriteF(4, ' F3'); Write(' Copy ');
  WriteF(4, ' F5'); Write(' RFind ');
  WriteF(4, ' F7'); Write(' Find ');
  WriteF(4, ' F9'); Write(' Hex-Dez');
  GotoXY(60, 1);
  Write(FSize: 8, ' Bytes');
  GotoXY(1, ScreenRows);
  ClrEol;
  Write(' ' + Shorten(Name, 36));
  WriteXY(40, ScreenRows, 'Zeile:');
  WriteXY(54, ScreenRows, 'Offset:');
  SetColor(14, 1);
  MouseShow;
end;

procedure DrawLine(L: Longint; var V: TView);
var
  S, T: string;
  N, I: Word;
  Bg, Fg: Byte;
  Abs: Longint;
begin
  I := V.Top + L;
  S := Sp255;
  N := LineIdx^[I] - LineIdx^[I - 1];
  if N > 255 then N := 0;
  if N > 0 then Move(Buf^[LineIdx^[I - 1]], S[1], N);
  I := 1;
  MouseHide;
  Bg := V.Bg;
  Fg := V.Fg;
  Abs := BlockPos^[Block] + LineIdx^[V.Top + L - 1];
  repeat
    Scr[L, I].Ch := S[I];
    Bg := V.Bg;
    if Marked and (I <= N) and (V.Row <> L) and (I + Abs - 1 >= MarkStart) and (I + Abs - 1 <= MarkEnd) then
      Bg := 5;
    Scr[L, I].At := Bg shl 4 + Fg;
    Inc(I);
  until I > 80;
  MouseShow;
end;

procedure ShowPos(L: Longint; var V: TView);
var
  A: Byte;
  S: string[12];
begin
  V.Offset := BlockPos^[Block] + LineIdx^[V.Row + V.Top - 1];
  A := TextAttr;
  SetColor(0, 7);
  V.Fg := 0;
  V.Bg := 7;
  DrawLine(L, V);
  SetColor(0, 3);
  L := BlockLines^[Block - 1] + V.Row + V.Top;
  Str(L, S);
  S := Copy(S + Sp255, 1, 6);
  MouseHide;
  WriteXYF(47, ScreenRows, 14, S);
  GotoXY(62, ScreenRows);
  if not HexMode then
  begin
    Str(V.Offset, S);
    WriteF(14, Copy(S + Sp255, 1, 8));
  end
  else
    WriteF(10, HexLong(V.Offset));
  ClrEol;
  TextAttr := A;
  V.Fg := 14;
  V.Bg := 1;
  MouseShow;
end;

procedure Redraw(var V: TView);
var
  I: Integer;
begin
  ShowPos(V.Row, V);
  for I := 1 to V.Rows do
    if V.Row <> I then DrawLine(I, V);
  MouseHide;
  if V.Rows < ScreenRows - 2 then
    for I := V.Rows + 1 to ScreenRows - 2 do
    begin
      GotoXY(1, I + 1);
      ClrEol;
    end;
  MouseShow;
end;

function ViewLoop(Name: Str79; var V: TView): Boolean;
var
  L1: Longint;
  Key: Word;
  L2: Longint;
  Col: Byte;
  W1, W: TWinState;
  CutName: string[80];
  Dir: DirStr;
  FName: NameStr;
  Ext: ExtStr;

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
        ScrollUp(0, 1, 79, ScreenRows - 3, 1);
        MouseShow;
        DrawLine(V.Row - 1, V);
      end
      else
        DrawLine(V.Row - 1, V);
      ShowPos(V.Row, V);
      Col := 1;
      FoundPos := 0;
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
        ScrollDown(0, 2, 79, ScreenRows - 2, 1);
        MouseShow;
        DrawLine(V.Row + 1, V);
      end
      else
        DrawLine(V.Row + 1, V);
      ShowPos(V.Row, V);
      Col := 1;
      FoundPos := 0;
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
    Col := 1;
    FoundPos := 0;
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
      Col := 1;
      FoundPos := 0;
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
    else if (V.Row = 1) and (V.Top = 0) then
      Exit;
    V.Row := 1;
    V.Top := 0;
    Redraw(V);
    Col := 1;
    FoundPos := 0;
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
      MouseHide;
      PushScreen(DlgStack);
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
    if (V.Row = V.Rows) and (V.Top = V.Lines - V.Rows) then Exit;
    V.Row := V.Rows;
    V.Top := V.Lines - V.Rows;
    Redraw(V);
    Col := 1;
    FoundPos := 0;
  end;

  procedure ShowFound(Line: Integer; Ofs: Word; S: string);
  var
    I: Integer;
  begin
    if Line > V.Lines then Exit;
    V.Row := 12;
    V.Top := Line - 12;
    if V.Rows >= Line then
    begin
      V.Top := 0;
      V.Row := Line;
    end;
    if Line >= Longint(V.Lines) - 12 then
    begin
      V.Top := V.Lines - V.Rows;
      V.Row := Line - V.Top;
    end;
    Redraw(V);
    GotoXY(Ofs - LineIdx^[V.Row + V.Top - 1] + 1, V.Row + 1);
    for I := 1 to Length(S) do
      WriteXYFB(Ofs - LineIdx^[V.Row + V.Top - 1] + I, V.Row + 1, 14, 0, Buf^[Ofs + I - 1]);
    Col := Ofs - LineIdx^[V.Row + V.Top - 1] + 1;
  end;

  procedure SearchBuf(P: Pointer; S: string; var Line: Integer; var AOfs: Longint; var Found: Boolean);
  var
    Len, BufSeg, BufOfs, SPtr, Limit, Res, FoundOfs, I, Start, Unused: Word;
    Sens: Boolean;
  begin
    Sens := CaseSens;
    if not CaseSens then S := LowerStr(S);
    BufSeg := Seg(P^);
    BufOfs := Ofs(P^);
    Len := Length(S);
    if Len > MaxSize then
    begin
      Found := False;
      Exit;
    end;
    Start := BufOfs + AOfs;
    Limit := BufOfs + (MaxSize - Len + 1) - Tail;
    Found := False;
    SPtr := Ofs(S);
    asm
        cld
        push    ds
        mov     ax, ss
        mov     es, ax
        mov     bx, Start
        mov     ax, BufSeg
        mov     ds, ax
@@1:    mov     si, bx
        mov     di, SPtr
        mov     cx, Len
@@2:    mov     al, [si]
        inc     si
        inc     di
        cmp     byte ptr es:Sens, 1
        je      @@3
        cmp     al, 9Ah
        jne     @@a
        mov     al, 81h
        jmp     @@3
@@a:    cmp     al, 8Eh
        jne     @@b
        mov     al, 84h
        jmp     @@3
@@b:    cmp     al, 99h
        jne     @@c
        mov     al, 94h
        jmp     @@3
@@c:    cmp     al, 'A'
        jb      @@3
        cmp     al, 'Z'
        ja      @@3
        add     al, 20h
@@3:    cmp     es:[di], al
        loope   @@2
        je      @@4
        inc     bx
        cmp     bx, Limit
        jae     @@5
        jmp     @@1
@@4:    pop     ds
        mov     Res, 0
        jmp     @@6
@@5:    pop     ds
        mov     Res, 1
@@6:    sub     bx, BufOfs
        mov     FoundOfs, bx
    end;
    Found := Res = 0;
    AOfs := FoundOfs;
    I := 0;
    repeat
      Inc(I);
    until (I >= $27FF) or (LineIdx^[I] > FoundOfs);
    Line := I;
  end;

  function Search(Again: Boolean): Boolean;
  var
    W1, Key, W2, SaveBlock: Word;
    SaveTop: Integer;
    SaveRow: ShortInt;
    W3: Word;
    Line: Integer;
    Found: Boolean;
    S1, S2: string;
    L: Longint;
    W4: Word;
  begin
    MouseHide;
    PushScreen(DlgStack);
    MouseShow;
    AtTop := False;
    AtEnd := False;
    SaveBlock := Block;
    SaveRow := V.Row;
    SaveTop := V.Top;
    Search := False;
    if not Again or (LastSearch = '') then
    begin
      if not SearchDlg(LastSearch, CaseSens) then
      begin
        CloseDialog;
        Exit;
      end;
      FoundPos := 0;
    end;
    V.Offset := FoundPos + 1;
    ArrowCursor;
    if V.Offset = 1 then V.Offset := LineIdx^[V.Row + V.Top - 1];
    DlgFrame(10, 15, 60, 5, 14, 1);
    MouseHide;
    WriteCenterXY(1, 1, 60, 'Der Suchvorgang wurde gestartet:');
    GotoXY(24, 4);
    Write(BlockPos^[Block]: 10, ' Bytes');
    BarLen := $3A;
    ClearBar(2, 3);
    MouseShow;
    SearchBuf(Buf, LastSearch, Line, V.Offset, Found);
    GetKey(Key);
    while not EofFlag and not Found and (Key <> 27) do
    begin
      MouseHide;
      Inc(Block);
      GotoXY(24, 4);
      Write(BlockPos^[Block]: 10);
      MouseShow;
      LoadNext;
      V.Offset := 0;
      MouseHide;
      ShowBar(14, BlockPos^[Block] * 100 div FileSize(F), 2, 3);
      MouseShow;
      SearchBuf(Buf, LastSearch, Line, V.Offset, Found);
      GetKey(Key);
    end;
    MouseHide;
    if Key <> 27 then ShowBar(14, 100, 2, 3);
    MouseShow;
    NormalCursor;
    if Found and (Line <= V.Lines) then
    begin
      PopScreen(DlgStack);
      SetColor(14, 1);
      FoundPos := V.Offset;
      ShowFound(Line, V.Offset, LastSearch);
    end
    else
    begin
      FoundPos := 0;
      Found := False;
      DlgFrame(20, 18, 19, 1, 14, 4);
      Write('  Nicht gefunden!');
      WaitInput;
      Window(1, 1, 80, ScreenRows);
      if SaveBlock <> Block then
      begin
        Block := SaveBlock;
        LoadNext;
      end;
      V.Row := SaveRow;
      V.Top := SaveTop;
      PopScreen(DlgStack);
    end;
    Search := Found;
  end;

  procedure ShowChar;
  var
    A: Byte;
    C: Char;
  begin
    A := TextAttr;
    if HexMode then SetColor(10, 3) else SetColor(14, 3);
    GotoXY(61, ScreenRows);
    ClrEol;
    GotoXY(62, ScreenRows);
    if not HexMode then
      Write(BlockPos^[Block] + LineIdx^[V.Row + V.Top - 1] + Col - 1)
    else
      Write(HexLong(BlockPos^[Block] + LineIdx^[V.Row + V.Top - 1] + Col - 1));
    C := Buf^[LineIdx^[V.Row + V.Top - 1] + Col - 1];
    GotoXY(71, ScreenRows);
    TextColor(0);
    case C of
      #13, #10, #8, #7: Write(' ');
    else
      Write(C);
    end;
    WriteXYF(74, ScreenRows, 10, HexByte(Ord(C)));
    GotoXY(77, ScreenRows);
    TextColor(14);
    Write(Ord(C): 3);
    TextAttr := A;
  end;

  function HotButton(Cap: Str8; X, X1, X2: Byte): Boolean;
  begin
    HotButton := False;
    MouseHide;
    WriteXYFB(X, 1, 14, 3, ' ' + Cap);
    MouseShow;
    repeat until (MouseButton and 1 = 0) or (MouseY <> 1) or (X1 > MouseX) or (X2 < MouseX);
    MouseHide;
    WriteXYFB(X, 1, 0, 3, Cap + ' ');
    MouseShow;
    if (MouseY = 1) and (X1 <= MouseX) and (X2 >= MouseX) then HotButton := True;
  end;

  procedure SetMarker;
  var
    Key: Word;
    B: T13B0Btn2;
    Hit1, Hit2, Cancel: Boolean;
    L: Longint;
  begin
    MouseHide;
    PushScreen(DlgStack);
    DlgFrame(20, 8, 40, 10, 0, 3);
    WriteCenterXYF(1, 1, 40, 0, 'Blockmarker setzen');
    WriteXYF(10, 2, 0, '(f'#$81'r die Copy-Funktion)');
    TextColor(14);
    WriteXYF(14, 4, 0, 'Dez: ');
    Writeln(Col + V.Offset - 1);
    WriteXYF(14, 5, 0, 'Hex: ');
    Writeln(HexLong(Col + V.Offset - 1));
    WriteCenterXYF(1, 7, 40, 0, 'Offset setzen als:');
    P13B0_60D(True, 2, 9, 22, 9, 14, 0, 7, 3, '  Blockanfang  ', '   Blockende   ', B);
    MouseShow;
    Cancel := False;
    repeat
      P13B0_6C0(Hit1, Hit2, Key, B);
      if IsCancel(Key) or (Key = $438) or (Key = $430) or MouseOutside(19, 62, 8, 19) then Cancel := True;
    until Hit1 or Hit2 or Cancel;
    if Cancel then
      CloseDialog
    else
    begin
      Marked := True;
      L := Col + V.Offset - 1;
      if Hit1 then MarkStart := L;
      if Hit2 then MarkEnd := L;
      if MarkStart = MarkEnd then Marked := False;
      if MarkStart > MarkEnd then
      begin
        L := MarkStart;
        MarkStart := MarkEnd;
        MarkEnd := L;
      end;
      CloseDialog;
      Redraw(V);
    end;
  end;

  procedure ClickLine(Y: Byte);
  var
    Changed: Boolean;
    OldRow: Byte;
  begin
    Changed := False;
    if Y - 1 + V.Top > V.Lines then
      AtEnd := True
    else
    begin
      if V.Row <> Y - 1 then
      begin
        OldRow := V.Row;
        V.Row := Y - 1;
        DrawLine(OldRow, V);
        ShowPos(V.Row, V);
        Changed := True;
      end;
      if Col <> MouseX then Changed := True;
      if BlockPos^[Block] + LineIdx^[V.Row + V.Top - 1] + MouseX <= BlockPos^[Block] + LineIdx^[V.Row + V.Top] then
      begin
        if Changed then
        begin
          MouseHide;
          Mem[$B800: V.Row * 160 + Col * 2 - 1] := $70;
          Col := MouseX;
          Mem[$B800: V.Row * 160 + Col * 2 - 1] := $0E;
          ShowChar;
          MouseShow;
        end;
        if DoubleClick(MouseX, Y) then SetMarker;
      end;
    end;
  end;

begin
  V.Top := 0;
  V.Row := 1;
  MouseHide;
  FSplit(Name, Dir, FName, Ext);
  CutName := FName + '.cut';
  if AtTop then V.Top := V.Lines - V.Rows;
  if AtEnd then V.Row := V.Rows;
  AtEnd := False;
  AtTop := False;
  Redraw(V);
  MouseShow;
  Col := 1;
  repeat
    GetKey(Key);
    if (MouseButton = 1) and (MouseY = 1) then
    begin
      SaveWin(W);
      case MouseX of
        2..9: if HotButton('Hilfe', 5, 2, 10) then Key := $423;
        12..19: if HotButton('Druck', 15, 12, 20) then Key := $424;
        22..28: if HotButton('Copy', 25, 22, 29) then Key := $425;
        31..38: if HotButton('RFind', 34, 31, 39) then Key := $427;
        41..47: if HotButton('Find', 44, 41, 48) then Key := $429;
        50..59: if HotButton('Hex-Dez', 53, 50, 60) then Key := $42B;
      end;
      RestoreWin(W);
    end;
    if MouseOn(1, 1, 1) then Key := $42F;
    if MouseOn(ScreenRows, 80, 80) then Key := $437;
    case Key of
      $423: ShowHelp($13);
      $435:
        if BlockPos^[Block] + LineIdx^[V.Row + V.Top - 1] + Col < BlockPos^[Block] + LineIdx^[V.Row + V.Top] then
        begin
          MouseHide;
          Mem[$B800: V.Row * 160 + Col * 2 - 1] := $70;
          if Col < 80 then Inc(Col);
          Mem[$B800: V.Row * 160 + Col * 2 - 1] := $0E;
          ShowChar;
          MouseShow;
        end;
      $433:
        begin
          MouseHide;
          Mem[$B800: V.Row * 160 + Col * 2 - 1] := $70;
          if Col > 1 then Dec(Col);
          Mem[$B800: V.Row * 160 + Col * 2 - 1] := $0E;
          ShowChar;
          MouseShow;
        end;
      $430: LineUp;
      $438: LineDown;
      $431: PageUp;
      $439: PageDown;
      $42F: Home;
      $437: EndKey;
      $424:
        begin
          if not SaveThin then
          begin
            ThinButtons := False;
            MouseHide;
            InitFont;
            MouseShow;
          end;
          P12CA_3ADA(Name);
          if not SaveThin then
          begin
            MouseHide;
            InitPlainFont;
            ThinButtons := True;
            MouseShow;
          end;
        end;
      $425: CutFile(V.Name, CutName, F, MarkStart, MarkEnd);
      $427, 12: if Search(True) then ShowChar;
      $429: if Search(False) then ShowChar;
      $42C: Key := 27;
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
      $42B:
        begin
          HexMode := HexMode = False;
          Mem[$B800: V.Row * 160 + Col * 2 - 1] := $0E;
          ShowChar;
        end;
      13: SetMarker;
    end;
    if (MouseButton = 1) and (ScreenRows = MouseY) and (MouseX < 80) then
    begin
      LineDown;
      Delay(ScrollDelay);
    end;
    if (MouseButton = 1) and (MouseY = 1) and (MouseX > 60) then
    begin
      LineUp;
      Delay(ScrollDelay);
    end;
    if (MouseButton = 1) and (ScreenRows > MouseY) and (MouseY > 1) then ClickLine(MouseY);
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
  A: Byte;
begin
  N := 0;
  LineIdx^[0] := 0;
  A := TextAttr;
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
        cmp     Col, 50h
        jge     @@3
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
  if ScreenRows - 2 < N then Len := LineIdx^[N - (ScreenRows - 3)];
  V.Lines := N;
  Tail := MaxSize - LineIdx^[V.Lines];
  if not Short then
    BlockLines^[Block] := BlockLines^[Block - 1] + V.Lines - (ScreenRows - 3);
  V.Rows := ScreenRows - 2;
  if V.Lines <= V.Rows then V.Rows := V.Lines;
  ReadBlock := Short;
  TextAttr := A;
end;

procedure FileViewer(Name, Search: string);
var
  S: string;
  I: Integer;
  L: Longint;
  NoMem: Boolean;
  SaveMap: TMouseMap;
begin
  StatBg := 3;
  StatFg := 0;
  Quit := False;
  AtTop := False;
  AtEnd := False;
  MaxBlock := 0;
  EofFlag := False;
  Block := 1;
  AllRead := False;
  ClockHidden := False;
  Marked := False;
  ArrowCursor;
  if Search <> '' then LastSearch := Search;
  Assign(F, Name);
  Reset(F, 1);
  if IOResult <> 0 then
  begin
    StatBg := 3;
    StatFg := 0;
    MsgBox('Die Datei konnte nicht ge'#$94'ffnet werden!', Name);
    Exit;
  end;
  {$I+}
  if FileSize(F) > $3C00000 then {$I-}
  begin
    StatBg := 3;
    StatFg := 0;
    MsgBox('Die Datei ist zu gro'#$E1' f'#$81'r den Betrachter!', Name);
    Exit;
  end;
  DateOff;
  NoMem := InitView(Name, V);
  if NoMem or (MaxSize + $6000 + $1000 > MaxAvail) then
  begin
    MsgBox('Zuwenig Speicher!', Name);
    {$I+} Close(F); {$I-}
    StatBg := 3;
    StatFg := 0;
    DateOn;
    Exit;
  end;
  GetMem(Buf, MaxSize);
  GetMem(LineIdx, $5000);
  GetMem(BlockLines, $1000);
  SaveThin := ThinButtons;
  MouseHide;
  InitPlainFont;
  MouseShow;
  BlockLines^[0] := 0;
  ThinButtons := True;
  GetMem(BlockPos, $1000);
  BlockPos^[1] := 0;
  SaveMap := MouseMap;
  InitMouse;
  FillChar(MouseMap[1, 61], 19, $18);
  FillChar(MouseMap[ScreenRows], 79, $19);
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
  repeat until MouseButton = 0;
  {$I+} Close(F); {$I-}
  FreeMem(Buf, MaxSize);
  FreeMem(LineIdx, $5000);
  FreeMem(BlockLines, $1000);
  FreeMem(BlockPos, $1000);
  StatBg := 3;
  StatFg := 0;
  MouseHide;
  ThinButtons := SaveThin;
  InitFont;
  MouseShow;
  DateOn;
end;

end.

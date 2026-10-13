{$F+,G+,S-,I-}
unit Lists;

interface

type
  PList = ^TList;
  TList = object
    Count: Integer;
    Rows, Width: Byte;
    Cur: ShortInt;
    Top: Integer;
    SavedMap: array[1..28, 1..80] of Byte;
    Scroll: Boolean;
    ThumbPos: Byte;
    LastRow: Byte;
    Text: string[80];
    Ready: Boolean;
    Fg, Bg, SelFg, SelBg: Byte;
    X, Y: Byte;
    constructor Init(AFg, ABg, ASelFg, ASelBg, AX, AY, ARows: Byte; ACount: Integer;
      AWidth: Byte; AScroll: Boolean);
    procedure DrawLine(Line: Integer); virtual;
    procedure ShowCur(Line: Integer); virtual;
    procedure UpdateThumb;
    procedure ThumbMouse;
    procedure DrawAll;
    procedure SetPos(Pos, Row: Word);
    procedure LineDown;
    procedure LineUp;
    function Handle(var Key: Word): Integer;
    procedure SetData(ACount: Integer; ARows: Byte; ACur: Integer; ATop: Integer);
    destructor Done;
  end;

implementation

uses Crt, DXGlob, Mouse, Palette, Screen, Status, Times;

const
  Blank = '                                                                ' +
          '                                                                ' +
          '                                                                ' +
          '                                                               ';

constructor TList.Init(AFg, ABg, ASelFg, ASelBg, AX, AY, ARows: Byte; ACount: Integer;
  AWidth: Byte; AScroll: Boolean);
var
  I: Integer;
begin
  Fg := AFg;
  Bg := ABg;
  Ready := True;
  SelFg := ASelFg;
  SelBg := ASelBg;
  X := AX;
  Y := AY;
  Rows := ARows;
  Count := ACount;
  Width := AWidth;
  Scroll := AScroll;
  Window(X, Y, 80, ScreenRows);
  SetColor(Fg, Bg);
  Top := 0;
  Cur := 1;
  ThumbPos := 0;
  DrawAll;
  if Scroll then
  begin
    MouseHide;
    WriteXYFB(Width + 1, 1, 2, 0, #24);
    WriteXYFB(Width + 1, 2, 2, 0, #$B2);
    for I := 3 to Rows - 1 do WriteXY(Width + 1, I, #$B0);
    WriteXYFB(Width + 1, Rows, 2, 0, #25);
    MouseShow;
  end;
  Move(MouseMap, SavedMap, SizeOf(SavedMap));
  InitMouse;
  FillChar(MouseMap[Y - 1, X], Width + 1, 24);
  FillChar(MouseMap[Y + Rows, X], Width + 1, 25);
  MouseMap[1, 80] := 15;
  MouseTextCursor;
end;

procedure TList.DrawLine(Line: Integer);
var
  S: string[80];
  W: Byte;
begin
  S := '';
  W := Width;
  if Scroll then Dec(W);
  MouseHide;
  if (Line + Top > 0) and (Line + Top <= Count) then S := Text;
  if Line <= 0 then Line := 1;
  WriteXY(1, Line, Copy(S + Blank, 1, W));
  if Scroll then
    if not ThinButtons then
      WriteF(0, #$CE)
    else
      WriteF(0, ' ');
  MouseShow;
  LastRow := 255;
end;

procedure TList.ShowCur(Line: Integer);
var
  Attr: Byte;
begin
  Attr := TextAttr;
  TextColor(SelFg);
  TextBackground(SelBg);
  DrawLine(Line);
  TextAttr := Attr;
end;

procedure TList.UpdateThumb;
var
  I, P: Byte;
begin
  P := Word(Rows - 2) * Word(Cur + Top) div (Count + 1) + 1;
  if Cur + Top = 1 then P := 1;
  if Cur + Top >= Count then P := Rows - 2;
  if ThumbPos = P then Exit;
  MouseHide;
  for I := 2 to Rows - 1 do WriteXY(Width + 1, I, #$B0);
  WriteXYFB(Width + 1, P + 1, 2, 0, #$B2);
  MouseShow;
  ThumbPos := P;
end;

procedure TList.ThumbMouse;
var
  N: Integer;
  Dummy: Word;
begin
  if (MouseButton = 1) and (Width + X = MouseX) and (Y < MouseY) and (Y + Rows - 1 > MouseY) then
  begin
    if Rows <> 2 then
      N := LongInt(Count) * (MouseY - Y) div (Rows - 2)
    else
      N := 1;
    if (MouseY - Y = 1) or (N <= 1) then N := 1;
    if LastRow <> MouseY - Y then SetPos(N, Rows div 2);
    LastRow := MouseY - Y;
  end;
end;

procedure TList.DrawAll;
var
  I: Integer;
begin
  for I := 1 to Rows do
    if Cur <> I then DrawLine(I);
  ShowCur(Cur);
end;

procedure TList.SetPos(Pos, Row: Word);
begin
  if (Row = 0) and (Count > 0) then
  begin
    Row := 1;
    Pos := 1;
  end;
  if Rows < Row then Row := Rows;
  Cur := Row;
  if Cur > Count then Cur := Count;
  if Pos > Count then Pos := Count;
  if Pos < Cur then Cur := Pos;
  Top := Pos - Cur;
  if Rows > Count then
  begin
    Cur := Pos;
    Top := 0;
  end
  else if Rows + Top > Count then
  begin
    Top := Count - Rows;
    Cur := Pos - Top;
  end;
  DrawAll;
end;

procedure TList.LineDown;
begin
  if Cur + Top >= Count then Exit;
  Inc(Cur);
  if Cur = Rows + 1 then
  begin
    Cur := Rows;
    Inc(Top);
    MouseHide;
    ScrollUp(X - 1, Y - 1, X + Width - 2, Y - 3 + Rows, Bg);
    MouseShow;
    DrawLine(Cur - 1);
  end
  else
    DrawLine(Cur - 1);
  ShowCur(Cur);
end;

procedure TList.LineUp;
begin
  if Cur + Top <= 1 then Exit;
  Cur := Cur - 1;
  if Cur = 0 then
  begin
    Cur := 1;
    Top := Top - 1;
    MouseHide;
    ScrollDown(X - 1, Y, X + Width - 2, Y - 2 + Rows, Bg);
    MouseShow;
    DrawLine(Cur + 1);
  end
  else
    DrawLine(Cur + 1);
  ShowCur(Cur);
end;

function TList.Handle(var Key: Word): Integer;
var
  Dummy1: LongInt;
  InList, Up, Down: Boolean;
  Dummy2: array[1..3] of Byte;
  T: LongInt;
  Dummy3: LongInt;

  procedure MouseSelect;
  var
    C: Byte;
  begin
    if Cur = MouseY - Y + 1 then
    begin
      C := MouseX;
      if DblClickSelect then
      begin
        if DoubleClick(MouseX, MouseY) then Key := 13 else Exit;
      end
      else
      begin
        MouseSetCursor(0, $EFB);
        repeat until MouseButton = 0;
        if (Cur = MouseY - Y + 1) and (C = MouseX) then Key := 13;
        MouseDefCursor;
        Exit;
      end;
    end;
    DrawLine(Cur);
    Cur := MouseY - Y + 1;
    ShowCur(Cur);
  end;

  procedure PageDown;
  var
    OC, R: Byte;
  begin
    if Cur + Top >= Count then Exit;
    OC := Cur;
    R := Rows - 1;
    if OC + Top + R > Count then R := Count - OC - Top;
    Cur := OC + R;
    if Cur > Rows then
    begin
      Cur := Rows;
      Top := R + Top - (Rows - OC);
      DrawAll;
    end
    else
      DrawLine(OC);
    ShowCur(Cur);
  end;

  procedure PageUp;
  var
    OC, R: Byte;
  begin
    if Cur + Top <= 1 then Exit;
    OC := Cur;
    R := Rows - 1;
    if OC + Top - R < 1 then R := OC + Top - 1;
    Cur := OC - R;
    if Cur < 1 then
    begin
      Cur := 1;
      Top := Top - R + OC - 1;
      DrawAll;
    end
    else
      DrawLine(OC);
    ShowCur(Cur);
  end;

  procedure Home;
  begin
    if (Cur <= 1) and (Top = 0) then Exit;
    Cur := 1;
    Top := 0;
    DrawAll;
  end;

  procedure EndKey;
  var
    L: Integer;
  begin
    L := Rows;
    if L > Count then L := Count;
    if (Count <= 1) or (Cur >= L) and (Count - L = Top) then Exit;
    Cur := L;
    Top := Count - L;
    DrawAll;
  end;

begin
  if Scroll then
  begin
    UpdateThumb;
    ThumbMouse;
  end;
  Up := (MouseButton and 1 <> 0) and (X <= MouseX) and (X + Width >= MouseX) and (Y - 1 = MouseY);
  Down := (MouseButton and 1 <> 0) and (X <= MouseX) and (X + Width >= MouseX) and (Y + Rows = MouseY);
  if Scroll and (MouseButton and 1 <> 0) and (Y + Rows - 1 = MouseY) and (Width + X = MouseX) then
    Down := True;
  if Scroll and (MouseButton and 1 <> 0) and (Y = MouseY) and (Width + X = MouseX) then
    Up := True;
  if (Key = $438) or Down then LineDown;
  if (Key = $430) or Up then LineUp;
  if Key = $439 then PageDown;
  if Key = $431 then PageUp;
  if Key = $42F then Home;
  if Key = $437 then EndKey;
  if Down or Up then Delay(ScrollDelay) else Ready := True;
  if (Down or Up) and Ready then
  begin
    T := TimeCount;
    Ready := False;
    repeat
      Idle;
      Down := (MouseButton = 1) and (X <= MouseX) and (X + Width >= MouseX) and (Y + Rows = MouseY);
    until (TimeCount - T > 35) or (MouseButton <> 1) or (MouseButton = 3);
  end;
  InList := (MouseButton = 1) and (X < MouseX) and (X + Width > MouseX) and (Y + Rows > MouseY) and
    (Y + Count > MouseY) and (Y <= MouseY);
  if InList then MouseSelect;
  Handle := Cur + Top;
end;

procedure TList.SetData(ACount: Integer; ARows: Byte; ACur: Integer; ATop: Integer);
begin
  Count := ACount;
  Cur := ACur;
  Top := ATop;
  Rows := ARows;
  DrawAll;
end;

destructor TList.Done;
begin
  Move(SavedMap, MouseMap, SizeOf(SavedMap));
end;

end.

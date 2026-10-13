{$O+,F+,G+,S-,I-,V-}
unit Browser;

interface

uses Buttons;

type
  Str4 = string[4];
  TItem = record
    Name: string[12];
    Size: string[9];
    Date: string[8];
    Time: string[6];
    Attr: Byte;
  end;
  TItems = array[1..1024] of TItem;
  PItems = ^TItems;
  PButton3 = ^TButton3;
  TBrowser = object
    Count: Integer;
    SaveAttr: Byte;
    Rows: Byte;
    Cur: ShortInt;
    Top: Integer;
    Dir: string;
    Mask: string;
    Items: PItems;
    Attr: Byte;
    Dummy: Byte;
    Height: Byte;
    Fg, Bg, HiFg, HiBg: Byte;
    X, Y: Byte;
    DirCount: Integer;
    TitleColor: Byte;
    Ext1, Ext2, Ext3: Str4;
    procedure Init(AFg, ABg, AHiFg, AHiBg, AX, AY, AHeight: Byte; E1, E2, E3: Str4; ATitle: Byte);
    procedure ReadDir;
    procedure Sort(Lo, Hi: Integer);
    procedure SortDirs;
    procedure DrawFrame;
    procedure Select(var Name: string; B: PButton3);
    function Execute(B: PButton3): string;
    procedure Done;
  end;

implementation

uses Dos, Crt, DXGlob, Mouse, Screen, DatStr, Dialogs, Sounds;

const
  OldDir: string[79] = '';

procedure TBrowser.Init(AFg, ABg, AHiFg, AHiBg, AX, AY, AHeight: Byte; E1, E2, E3: Str4; ATitle: Byte);
var
  S: string[3];
begin
  Fg := AFg;
  Bg := ABg;
  HiFg := AHiFg;
  HiBg := AHiBg;
  X := AX;
  Y := AY;
  Height := AHeight;
  SaveAttr := TextAttr;
  TitleColor := ATitle;
  Window(X, Y, X + 39, Y + Height + 1);
  TextColor(Fg);
  TextBackground(Bg);
  GetMem(Items, SizeOf(TItems));
  Ext1 := E1;
  Ext2 := E2;
  Ext3 := E3;
  ReadDir;
  DrawFrame;
  S := 'ini';
  Select(S, nil);
end;

procedure TBrowser.ReadDir;
var
  SR: SearchRec;
  D: DirStr;
  N: NameStr;
  E: ExtStr;
  DT: DateTime;
  I: Integer;
  J: Integer;
  S: string[10];
begin
  ArrowCursor;
  GetDir(0, Dir);
  if Dir[Length(Dir)] = '\' then Mask := Dir + '*.*'
  else Mask := Dir + '\*.*';
  I := 0;
  Count := 0;
  FindFirst(Mask, $37, SR);
  if SR.Name = '.' then FindNext(SR);
  while DosError = 0 do
  begin
    FSplit(SR.Name, D, N, E);
    E := UpperStr(E);
    if (SR.Attr and Directory <> 0) or (E = Ext1) or (E = Ext2) or (E = Ext3) then
    begin
      Inc(I);
      Items^[I].Attr := SR.Attr;
      if SR.Attr and Directory = 0 then Items^[I].Name := LowerStr(SR.Name)
      else Items^[I].Name := SR.Name;
      FormatName(Items^[I].Name);
      if SR.Attr and Hidden <> 0 then Items^[I].Name[9] := #176;
      if SR.Attr and Directory <> 0 then
      begin
        if SR.Name = '..' then Items^[I].Size := #16'UP--DIR'#17
        else Items^[I].Size := #16'SUB-DIR'#17;
      end
      else
      begin
        Str(SR.Size:9, S);
        Items^[I].Size := S;
      end;
      UnpackTime(SR.Time, DT);
      Items^[I].Date := DateStr(DT);
      Items^[I].Time := TimeStr(DT);
    end;
    FindNext(SR);
  end;
  Count := I;
  SortDirs;
  NormalCursor;
end;

procedure TBrowser.Sort(Lo, Hi: Integer);
var
  I, J: Integer;
  S: string[12];
  T: TItem;
begin
  if Hi > Lo then
  begin
    I := Lo;
    J := Hi;
    S := Items^[(Lo + Hi) div 2].Name;
    repeat
      if SortAsc then
      begin
        while Items^[I].Name < S do Inc(I);
        while S < Items^[J].Name do Dec(J);
      end
      else
      begin
        while Items^[I].Name > S do Inc(I);
        while S > Items^[J].Name do Dec(J);
      end;
      if I <= J then
      begin
        T := Items^[I];
        Items^[I] := Items^[J];
        Items^[J] := T;
        Inc(I);
        Dec(J);
      end;
    until I > J;
    if Lo < J then Sort(Lo, J);
    if I < Hi then Sort(I, Hi);
  end;
end;

procedure TBrowser.SortDirs;
var
  I: Integer;
  T: TItem;
begin
  DirCount := 0;
  for I := 1 to Count do
  begin
    if Items^[I].Size = #16'UP--DIR'#17 then Inc(DirCount);
    if Items^[I].Size = #16'SUB-DIR'#17 then
    begin
      Inc(DirCount);
      T := Items^[DirCount];
      Items^[DirCount] := Items^[I];
      Items^[I] := T;
    end;
  end;
  Sort(1, DirCount);
  Sort(DirCount + 1, Count);
end;

procedure TBrowser.DrawFrame;
var
  I: Integer;
begin
  Top := 0;
  Cur := 1;
  Rows := Height;
  MouseHide;
  if Rows > Count then Rows := Count;
  WriteCenterXYFB(1, 1, 40, 0, TitleColor, Shorten(Dir, 38));
  WriteXY(14, 2, #194#196#196#196#196#196#196#196#196#196#194#196#196#196#196#196#196#196#196#194#196#196#196#196#196#196);
  for I := Rows + 1 to Height do
    WriteXY(2, I + 2, '            '#179'         '#179'        '#179'      ');
  MouseShow;
end;

procedure TBrowser.Select(var Name: string; B: PButton3);
var
  Dummy1: Word;
  Key: Word;
  InList, UpArea, DnArea: Boolean;
  Drive: Char;
  Dummy2: Word;
  E, F, L: Boolean;
  X1, Y1, X2, Y2: Byte;

procedure DrawLine(N: Integer);
begin
  if Count <> 0 then
  begin
    GotoXY(2, N + 2);
    MouseHide;
    Write(Items^[N + Top].Name, #179, Items^[N + Top].Size, #179);
    Write(Items^[N + Top].Date, #179, Items^[N + Top].Time);
    MouseShow;
  end;
end;

procedure HiLine(N: Byte);
var
  A: Byte;
begin
  A := TextAttr;
  SetColor(HiFg, HiBg);
  DrawLine(N);
  TextAttr := A;
end;

procedure Redraw;
var
  I: Integer;
begin
  for I := 1 to Rows do
    if Cur <> I then DrawLine(I);
  HiLine(Cur);
end;

procedure MouseClick;
begin
  if Cur = MouseY - Y - 1 then
  begin
    if DoubleClick(MouseX, MouseY) then Key := 13;
  end
  else
  begin
    DrawLine(Cur);
    Cur := MouseY - Y - 1;
    HiLine(Cur);
  end;
end;

procedure LineDown;
begin
  if Cur + Top >= Count then Exit;
  Cur := Cur + 1;
  if Cur = Rows + 1 then
  begin
    Cur := Rows;
    Top := Top + 1;
    Redraw;
  end
  else DrawLine(Cur - 1);
  HiLine(Cur);
end;

procedure LineUp;
begin
  if Cur + Top <= 1 then Exit;
  Cur := Cur - 1;
  if Cur = 0 then
  begin
    Cur := 1;
    Top := Top - 1;
    Redraw;
  end
  else DrawLine(Cur + 1);
  HiLine(Cur);
end;

procedure PageDown;
var
  C, D: Byte;
begin
  if Cur + Top >= Count then Exit;
  C := Cur;
  D := Height - 1;
  if C + Top + D > Count then D := Count - C - Top;
  Cur := C + D;
  if Cur > Rows then
  begin
    Cur := Rows;
    Top := D + Top - (Rows - C);
    Redraw;
  end
  else DrawLine(C);
  HiLine(Cur);
end;

procedure PageUp;
var
  C, D: Byte;
begin
  if Cur + Top <= 1 then Exit;
  C := Cur;
  D := Height - 1;
  if C + Top - D < 1 then D := C + Top - 1;
  Cur := C - D;
  if Cur < 1 then
  begin
    Cur := 1;
    Top := Top - D + C - 1;
    Redraw;
  end
  else DrawLine(C);
  HiLine(Cur);
end;

procedure GoHome;
begin
  Cur := 1;
  Top := 0;
  Redraw;
end;

procedure GoEnd;
begin
  Cur := Rows;
  Top := Count - Rows;
  Redraw;
end;

begin
  Redraw;
  Key := 1;
  if (Name = 'ini') or (B = nil) then
  begin
    DrawLine(1);
    Exit;
  end;
  repeat
    if DnArea or UpArea or InList then Delay(ScrollDelay);
    X1 := Lo(WindMin) + 1;
    Y1 := Hi(WindMin) + 1;
    X2 := Lo(WindMax) + 1;
    Y2 := Hi(WindMax) + 1;
    Window(1, 1, 80, 25);
    if B = nil then GetKey(Key)
    else HandleButton3(E, L, F, Key, B^);
    if LoCaseW(Key) = 'e' then E := True;
    if LoCaseW(Key) = 'f' then F := True;
    if LoCaseW(Key) = 'l' then L := True;
    Window(X1, Y1, X2, Y2);
    if F then Key := $42C;
    if E then Key := 13;
    DnArea := (MouseButton = 1) and (X < MouseX) and (X + 40 > MouseX) and (Y + Height + 2 = MouseY);
    UpArea := (MouseButton = 1) and (X < MouseX) and (X + 40 > MouseX) and ((Y = MouseY) or (Y + 1 = MouseY));
    if (Key = $438) or DnArea then LineDown;
    if (Key = $430) or UpArea then LineUp;
    if Key = $439 then PageDown;
    if Key = $431 then PageUp;
    if Key = $42F then GoHome;
    if Key = $437 then GoEnd;
    if (Key = $450) or (Key = $451) or L then
    begin
      Key := 0;
      Window(1, 1, 80, 25);
      ResetButton3(B^);
      Window(X1, Y1, X2, Y2);
      Drive := SelectDrive(20, 8, Dir[1]);
      if Drive <> ' ' then
      begin
        Attr := Directory;
        Name := Drive + ':';
        Key := 13;
        Window(1, 1, 80, 25);
        SetButton3(1, B^);
        Window(X1, Y1, X2, Y2);
        Exit;
      end;
      Window(1, 1, 80, 25);
      SetButton3(1, B^);
      Window(X1, Y1, X2, Y2);
    end;
    InList := (MouseButton = 1) and (X < MouseX) and (X + 40 > MouseX) and (Y + Rows + 2 > MouseY) and (Y + 1 < MouseY);
    if InList then MouseClick;
    if MouseButton = 2 then Key := $42C;
  until (Key = 27) or (Key = 13) or (Key = $42C);
  Name := Copy(Items^[Cur + Top].Name, 1, 12);
  Name[9] := '.';
  Name := CompressName(Name);
  Attr := Items^[Cur + Top].Attr;
  if (Key = 27) or (Key = $42C) then Name := '*';
  if Copy(Name, 1, 2) = '..' then Name := '..';
end;

function TBrowser.Execute(B: PButton3): string;
var
  Name: string;
  SR: SearchRec;
  I: Integer;
  L: Integer;
  Dummy3: Word;
  S1: string[12];
  S2: string[12];
begin
  Window(X, Y, X + 39, Y + Height + 1);
  WriteCenterXYFB(1, 1, 40, 0, TitleColor, Shorten(Dir, 38));
  ChDir(Dir);
  repeat
    Select(Name, B);
    if (Attr and Directory <> 0) and (Name <> '*') then
    begin
      OldDir := Dir;
      ChDir(Name);
      FindFirst('*.*', $3F, SR);
      if (IOResult <> 0) or (DosError <> 0) then
      begin
        {$I+}
        ChDir(Dir);
        {$I-}
        Name := '';
        if SoundOn then PlaySound(4);
      end
      else
      begin
        ReadDir;
        DrawFrame;
        if Name = '..' then
        begin
          L := Length(OldDir);
          I := L;
          repeat
            Dec(I);
          until OldDir[I] = '\';
          S1 := Copy(OldDir, I + 1, L);
          FormatName(S1);
          for I := 1 to DirCount do
          begin
            S2 := Items^[I].Name;
            S2[9] := ' ';
            if S2 = S1 then
            begin
              Cur := I;
              Break;
            end;
          end;
          while Cur > Rows do
          begin
            Inc(Top);
            Dec(Cur);
          end;
        end;
      end;
    end;
  until (Name = '*') or (Attr and Directory = 0);
  if Name <> '*' then Execute := Dir + '\' + CompressName(Name)
  else Execute := '';
  if (Length(Dir) = 3) and (Name <> '*') then Execute := Dir + CompressName(Name);
  Window(1, 1, 80, 25);
end;

procedure TBrowser.Done;
begin
  FreeMem(Items, SizeOf(TItems));
  TextAttr := SaveAttr;
  Window(1, 1, 80, 25);
end;

end.

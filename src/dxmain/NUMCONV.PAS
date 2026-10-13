{$O+,F+,G+,S-,I-,X+,V-}
unit NumConv;

interface

procedure NumConverter;

implementation

uses Crt, DXGlob, Buttons, Mouse, Screen, Windows, Dialogs, Status, U1D10;

type
  TLong = record
    Lo, Hi: Word;
  end;

procedure NumConverter;
label
  HexInput, DecInput;
var
  L: Longint;
  Mode: Byte;
  Key: Word;
  Dummy: Word;
  Code: Integer;
  OkBtn, SwapBtn: TButton;
  HexS: string[8];
  DecS: string[11];
  BinS: string[32];
  Done: Boolean;

  procedure BinToLong(S: string; var L: Longint);
  var
    I: Byte;

    function Digit(C: Char): Byte;
    begin
      if C = '1' then Digit := 1 else Digit := 0;
    end;

  begin
    L := 0;
    for I := 1 to 31 do
      L := (L + Digit(S[I])) * 2;
    L := L + Digit(S[32]);
  end;

  procedure ShowMode;
  begin
    case Mode of
      1: WriteXY(23, 16, '31  27  23  19  15  11   7   3  0 ');
      2: WriteXY(23, 16, '32  28  24  20  16  12   8   4  1 ');
      3: WriteXY(23, 16, ' '#$D0'   '#$D0'   '#$D0'   '#$D0'   '#$D0'   '#$D0'   '#$D0'   '#$D0'   '#$D0);
    end;
  end;

  procedure Update;
  begin
    HexS := HexLong(L);
    InputLine(23, 11, 29, 38, HexS, 8, 0, #$D8, False);
    Str(L, DecS);
    InputLine(23, 13, 29, 38, DecS, 11, 0, #$D8, False);
    BinS := BinWord(TLong(L).Hi) + BinWord(TLong(L).Lo);
    InputLine(23, 15, 29, 38, BinS, 32, 0, #$D8, False);
  end;

begin
  OpenDialog;
  L := 0;
  Mode := 1;
  Frame(14, 8, 50, 11, 11, 3, 0, 1);
  WriteCenterXYF(1, 1, 49, 0, 'Hex-Dez-Bin-Konverter:');
  WriteXYF(4, 3, 14, 'H');
  Write('ex:                    00000000..FFFFFFFF');
  WriteXYF(4, 5, 14, 'D');
  Write('ez:                 -2147483648..2147483647');
  WriteXYF(4, 7, 14, 'B');
  Write('in: ');
  Window(1, 1, 80, 25);
  ShowMode;
  Update;
  InitButton(True, 16, 17, 14, 0, 11, 3, '                     OK                     ', OkBtn);
  InitButton(True, 58, 14, 14, 0, 11, 3, 'S', SwapBtn);
  MouseShow;
  Key := 0;
  repeat
    if (Key = $40B) or (LoCaseW(Key) = 'h') or (Key = 9) or (Key = $438) or MouseOn(11, 23, 32) then
    begin
    HexInput:
      ShowCursor;
      HexOnly := True;
      Key := InputLine(23, 11, 22, 48, HexS, 8, 8, #$D8, False);
      HideCursor;
      HexOnly := False;
      L := HexVal(HexS);
      Update;
      if Key = 9 then Key := $408;
    end;
    if (Key = $408) or (LoCaseW(Key) = 'd') or MouseOn(13, 23, 35) then
    begin
    DecInput:
      ShowCursor;
      DigOnly := True;
      MinusOk := True;
      Key := InputLine(23, 13, 22, 48, DecS, 11, 11, #$D8, False);
      HideCursor;
      DigOnly := False;
      MinusOk := True;
      Val(DecS, L, Code);
      if Code <> 0 then Write(#7);
      Update;
      if Key = 9 then Key := $418;
      if Key = $3F7 then goto HexInput;
    end;
    if (Key = $418) or (LoCaseW(Key) = 'b') or (Key = $3F7) or (Key = $430) or MouseOn(15, 23, 56) then
    begin
      ShowCursor;
      BinOnly := True;
      Key := InputLine(23, 15, 22, 58, BinS, 32, 32, #$D8, False);
      HideCursor;
      BinOnly := False;
      while Length(BinS) < 32 do Insert('0', BinS, 1);
      BinToLong(BinS, L);
      Update;
      if Key = $3F7 then goto DecInput;
    end;
    GetKey(Key);
    Done := Buttons.MouseButton(OkBtn) or (LoCaseW(Key) = 'o') or (Key = 27) or (Key = $42C) or (Key = 13) or
      (Mouse.MouseButton = 2) or MouseOutside(14, 65, 8, 20);
    if Buttons.MouseButton(SwapBtn) or (LoCaseW(Key) = 's') then
    begin
      Inc(Mode);
      if Mode > 3 then Mode := 1;
      ShowMode;
    end;
  until Done;
  CloseDialog;
end;

end.

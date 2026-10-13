{$O+,F+,G+,S-,I-}
unit PanelFrm;

interface

procedure DrawPanelFrame(Active: Boolean; Mode, X, Y, Detail: Byte);

implementation

uses Crt, DXGlob, Mouse, Screen, Windows;

const
  S0 =
    #$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C2#$C4#$C4 +
    #$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C2#$C4#$C4#$C4#$C4 +
    #$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C2#$C4#$C4#$C4#$C4#$C4#$C4 +
    #$C4#$C4#$C4#$C4#$C4#$C4#$C2;
  S1 =
    #$B3'            '#$B3'            '#$B3'            '#$B3;
  S2 =
    #$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C1#$C4#$C4 +
    #$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C1#$C4#$C4#$C4#$C4 +
    #$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C1#$C4#$C4#$C4#$C4#$C4#$C4 +
    #$C4#$C4#$C4#$C4#$C4#$C4#$C1#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4 +
    #$C4#$C4#$C4#$C4;
  S3 =
    #$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4;
  S4 =
    #$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C2#$C4#$C4 +
    #$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C2;
  S5 =
    #$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C1#$C4#$C4 +
    #$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C1#$C4#$C4#$C4#$C4 +
    #$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4;
  S6 =
    #$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C2#$C4#$C4 +
    #$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C2#$C4#$C4#$C4#$C4#$C4#$C4#$C4 +
    #$C4#$C2;
  S7 =
    #$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C1#$C4#$C4 +
    #$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C1#$C4#$C4#$C4#$C4#$C4#$C4#$C4 +
    #$C4#$C1#$C4#$C4#$C4#$C4#$C4#$C4;

procedure DrawPanelFrame(Active: Boolean; Mode, X, Y, Detail: Byte);
var
  I, Col: Byte;
begin
  if Mode = 1 then Col := 1 else Col := 41;
  MouseHide;
  if CfgColors[6] <> 0 then
  begin
    if Mode = 1 then
    begin
      if Active then Frame(1, 5, 64, ListRows, 11, 1, 0, 0)
      else PlainFrame(1, 5, 64, ListRows, 11, 1, 0);
      Window(1, 1, 80, ScreenRows);
      SetColor(11, 1);
      WriteXY(2, 5, S0);
      if Active then
        for I := Y + 2 to Y + ListRows - 1 do
          WriteXY(14, I, S1);
      if SingleFrame then WriteXY(X, Y + ListRows, #$C3)
      else WriteXY(X, Y + ListRows, #$CE);
      Write(S2);
    end
    else
    begin
      if Active then Frame(67, 5, 12, ListRows, 11, 1, 0, 0)
      else PlainFrame(67, 5, 12, ListRows, 11, 1, 0);
      Window(1, 1, 80, ScreenRows);
      SetColor(11, 1);
      if SingleFrame then WriteXY(67, Y + ListRows, #$C3)
      else WriteXY(67, Y + ListRows, #$CE);
      Write(S3);
    end;
  end
  else
  begin
    if Active then Frame(X, 5, 38, ListRows, 11, 1, 0, 0)
    else PlainFrame(X, 5, 38, ListRows, 11, 1, 0);
    Window(1, 1, 80, ScreenRows);
    SetColor(11, 1);
    if Detail <> 0 then
    begin
      WriteXY(X + 1, Y + 1, S4);
      if Active then
        for I := Y + 2 to Y + ListRows - 1 do
          WriteXY(X + 13, I, #$B3'            '#$B3);
      if SingleFrame then WriteXY(X, Y + ListRows, #$C3)
      else WriteXY(X, Y + ListRows, #$CE);
      Write(S5);
    end
    else
    begin
      if CfgColors[53] = 0 then
        WriteXY(X + 1, Y + 1, S6);
      if SingleFrame then WriteXY(X, Y + ListRows, #$C3)
      else WriteXY(X, Y + ListRows, #$CE);
      if CfgColors[53] <> 0 then Write(FillStr(#$C4, 38))
      else Write(S7);
    end;
  end;
  if Active then Frame(Col, Y - 2, 38, 1, 11, 3, 0, 0)
  else PlainFrame(Col, Y - 2, 38, 1, 11, 3, 0);
  Window(1, 1, 80, ScreenRows);
  SetColor(11, 1);
  if (CfgColors[6] <> 0) and (Mode = 2) then
  begin
    MemW[$B800:Y * 160 + $88] := $1E07;
    MemW[$B800:Y * 160 + $88 + 4] := $1E07;
    MemW[$B800:Y * 160 + $88 + 8] := $1E07;
  end
  else
  begin
    MemW[$B800:Y * 160 + Col * 2 + 2] := $1E07;
    MemW[$B800:Y * 160 + Col * 2 + 6] := $1E07;
    MemW[$B800:Y * 160 + Col * 2 + 10] := $1E07;
  end;
  if (CfgColors[6] <> 0) and (Mode = 2) then
  begin
    WriteXYF(74, Y + 1, 14, #$1E);
    WriteXYF(76, Y + 1, 14, #$17);
    WriteXYF(78, Y + 1, 14, '\');
  end
  else if (CfgColors[6] <> 0) and (Mode = 1) then
  begin
    WriteXYF(Col + 59, Y + 1, 14, #$1E);
    WriteXYF(Col + 61, Y + 1, 14, #$17);
    WriteXYF(Col + 63, Y + 1, 14, '\');
  end
  else
  begin
    WriteXYF(Col + 33, Y + 1, 14, #$1E);
    WriteXYF(Col + 35, Y + 1, 14, #$17);
    WriteXYF(Col + 37, Y + 1, 14, '\');
  end;
  MouseShow;
end;

end.

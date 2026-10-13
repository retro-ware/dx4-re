{$O+,F+,G+,S-,I-}
unit Toggle;

interface

type
  Str60 = string[60];
  TToggle = object
    X, Y: Byte;
    OnFg, OffFg: Byte;
    Len: Byte;
    Light, Bg: Byte;
    Checked, OldChecked: Boolean;
    OnText: Str60;
    OffText: Str60;
    procedure Init(AChecked: Boolean; AX, AY, AOnFg, AOffFg, ALight, ABg: Byte; AOn, AOff: Str60);
    function Clicked: Boolean;
    procedure Toggle;
    procedure Draw;
  end;

implementation

uses Crt, DXGlob, Mouse, Screen, Dialogs;

procedure TToggle.Init(AChecked: Boolean; AX, AY, AOnFg, AOffFg, ALight, ABg: Byte; AOn, AOff: Str60);
begin
  Checked := AChecked;
  OldChecked := not AChecked;
  X := AX;
  OnText := AOn;
  Y := AY;
  OffText := AOff;
  Bg := ABg;
  Len := Length(OnText);
  if Length(OffText) > Len then Len := Length(OffText);
  Light := ALight;
  Inc(Len, 2);
  OnFg := AOnFg;
  OffFg := AOffFg;
  Draw;
end;

procedure TToggle.Toggle;
begin
  Checked := not Checked;
  OldChecked := not Checked;
  Draw;
end;

procedure TToggle.Draw;
var
  Attr, Dark, Lit, Text: Byte;
  Dummy: Word;
  I: Integer;
  S: string[62];
begin
  Attr := TextAttr;
  if OldChecked = Checked then Exit;
  OldChecked := Checked;
  S := ' ' + OffText + ' ';
  if Checked then S := ' ' + OnText + ' ';
  Len := Length(S);
  Dark := 0;
  Lit := Dark;
  if Checked then
  begin
    Lit := Light;
    Text := OnFg;
  end
  else
  begin
    Dark := Light;
    Text := OffFg;
  end;
  SetColor(Dark, Bg);
  MouseHide;
  if SingleFrame then
  begin
    WriteXY(X, Y, #$DA);
    for I := 1 to Len do Write(#$C4);
    TextColor(Lit);
    Write(#$BF);
    WriteXYF(X, Y + 1, Dark, #$B3);
    WriteF(Text, S);
    WriteF(Lit, #$B3);
    TextColor(Dark);
    WriteXY(X, Y + 2, #$C0);
    TextColor(Lit);
    for I := 1 to Len do Write(#$C4);
    Write(#$D9);
  end
  else
  begin
    WriteXY(X, Y, #$D2);
    for I := 1 to Len do Write(#$C4);
    TextColor(Lit);
    Write(#$D3);
    WriteXYF(X, Y + 1, Dark, #$CE);
    WriteF(Text, S);
    WriteF(Lit, #$D0);
    TextColor(Dark);
    WriteXY(X, Y + 2, #$D4);
    TextColor(Lit);
    for I := 1 to Len do Write(#$C4);
    Write(#$D5);
  end;
  MouseShow;
  TextAttr := Attr;
end;

function TToggle.Clicked: Boolean;
var
  X1, X2, Y1: Byte;
begin
  Clicked := False;
  X1 := X + Lo(WindMin) + 1;
  X2 := X1 + Len;
  Y1 := Y + Hi(WindMin) + 1;
  if (MouseButton = 1) and (Y1 = MouseY) and (X1 < MouseX) and (X2 > MouseX) then
  begin
    Checked := not Checked;
    Clicked := True;
    Draw;
    WaitRelease;
  end;
end;

end.

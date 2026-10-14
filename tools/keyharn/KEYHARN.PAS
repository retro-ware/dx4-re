{$M 4096,0,0}
{$F+,S-,I-}
program KeyHarn;
{ TSR test harness: hooks int 16h, feeds keys from a script file and dumps the text screen.
  Script lines:  K hhhh   key word (scan<<8 | ascii) returned by the next keyboard read
                 D name   write the text screen (80 x rows x 2 bytes) to file NAME
                 W n      n "no key" answers to keyboard polls (lets clocks/idle code run)
  When the script is used up every read returns Esc. }
uses Dos;

const
  MaxLines = 400;
type
  TLine = record
    Kind: Char;
    Arg: string[12];
  end;
var
  Lines: array[1..MaxLines] of TLine;
  Count, Cur, WaitLeft: Integer;
  Old16: Pointer;

function HexWord(S: string): Word;
var
  I: Integer;
  V: Word;
  C: Char;
begin
  V := 0;
  for I := 1 to Length(S) do
  begin
    C := UpCase(S[I]);
    if C in ['0'..'9'] then V := V * 16 + Ord(C) - 48
    else if C in ['A'..'F'] then V := V * 16 + Ord(C) - 55;
  end;
  HexWord := V;
end;

procedure Dump(const Name: string);
var
  F: file;
  Rows: Byte;
begin
  Rows := Mem[$40:$84] + 1;
  if Rows < 25 then Rows := 25;
  Assign(F, Name);
  Rewrite(F, 1);
  BlockWrite(F, Mem[$B800:0], 160 * Rows);
  Close(F);
  InOutRes := 0;
end;

{ runs D lines until the next K/W; returns True with the key in K when a key is ready }
function NextKey(var K: Word; Consume: Boolean): Boolean;
begin
  NextKey := False;
  while (Cur <= Count) and (Lines[Cur].Kind = 'D') do
  begin
    Dump(Lines[Cur].Arg);
    Inc(Cur);
  end;
  if Cur > Count then
  begin
    K := $011B;
    NextKey := True;
    Exit;
  end;
  if Lines[Cur].Kind = 'W' then
  begin
    if WaitLeft < 0 then Val(Lines[Cur].Arg, WaitLeft, K);
    if WaitLeft > 0 then
    begin
      if Consume then Dec(WaitLeft);
      Exit;
    end;
    WaitLeft := -1;
    Inc(Cur);
    NextKey := NextKey(K, Consume);
    Exit;
  end;
  K := HexWord(Lines[Cur].Arg);
  if Consume then Inc(Cur);
  NextKey := True;
end;

procedure Int16(Flags, CS, IP, AX, BX, CX, DX, SI, DI, DS, ES, BP: Word); interrupt;
var
  K: Word;
  Fn: Byte;
begin
  Fn := Hi(AX);
  case Fn of
    $00, $10:
      begin
        while not NextKey(K, True) do ;
        AX := K;
      end;
    $01, $11:
      if NextKey(K, False) then
      begin
        AX := K;
        Flags := Flags and not $40;
      end
      else
      begin
        if WaitLeft > 0 then Dec(WaitLeft);
        Flags := Flags or $40;
      end;
    $02, $12: AX := AX and $FF00;
  else
    { other functions: ignore }
  end;
end;

procedure Load(const Name: string);
var
  T: Text;
  S: string;
begin
  Assign(T, Name);
  Reset(T);
  if IOResult <> 0 then
  begin
    Writeln('KEYHARN: cannot open ', Name);
    Halt(1);
  end;
  Count := 0;
  while not Eof(T) and (Count < MaxLines) do
  begin
    Readln(T, S);
    if (Length(S) >= 3) and (UpCase(S[1]) in ['K', 'D', 'W']) then
    begin
      Inc(Count);
      Lines[Count].Kind := UpCase(S[1]);
      Lines[Count].Arg := Copy(S, 3, 12);
    end;
  end;
  Close(T);
end;

begin
  Load(ParamStr(1));
  Cur := 1;
  WaitLeft := -1;
  GetIntVec($16, Old16);
  SetIntVec($16, @Int16);
  Keep(0);
end.

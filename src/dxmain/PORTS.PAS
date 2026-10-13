{$O+,F+,G+,S-,I-}
unit Ports;

interface

procedure ShowComPorts;
procedure ShowLptPorts;
procedure SetComPort(PortNo: Byte; Baud: Longint; Parity: Char; DataBits, StopBits: Byte);
function ComPresent(N: Byte): Boolean;

implementation

uses U1D10;

function PortInfo(Base: Word): string;
var
  LCR: Byte;
  S: string;
  Baud: Longint;
begin
  PortInfo := '----';
  if Base = 0 then Exit;
  Port[Base + 3] := Port[Base + 3] or $80;
  LCR := PortW[Base + 3];
  Baud := 115200 div PortW[Base];
  Str(Baud, S);
  S := S + ',';
  if LCR and 8 = 0 then S := S + 'N,'
  else if LCR and $10 = 0 then S := S + 'O,'
  else S := S + 'E,';
  case LCR and 3 of
    0: S := S + '5,';
    1: S := S + '6,';
    2: S := S + '7,';
    3: S := S + '8,';
  end;
  if LCR and 4 = 0 then S := S + '1' else S := S + '2';
  PortInfo := S;
  Port[Base + 3] := Port[Base + 3] and $7F;
end;

procedure ShowComPorts;
var
  Dummy: string[20];
  W: Word;
  B: Byte;
begin
  W := MemW[$40:0];
  Write('COM1: ', HexWord(W), '  ');
  Writeln(PortInfo(W));
  W := MemW[$40:2];
  Write('COM2: ', HexWord(W), '  ');
  Writeln(PortInfo(W));
  W := MemW[$40:4];
  Write('COM3: ', HexWord(W), '  ');
  Writeln(PortInfo(W));
  W := MemW[$40:6];
  Write('COM4: ', HexWord(W), '  ');
  Writeln(PortInfo(W));
end;

procedure ShowLptPorts;
var
  Dummy: string[20];
  W: Word;
begin
  W := MemW[$40:8];
  Writeln('LPT1: ', HexWord(W));
  W := MemW[$40:$A];
  Writeln('LPT2: ', HexWord(W));
  W := MemW[$40:$C];
  Writeln('LPT3: ', HexWord(W));
  W := MemW[$40:$E];
  Writeln('LPT4: ', HexWord(W));
end;

procedure SetComPort(PortNo: Byte; Baud: Longint; Parity: Char; DataBits, StopBits: Byte);
var
  Base, Divisor: Word;
  LCR: Byte;
begin
  Parity := UpCase(Parity);
  Base := MemW[$40:PortNo];
  if Baud = 300 then Divisor := $180
  else if Baud = 1200 then Divisor := $60
  else if Baud = 2400 then Divisor := $30
  else if Baud = 4800 then Divisor := $18
  else if Baud = 9600 then Divisor := $C
  else if Baud = 19200 then Divisor := 6
  else if Baud = 38400 then Divisor := 3
  else if Baud = 57600 then Divisor := 2
  else if Baud = 115200 then Divisor := 1
  else Exit;
  Port[Base + 3] := Port[Base + 3] or $80;
  PortW[Base] := Divisor;
  LCR := 0;
  if Parity = 'E' then LCR := LCR or $18
  else if Parity = 'O' then LCR := LCR or 8;
  if StopBits = 2 then LCR := LCR or 4;
  case DataBits of
    5: ;
    6: LCR := LCR or 1;
    7: LCR := LCR or 2;
    8: LCR := LCR or 3;
  else
    Exit;
  end;
  Port[Base + 3] := LCR;
end;

function ComPresent(N: Byte): Boolean;
var
  Base: Word;
begin
  ComPresent := False;
  if (N < 1) or (N > 4) then Exit;
  case N of
    1: N := 0;
    2: N := 2;
    3: N := 4;
    4: N := 6;
  end;
  Base := MemW[$40:N];
  if Base = 0 then Exit;
  Port[Base + 7] := $55;
  if Port[Base + 7] <> $55 then Exit;
  Port[Base + 7] := $AA;
  if Port[Base + 7] <> $AA then Exit;
  ComPresent := True;
end;

end.

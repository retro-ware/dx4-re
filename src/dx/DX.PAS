{$G+,S-}
{$M 1024,0,0}
program DX;

uses Dos;

const
  Pars     : string[19] = '';
  XmsHandle: Word = 0;
  XmsEntry : Pointer = nil;
  ComSpec  : string[79] = '';

var
  Cmd      : string[79];
  NumStr   : string[161];  { DXMAIN writes the next command line here }

procedure Print(const S: string);
begin
  asm
    push ds
    push dx
    lds  dx,S
    inc  dx
    mov  ah,9
    int  21h
    pop  dx
    pop  ds
  end;
end;

procedure MakeNum(N: Word);
var
  I: Byte;
begin
  NumStr[0] := #6;
  NumStr[6] := ' ';
  for I := 5 downto 1 do
  begin
    NumStr[I] := Chr(N mod 10 + $30);
    N := N div 10;
  end;
end;

begin
  ComSpec := GetEnv('COMSPEC');
  Print('Dos-Expander 4.0 (C) Copyright 1994-1996 Hombergs'#10#13'$');
  asm
    mov ax,1A00h
    int 10h
    mov ExitCode,ax
  end;
  if Lo(ExitCode) <> $1A then
  begin
    Print('Sorry, der DX l'#$84'uft nur mit Farb-VGA-Karten!'#10#13'$');
    Halt(13);
  end;
  asm
    mov ax,4300h
    int 2Fh
    cmp al,80h
    jne @@1
    mov ax,4310h
    int 2Fh
    mov word ptr XmsEntry,bx
    mov word ptr XmsEntry+2,es
    mov ah,9
    mov dx,20h
    call XmsEntry
    cmp ax,1
    jne @@1
    mov XmsHandle,dx
  @@1:
  end;
  Cmd := ParamStr(0);
  Dec(Cmd[0], 6);
  Cmd := Cmd + 'dxmain.exe';
  MakeNum(Seg(NumStr));
  Pars := NumStr;
  MakeNum(Ofs(NumStr));
  Pars := Pars + NumStr;
  MakeNum(XmsHandle);
  Pars := Pars + NumStr + '1';
  if Pos('a', ParamStr(1)) <> 0 then Pars[19] := '2';
  repeat
    SwapVectors;
    Exec(Cmd, Pars);
    SwapVectors;
    Pars[19] := '0';
    ExitCode := DosExitCode;
    if DosError <> 0 then
    begin
      Print('DX: Die Datei konnte nicht ausgef'#$81'hrt werden: ' + Cmd + #10#13'$');
      Halt;
    end;
    if ExitCode > 0 then
    begin
      SwapVectors;
      Exec(ComSpec, '/c ' + NumStr);
      SwapVectors;
      if DosError <> 0 then
        Print('DX: Die Datei konnte nicht ausgef'#$81'hrt werden: ' + ComSpec + #10#13'$');
    end;
  until ExitCode = 0;
end.

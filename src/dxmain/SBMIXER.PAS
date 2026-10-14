{$O+,F+,G+,S-,I-,X+,V-}
unit SBMixer;
{ Overlay 031f: Sound Blaster mixer dialog ("LautstÑrke"): BLASTER environment variable gives the
  base port, the DSP is reset and its version checked (3.x/4.x), then Master/Wave/Midi/CD L+R sliders
  are shown and set through mixer registers $22/$04/$26/$28 }

interface

procedure Mixer;

implementation

uses Dos, Crt, DXGlob, Mouse, Screen, Windows, Dialogs, Status, U1D10;

procedure Mixer;
var
  Port: Word;
  Ver: Word;
  Key: Word;
  CdL, CdR, MasterL, MasterR, WaveL, WaveR, MidiL, MidiR: Byte;
  X, Y: Byte;
  P: Word;
  OldY, CurY, OldX: Byte;
  S, S2: string;
  Dummy: Word;
  Group: Integer;

function ReadMixer(Port: Word; Reg: Byte): Byte;
var
  V: Byte;
begin
  asm
    mov dx, Port
    add dl, 4
    mov al, Reg
    out dx, al
    inc dl
    in al, dx
    mov V, al
  end;
  ReadMixer := V;
end;

procedure WriteMixer(Port: Word; Reg, Val: Byte);
var
  V: Byte;
begin
  asm
    mov dx, Port
    add dl, 4
    mov al, Reg
    out dx, al
    inc dl
    mov al, Val
    out dx, al
  end;
end;

function ResetDSP(Port: Word; var Ver: Word): Boolean;
var
  Hi, Lo: Byte;
  Ok: Boolean;
begin
  Ok := False;
  asm
    mov dx, Port
    add dl, 6
    mov al, 1
    out dx, al
    sub al, al
@1: dec al
    jne @1
    out dx, al
    xor cx, cx
    add dl, 8
@2: in al, dx
    test al, 80h
    jne @3
    loop @2
    jmp @9
@3: sub dl, 4
    in al, dx
    cmp al, 0AAh
    jne @9
    mov Ok, 1
    mov dx, Port
    add dl, 0Ch
@4: in al, dx
    test al, 80h
    jne @4
    mov al, 0E1h
    out dx, al
    mov dx, Port
    add dl, 0Eh
@5: in al, dx
    test al, 80h
    je @5
    sub dl, 4
    in al, dx
    mov Hi, al
    mov dx, Port
    add dl, 0Eh
@6: in al, dx
    test al, 80h
    je @6
    sub dl, 4
    in al, dx
    mov Lo, al
@9:
  end;
  Ver := Hi shl 8 + Lo;
  ResetDSP := Ok;
end;

procedure ReadAll;
var
  V: Byte;
begin
  V := ReadMixer(Port, $22);
  MasterL := V shr 4;
  MasterR := V mod 16;
  V := ReadMixer(Port, 4);
  WaveL := V shr 4;
  WaveR := V mod 16;
  V := ReadMixer(Port, $26);
  MidiL := V shr 4;
  MidiR := V mod 16;
  V := ReadMixer(Port, $28);
  CdL := V shr 4;
  CdR := V mod 16;
end;

procedure SetCdL(V: Byte);
var
  T: Byte;
begin
  V := V and $F;
  T := ReadMixer(Port, $28);
  T := (T and $F) or (V shl 4);
  WriteMixer(Port, $28, T);
end;

procedure SetCdR(V: Byte);
var
  T: Byte;
begin
  V := V and $F;
  T := ReadMixer(Port, $28);
  T := (T and $F0) or V;
  WriteMixer(Port, $28, T);
end;

procedure SetMasterL(V: Byte);
var
  T: Byte;
begin
  V := V and $F;
  T := ReadMixer(Port, $22);
  T := (T and $F) or (V shl 4);
  WriteMixer(Port, $22, T);
end;

procedure SetMasterR(V: Byte);
var
  T: Byte;
begin
  V := V and $F;
  T := ReadMixer(Port, $22);
  T := (T and $F0) or V;
  WriteMixer(Port, $22, T);
end;

procedure SetWaveL(V: Byte);
var
  T: Byte;
begin
  V := V and $F;
  T := ReadMixer(Port, 4);
  T := (T and $F) or (V shl 4);
  WriteMixer(Port, 4, T);
end;

procedure SetWaveR(V: Byte);
var
  T: Byte;
begin
  V := V and $F;
  T := ReadMixer(Port, 4);
  T := (T and $F0) or V;
  WriteMixer(Port, 4, T);
end;

procedure SetMidiL(V: Byte);
var
  T: Byte;
begin
  V := V and $F;
  T := ReadMixer(Port, $26);
  T := (T and $F) or (V shl 4);
  WriteMixer(Port, $26, T);
end;

procedure SetMidiR(V: Byte);
var
  T: Byte;
begin
  V := V and $F;
  T := ReadMixer(Port, $26);
  T := (T and $F0) or V;
  WriteMixer(Port, $26, T);
end;

function LevelToVal(L: Byte): Byte;
begin
  LevelToVal := 0;
  case L of
    7: LevelToVal := 15;
    6: LevelToVal := 14;
    5: LevelToVal := 13;
    4: LevelToVal := 12;
    3: LevelToVal := 10;
    2: LevelToVal := 8;
    1: LevelToVal := 6;
  end;
end;

function ValToLevel(V: Byte): Byte;
begin
  ValToLevel := 0;
  case V of
    15: ValToLevel := 7;
    14: ValToLevel := 6;
    13: ValToLevel := 5;
    11, 12: ValToLevel := 4;
    9, 10: ValToLevel := 3;
    7, 8: ValToLevel := 2;
    1..6: ValToLevel := 1;
  end;
end;

procedure DrawSliders;
var
  I: Byte;
begin
  MouseHide;
  ReadAll;
  for I := 1 to 8 do
  begin
    WriteXY(4, I, #$B1#$B1);
    WriteXY(8, I, #$B1#$B1);
    WriteXY(14, I, #$B1#$B1);
    WriteXY(18, I, #$B1#$B1);
    WriteXY(24, I, #$B1#$B1);
    WriteXY(28, I, #$B1#$B1);
    WriteXY(34, I, #$B1#$B1);
    WriteXY(38, I, #$B1#$B1);
  end;
  WriteXYF(4, 8 - ValToLevel(MasterL), 14, #$DB#$DB#$C4);
  WriteXYF(7, 8 - ValToLevel(MasterR), 14, #$C4#$DB#$DB);
  WriteXYF(14, 8 - ValToLevel(WaveL), 14, #$DB#$DB#$C4);
  WriteXYF(17, 8 - ValToLevel(WaveR), 14, #$C4#$DB#$DB);
  WriteXYF(24, 8 - ValToLevel(MidiL), 14, #$DB#$DB#$C4);
  WriteXYF(27, 8 - ValToLevel(MidiR), 14, #$C4#$DB#$DB);
  WriteXYF(34, 8 - ValToLevel(CdL), 14, #$DB#$DB#$C4);
  WriteXYF(37, 8 - ValToLevel(CdR), 14, #$C4#$DB#$DB);
  MouseShow;
end;

procedure IncVal(var V: Byte);
begin
  case V of
    14: V := 15;
    13: V := 14;
    11, 12: V := 13;
    9, 10: V := 12;
    7, 8: V := 10;
    1..6: V := 7;
    0: V := 6;
  end;
end;

procedure DecVal(var V: Byte);
begin
  case V of
    15: V := 14;
    14: V := 13;
    13: V := 12;
    11, 12: V := 10;
    9, 10: V := 8;
    7, 8: V := 6;
    1..6: V := 0;
  end;
end;

procedure SelectGroup(N: Byte);
begin
  MouseHide;
  WriteXY(Group * 10 + 3, 9, '        ');
  WriteXY(Group * 10 + 3, 8, ' ');
  WriteXY(Group * 10 + 10, 8, ' ');
  Group := N;
  WriteXYF(Group * 10 + 3, 9, 11, #$DF#$DF#$DF#$DF#$DF#$DF#$DF#$DF);
  WriteXYF(Group * 10 + 3, 8, 11, #$DB);
  WriteXYF(Group * 10 + 10, 8, 11, #$DB);
  MouseShow;
end;

procedure HandleMaster(Key: Word);
begin
  if ((Key = $430) or (Key = $438)) and (Group <> 0) then Exit;
  if (OldY <> CurY) and (MouseButton = 1) and (CurY in [Y..Y + 7]) and (Byte(MouseX) in [X + 4, X + 5]) then
  begin
    SelectGroup(0);
    MouseHide;
    WriteXY(4, 8 - ValToLevel(MasterL), #$B1#$B1' ');
    MouseShow;
    MasterL := LevelToVal((7 - CurY) + Y);
    SetMasterL(MasterL);
    MouseHide;
    WriteXYF(4, 8 - ValToLevel(MasterL), 14, #$DB#$DB#$C4);
    MouseShow;
    OldY := CurY;
  end;
  if (OldY <> CurY) and (MouseButton = 1) and (CurY in [Y..Y + 7]) and (Byte(MouseX) in [X + 8, X + 9]) then
  begin
    SelectGroup(0);
    MouseHide;
    WriteXY(7, 8 - ValToLevel(MasterR), ' '#$B1#$B1);
    MasterR := LevelToVal((7 - CurY) + Y);
    SetMasterR(MasterR);
    WriteXYF(7, 8 - ValToLevel(MasterR), 14, #$C4#$DB#$DB);
    MouseShow;
    OldY := CurY;
  end;
  if (OldY <> CurY) and (MouseButton = 1) and (CurY in [Y..Y + 7]) and (Byte(MouseX) in [X + 6, X + 7]) then
  begin
    SelectGroup(0);
    MouseHide;
    WriteXY(4, 8 - ValToLevel(MasterL), #$B1#$B1' ');
    WriteXY(7, 8 - ValToLevel(MasterR), ' '#$B1#$B1);
    MasterL := LevelToVal((7 - CurY) + Y);
    SetMasterL(MasterL);
    MasterR := MasterL;
    SetMasterR(MasterR);
    WriteXYF(7, 8 - ValToLevel(MasterR), 14, #$C4#$DB#$DB);
    WriteXYF(4, 8 - ValToLevel(MasterL), 14, #$DB#$DB#$C4);
    MouseShow;
    OldY := CurY;
  end;
  if (Key = $430) or (Key = $438) then
  begin
    MouseHide;
    WriteXY(4, 8 - ValToLevel(MasterL), #$B1#$B1' ');
    WriteXY(7, 8 - ValToLevel(MasterR), ' '#$B1#$B1);
    if Key = $430 then
    begin
      IncVal(MasterL);
      IncVal(MasterR);
    end
    else
    begin
      DecVal(MasterL);
      DecVal(MasterR);
    end;
    SetMasterL(MasterL);
    SetMasterR(MasterR);
    WriteXYF(7, 8 - ValToLevel(MasterR), 14, #$C4#$DB#$DB);
    WriteXYF(4, 8 - ValToLevel(MasterL), 14, #$DB#$DB#$C4);
    MouseShow;
  end;
end;

procedure HandleWave(Key: Word);
begin
  if ((Key = $430) or (Key = $438)) and (Group <> 1) then Exit;
  if (OldY <> CurY) and (MouseButton = 1) and (CurY in [Y..Y + 7]) and (Byte(MouseX) in [X + 14, X + 15]) then
  begin
    SelectGroup(1);
    MouseHide;
    WriteXY(14, 8 - ValToLevel(WaveL), #$B1#$B1' ');
    MouseShow;
    WaveL := LevelToVal((7 - CurY) + Y);
    SetWaveL(WaveL);
    MouseHide;
    WriteXYF(14, 8 - ValToLevel(WaveL), 14, #$DB#$DB#$C4);
    MouseShow;
    OldY := CurY;
  end;
  if (OldY <> CurY) and (MouseButton = 1) and (CurY in [Y..Y + 7]) and (Byte(MouseX) in [X + 18, X + 19]) then
  begin
    SelectGroup(1);
    MouseHide;
    WriteXY(17, 8 - ValToLevel(WaveR), ' '#$B1#$B1);
    MouseShow;
    WaveR := LevelToVal((7 - CurY) + Y);
    SetWaveR(WaveR);
    MouseHide;
    WriteXYF(17, 8 - ValToLevel(WaveR), 14, #$C4#$DB#$DB);
    MouseShow;
    OldY := CurY;
  end;
  if (OldY <> CurY) and (MouseButton = 1) and (CurY in [Y..Y + 7]) and (Byte(MouseX) in [X + 16, X + 17]) then
  begin
    SelectGroup(1);
    MouseHide;
    WriteXY(14, 8 - ValToLevel(WaveL), #$B1#$B1' ');
    WriteXY(17, 8 - ValToLevel(WaveR), ' '#$B1#$B1);
    MouseShow;
    WaveL := LevelToVal((7 - CurY) + Y);
    SetWaveL(WaveL);
    WaveR := WaveL;
    SetWaveR(WaveR);
    MouseHide;
    WriteXYF(17, 8 - ValToLevel(WaveR), 14, #$C4#$DB#$DB);
    WriteXYF(14, 8 - ValToLevel(WaveL), 14, #$DB#$DB#$C4);
    MouseShow;
    OldY := CurY;
  end;
  if (Key = $430) or (Key = $438) then
  begin
    MouseHide;
    WriteXY(14, 8 - ValToLevel(WaveL), #$B1#$B1' ');
    WriteXY(17, 8 - ValToLevel(WaveR), ' '#$B1#$B1);
    if Key = $430 then
    begin
      IncVal(WaveL);
      IncVal(WaveR);
    end
    else
    begin
      DecVal(WaveL);
      DecVal(WaveR);
    end;
    SetWaveL(WaveL);
    SetWaveR(WaveR);
    WriteXYF(17, 8 - ValToLevel(WaveR), 14, #$C4#$DB#$DB);
    WriteXYF(14, 8 - ValToLevel(WaveL), 14, #$DB#$DB#$C4);
    MouseShow;
  end;
end;

procedure HandleMidi(Key: Word);
begin
  if ((Key = $430) or (Key = $438)) and (Group <> 2) then Exit;
  if (OldY <> CurY) and (MouseButton = 1) and (CurY in [Y..Y + 7]) and (Byte(MouseX) in [X + 24, X + 25]) then
  begin
    SelectGroup(2);
    MouseHide;
    WriteXY(24, 8 - ValToLevel(MidiL), #$B1#$B1' ');
    MouseShow;
    MidiL := LevelToVal((7 - CurY) + Y);
    SetMidiL(MidiL);
    MouseHide;
    WriteXYF(24, 8 - ValToLevel(MidiL), 14, #$DB#$DB#$C4);
    MouseShow;
    OldY := CurY;
  end;
  if (OldY <> CurY) and (MouseButton = 1) and (CurY in [Y..Y + 7]) and (Byte(MouseX) in [X + 28, X + 29]) then
  begin
    SelectGroup(2);
    MouseHide;
    WriteXY(27, 8 - ValToLevel(MidiR), ' '#$B1#$B1);
    MouseShow;
    MidiR := LevelToVal((7 - CurY) + Y);
    SetMidiR(MidiR);
    MouseHide;
    WriteXYF(27, 8 - ValToLevel(MidiR), 14, #$C4#$DB#$DB);
    MouseShow;
    OldY := CurY;
  end;
  if (OldY <> CurY) and (MouseButton = 1) and (CurY in [Y..Y + 7]) and (Byte(MouseX) in [X + 26, X + 27]) then
  begin
    SelectGroup(2);
    MouseHide;
    WriteXY(24, 8 - ValToLevel(MidiL), #$B1#$B1' ');
    WriteXY(27, 8 - ValToLevel(MidiR), ' '#$B1#$B1);
    MouseShow;
    MidiL := LevelToVal((7 - CurY) + Y);
    SetMidiL(MidiL);
    MidiR := MidiL;
    SetMidiR(MidiR);
    MouseHide;
    WriteXYF(27, 8 - ValToLevel(MidiR), 14, #$C4#$DB#$DB);
    WriteXYF(24, 8 - ValToLevel(MidiL), 14, #$DB#$DB#$C4);
    MouseShow;
    OldY := CurY;
  end;
  if (Key = $430) or (Key = $438) then
  begin
    MouseHide;
    WriteXY(24, 8 - ValToLevel(MidiL), #$B1#$B1' ');
    WriteXY(27, 8 - ValToLevel(MidiR), ' '#$B1#$B1);
    if Key = $430 then
    begin
      IncVal(MidiL);
      IncVal(MidiR);
    end
    else
    begin
      DecVal(MidiL);
      DecVal(MidiR);
    end;
    SetMidiL(MidiL);
    SetMidiR(MidiR);
    WriteXYF(27, 8 - ValToLevel(MidiR), 14, #$C4#$DB#$DB);
    WriteXYF(24, 8 - ValToLevel(MidiL), 14, #$DB#$DB#$C4);
    MouseShow;
  end;
end;

procedure HandleCD(Key: Word);
begin
  if ((Key = $430) or (Key = $438)) and (Group <> 3) then Exit;
  if (OldY <> CurY) and (MouseButton = 1) and (CurY in [Y..Y + 7]) and (Byte(MouseX) in [X + 34, X + 35]) then
  begin
    SelectGroup(3);
    MouseHide;
    WriteXY(34, 8 - ValToLevel(CdL), #$B1#$B1' ');
    MouseShow;
    CdL := LevelToVal((7 - CurY) + Y);
    SetCdL(CdL);
    MouseHide;
    WriteXYF(34, 8 - ValToLevel(CdL), 14, #$DB#$DB#$C4);
    MouseShow;
    OldY := CurY;
  end;
  if (OldY <> CurY) and (MouseButton = 1) and (CurY in [Y..Y + 7]) and (Byte(MouseX) in [X + 38, X + 39]) then
  begin
    SelectGroup(3);
    MouseHide;
    WriteXY(37, 8 - ValToLevel(CdR), ' '#$B1#$B1);
    MouseShow;
    CdR := LevelToVal((7 - CurY) + Y);
    SetCdR(CdR);
    MouseHide;
    WriteXYF(37, 8 - ValToLevel(CdR), 14, #$C4#$DB#$DB);
    MouseShow;
    OldY := CurY;
  end;
  if (OldY <> CurY) and (MouseButton = 1) and (CurY in [Y..Y + 7]) and (Byte(MouseX) in [X + 36, X + 37]) then
  begin
    SelectGroup(3);
    MouseHide;
    WriteXY(34, 8 - ValToLevel(CdL), #$B1#$B1' ');
    WriteXY(37, 8 - ValToLevel(CdR), ' '#$B1#$B1);
    MouseShow;
    CdL := LevelToVal((7 - CurY) + Y);
    SetCdL(CdL);
    CdR := CdL;
    SetCdR(CdR);
    MouseHide;
    WriteXYF(37, 8 - ValToLevel(CdR), 14, #$C4#$DB#$DB);
    WriteXYF(34, 8 - ValToLevel(CdL), 14, #$DB#$DB#$C4);
    MouseShow;
    OldY := CurY;
  end;
  if (Key = $430) or (Key = $438) then
  begin
    MouseHide;
    WriteXY(34, 8 - ValToLevel(CdL), #$B1#$B1' ');
    WriteXY(37, 8 - ValToLevel(CdR), ' '#$B1#$B1);
    if Key = $430 then
    begin
      IncVal(CdL);
      IncVal(CdR);
    end
    else
    begin
      DecVal(CdL);
      DecVal(CdR);
    end;
    SetCdL(CdL);
    SetCdR(CdR);
    WriteXYF(37, 8 - ValToLevel(CdR), 14, #$C4#$DB#$DB);
    WriteXYF(34, 8 - ValToLevel(CdL), 14, #$DB#$DB#$C4);
    MouseShow;
  end;
end;

begin
  Port := $220;
  S := GetEnv('BLASTER');
  S := StripSpaces(S);
  S := UpperStr(S);
  P := Pos('A', S);
  if (S = '') or (P = 0) or (Length(Copy(S, P + 1, 3)) <> 3) then
  begin
    ErrorBox('Umgebungsvariable Blaster nicht gefunden oder falsch!',
      'Autoexec.bat mindestens z.B.: set BLASTER=A220');
    Exit;
  end
  else
  begin
    S := Copy(S, P + 1, 3);
    Port := 0;
    for P := 1 to 3 do
    begin
      Port := Port shl 4;
      Port := (Port and $FF0) or HexDigit(S[P]);
    end;
  end;
  ArrowCursor;
  if not ResetDSP(Port, Ver) then
  begin
    ErrorBox('Kein Zugriff auf die Soundkarte mîglich.', 'Evt. wird die Soundkarte schon benutzt.');
    Exit;
  end;
  NormalCursor;
  Str(Hi(Ver), S);
  Str(Lo(Ver), S2);
  if Length(S2) < 2 then S2 := '0' + S2;
  S := S + '.' + S2;
  if (Hi(Ver) < 3) or (Hi(Ver) > 8) then
  begin
    ErrorBox('Der Signalprozessor (DSP) wird nicht unterstÅtzt!', 'UnterstÅtzt werden die Versionen 3 und 4. Ihre: ' + S);
    Exit;
  end;
  OpenDialog;
  X := 18;
  Y := 10;
  Frame(X, Y - 4, 42, 12, 11, 3, 0, 1);
  WriteCenterXYF(1, 1, 42, 11, 'LautstÑrke');
  Str(Hi(Ver), S);
  Str(Lo(Ver), S2);
  if Length(S2) < 2 then S2 := '0' + S2;
  S := S + '.' + S2;
  WriteXY(31, 1, '(DSP: ' + S + ')');
  S := HexWord(Port);
  if S[1] = '0' then Delete(S, 1, 1);
  WriteXY(2, 1, '(ADR: ' + S + 'h)');
  if ThinButtons then WriteCenterXY(1, 2, 42, FillStr(#$DF, 10))
  else WriteCenterXY(1, 2, 42, FillStr(#$DD, 10));
  WriteXY(4, 2, 'Master     Wave      Midi       CD');
  WriteXY(4, 3, 'L    R    L    R    L    R    L    R');
  Window(X + 1, Y, 80, 25);
  MouseShow;
  DrawSliders;
  WriteXYF(3, 9, 11, #$DF#$DF#$DF#$DF#$DF#$DF#$DF#$DF);
  WriteXYF(3, 8, 11, #$DB);
  WriteXYF(10, 8, 11, #$DB);
  MouseShow;
  OldY := 0;
  OldX := 0;
  Group := 0;
  WaitRelease;
  repeat
    GetKey(Key);
    if (Key = $435) or (Key = 9) then
    begin
      MouseHide;
      WriteXY(Group * 10 + 3, 9, '        ');
      WriteXY(Group * 10 + 3, 8, ' ');
      WriteXY(Group * 10 + 10, 8, ' ');
      Inc(Group);
      if Group > 3 then Group := 0;
      WriteXYF(Group * 10 + 3, 9, 11, #$DF#$DF#$DF#$DF#$DF#$DF#$DF#$DF);
      WriteXYF(Group * 10 + 3, 8, 11, #$DB);
      WriteXYF(Group * 10 + 10, 8, 11, #$DB);
      MouseShow;
    end;
    if (Key = $433) or (Key = $3F7) then
    begin
      MouseHide;
      WriteXY(Group * 10 + 3, 9, '        ');
      WriteXY(Group * 10 + 3, 8, ' ');
      WriteXY(Group * 10 + 10, 8, ' ');
      Dec(Group);
      if Group < 0 then Group := 3;
      WriteXYF(Group * 10 + 3, 9, 11, #$DF#$DF#$DF#$DF#$DF#$DF#$DF#$DF);
      WriteXYF(Group * 10 + 3, 8, 11, #$DB);
      WriteXYF(Group * 10 + 10, 8, 11, #$DB);
      MouseShow;
    end;
    CurY := MouseY;
    HandleMaster(Key);
    HandleWave(Key);
    HandleMidi(Key);
    HandleCD(Key);
    if OldX <> MouseX then
    begin
      OldY := 0;
      OldX := MouseX;
    end;
  until IsCancel(Key) or MouseOutside(X, X + 43, Y - 4, Y - 4 + 13);
  CloseDialog;
end;

end.

{$O+,F+,G+,S-,I-,X+,V-}
unit DirCmp;

interface

uses DXGlob;

procedure CompareDirs(P1, P2: PPanel);

implementation

uses Crt, Buttons, Mouse, Screen, Windows, ScrSave, Dialogs, Status, Help, U0365;

procedure CompareDirs(P1, P2: PPanel);
var
  I, J, N1, N2: Integer;
  Same: Boolean;
  Ok, Cancel: Boolean;
  B: TButton2;
  Key: Word;
  WithDirs: Boolean;
  Dot1, Dot2: Boolean;
begin
  OpenDialog;
  Dot1 := False;
  Dot2 := False;
  Frame(16, 7, 47, 9, 15, 5, 0, 1);
  WriteCenterXY(1, 1, 47, 'Verzeichnisse vergleichen:');
  if not ThinButtons then
    WriteCenterXY(1, 2, 47, 'нннннннннннннннннннннннннн');
  WriteXY(6, 3, '[ ] Mit Verzeichnisnamen');
  WriteXYF(10, 3, 14, 'M');
  WriteXY(6, 4, '( ) Gleiche Dateien markieren');
  WriteXYF(10, 4, 14, 'G');
  WriteXY(6, 5, '( ) Unterschiedliche Dateien markieren');
  WriteXYF(10, 5, 14, 'U');
  if MarkSame then WriteXY(7, 4, 'X') else WriteXY(7, 5, 'X');
  if CmpDirNames then WriteXY(7, 3, 'X');
  InitButton2(True, 3, 7, 25, 7, 14, 0, 15, 5, '   Vergleichen   ', '     Abbruch     ', B);
  MouseShow;
  repeat
    HandleButton2(Ok, Cancel, Key, B);
    if IsCancel(Key) or MouseOutside(16, 64, 7, 17) then Cancel := True;
    if Key = $423 then ShowHelp(26);
    if LoCaseW(Key) = 'v' then Ok := True;
    if LoCaseW(Key) = 'a' then Cancel := True;
    if (LoCaseW(Key) = 'm') or (Key = $41A) or (Key = 32) or MouseOn(10, 22, 45) then
    begin
      CmpDirNames := not CmpDirNames;
      MouseHide;
      if CmpDirNames then WriteXY(7, 3, 'X') else WriteXY(7, 3, ' ');
      MouseShow;
      WaitRelease;
    end;
    if (LoCaseW(Key) = 'g') or (Key = $40A) or (Key = $430) or MouseOn(11, 22, 50) then
    begin
      MarkSame := True;
      MouseHide;
      WriteXY(7, 4, 'X');
      WriteXY(7, 5, ' ');
      MouseShow;
      WaitRelease;
    end;
    if (LoCaseW(Key) = 'u') or (Key = $3FE) or (Key = $438) or MouseOn(12, 22, 59) then
    begin
      MarkSame := False;
      MouseHide;
      WriteXY(7, 4, ' ');
      WriteXY(7, 5, 'X');
      MouseShow;
      WaitRelease;
    end;
  until Ok or Cancel;
  CloseDialog;
  if Cancel then Exit;
  WithDirs := CmpDirNames;
  Same := True;
  ArrowCursor;
  P1^.W1252 := 0;
  P2^.W1252 := 0;
  if WithDirs then
  begin
    if P1^.W1007 <> P2^.W1007 then Same := False;
    for I := 1 to P1^.W1007 do
      if P1^.Data[I]^.Name[1] <> '.' then
      begin
        P1^.Data[I]^.Marked := True;
        Inc(P1^.W1252);
      end
      else
        Dot1 := True;
    for I := 1 to P2^.W1007 do
      if P2^.Data[I]^.Name[1] <> '.' then
      begin
        P2^.Data[I]^.Marked := True;
        Inc(P2^.W1252);
      end
      else
        Dot2 := True;
  end
  else
  begin
    if P1^.W1007 - P1^.W1250 <> P2^.W1007 - P2^.W1250 then Same := False;
    for I := 1 to P1^.W1007 do
      if P1^.Data[I]^.Attr and $10 = 0 then
      begin
        P1^.Data[I]^.Marked := True;
        Inc(P1^.W1252);
      end
      else
        P1^.Data[I]^.Marked := False;
    for I := 1 to P2^.W1007 do
      if P2^.Data[I]^.Attr and $10 = 0 then
      begin
        P2^.Data[I]^.Marked := True;
        Inc(P2^.W1252);
      end
      else
        P2^.Data[I]^.Marked := False;
  end;
  N1 := 0;
  N2 := 0;
  if P1^.W1007 <= P2^.W1007 then
  begin
    for I := 1 to P1^.W1007 do
      if P1^.Data[I]^.Marked then
      begin
        Inc(N1);
        for J := 1 to P2^.W1007 do
          if P2^.Data[J]^.Marked then
          begin
            Ok := ((P1^.Data[I]^.Attr and $10 = 0) and (P2^.Data[J]^.Attr and $10 = 0) and
              (P1^.Data[I]^.Name = P2^.Data[J]^.Name) and (P1^.Data[I]^.Size = P2^.Data[J]^.Size) and
              (P1^.Data[I]^.Time = P2^.Data[J]^.Time)) or
              ((P1^.Data[I]^.Attr and $10 <> 0) and (P2^.Data[J]^.Attr and $10 <> 0) and
              (P1^.Data[I]^.Name = P2^.Data[J]^.Name));
            if Ok then
            begin
              if P1^.Data[I]^.Marked then Dec(P1^.W1252);
              if P2^.Data[J]^.Marked then Dec(P2^.W1252);
              P1^.Data[I]^.Marked := False;
              P2^.Data[J]^.Marked := False;
              Inc(N2);
            end;
          end;
      end;
  end
  else
  begin
    for I := 1 to P2^.W1007 do
      if P2^.Data[I]^.Marked then
      begin
        Inc(N1);
        for J := 1 to P1^.W1007 do
          if P1^.Data[J]^.Marked then
          begin
            Ok := ((P1^.Data[J]^.Attr and $10 = 0) and (P2^.Data[I]^.Attr and $10 = 0) and
              (P1^.Data[J]^.Name = P2^.Data[I]^.Name) and (P1^.Data[J]^.Size = P2^.Data[I]^.Size) and
              (P1^.Data[J]^.Time = P2^.Data[I]^.Time)) or
              ((P1^.Data[J]^.Attr and $10 <> 0) and (P2^.Data[I]^.Attr and $10 <> 0) and
              (P1^.Data[J]^.Name = P2^.Data[I]^.Name));
            if Ok then
            begin
              if P1^.Data[J]^.Marked then Dec(P1^.W1252);
              if P2^.Data[I]^.Marked then Dec(P2^.W1252);
              P1^.Data[J]^.Marked := False;
              P2^.Data[I]^.Marked := False;
              Inc(N2);
            end;
          end;
      end;
  end;
  if N1 <> N2 then Same := False;
  if MarkSame then
  begin
    J := 1;
    if P1^.Data[1]^.Name[1] = '.' then J := 2;
    P1^.W1252 := 0;
    for I := J to P1^.W1007 do
    begin
      if WithDirs or (P1^.Data[I]^.Attr and $10 = 0) then P1^.Data[I]^.Marked := not P1^.Data[I]^.Marked;
      if P1^.Data[I]^.Marked then Inc(P1^.W1252);
    end;
    J := 1;
    if P2^.Data[1]^.Name[1] = '.' then J := 2;
    P2^.W1252 := 0;
    for I := J to P2^.W1007 do
    begin
      if WithDirs or (P2^.Data[I]^.Attr and $10 = 0) then P2^.Data[I]^.Marked := not P2^.Data[I]^.Marked;
      if P2^.Data[I]^.Marked then Inc(P2^.W1252);
    end;
  end;
  NormalCursor;
  P0365_602(P1^);
  P0365_41FB(P1^);
  P0365_602(P2^);
  P0365_41FB(P2^);
  if Same then ErrorBox('Verzeichnisvergleich:', 'Die Verzeichnisse scheinen gleich zu sein!');
  if (MarkSame and (P1^.W1252 = 0) and (P2^.W1252 = 0)) or
    (not MarkSame and ((WithDirs and (P1^.W1007 - Byte(Dot1) = P1^.W1252) and (P2^.W1007 - Byte(Dot2) = P2^.W1252)) or
    (not WithDirs and (P1^.W1007 - P1^.W1250 = P1^.W1252) and (P2^.W1007 - P2^.W1250 = P2^.W1252)))) then
    ErrorBox('Verzeichnisvergleich:', 'Keine gleichen Dateien gefunden!');
end;

end.

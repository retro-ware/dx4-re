{$O+,F+,G+,S-,I-,X+,V-}
unit RenFile;

interface

uses DXGlob;

type
  PPanel = ^TPanel;

function RenameFiles(P: PPanel): Boolean;

implementation

uses Dos, Crt, Buttons, Mouse, Screen, Windows, Dialogs, U0365, U13A5, LongName;

type
  PFileRec = ^TFileRec;
  TFileRec = record
    Name: string[12];
    Fill: array[13..20] of Byte;
    Attr: Byte;
    Sel: Boolean;
  end;
  TPanelFiles = array[0..$400] of PFileRec;

function AskName(var S: string; N: Integer): Boolean;
var
  B2: TButton2;
  Hit1, Hit2: Boolean;
  Key, Ret: Word;
  X, W, Max: Byte;
  Txt: string;
begin
  OpenDialog;
  X := 34;
  W := 12;
  Max := 12;
  if CfgColors[56] <> 0 then
  begin
    X := 16;
    Max := 200;
    W := 48;
  end;
  Frame(13, 8, 54, 7, 15, 5, 0, 1);
  if N = 0 then
  begin
    Txt := CutStr(S, 30);
    WriteXY(3, 1, 'Umbenennen von ');
    WriteF(14, Txt);
    Write(' nach:');
  end
  else
  begin
    Str(N, S);
    WriteXY(16, 1, 'Umbenennen von ');
    WriteF(4, S);
    Writeln(' Dateien');
    S := '';
  end;
  MouseShow;
  Window(1, 1, 80, 25);
  InitButton2(True, 15, 13, 42, 13, 14, 0, 15, 5, '      Umbenennen      ', '      Abbrechen      ', B2);
  MouseShow;
  Key := $3F9;
  repeat
    if (Key = $3F9) or (Key = $430) or (Key = 9) or (Key = $3F7) or MouseOn(11, X, X + W + 1) then
      Ret := InputLine(X, 11, X - 1, X + W + 2, S, W, Max, #$D8, False)
    else
      Ret := 99;
    HandleButton2(Hit1, Hit2, Key, B2);
    if (Ret = 13) and (MouseButton = 0) then
    begin
      if B2[1].Focused then Hit1 := True
      else if B2[2].Focused then Hit2 := True;
    end;
    if LoCaseW(Key) = 'u' then Hit1 := True
    else if LoCaseW(Key) = 'a' then Hit2 := True
    else if Ret = 0 then Hit2 := True;
    if IsCancel(Key) or MouseOutside(13, 68, 8, 16) then Hit2 := True;
  until Hit1 or Hit2;
  if Hit2 then AskName := False else AskName := True;
  CloseDialog;
end;

function RenameError(Name: string): Boolean;
var
  B2: TButton2;
  Hit1, Hit2: Boolean;
  Key: Word;
begin
  NormalCursor;
  OpenDialog;
  Frame(13, 8, 54, 7, 15, 5, 0, 1);
  WriteCenterXY(1, 1, 54, 'Fehler beim Umbenennen von');
  WriteCenterXYF(1, 3, 54, 14, CutStr(Name, 50));
  MouseShow;
  Window(1, 1, 80, 25);
  InitButton2(True, 15, 13, 42, 13, 14, 0, 15, 5, '        Weiter        ', '      Abbrechen      ', B2);
  MouseShow;
  repeat
    HandleButton2(Hit1, Hit2, Key, B2);
    if LoCaseW(Key) = 'w' then Hit1 := True;
    if LoCaseW(Key) = 'a' then Hit2 := True;
    if IsCancel(Key) or MouseOutside(13, 68, 8, 16) then Hit2 := True;
  until Hit1 or Hit2;
  RenameError := Hit1;
  CloseDialog;
  ArrowCursor;
end;

function AskOverwrite(Name: string): Boolean;
var
  B2: TButton2;
  Hit1, Hit2: Boolean;
  Key: Word;
begin
  OpenDialog;
  Frame(13, 8, 54, 7, 11, 3, 0, 1);
  WriteCenterXY(1, 1, 55, 'Folgende Datei ist schon vorhanden:');
  WriteCenterXYF(1, 3, 55, 14, Name);
  InitButton2(True, 3, 5, 28, 5, 14, 0, 11, 3, ' L'#$94'schen+Umbenennen ', '      Abbrechen      ', B2);
  MouseShow;
  NormalCursor;
  repeat
    HandleButton2(Hit1, Hit2, Key, B2);
    if LoCaseW(Key) = 'l' then Hit1 := True;
    if (LoCaseW(Key) = 'a') or IsCancel(Key) or MouseOutside(13, 68, 8, 16) then Hit2 := True;
  until Hit2 or Hit1;
  CloseDialog;
  AskOverwrite := Hit1;
end;

function RenameFiles(P: PPanel): Boolean;
var
  Old, S2, New, Mask, Unused, Short: string;
  F: File;
  Attr, I, Cur: Word;
begin
  RenameFiles := False;
  if (P^.W1007 = 0) or P^.Flag or
     ((P^.W1252 = 0) and (TPanelFiles(P^.Data)[P^.W1009 + P^.W100B]^.Name[1] = '.')) then
  begin
    ErrorBox('Umbenennen nicht m'#$94'glich!', '');
    Exit;
  end;
  S2 := P0365_91(P^);
  New := S2;
  Old := S2;
  if P^.W1252 > 0 then New := '';
  ArrowCursor;
  if CfgColors[56] <> 0 then
  begin
    GetLongName(Old, Old, False);
    New := Old;
  end;
  NormalCursor;
  if not AskName(New, P^.W1252) then Exit;
  if Pos('\', New) <> 0 then
  begin
    P13A5_3B2(3);
    Exit;
  end;
  RenameFiles := True;
  if P^.W1252 = 0 then
  begin
    New := ApplyMask(New, Old);
    if ((CfgColors[56] = 0) and (LowerStr(New) = LowerStr(Old))) or
       ((CfgColors[56] <> 0) and (Old = New)) or (New = '') or (New = '*.*') or
       (LowerStr(New + '.') = LowerStr(Old)) then Exit;
    if CfgColors[56] = 0 then
    begin
      if FSearch(New, '') <> '' then
      begin
        if not AskOverwrite(New) then Exit;
        Assign(F, New);
        Erase(F);
        if IOResult <> 0 then
        begin
          ErrorBox('Konnte die Datei nicht l'#$94'schen:', New);
          Exit;
        end;
      end;
      Assign(F, Old);
      Rename(F, New);
      if IOResult <> 0 then
      begin
        ErrorBox('Fehler beim Umbenennen von', CutStr(Old, 53));
        Exit;
      end;
    end
    else
    begin
      if LfnFileExists(New) and (LowerStr(New) <> LowerStr(Old)) then
      begin
        if not AskOverwrite(New) then Exit;
        GetShortName(New, Short, False);
        Assign(F, Short);
        Erase(F);
        if IOResult <> 0 then
        begin
          ErrorBox('Konnte die Datei nicht l'#$94'schen:', New);
          Exit;
        end;
      end;
      if not LfnRename(Old, New) then
      begin
        ErrorBox('Fehler beim Umbenennen von', CutStr(Old, 53));
        Exit;
      end;
      GetShortName(New, New, False);
    end;
    Assign(F, New);
    GetFAttr(F, Attr);
    FormatName(New);
    if Attr and $10 <> 0 then New := UpperStr(New)
    else New := LowerStr(New);
    if Attr and 2 <> 0 then
    begin
      New[1] := UpCaseC(New[1]);
      New[9] := #$B0;
    end
    else if Attr and 1 <> 0 then New[9] := #$F8;
    Cur := P^.W100B;
    P0365_141E(P^);
    P0365_C28F(New, 1, P^.Mode * 8, Cur, P^);
    Exit;
  end;
  if not HasWildcards(New) then
  begin
    P13A5_973(27, 'Namen bekommen: ' + CutStr(New, 35));
    Exit;
  end;
  I := 0;
  Mask := New;
  ArrowCursor;
  repeat
    Inc(I);
    if TPanelFiles(P^.Data)[I]^.Sel then
    begin
      S2 := P0365_3C(I, P^);
      if CfgColors[56] <> 0 then GetLongName(S2, S2, False);
      New := ApplyMask(Mask, S2);
      if ((CfgColors[56] = 0) and (LowerStr(S2) <> LowerStr(New))) or
         ((CfgColors[56] <> 0) and (S2 <> New)) then
      begin
        if CfgColors[56] = 0 then
        begin
          Assign(F, S2);
          Rename(F, New);
          if IOResult <> 0 then
            if not RenameError(S2) then Break;
        end
        else if not LfnRename(S2, New) then
          if not RenameError(S2) then Break;
      end;
    end;
  until I = P^.W1007;
  if TPanelFiles(P^.Data)[P^.W1009 + P^.W100B]^.Sel then Old := ApplyMask(Mask, Old);
  if CfgColors[56] <> 0 then GetShortName(Old, Old, False);
  Old := CompressName(Old);
  Assign(F, Old);
  GetFAttr(F, Attr);
  FormatName(Old);
  if Attr and $10 <> 0 then Old := UpperStr(Old);
  if Attr and 2 <> 0 then
  begin
    Old[1] := UpCaseC(Old[1]);
    Old[9] := #$B0;
  end
  else if Attr and 1 <> 0 then Old[9] := #$F8;
  Cur := P^.W100B;
  P0365_141E(P^);
  P0365_C28F(Old, 1, P^.Mode * 8, Cur, P^);
  WaitRelease;
end;

end.

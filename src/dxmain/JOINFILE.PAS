{$O+,F+,G+,S-,I-,X+,V-}
unit JoinFile;

interface

type
  PFileRec = ^TFileRec;
  TFileRec = record
    Name: string[12];
    Fill: array[13..20] of Byte;
    Attr: Byte;
    Sel: Boolean;
  end;
  TFileList = array[0..16000] of PFileRec;

function JoinFiles(Dst: string; var List: TFileList; Count: Integer; Sel: Word; Move: Boolean): Boolean;

implementation

uses Dos, Crt, DXGlob, Buttons, Mouse, Screen, Windows, Status, Dialogs, U13A5, LongName;

function CopyInto(Src, Dst: string; var F: File; Num, Total: Word): Boolean;
var
  Buf: Pointer;
  Unused: Longint;
  F2: File;
  Key, R, W, Attr: Word;
  BufSize: Longint;
  X, Err: Word;
  Done, FSz: Longint;
  S: string[9];
begin
  CopyInto := False;
  Assign(F2, Src);
  GetFAttr(F2, Attr);
  SetFAttr(F2, $20);
  MouseHide;
  Frame(13, 6, 55, 12, 11, 3, 0, 1);
  WriteCenterXY(1, 2, 55, 'Kopieren der Datei');
  WriteCenterXYF(1, 4, 55, 14, Shorten(Src, 53));
  WriteCenterXY(1, 6, 55, ' nach:');
  WriteCenterXYF(1, 8, 55, 14, Shorten(Dst, 53));
  GB44 := 41;
  InputFrame(8, 10, 41, 11, 3);
  MouseShow;
  Reset(F2, 1);
  if IOResult <> 0 then
    P13A5_973(1, Src)
  else
  begin
    BufSize := FileSize(F2);
    FSz := BufSize;
    Str(FSz, S);
    S := ' ' + S;
    MouseHide;
    WriteCenterXY(3, 12, 51, S + ' Bytes');
    GotoXY(8, 6);
    Write(Num);
    if Total <> 0 then Write(' von ', Total);
    MouseShow;
    if BufSize >= $3001 then BufSize := $3001;
    if MaxAvail < BufSize then
    begin
      P13A5_973(2, Src);
      Close(F2);
    end
    else
    begin
      GetMem(Buf, BufSize);
      Done := 0;
      repeat
        BlockRead(F2, Buf^, BufSize, R);
        Err := IOResult;
        GetKey(Key);
        if Key = 27 then Err := 22222;
        MouseMoved := 0;
        if Err = 0 then
        begin
          BlockWrite(F, Buf^, R, W);
          Err := IOResult;
        end;
        Done := Done + W;
        MouseHide;
        if FSz = 0 then ShowBar(14, 100, 8, 10)
        else ShowBar(14, Round(Done / FSz * 100), 8, 10);
        MouseShow;
      until (R = 0) or (W <> R) or (Err <> 0);
      FreeMem(Buf, BufSize);
      if (W <> R) or (Err <> 0) then
      begin
        case Err of
          0: ;
          158: P13A5_973(5, Dst);
          160: P13A5_973(6, Dst);
          159: P13A5_973(7, Dst);
          100: P13A5_973(8, Dst);
          22222: P13A5_973(9, Dst);
        else
          P13A5_973(10, Dst);
        end;
        if (W <> R) and (Err = 0) then P13A5_973(11, Dst);
        Close(F2);
        Err := IOResult;
      end
      else
      begin
        Close(F2);
        if IOResult <> 0 then P13A5_973(12, Src)
        else CopyInto := True;
      end;
    end;
  end;
  SetFAttr(F2, Attr);
  GB90 := 0;
end;

function JoinFiles(Dst: string; var List: TFileList; Count: Integer; Sel: Word; Move: Boolean): Boolean;
var
  B2: TButton2;
  B3: TButton3;
  Over, App, Cancel: Boolean;
  Key: Word;
  I: Word;
  Bin: Boolean;
  F: File;
  F2: File;
  Num, Total: Word;
  Name: string[12];
  Ch: Char;
  Cnt: Word;
  Unused: string;
begin
  OpenDialog;
  JoinFiles := False;
  App := False;
  Bin := True;
  Total := Sel;
  Num := 0;
  Frame(13, 7, 55, 11, 11, 3, 0, 1);
  if Move then WriteCenterXY(1, 1, 55, 'Bewegen mehrerer Dateien in die Datei')
  else WriteCenterXY(1, 1, 55, 'Kopieren mehrerer Dateien in die Datei');
  WriteCenterXYF(1, 3, 55, 14, Shorten(Dst, 52));
  WriteXY(6, 5, 'Evt. markierte Verzeichnisse werden ignoriert!');
  WriteXY(18, 7, '[X] Bin'#$84'res Kopieren');
  WriteXYF(22, 7, 14, 'B');
  if ((CfgColors[56] = 0) and (FSearch(Dst, '') <> '')) or
     ((CfgColors[56] <> 0) and LfnFileExists(Dst)) then
  begin
    InitButton3(True, 3, 9, 23, 9, 39, 9, 14, 0, 11, 3, ' '#$9A'berschreiben ', '  Anf'#$81'gen  ',
      ' Abbrechen ', B3);
    WriteCenterXYF(1, 8, 55, 11, 'Die Zieldatei existiert bereits!');
    MouseShow;
    repeat
      HandleButton3(Over, App, Cancel, Key, B3);
      if LoCaseW(Key) = #$81 then Over := True;
      if LoCaseW(Key) = 'f' then App := True;
      if LoCaseW(Key) = 'a' then Cancel := True;
      if MouseOn(14, 31, 50) or (LoCaseW(Key) = 'b') or (Key = $418) or (Key = 32) then
      begin
        Bin := not Bin;
        MouseHide;
        if Bin then WriteXY(19, 7, 'X') else WriteXY(19, 7, ' ');
        MouseShow;
        WaitRelease;
      end;
      if IsCancel(Key) or MouseOutside(13, 69, 7, 19) then Cancel := True;
    until Over or App or Cancel;
  end
  else
  begin
    InitButton2(True, 3, 9, 29, 9, 14, 0, 11, 3, '       Weiter       ', '       Abbruch       ', B2);
    MouseShow;
    repeat
      HandleButton2(Over, Cancel, Key, B2);
      if LoCaseW(Key) = 'k' then Over := True;
      if LoCaseW(Key) = 'a' then Cancel := True;
      if MouseOn(14, 31, 50) or (LoCaseW(Key) = 'b') or (Key = $418) or (Key = 32) then
      begin
        Bin := not Bin;
        MouseHide;
        if Bin then WriteXY(19, 7, 'X') else WriteXY(19, 7, ' ');
        MouseShow;
        WaitRelease;
      end;
      if IsCancel(Key) or MouseOutside(13, 69, 7, 19) then Cancel := True;
    until Over or Cancel;
  end;
  if Cancel then
  begin
    CloseDialog;
    Exit;
  end;
  if CfgColors[56] <> 0 then
  begin
    if not App and not LfnCreate(Dst) then
    begin
      MsgBox('Fehler beim Erzeugen der Datei', Dst);
      CloseDialog;
      Exit;
    end;
    if not GetShortName(Dst, Dst, True) then
    begin
      MsgBox('Fehler beim Ermitteln des kurzen Namens von', Dst);
      CloseDialog;
      Exit;
    end;
  end;
  Assign(F, Dst);
  FileMode := 2;
  if App then Reset(F, 1) else Rewrite(F, 1);
  if IOResult <> 0 then
  begin
    MsgBox('Fehler beim '#$99'ffnen der Datei', Dst);
    CloseDialog;
    Exit;
  end;
  FileMode := 0;
  if App then
  begin
    Seek(F, FileSize(F));
    if IOResult <> 0 then
    begin
      MsgBox('Fehler beim Positionieren in der Datei', Dst);
      CloseDialog;
      Exit;
    end;
  end;
  I := 0;
  Cancel := False;
  ArrowCursor;
  repeat
    Inc(I);
    if List[I]^.Sel and (List[I]^.Attr and $10 = 0) then
    begin
      Inc(Num);
      Name := List[I]^.Name;
      Name[9] := '.';
      Name := CompressName(Name);
      if not Bin and (FileSize(F) > 0) then
      begin
        Seek(F, FileSize(F) - 1);
        GB90 := 0;
        BlockRead(F, Ch, 1, Cnt);
        if (IOResult = 0) and (Ch = #$1A) then
        begin
          Seek(F, FileSize(F) - 1);
          GB90 := 0;
        end;
        Key := $0A0D;
        BlockWrite(F, Key, 2, Cnt);
      end;
      if CopyInto(Name, Dst, F, Num, Total) then
      begin
        List[I]^.Sel := False;
        Dec(Sel);
        if Move then
        begin
          Assign(F2, Name);
          SetFAttr(F2, $20);
          Erase(F2);
          if IOResult <> 0 then
          begin
            ErrorBox('Fehler beim L'#$94'schen von', Name);
            List[I]^.Sel := True;
            Inc(Sel);
          end;
        end;
      end
      else
        Cancel := True;
    end;
  until (I >= Count) or Cancel;
  Close(F);
  if IOResult <> 0 then MsgBox('Fehler beim Schlie'#$E1'en der Datei', Dst);
  JoinFiles := True;
  CloseDialog;
  NormalCursor;
end;

end.

{$O+,F+,G+,S-,I+,X+,V-}
unit ViewDlgs;
{ Viewer dialogs: double-line dialog frame, 2-line info box, "copy a cut" of a file, hex/ascii search prompt }

interface

procedure DlgFrame(X, Y, W, H, Fg, Bg: Byte);
procedure InfoBox(S1, S2: string);
procedure CutFile(Title: string; var Name: string; var F: file; var AStart, AStop: Longint);
function SearchDlg(var Text: string; var IgnoreCase: Boolean): Boolean;

implementation

uses Dos, Crt, DXGlob, Buttons, Mouse, Screen, Windows, Dialogs, Status, U1D10, U13B0, U13AD;

type
  Str79 = string[79];

function AskOverwrite(S1, S2: Str79; var Append: Boolean): Boolean;
var
  B: TButton3;
  Overwrite, Cancel: Boolean;
  Key: Word;
begin
  OpenDialog;
  AskOverwrite := False;
  Append := False;
  DlgFrame(13, 8, 55, 9, 15, 5);
  WriteCenterXYF(1, 1, 55, 0, S1);
  WriteCenterXYF(1, 3, 55, 14, S2);
  WriteXYF(2, 5, 4, 'Original- und Cut-Datei d'#$81'rfen nicht den selben Namen');
  WriteXYF(2, 6, 4, 'haben! Andernfalls werden beide Dateien zerst'#$94'rt!');
  InitButton3(True, 3, 7, 22, 7, 39, 7, 14, 0, 15, 5, #$9A'berschreiben', ' Anh'#$84'ngen ', ' Abbrechen ', B);
  MouseShow;
  repeat
    HandleButton3(Overwrite, Append, Cancel, Key, B);
    if IsCancel(Key) then Cancel := True;
  until Overwrite or Append or Cancel;
  CloseDialog;
  if Overwrite then AskOverwrite := True;
  if Append then AskOverwrite := True;
end;

procedure DlgFrame(X, Y, W, H, Fg, Bg: Byte);
begin
  MouseHide;
  SetColor(Fg, Bg);
  Window(1, 1, 80, 25);
  DoubleBox(X, Y, W, H);
  Window(X + 1, Y + 1, X + W, Y + H);
  ClrScr;
  MouseShow;
end;

procedure InfoBox(S1, S2: string);
var
  Dummy: Word;
  W: TWinState;
begin
  SaveWin(W);
  DlgFrame(13, 8, 54, 5, 14, 4);
  WriteCenterXY(1, 2, 54, S1);
  WriteCenterXY(1, 4, 54, S2);
  WaitInput;
  RestoreWin(W);
end;

procedure CutFile(Title: string; var Name: string; var F: file; var AStart, AStop: Longint);
var
  Out: file;
  FSize, SavePos: Longint;
  Start, Stop: Longint;
  Count: Longint;
  Buf: Pointer;
  NRead, NWritten: Word;
  Key: Word;
  I: Word;
  Code: Integer;
  Pct: Word;
  B: T13B0Btn2;
  HexStart, HexStop: string[8];
  DecStart, DecStop: string[9];
  Attr: Byte;
  Hit1, Cancel, Append: Boolean;
  CountStr: string[80];
label
  Done;

procedure ShowCount;
begin
  Count := Stop - Start + 1;
  Str(Count, CountStr);
  WriteCenterXYFB(9, 16, 64, 0, 3, 'Gr'#$94#$e1'e: ' + CountStr + ' Bytes');
end;

procedure ShowDecStart;
begin
  Str(Start, DecStart);
  WriteXY(53, 8, Spaces(11));
  WriteXY(54, 8, DecStart);
  ShowCount;
end;

procedure ShowDecStop;
begin
  Str(Stop, DecStop);
  WriteXY(53, 10, Spaces(11));
  WriteXY(54, 10, DecStop);
  ShowCount;
end;

procedure ShowHexStart;
begin
  HexStart := HexLong(Start);
  Delete(HexStart, 1, 1);
  WriteXY(29, 8, ' ' + HexStart + ' ');
  ShowCount;
end;

procedure ShowHexStop;
begin
  HexStop := HexLong(Stop);
  Delete(HexStop, 1, 1);
  WriteXY(29, 10, ' ' + HexStop + ' ');
  ShowCount;
end;

{$I-}
procedure CloseErase;
begin
  Close(Out);
  Erase(Out);
  if IOResult <> 0 then;
end;
{$I+}

begin
  FSize := FileSize(F);
  OpenDialog;
  Start := AStart;
  Stop := AStop;
  DlgFrame(8, 5, 64, 14, 0, 3);
  Attr := TextAttr;
  WriteCenterXYF(1, 1, 64, 0, 'Kopieren eines Ausschnittes:');
  SetColor(0, 2);
  WriteXYFB(8, 3, 0, 3, 'Anfang(Hex): ');
  WriteXYFB(8, 5, 0, 3, '  Ende(Hex): ');
  WriteXYFB(32, 3, 0, 3, 'Anfang(Dez): ');
  WriteXYFB(32, 5, 0, 3, '  Ende(Dez): ');
  WriteXYFB(8, 7, 0, 3, '  Dateiname: ');
  Write(Spaces(35));
  WriteXY(22, 7, Name);
  WriteXYFB(8, 3, 14, 3, 'A');
  WriteXYFB(34, 3, 14, 3, 'f');
  WriteXYFB(10, 5, 14, 3, 'E');
  WriteXYFB(35, 5, 14, 3, 'n');
  WriteXYFB(10, 7, 14, 3, 'D');
  WriteCenterXYFB(1, 9, 64, 0, 3, 'Markieren des Ausschnittes vorher mit Return');
  Window(1, 1, 80, 25);
  ShowHexStart;
  ShowHexStop;
  ShowDecStart;
  ShowDecStop;
  P13B0_60D(True, 13, 18, 45, 18, 14, 0, 7, 3, '      Kopieren      ', '      Abbrechen      ', B);
  MouseShow;
  Key := 0;
  Append := False;
  repeat
    if Key = $406 then
    begin
      ShowCursor;
      HexOnly := True;
      EditLine(30, 8, HexStart, 7, 7, Attr, 28, 38, False, '', '', False);
      HideCursor;
      HexOnly := False;
      Start := HexVal(HexStart);
      if FSize - 1 < Start then
      begin
        Write(#7);
        Start := FSize - 1;
        ShowHexStart;
      end;
      ShowDecStart;
    end;
    if Key = $3FA then
    begin
      ShowCursor;
      HexOnly := True;
      EditLine(30, 10, HexStop, 7, 7, Attr, 28, 38, False, '', '', False);
      HideCursor;
      HexOnly := False;
      Stop := HexVal(HexStop);
      if FSize - 1 < Stop then
      begin
        Write(#7);
        Stop := FSize - 1;
        ShowHexStop;
      end;
      ShowDecStop;
    end;
    if Key = $409 then
    begin
      ShowCursor;
      DigOnly := True;
      EditLine(54, 8, DecStart, 9, 9, Attr, 52, 64, False, '', '', False);
      HideCursor;
      DigOnly := False;
      Val(DecStart, Start, Code);
      if FSize - 1 < Start then
      begin
        Write(#7);
        Start := FSize - 1;
        ShowDecStart;
      end;
      ShowHexStart;
    end;
    if Key = $419 then
    begin
      ShowCursor;
      DigOnly := True;
      EditLine(54, 10, DecStop, 9, 9, Attr, 52, 64, False, '', '', False);
      HideCursor;
      DigOnly := False;
      Val(DecStop, Stop, Code);
      if FSize - 1 < Stop then
      begin
        Write(#7);
        Stop := FSize - 1;
        ShowDecStop;
      end;
      ShowHexStop;
    end;
    if (Key = $408) or (Key = $430) then
    begin
      ShowCursor;
      EditLine(30, 12, Name, 34, 80, Attr, 28, 64, False, '', '', False);
      HideCursor;
    end;
    P13B0_6C0(Hit1, Cancel, Key, B);
    if MouseButton = 1 then
      case MouseY of
        8:
          begin
            if MouseX in [29..37] then Key := $406;
            if MouseX in [53..63] then Key := $409;
          end;
        10:
          begin
            if MouseX in [29..37] then Key := $3FA;
            if MouseX in [53..63] then Key := $419;
          end;
        12:
          if MouseX in [29..63] then Key := $408;
      end;
    if IsCancel(Key) or MouseOutside(7, 74, 5, 20) then Cancel := True;
    if Hit1 then
    begin
      ArrowCursor;
      if FSearch(Name, '') <> '' then
      begin
        NormalCursor;
        if not AskOverwrite('Datei existiert bereits!', Name, Append) then Hit1 := False;
      end;
      NormalCursor;
    end;
  until Hit1 or Cancel;
  if Cancel then
    CloseDialog
  else
  begin
    MouseHide;
    DlgFrame(13, 8, 55, 5, 0, 5);
    Str(Stop - Start + 1, CountStr);
    WriteCenterXY(1, 1, 55, 'Kopiere ' + CountStr + ' Bytes nach');
    WriteCenterXYF(1, 3, 55, 14, Name);
    GB44 := 53;
    ClearBar(2, 5);
    MouseShow;
    ArrowCursor;
    Assign(Out, Name);
    GetMem(Buf, 24577);
    SavePos := FilePos(F);
    Seek(F, Start);
{$I-}
    if Append then
    begin
      FileMode := 2;
      Reset(Out, 1);
      Seek(Out, FileSize(Out));
      FileMode := 0;
    end
    else
      Rewrite(Out, 1);
    if IOResult <> 0 then
      InfoBox('Fehler beim Erstellen der Datei!', Name)
    else
    begin
      Key := Count div 24577;
      for I := 1 to Key do
      begin
        BlockRead(F, Buf^, 24577, NRead);
        BlockWrite(Out, Buf^, NRead, NWritten);
        if (IOResult <> 0) or (NWritten <> NRead) then
        begin
          InfoBox('Fehler beim Kopieren!', Name);
          CloseErase;
          goto Done;
        end;
        if Count > 0 then
        begin
          MouseHide;
          Pct := Longint(I) * 100 * 24577 div Count;
          ShowBar(14, Pct, 2, 5);
          MouseShow;
        end;
        GetKey(Word(Code));
        if Code = 27 then
        begin
          CloseErase;
          goto Done;
        end;
      end;
      MouseHide;
      ShowBar(14, 100, 2, 5);
      MouseShow;
      BlockRead(F, Buf^, Count mod 24577, NRead);
      BlockWrite(Out, Buf^, NRead, NWritten);
      if (IOResult <> 0) or (NWritten <> NRead) then
      begin
        InfoBox('Fehler beim Kopieren!', Name);
        CloseErase;
        goto Done;
      end
      else
      begin
        NormalCursor;
        ErrorBox('Die Datei wurde erzeugt:', Name);
      end;
      Close(Out);
      if IOResult <> 0 then;
      NormalCursor;
    end;
Done:
    FreeMem(Buf, 24577);
    NormalCursor;
    Seek(F, SavePos);
    InOutRes := 0;
    CloseDialog;
  end;
end;

{$I+}
function SearchDlg(var Text: string; var IgnoreCase: Boolean): Boolean;
const
  Blank = '                                                                ' +
          '                                                                ' +
          '                                                                ' +
          '                                                               ';
var
  Attr: Byte;
  Key: Word;
  HexStr: string;
  S: string;
  I: Integer;
  B: T13B0Btn2;
  Hit1, Cancel: Boolean;
label
  Ascii;
begin
  MouseHide;
  SearchDlg := False;
  DlgFrame(8, 5, 64, 13, 0, 3);
  Attr := TextAttr;
  WriteCenterXYF(1, 1, 64, 0, 'Suche nach:');
  SetColor(0, 2);
  WriteXYFB(4, 3, 0, 3, 'Ascii: ');
  Write(Spaces(50));
  WriteXYFB(4, 5, 0, 3, '  Hex: ');
  Write(Spaces(50));
  WriteXYFB(11, 6, 0, 3, 'F1 = Asciitabelle');
  WriteXYFB(15, 8, 0, 3, '[ ] Ignoriere Gro'#$e1'- Kleinschreibung ');
  WriteXYFB(7, 12, 0, 3, 'Achtung: Steuerzeichen (z.B. CR + LF) werden in der');
  WriteXYFB(16, 13, 0, 3, 'Ascii-Eingabe in Blanks umgewandelt!');
  if not IgnoreCase then WriteXYFB(16, 8, 0, 3, 'X');
  WriteXYFB(4, 3, 14, 3, 'A');
  WriteXYFB(6, 5, 14, 3, 'H');
  WriteXYFB(19, 8, 14, 3, 'I');
  Window(1, 1, 80, 25);
  P13B0_60D(True, 13, 15, 46, 15, 14, 0, 7, 3, '       Suchen       ', '      Abbrechen      ', B);
  MouseShow;
  Key := $406;
  repeat
    if Key = $430 then Key := $40B;
    if Key = $438 then Key := $406;
    if Key = $406 then
    begin
Ascii:
      ShowCursor;
      S := Text;
      for I := 1 to Length(S) do
        case S[I] of
          #10, #13, #8: S[I] := ' ';
        end;
      Key := EditLine(20, 8, S, 48, 80, Attr, 18, 69, False, '', '', False);
      if (Key = 13) or (Key = 9) then Text := S;
      if Key = 9 then Key := $40B;
      HideCursor;
      HexStr := '';
      for I := 1 to Length(Text) do HexStr := HexStr + HexByte(Ord(Text[I])) + ' ';
      GotoXY(20, 10);
      MouseHide;
      Write(Copy(HexStr + Blank, 1, 48));
      MouseShow;
    end;
    if Key = $40B then
    begin
      HexOnly := True;
      S := HexStr;
      ShowCursor;
      Key := EditLine(20, 10, S, 48, 240, Attr, 18, 69, False, '', '', False);
      if (Key = 13) or (Key = 9) or (Key = $3F7) then HexStr := S;
      HexOnly := False;
      HideCursor;
      Text := HexToStr(HexStr);
      S := Text;
      for I := 1 to Length(S) do
        case S[I] of
          #10, #13, #8: S[I] := ' ';
        end;
      GotoXY(20, 8);
      MouseHide;
      Write(Copy(S + Blank, 1, 48));
      HexStr := '';
      for I := 1 to Length(Text) do HexStr := HexStr + HexByte(Ord(Text[I])) + ' ';
      GotoXY(20, 10);
      Write(Copy(HexStr + Blank, 1, 48));
      MouseShow;
      if Key = $3F7 then goto Ascii;
    end;
    if (Key = $3FF) or (Key = 32) or MouseOn(13, 23, 57) then
    begin
      IgnoreCase := not IgnoreCase;
      MouseHide;
      if not IgnoreCase then WriteXYFB(24, 13, 0, 3, 'X') else WriteXYFB(24, 13, 0, 3, ' ');
      MouseShow;
      WaitRelease;
    end;
    if Key = $423 then P13AD_2CA2(0);
    P13B0_6C0(Hit1, Cancel, Key, B);
    if MouseOn(8, 19, 68) then Key := $406;
    if MouseOn(10, 19, 68) then Key := $40B;
    if IsCancel(Key) or MouseOutside(7, 74, 5, 19) then Cancel := True;
  until Hit1 or Cancel;
  if Cancel or (Text = '') then SearchDlg := False else SearchDlg := True;
end;

end.

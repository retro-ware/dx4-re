{$O+,F+,G+,S-,I-}
unit Execute;

interface

function RunProg(Prog, Params: string): Boolean;

implementation

uses Dos, Crt, DXGlob, Mouse, Screen, Windows, ScrSave, Dialogs, U0DA0;

procedure ShowError(Prog: string; Err, Code: Byte); forward;

function RunProg(Prog, Params: string): Boolean;
var
  R: Registers;
  SaveTop: Pointer;
  Err, Code: Word;
  Path, S2: string;
begin
  Path := FSearch(Prog, GetEnv('PATH') + ';' + HomeDir);
  if Path = '' then
  begin
    MsgBox('Programm ' + Prog + ' nicht gefunden!', 'Es mu'#$E1' im Pfad (Path) vorhanden sein!');
    RunProg := False;
  end
  else
  begin
    Prog := Path;
    R.AH := $3E;
    R.BX := 1;
    MsDos(R);
    R.AH := $3E;
    R.BX := 2;
    MsDos(R);
    R.AH := $3D;
    R.AL := 1;
    R.DS := DSeg;
    R.DX := Ofs(NulName);
    MsDos(R);
    R.AH := $3D;
    R.AL := 1;
    R.DS := DSeg;
    R.DX := Ofs(NulName);
    MsDos(R);
    SaveTop := HeapEnd;
    SetMemTop(HeapPtr);
    SwapVectors;
    Exec(Prog, Params);
    Err := DosError;
    Code := DosExitCode;
    SwapVectors;
    SetMemTop(SaveTop);
    R.AH := $3E;
    R.BX := 1;
    MsDos(R);
    R.AH := $3E;
    R.BX := 2;
    MsDos(R);
    R.AH := $3D;
    R.AL := 1;
    R.DS := DSeg;
    R.DX := Ofs(ConName);
    MsDos(R);
    R.AH := $3D;
    R.AL := 1;
    R.DS := DSeg;
    R.DX := Ofs(ConName);
    MsDos(R);
    Str(Err, Path);
    Str(Code, S2);
    InstallHandler;
    MouseShow;
    MouseYRange(0, ScreenRows - 1);
    if Err + Code <> 0 then
      ShowError(Prog, Err, Code);
    RunProg := Err + Code = 0;
  end;
end;

procedure ShowError(Prog: string; Err, Code: Byte);
var
  NoMsg: Boolean;
  D: DirStr;
  N: NameStr;
  E: ExtStr;
  PName: string[12];
  NumS: string[12];
begin
  NoMsg := False;
  NormalCursor;
  FSplit(Prog, D, N, E);
  PName := N + E;
  MouseHide;
  PushScreen(DlgStack);
  Frame(13, 6, 55, 11, 15, 4, 0, 1);
  WriteCenterXYF(1, 1, 55, 14, 'Fehler:');
  SetColor(15, 4);
  WriteCenterXY(1, 11, 54, ' Weiter mit beliebiger Taste ...');
  Str(Err, NumS);
  WriteCenterXY(1, 3, 55, 'DOS meldet Fehler Nr.: ' + NumS);
  Str(Code, NumS);
  WriteCenterXY(1, 5, 55, Shorten(UpperStr(Prog), 30) + ' meldet Fehler Nr.: ' + NumS);
  Window(17, 13, 80, 25);
  if PName = 'arj.exe' then
    case Code of
      1: Write('Warning: file not found.');
      2: Write('Fatal error.');
      3: Write('CRC error (header or file CRC error).');
      4:
        begin
          WriteLn('ARJ-SECURITY error or attempt to update an');
          WriteLn('ARJ-SECURED archive.');
        end;
      5: Write('Disk full or write error.');
      6: Write('Can''t open archive or file.');
      7: Write('Simple user error (bad parameters).');
      8: Write('Not enough memory.');
      9: Write('Not an ARJ archive.');
    else
      NoMsg := True;
    end
  else if PName = 'lha.exe' then
    case Code of
      1:
        begin
          WriteLn('CRC error occured or failed to create files');
          WriteLn('because of disk space, or because of files');
          WriteLn('in existence.');
        end;
      2:
        begin
          WriteLn('Fatal error:');
          WriteLn('Process terminated without transactions.');
        end;
      3: Write('Failed to write temporary files in the archive.');
    else
      NoMsg := True;
    end
  else if PName = 'pkzip.exe' then
    case Code of
      1: Write('Bad file name or file specification.');
      2, 3: Write('Error in .ZIP file.');
      4..11: Write('Insufficient Memory.');
      12:
        begin
          WriteLn('No files were found to add to the .ZIP file, or');
          WriteLn('no files were specified for deletion.');
        end;
      13:
        begin
          WriteLn('File not found.  The specified .ZIP file or');
          WriteLn('list file was not found.');
        end;
      14: Write('Disk full.');
      15: Write('.ZIP file is read-only and can not be modified.');
      16: Write('Bad or illegal parameters specified.');
      17: Write('Too many files.');
      18: Write('Could not open file.');
      255: Write('User pressed control-c or control-break');
    else
      NoMsg := True;
    end
  else if PName = 'pkunzip.exe' then
    case Code of
      1: Write('Warning error (such as failed CRC check).');
      2, 3: Write('Error in .ZIP file.');
      4..8: Write('Insufficient Memory.');
      9: Write('File not found.  No .ZIP files found.');
      10: Write('Bad or illegal parameters specified.');
      11: Write('No files found to extract/view etc.');
      50: Write('Disk Full.');
      51: Write('Unexpected EOF in .ZIP file.');
      255: Write('User pressed control-c or control-break');
    else
      NoMsg := True;
    end
  else if PName = 'zip2exe.exe' then
    case Code of
      1: Write('Error in .ZIP file');
      2: Write('Error in .ZIP file, use PKZIPFIX');
      3, 4: Write('Insufficient memory to process file');
      7: Write('Can''t open Source file');
      8: Write('Error in .ZIP file');
      9:
        begin
          WriteLn('Disk full writing target file');
          WriteLn('during EXE to ZIP process.');
        end;
      11:
        begin
          WriteLn('Disk full writing target file');
          WriteLn('during ZIP to EXE process.');
        end;
      12:
        begin
          WriteLn('.ZIP file being converted contains a file');
          WriteLn('compressed with a method not supported by');
          WriteLn('the version of PKSFX being attached by ZIP2EXE');
        end;
    else
      NoMsg := True;
    end
  else
    NoMsg := True;
  if NoMsg then
    WriteLn('    Keine Klarschrift-Fehlermeldung vorhanden.');
  MouseShow;
  WaitInput;
  CloseDialog;
end;

end.

{$O+,F+,G+,S-,I-,X+,V-}
unit DriveOps;

interface

procedure RenameDrive;
procedure MakeSysDisk;

implementation

uses Dos, Crt, DXGlob, Buttons, Mouse, Screen, Windows, ScrSave, Dialogs, Status, Execute;

procedure RenameDrive;
var
  Drive: Char;
  Dir: string;
begin
  OpenDialog;
  Frame(30, 5, 21, 1, 15, 5, 0, 1);
  Write(' Laufwerk Umbenennen');
  MouseShow;
  GetDir(0, Dir);
  Drive := SelectDrive(32, 8, UpCase(Dir[1]));
  PopScreen(DlgStack);
  ClockOff;
  if Drive <> ' ' then
    RunPacker(GetEnv('COMSPEC'), '/C label ' + Drive + ':', 'Label ' + Drive + ':');
  ClockOn;
end;

procedure MakeSysDisk;
var
  B: TButton2;
  Ok, Cancel: Boolean;
  Key: Word;
begin
  OpenDialog;
  Frame(10, 7, 60, 7, 15, 5, 0, 1);
  WriteCenterXY(1, 1, 60, 'Systemdiskette erstellen');
  WriteXY(1, 3, '   Bitte eine formatierte Diskette in Laufwerk A: einlegen');
  InitButton2(True, 3, 5, 32, 5, 14, 0, 15, 5, '           OK           ', '        Abbruch        ', B);
  MouseShow;
  repeat
    HandleButton2(Ok, Cancel, Key, B);
    if IsCancel(Key) or MouseOutside(10, 71, 7, 15) then Cancel := True;
  until Ok or Cancel;
  PopScreen(DlgStack);
  if Ok then
    RunPacker(GetEnv('COMSPEC'), '/C sys c: a:', 'Systemdiskette erstellen');
  WaitRelease;
end;

end.

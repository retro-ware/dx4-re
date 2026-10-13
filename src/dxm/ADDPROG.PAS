{$O+,F+,G+,S-,I-}
unit AddProg;

interface

function SelectProgram: string;

implementation

uses Crt, Mouse, Screen, Windows, Buttons, Dialogs, Browser;

function SelectProgram: string;
var
  P: ^TBrowser;
  B: TButton3;
  S: string;
  Save: TMouseMap;
begin
  GetMem(P, SizeOf(TBrowser));
  OpenDialog;
  Save := MouseMap;
  InitMouse;
  Frame(17, 3, 44, 20, 11, 6, 0, 1);
  WriteCenterXY(1, 17, 44, 'Angezeigt wird: *.exe;*.bat und *.com');
  Window(1, 1, 80, 25);
  InitButton3(True, 19, 21, 34, 21, 49, 21, 14, 0, 11, 6, ' Einf'#129'gen ', ' Laufwerk ', ' Fertig ', B);
  Frame(19, 5, 40, 13, 11, 1, 0, 0);
  P^.Init(11, 1, 0, 3, 20, 4, 13, '.EXE', '.COM', '.BAT', 6);
  MouseShow;
  S := P^.Execute(@B);
  P^.Done;
  CloseDialog;
  FreeMem(P, SizeOf(TBrowser));
  SelectProgram := S;
  MouseMap := Save;
end;

end.

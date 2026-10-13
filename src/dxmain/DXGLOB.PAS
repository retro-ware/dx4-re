{$F+,G+,S-}
unit DXGlob;
{ PLACEHOLDER: globals whose owning unit/DS position is not yet known }

interface

const
  ScreenRows: Byte = 25;
  SingleFrame: Boolean = False;
  Explode: Boolean = False;
  G36E: Byte = 0;
  BorderColor: Byte = 0;
  MenuRows: Byte = 0;
  ListRows: Byte = 0;
  Mode28: Boolean = False;
  G507: Boolean = False;
  SaverDelay: Word = 300;
  StatX: Byte = 75;
  StatY: Byte = 1;
  StatFg: Byte = 0;
  StatBg: Byte = 3;
  SaverOn: Boolean = False;
  Replay: Boolean = False;
  ThinButtons: Boolean = False;
  ScrollDelay: Word = 20;
  DblClickSelect: Boolean = False;
  ConName: array[0..3] of Char = 'CON'#0;
  NulName: array[0..3] of Char = 'NUL'#0;
  G96: Boolean = False;
  PasswordOn: Boolean = False;
  Password: string[12] = '';
  MouseSaver: Boolean = False;
  SaverExt: Boolean = False;
  SaverStars: Boolean = False;
  SaverDot: Boolean = False;
  FadeOn: Boolean = False;
  SaverProg: string[12] = '';
  PalRegs: array[0..16] of Byte = (0, 1, 2, 3, 4, 5, $14, 7, $38, $39, $3A, $3B, $3C, $3D, $3E, $3F, 0);
  HexOnly: Boolean = False;
  DigOnly: Boolean = False;
  BinOnly: Boolean = False;
  MinusOk: Boolean = False;
  HistCount: Byte = 0;
  InsMode: Boolean = True;
  ShowLabels: Boolean = False;
  BigCursor: Boolean = False;
  SoundOn: Boolean = True;
  SortAsc: Boolean = True;
  IniId: string[41] = 'DOS-Expander 4.0 (C) 1994-1996 Hombergs';
  IniName: string[12] = 'dx.ini';

type
  THistory = array[0..25] of string[128];
  PHistory = ^THistory;

var
  HomeDir: string[79];
  History: PHistory;
  DriveFlag: array[1..26] of Boolean;

implementation

end.

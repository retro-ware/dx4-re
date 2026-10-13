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
  G9E6: Boolean = False;
  LastShift: Boolean = False;
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
  DelAbort: Boolean = False;
  HistCount: Byte = 0;
  InsMode: Boolean = True;
  ShowLabels: Boolean = False;
  BigCursor: Boolean = False;
  SoundOn: Boolean = True;
  SortAsc: Boolean = True;
  ConfirmDel: Boolean = True;
  LongNames: Boolean = False;
  IniId: string[41] = 'DOS-Expander 4.0 (C) 1994-1996 Hombergs';
  IniName: string[12] = 'dx.ini';
  PackY2: Byte = 20;
  PackX2: Byte = 70;
  PackX1: Byte = 10;
  PackY1: Byte = 3;
  RunMode: Byte = 0;
  PackFull: Boolean = False;

type
  THistory = array[0..25] of string[128];
  PHistory = ^THistory;

var
  HomeDir: string[79];
  History: PHistory;
  DriveFlag: array[1..26] of Boolean;
  ViewerName: string[79];
  MouseSpeed: Byte;

var
  { SaveCfg (0362) globals }
  CfgStr932, CfgStr982: string[79];
  CfgColors: array[0..64] of Byte;
  CfgColors2: array[0..64] of Byte;
  CfgB809, CfgB808, CfgB9D3, CfgB9D2, CfgB2263, CfgB3674, CfgBABC, CfgBABD: Byte;
  CfgW806, CfgW83E: Word;
  CfgStr814, CfgStr7F8: string[12];
  CfgBlkA68: array[0..25] of Byte;
  CfgStr2200, CfgStr3611: string[79];
  CfgStr226E, CfgStr367F: string[80];
  CfgBlkA9C: array[0..31] of Byte;
  CfgLABE, CfgLAC2, CfgLAC6, CfgLACA: Longint;
  CfgBlkAFE: array[0..47] of Byte;

implementation

end.

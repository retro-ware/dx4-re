{$O+,F+,G+,S-,I-,X+,V-}
unit StateIO;
{ Overlay 031b: program state kept across shell-outs (XMS block or dxtemp.tmp), dx.ini / dxcom.dat loading }

interface

uses DXGlob;

type
  Str79 = string[79];
  TNames = array[1..1024] of string[12];
  THistRec = record
    Count: Byte;
    Dirs: THistory;
  end;
  TState = record
    HistCount: Byte;
    Hist: THistory;
    Colors: TColors;
    Colors2: TColors;
    Path1, Path2: string[79];
    S2200, S3611: string[79];
    S226E, S367F: string[80];
    W83E: Word;
    S932, S982: string[79];
    S814: string[12];
    Flag1, Flag2: Boolean;
    B809: Byte;
    Active: Byte;
    Top1, Top2: Byte;
    Cur1, Cur2: Word;
    Marked1, Marked2: Word;
    Names1, Names2: TNames;
    W806: Word;
    S822: string[12];
    B808: Byte;
    MouseXb, MouseYb: Byte;
    BlkA9C: TBlk32;
    BABC, BABD: Byte;
    LABE, LAC2, LAC6, LACA: Longint;
    B9D2: Byte;
    W7902: Word;
    B7904, B7905: Byte;
    BlkAFE: TBlk48;
    Pw: string[12];
    W7943: Word;
    BlkA68: TBlk26;
    S7F8: string[12];
    B2263, B3674, B9D3: Byte;
    Filt1, Filt2: TFilterOpts;
    PackY2, PackX2, PackX1, PackY1, RunMode, B7F1: Byte;
    IniName: string[12];
  end;
  PState = ^TState;

procedure LoadState(var Path1, Path2: Str79; var Flag1, Flag2: Boolean; var Marked1, Marked2: Word;
  var Names: TNames; var Top1, Top2: Byte; var Cur1, Cur2: Word; var New1, New2: Boolean; var W1: Word;
  var B1, B2: Byte; var W6: Word);
procedure LoadNames(var Names: TNames);
procedure ApplyConfig(Cfg: TConfig; var W: Word);
procedure InitConfig(var S: string; var W: Word; var B1, B2: Byte);
procedure SaveState(P: PState; W1, W2: Word; B1, B2: Byte);
procedure SaveHist(P: PState);

implementation

uses Dos, Mouse, Palette, Dialogs, LongName, U109E;

procedure LoadState(var Path1, Path2: Str79; var Flag1, Flag2: Boolean; var Marked1, Marked2: Word;
  var Names: TNames; var Top1, Top2: Byte; var Cur1, Cur2: Word; var New1, New2: Boolean; var W1: Word;
  var B1, B2: Byte; var W6: Word);
var
  Ok: Boolean;
  F: file of TState;
  P: PState;
  Cur: string[79];
  Dir: string[67];
  Name: string[9];
  Ext: string[5];
begin
  GetMem(P, $79A6);
  Ok := False;
  if DxXmsHandle <> 0 then Ok := P109E_3B7($79A6, 0, P, DxXmsHandle);
  if (DxXmsHandle = 0) or not Ok then
  begin
    Assign(F, TempDir + 'dxtemp.tmp');
    Reset(F);
    Read(F, P^);
    Close(F);
    Ok := IOResult = 0;
  end;
  if Ok then
  begin
    Path1 := P^.Path1;
    Path2 := P^.Path2;
    TColors(CfgColors) := P^.Colors;
    TColors(CfgColors2) := P^.Colors2;
    CfgStr932 := P^.S932;
    CfgStr982 := P^.S982;
    CfgStr814 := P^.S814;
    CfgB809 := P^.B809;
    CfgW83E := P^.W83E;
    ActivePanel := P^.Active;
    Flag1 := P^.Flag1;
    Flag2 := P^.Flag2;
    CfgW806 := P^.W806;
    CfgB808 := P^.B808;
    CfgStr822 := P^.S822;
    CfgStr2200 := P^.S2200;
    CfgStr3611 := P^.S3611;
    CfgStr226E := P^.S226E;
    CfgStr367F := P^.S367F;
    History^ := P^.Hist;
    HistCount := P^.HistCount;
    Marked1 := P^.Marked1;
    Marked2 := P^.Marked2;
    MouseX := P^.MouseXb;
    MouseY := P^.MouseYb;
    Names := P^.Names1;
    TBlk32(CfgBlkA9C) := P^.BlkA9C;
    CfgBABC := P^.BABC;
    CfgBABD := P^.BABD;
    CfgLABE := P^.LABE;
    CfgLAC2 := P^.LAC2;
    CfgLAC6 := P^.LAC6;
    CfgLACA := P^.LACA;
    CfgB9D2 := P^.B9D2;
    W1 := P^.W7902;
    B1 := P^.B7904;
    B2 := P^.B7905;
    W6 := P^.W7943;
    TBlk48(CfgBlkAFE) := P^.BlkAFE;
    Password := P^.Pw;
    TBlk26(CfgBlkA68) := P^.BlkA68;
    CfgStr7F8 := P^.S7F8;
    CfgB2263 := P^.B2263;
    CfgB3674 := P^.B3674;
    CfgB9D3 := P^.B9D3;
    Panels[1].Filter := P^.Filt1;
    Panels[2].Filter := P^.Filt2;
    PackX2 := P^.PackX2;
    PackY2 := P^.PackY2;
    PackX1 := P^.PackX1;
    PackY1 := P^.PackY1;
    RunMode := P^.RunMode;
    G7F1 := P^.B7F1;
    MouseSensitivity(G7F1);
    IniName := P^.IniName;
    GetDir(0, Cur);
    Dir := Path1;
    if Flag1 then
    begin
      FSplit(Path1, Dir, Name, Ext);
      TrimBackslash(Dir);
    end;
    if (ActivePanel = 1) and (Cur <> Dir) then
    begin
      Top1 := 1;
      Cur1 := 0;
      Path1 := Cur;
      Flag1 := False;
    end
    else
    begin
      Top1 := P^.Top1;
      Cur1 := P^.Cur1;
      New1 := True;
    end;
    Dir := Path2;
    if Flag2 then
    begin
      FSplit(Path2, Dir, Name, Ext);
      TrimBackslash(Dir);
    end;
    if (ActivePanel = 2) and (Cur <> Dir) then
    begin
      Top2 := 1;
      Cur2 := 0;
      Path2 := Cur;
      Flag2 := False;
    end
    else
    begin
      Top2 := P^.Top2;
      Cur2 := P^.Cur2;
      New2 := True;
    end;
  end;
  FreeMem(P, $79A6);
end;

procedure LoadNames(var Names: TNames);
var
  Ok: Boolean;
  F: file of TState;
  P: PState;
begin
  GetMem(P, $79A6);
  Ok := False;
  if DxXmsHandle <> 0 then Ok := P109E_3B7($79A6, 0, P, DxXmsHandle);
  if (DxXmsHandle = 0) or not Ok then
  begin
    Assign(F, TempDir + 'dxtemp.tmp');
    Reset(F);
    Read(F, P^);
    Close(F);
    Ok := IOResult = 0;
  end;
  if Ok then Names := P^.Names2;
  FreeMem(P, $79A6);
end;

procedure ApplyConfig(Cfg: TConfig; var W: Word);
var
  I: Byte;
begin
  CfgStr932 := Cfg.S286;
  CfgStr982 := Cfg.S2D6;
  CfgStr814 := Cfg.S326;
  CfgW83E := Cfg.W284;
  TColors(CfgColors) := Cfg.Colors;
  TColors(CfgColors2) := Cfg.Colors2;
  CfgB809 := Cfg.B333;
  CfgW806 := Cfg.W334;
  CfgB808 := Cfg.B41F;
  CfgStr2200 := Cfg.S420;
  CfgStr3611 := Cfg.S470;
  CfgStr226E := Cfg.S4C0;
  CfgStr367F := Cfg.S511;
  TBlk32(CfgBlkA9C) := Cfg.Blk562;
  CfgBABC := Cfg.B582;
  CfgBABD := Cfg.B583;
  CfgLABE := Cfg.L584;
  CfgLAC2 := Cfg.L588;
  CfgLAC6 := Cfg.L58C;
  CfgLACA := Cfg.L590;
  CfgB9D2 := Cfg.B594;
  TBlk48(CfgBlkAFE) := Cfg.Blk595;
  Password := Cfg.Pw;
  W := Cfg.W6E0;
  TBlk26(CfgBlkA68) := Cfg.Blk6E2;
  CfgStr7F8 := Cfg.S6FC;
  CfgB2263 := Cfg.B709;
  CfgB3674 := Cfg.B70A;
  CfgB9D3 := Cfg.B70B;
  PackX2 := Cfg.B70D;
  PackY2 := Cfg.B70C;
  PackX1 := Cfg.B70E;
  PackY1 := Cfg.B70F;
  RunMode := Cfg.B710;
  G7F1 := Cfg.B711;
  MouseSensitivity(G7F1);
  if not LfnSupported then LongNames := False;
  if not LongNames then GA15 := False;
  for I := 1 to Length(Password) do Dec(Password[I], 13);
end;

procedure InitConfig(var S: string; var W: Word; var B1, B2: Byte);
var
  F: file of TConfig;
  I: Byte;
  Cfg: TConfig;
  F2: file of THistRec;
  Hist: THistRec;
begin
  CfgStr226E := '*.*';
  CfgStr367F := '*.*';
  CfgB2263 := 65;
  CfgB3674 := 65;
  Panels[1].Filter.MinSize := 0;
  Panels[1].Filter.MaxSize := 999999999;
  Panels[1].Filter.MinTime := $80000000;
  Panels[1].Filter.MaxTime := $7FFFFFFF;
  Panels[1].Filter.Attr := 0;
  Panels[2].Filter.MinSize := 0;
  Panels[2].Filter.MaxSize := 999999999;
  Panels[2].Filter.MinTime := $80000000;
  Panels[2].Filter.MaxTime := $7FFFFFFF;
  Panels[2].Filter.Attr := 0;
  SetPalRegs(TPalRegs(PalRegs));
  if ParamStr(4) = '2' then IniName := 'dxa.ini';
  Assign(F, HomeDir + IniName);
  Reset(F);
  Read(F, Cfg);
  Close(F);
  if (IOResult <> 0) or (Cfg.Id <> IniId) then
  begin
    S := '';
    WriteLn('Einstellungen konnten nicht geladen werden! (', IniName, ')');
  end
  else
  begin
    S := Cfg.S203;
    ApplyConfig(Cfg, W);
  end;
  B1 := CfgColors[5];
  B2 := CfgColors2[5];
  Assign(F2, HomeDir + 'dxcom.dat');
  Reset(F2);
  Read(F2, Hist);
  Close(F2);
  if IOResult = 0 then
  begin
    HistCount := Hist.Count;
    History^ := Hist.Dirs;
  end
  else
  begin
    for I := 0 to 25 do Hist.Dirs[I] := '';
    Hist.Count := 1;
    Rewrite(F2);
    Write(F2, Hist);
    Close(F2);
    InOutRes := 0;
  end;
end;

procedure SaveState(P: PState; W1, W2: Word; B1, B2: Byte);
var
  N1, N2, J, I: Integer;
  Ok: Boolean;
  F: file of TState;
begin
  P^.Path1 := Panels[1].Path;
  P^.Path2 := Panels[2].Path;
  P^.Colors := TColors(CfgColors);
  P^.Colors2 := TColors(CfgColors2);
  P^.S932 := CfgStr932;
  P^.S982 := CfgStr982;
  P^.Flag1 := Panels[1].Flag;
  P^.Flag2 := Panels[2].Flag;
  P^.S814 := CfgStr814;
  P^.B809 := CfgB809;
  P^.W83E := CfgW83E;
  P^.Active := ActivePanel;
  P^.Top1 := Byte(Panels[1].W1009);
  P^.Cur1 := Panels[1].W100B;
  P^.Top2 := Byte(Panels[2].W1009);
  P^.Cur2 := Panels[2].W100B;
  P^.Marked1 := Panels[1].W1252;
  P^.Marked2 := Panels[2].W1252;
  P^.W806 := CfgW806;
  P^.S822 := CfgStr822;
  P^.Hist := History^;
  P^.HistCount := HistCount;
  P^.B808 := CfgB808;
  P^.MouseXb := Byte(MouseX);
  P^.MouseYb := Byte(MouseY);
  P^.S2200 := CfgStr2200;
  P^.S3611 := CfgStr3611;
  P^.S226E := CfgStr226E;
  P^.S367F := CfgStr367F;
  P^.BlkA9C := TBlk32(CfgBlkA9C);
  P^.BABC := CfgBABC;
  P^.BABD := CfgBABD;
  P^.LABE := CfgLABE;
  P^.LAC2 := CfgLAC2;
  P^.LAC6 := CfgLAC6;
  P^.LACA := CfgLACA;
  P^.B9D2 := CfgB9D2;
  P^.W7902 := W1;
  P^.B7904 := B1;
  P^.B7905 := B2;
  P^.BlkAFE := TBlk48(CfgBlkAFE);
  P^.Pw := Password;
  P^.W7943 := W2;
  P^.BlkA68 := TBlk26(CfgBlkA68);
  P^.S7F8 := CfgStr7F8;
  P^.B2263 := CfgB2263;
  P^.B3674 := CfgB3674;
  P^.B9D3 := CfgB9D3;
  P^.Filt1 := Panels[1].Filter;
  P^.Filt2 := Panels[2].Filter;
  P^.PackX2 := PackX2;
  P^.PackY2 := PackY2;
  P^.PackX1 := PackX1;
  P^.PackY1 := PackY1;
  P^.RunMode := RunMode;
  P^.B7F1 := G7F1;
  P^.IniName := IniName;
  N1 := 0;
  N2 := 0;
  if Integer(Panels[1].W1252) > 0 then
    for I := 1 to Panels[1].W1007 do
      if Panels[1].Data[I]^.Marked then
      begin
        Inc(N1);
        P^.Names1[N1] := Panels[1].Data[I]^.Name;
      end;
  if Integer(Panels[2].W1252) > 0 then
    for I := 1 to Panels[2].W1007 do
      if Panels[2].Data[I]^.Marked then
      begin
        Inc(N2);
        P^.Names2[N2] := Panels[2].Data[I]^.Name;
      end;
  Ok := True;
  if DxXmsHandle <> 0 then Ok := P109E_316($79A6, 0, P, DxXmsHandle);
  if (DxXmsHandle = 0) or not Ok then
  begin
    Assign(F, TempDir + 'dxtemp.tmp');
    Rewrite(F);
    Write(F, P^);
    Close(F);
    if IOResult <> 0 then;
  end;
end;

procedure SaveHist(P: PState);
var
  F: file of TState;
  Ok: Boolean;
begin
  Ok := True;
  if DxXmsHandle <> 0 then
  begin
    P109E_3B7($79A6, 0, P, DxXmsHandle);
    P^.Hist := History^;
    P^.HistCount := HistCount;
    Ok := P109E_316($79A6, 0, P, DxXmsHandle);
  end;
  if (DxXmsHandle = 0) or not Ok then
  begin
    Assign(F, TempDir + 'dxtemp.tmp');
    Reset(F);
    Read(F, P^);
    Close(F);
    InOutRes := 0;
    P^.Hist := History^;
    P^.HistCount := HistCount;
    Rewrite(F);
    Write(F, P^);
    Close(F);
    InOutRes := 0;
  end;
end;

end.

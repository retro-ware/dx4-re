{$O+,F+,G+,S-,I-,V-}
unit PanelIni;

interface

type
  Str12 = string[12];

procedure SaveSetupAs(Name: Str12; N: Byte);
procedure SwapPanels(N: Byte);

implementation

uses Dos, DXGlob, Dialogs, U0365, U13A5;

type
  TColors = array[0..64] of Byte;
  TBlk26 = array[0..25] of Byte;
  TBlk32 = array[0..31] of Byte;
  TBlk48 = array[0..47] of Byte;
  TProg = record
    W: Word;
    S: string[20];
  end;
  TConfig = record
    Id: string;
    Colors: TColors;
    Colors2: TColors;
    S182, S203: string[128];
    W284: Word;
    S286, S2D6: string[79];
    S326: string[12];
    B333: Byte;
    W334: Word;
    Drives: array[1..26] of Boolean;
    Progs: array[1..9] of TProg;
    B41F: Byte;
    S420, S470: string[79];
    S4C0, S511: string[80];
    Blk562: TBlk32;
    B582, B583: Byte;
    L584, L588, L58C, L590: Longint;
    B594: Byte;
    Blk595: TBlk48;
    Pw: string[11];
    S1, S2, S3: string[77];
    Prn1, Prn2: string[12];
    B6D5, B6D6, B6D7, B6D8, B6D9, B6DA, B6DB, B6DC, B6DD, B6DE, B6DF: Byte;
    W6E0: Word;
    Blk6E2: TBlk26;
    S6FC: string[12];
    B709, B70A, B70B: Byte;
    B70C, B70D, B70E, B70F, B710, B711: Byte;
  end;

procedure SaveSetupAs(Name: Str12; N: Byte);
var
  F: file of TConfig;
  Rec: TConfig;
  I: Integer;
  D: DirStr;
  Nm: NameStr;
  E: ExtStr;
begin
  if Length(Name) = 0 then Exit;
  Assign(F, HomeDir + Name);
  Reset(F);
  Read(F, Rec);
  Close(F);
  if IOResult <> 0 then
  begin
    for I := 1 to 9 do
    begin
      Rec.Progs[I].W := 999;
      Rec.Progs[I].S := 'niemand';
    end;
    for I := 3 to 26 do Rec.Drives[I] := True;
    Rec.Drives[1] := False;
    Rec.Drives[2] := False;
  end;
  Rewrite(F);
  if IOResult <> 0 then
  begin
    P13A5_973(14, HomeDir + Name);
    Exit;
  end;
  Rec.Id := IniId;
  Rec.S182 := Panels[1].Path;
  Rec.S203 := Panels[2].Path;
  if Panels[1].Flag then
  begin
    FSplit(Rec.S182, D, Nm, E);
    TrimBackslash(D);
    Rec.S182 := D;
  end;
  if Panels[2].Flag then
  begin
    FSplit(Rec.S203, D, Nm, E);
    TrimBackslash(D);
    Rec.S203 := D;
  end;
  Rec.S286 := CfgStr932;
  Rec.S2D6 := CfgStr982;
  Rec.S326 := CfgStr814;
  Rec.W284 := CfgW83E;
  Rec.Colors := TColors(CfgColors);
  Rec.Colors2 := TColors(CfgColors2);
  Rec.B333 := CfgB809;
  Rec.W334 := CfgW806;
  Rec.B41F := CfgB808;
  Rec.S420 := Panels[1].S11FE;
  Rec.S470 := Panels[2].S11FE;
  Rec.S4C0 := Panels[1].S126C;
  Rec.S511 := Panels[2].S126C;
  Rec.Blk562 := TBlk32(CfgBlkA9C);
  Rec.B582 := CfgBABC;
  Rec.B583 := CfgBABD;
  Rec.L584 := CfgLABE;
  Rec.L588 := CfgLAC2;
  Rec.L58C := CfgLAC6;
  Rec.L590 := CfgLACA;
  Rec.B594 := CfgB9D2;
  Rec.Blk595 := TBlk48(CfgBlkAFE);
  Rec.Pw := Password;
  Rec.W6E0 := N;
  Rec.Blk6E2 := TBlk26(CfgBlkA68);
  Rec.S6FC := CfgStr7F8;
  Rec.B709 := Panels[1].B1261;
  Rec.B70A := Panels[2].B1261;
  Rec.B70B := CfgB9D3;
  Rec.B70C := PackY2;
  Rec.B70D := PackX2;
  Rec.B70E := PackX1;
  Rec.B70F := PackY1;
  Rec.B710 := RunMode;
  Rec.B711 := G7F1;
  for I := 1 to Length(Password) do Inc(Rec.Pw[I], 13);
  Write(F, Rec);
  Close(F);
  GB90 := 0;
  if CfgColors[4] <> 0 then P13A5_149B(1, HomeDir + Name);
end;

procedure SwapPanels(N: Byte);
var
  S: string[79];
  Name1, Name2: Str12;
  Flag2, Flag1: Boolean;
  D: DirStr;
  Nm: NameStr;
  E: ExtStr;
  Colors: TColors;
  Saved: TPanel;
  I: Integer;
begin
  Saved := Panels[1];
  Flag1 := Panels[1].Flag;
  Flag2 := Panels[2].Flag;
  Name1 := P0365_91(Panels[2]);
  Name2 := P0365_91(Panels[1]);
  Colors := TColors(CfgColors);
  CfgColors2[6] := CfgColors[6];
  Panels[1].Path := Panels[2].Path;
  Panels[1].S10AE := Panels[2].S10AE;
  Panels[1].S105E := Panels[2].S105E;
  Panels[1].S11FE := Panels[2].S11FE;
  Panels[1].Data := Panels[2].Data;
  Panels[1].W1252 := Panels[2].W1252;
  Panels[1].W1007 := Panels[2].W1007;
  Panels[1].W1009 := Panels[2].W1009;
  Panels[1].W100B := Panels[2].W100B;
  Panels[1].S1254 := Panels[2].S1254;
  Panels[1].Flag := Panels[2].Flag;
  Panels[1].Blk1262 := Panels[2].Blk1262;
  Panels[1].S126C := Panels[2].S126C;
  Panels[1].W1250 := Panels[2].W1250;
  Panels[2].Path := Saved.Path;
  Panels[2].S10AE := Saved.S10AE;
  Panels[2].S105E := Saved.S105E;
  Panels[2].S11FE := Saved.S11FE;
  Panels[2].Data := Saved.Data;
  Panels[2].W1252 := Saved.W1252;
  Panels[2].W1007 := Saved.W1007;
  Panels[2].W1009 := Saved.W1009;
  Panels[2].W100B := Saved.W100B;
  Panels[2].S1254 := Saved.S1254;
  Panels[2].Flag := Saved.Flag;
  Panels[2].Blk1262 := Saved.Blk1262;
  Panels[2].S126C := Saved.S126C;
  Panels[2].W1250 := Saved.W1250;
  for I := 5 to 11 do CfgColors[I] := CfgColors2[I];
  for I := 24 to 25 do CfgColors[I] := CfgColors2[I];
  TColors(CfgColors2) := Colors;
  Panels[1].Mode := 1;
  Panels[2].Mode := 1;
  if Panels[1].Blk1262[0] <> 0 then Panels[1].Mode := 3;
  if Panels[2].Blk1262[0] <> 0 then Panels[2].Mode := 3;
  if CfgColors[6] <> 0 then
  begin
    Panels[1].Mode := 5;
    Panels[2].Mode := 1;
  end;
  P0365_EF(1, Panels[1]);
  P0365_EF(1, Panels[2]);
  if CfgColors[6] <> 0 then
  begin
    Panels[1].W1009 := 1;
    Panels[1].W100B := 0;
    Panels[2].W1009 := 1;
    Panels[2].W100B := 0;
    P0365_C28F(Name1, 1, 6, Panels[1].W100B, Panels[1]);
    P0365_C28F(Name2, 1, 6, Panels[2].W100B, Panels[2]);
  end
  else
  begin
    P0365_41FB(Panels[1]);
    P0365_41FB(Panels[2]);
  end;
  D := Panels[N].Path;
  S := D;
  if Panels[N].Flag then
  begin
    FSplit(S, D, Nm, E);
    TrimBackslash(D);
  end;
  P0365_C3B(D, Panels[N]);
  Panels[N].Path := S;
  Panels[1].Flag := Flag2;
  Panels[2].Flag := Flag1;
  G562 := Flag1 or Flag2;
end;

end.

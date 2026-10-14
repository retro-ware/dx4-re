{$O+,F+,G+,S-,I-}
unit SaveCfg;

interface

procedure SaveConfig;

implementation

uses DXGlob, Dialogs;

procedure SaveConfig;
var
  F: file of TConfig;
  Rec: TConfig;
  NeedInit: Boolean;
  I: Byte;
begin
  Assign(F, HomeDir + IniName);
  Reset(F);
  Read(F, Rec);
  Close(F);
  NeedInit := (IOResult <> 0) or (Rec.Id <> IniId);
  Rec.S286 := CfgStr932;
  Rec.S2D6 := CfgStr982;
  for I := 0 to 4 do Rec.Colors[I] := CfgColors[I];
  Rec.Colors[12] := CfgColors[12];
  for I := 19 to 23 do Rec.Colors[I] := CfgColors[I];
  Rec.Colors[26] := CfgColors[26];
  Rec.Colors[29] := CfgColors[29];
  Rec.Colors[30] := CfgColors[30];
  Rec.Colors[32] := CfgColors[32];
  Rec.Colors[33] := CfgColors[33];
  Rec.Colors[34] := CfgColors[34];
  for I := 36 to 49 do Rec.Colors[I] := CfgColors[I];
  Rec.Colors[51] := CfgColors[51];
  Rec.Colors[56] := CfgColors[56];
  Rec.Colors[57] := CfgColors[57];
  Rec.Colors[58] := CfgColors[58];
  Rec.Colors[59] := CfgColors[59];
  Rec.B333 := CfgB809;
  Rec.Pw := Password;
  Rec.B41F := CfgB808;
  Rec.Blk6E2 := TBlk26(CfgBlkA68);
  Rec.S326 := CfgStr814;
  Rec.W334 := CfgW806;
  Rec.B70B := CfgB9D3;
  for I := 1 to Length(Password) do Inc(Rec.Pw[I], 13);
  if NeedInit then
  begin
    Rec.Id := IniId;
    for I := 1 to 9 do
    begin
      Rec.Progs[I].W := 999;
      Rec.Progs[I].S := '------';
    end;
    Rec.Drives[1] := False;
    Rec.Drives[2] := False;
    for I := 3 to 26 do Rec.Drives[I] := True;
    Rec.S182 := '';
    Rec.S203 := '';
    Rec.W284 := CfgW83E;
    Rec.Colors := TColors(CfgColors);
    Rec.Colors2 := TColors(CfgColors2);
    Rec.B41F := CfgB808;
    Rec.S420 := CfgStr2200;
    Rec.S470 := CfgStr3611;
    Rec.S4C0 := CfgStr226E;
    Rec.S511 := CfgStr367F;
    Rec.Blk562 := TBlk32(CfgBlkA9C);
    Rec.B582 := CfgBABC;
    Rec.B583 := CfgBABD;
    Rec.L584 := CfgLABE;
    Rec.L588 := CfgLAC2;
    Rec.L58C := CfgLAC6;
    Rec.L590 := CfgLACA;
    Rec.B594 := CfgB9D2;
    Rec.Blk595 := TBlk48(CfgBlkAFE);
    Rec.W6E0 := $101;
    Rec.S6FC := CfgStr7F8;
    Rec.B709 := CfgB2263;
    Rec.B70A := CfgB3674;
    Rec.S1 := '';
    Rec.S2 := '';
    Rec.S3 := '';
    while Length(Rec.S1) < 77 do Rec.S1 := Rec.S1 + ' ';
    while Length(Rec.S2) < 77 do Rec.S2 := Rec.S2 + ' ';
    while Length(Rec.S3) < 77 do Rec.S3 := Rec.S3 + ' ';
    Rec.Prn1 := 'epson500.drv';
    Rec.B6D6 := 0;
    Rec.B6D5 := 1;
    Rec.B6D7 := 0;
    Rec.B6D8 := 0;
    Rec.B6D9 := 0;
    Rec.B6DA := 0;
    Rec.Prn2 := 'hp520.drv';
    Rec.B6DB := 0;
    Rec.B6DC := 0;
    Rec.B6DD := 0;
    Rec.B6DE := 0;
    Rec.B6DF := 0;
    Rec.B70C := 20;
    Rec.B70D := 70;
    Rec.B70E := 10;
    Rec.B70F := 3;
    Rec.B710 := 2;
    Rec.B711 := 60;
  end;
  Rewrite(F);
  Write(F, Rec);
  Close(F);
  if IOResult <> 0 then
    MsgBox('Fehler beim Erstellen von ' + IniName + '!',
      'Einstellungen konnten nicht gespeichert werden.');
end;

end.

{$F+,G+,S-}
unit U1439;
{ Resident segment 1439: calendar functions (leap years, weekdays, day numbers, German holidays) }

interface

type
  Str12 = string[12];

procedure FebDays(Year: Integer; var D: Integer);
function DaysInMonth(Year, Month: Integer): Integer;
function DaysInYear(Year: Integer): Integer;
procedure WeekDay(Year, Day: Integer; var S: string; var N: Longint);
procedure DateToDayNo(Year, Month, Day: Integer; var MDays, DayNo: Integer; var MonthName: string);
procedure DayNoToDate(DayNo, Year: Integer; var Month, Day: Integer);
procedure Holidays(Year: Integer;
  var D1, M1, D2, M2, D3, M3, D4, M4, D5, M5, D6, M6,
    D7, M7, D8, M8, D9, M9, D10, M10, D11, M11, D12, M12,
    D13, M13, D14, M14, D15, M15, D16, M16, D17, M17: Integer;
  var S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17: string);
function ParseDate(var S: Str12; var Year, Month, Day: Word): Boolean;

implementation

uses Dos, Screen;

procedure FebDays(Year: Integer; var D: Integer);
begin
  if (Year mod 4 = 0) and (Year mod 100 <> 0) or (Year mod 400 = 0) then
    D := 29
  else
    D := 28;
end;

function DaysInMonth(Year, Month: Integer): Integer;
var
  D: Integer;
begin
  case Month of
    1: DaysInMonth := 31;
    2: begin
         FebDays(Year, D);
         DaysInMonth := D;
       end;
    3: DaysInMonth := 31;
    4: DaysInMonth := 30;
    5: DaysInMonth := 31;
    6: DaysInMonth := 30;
    7: DaysInMonth := 31;
    8: DaysInMonth := 31;
    9: DaysInMonth := 30;
    10: DaysInMonth := 31;
    11: DaysInMonth := 30;
    12: DaysInMonth := 31;
  end;
end;

function DaysInYear(Year: Integer): Integer;
begin
  DaysInYear := DaysInMonth(Year, 2) + 337;
end;

procedure WeekDay(Year, Day: Integer; var S: string; var N: Longint);
var
  I, T, Start: Integer;
begin
  if Year <> 22222 then
  begin
    N := 0;
    Start := 1900;
    if Year >= 2000 then
    begin
      Start := 2000;
      N := 36524;
    end;
    if Year >= 2100 then
    begin
      Start := 2100;
      N := 73049;
    end;
    if Year >= 2200 then
    begin
      Start := 2200;
      N := 109573;
    end;
    if Year >= 2300 then
    begin
      Start := 2300;
      N := 146097;
    end;
    for I := Start to Year - 1 do
    begin
      T := DaysInMonth(I, 2);
      Inc(N, T + 337);
    end;
  end;
  Inc(N, Day);
  case N mod 7 of
    0: S := 'Sonntag';
    1: S := 'Montag';
    2: S := 'Dienstag';
    3: S := 'Mittwoch';
    4: S := 'Donnerstag';
    5: S := 'Freitag';
    6: S := 'Samstag';
  end;
end;

procedure DateToDayNo(Year, Month, Day: Integer; var MDays, DayNo: Integer; var MonthName: string);
var
  I: Integer;
begin
  case Month of
    1: MonthName := 'Januar';
    2: MonthName := 'Februar';
    3: MonthName := 'M'#$84'rz';
    4: MonthName := 'April';
    5: MonthName := 'Mai';
    6: MonthName := 'Juni';
    7: MonthName := 'Juli';
    8: MonthName := 'August';
    9: MonthName := 'September';
    10: MonthName := 'Oktober';
    11: MonthName := 'November';
    12: MonthName := 'Dezember';
  end;
  DayNo := 0;
  for I := 1 to Month do
  begin
    MDays := DaysInMonth(Year, I);
    DayNo := DayNo + MDays;
  end;
  DayNo := DayNo - MDays + Day;
end;

procedure DayNoToDate(DayNo, Year: Integer; var Month, Day: Integer);
var
  F: Integer;
begin
  FebDays(Year, F);
  if F = 28 then
    case DayNo of
      1..31: begin Day := DayNo; Month := 1; end;
      32..59: begin Day := DayNo - 31; Month := 2; end;
      60..90: begin Day := DayNo - 59; Month := 3; end;
      91..120: begin Day := DayNo - 90; Month := 4; end;
      121..151: begin Day := DayNo - 120; Month := 5; end;
      152..181: begin Day := DayNo - 151; Month := 6; end;
      182..212: begin Day := DayNo - 181; Month := 7; end;
      213..243: begin Day := DayNo - 212; Month := 8; end;
      244..273: begin Day := DayNo - 243; Month := 9; end;
      274..304: begin Day := DayNo - 273; Month := 10; end;
      305..334: begin Day := DayNo - 304; Month := 11; end;
      335..365: begin Day := DayNo - 334; Month := 12; end;
    end
  else
    case DayNo of
      1..31: begin Day := DayNo; Month := 1; end;
      32..60: begin Day := DayNo - 31; Month := 2; end;
      61..91: begin Day := DayNo - 60; Month := 3; end;
      92..121: begin Day := DayNo - 91; Month := 4; end;
      122..152: begin Day := DayNo - 121; Month := 5; end;
      153..182: begin Day := DayNo - 152; Month := 6; end;
      183..213: begin Day := DayNo - 182; Month := 7; end;
      214..244: begin Day := DayNo - 213; Month := 8; end;
      245..274: begin Day := DayNo - 244; Month := 9; end;
      275..305: begin Day := DayNo - 274; Month := 10; end;
      306..335: begin Day := DayNo - 305; Month := 11; end;
      336..366: begin Day := DayNo - 335; Month := 12; end;
    end;
end;

{ German holidays of a year: Day/Month pairs and weekday names (Easter by Gauss) }
procedure Holidays(Year: Integer;
  var D1, M1, D2, M2, D3, M3, D4, M4, D5, M5, D6, M6,
    D7, M7, D8, M8, D9, M9, D10, M10, D11, M11, D12, M12,
    D13, M13, D14, M14, D15, M15, D16, M16, D17, M17: Integer;
  var S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17: string);
var
  D, E, N, Mc, EMonth, EDay, Corr, EasterNo, DayNo, MDays, DayNo2: Integer;
  MonthName, MonthName2: string;
  N2, Base, T: Longint;
begin
  case Year of
    1900..2099: begin N := 13; Mc := 204; Corr := 2; end;
    2100..2199: begin N := 14; Mc := 204; Corr := 2; end;
    2200..2299: begin N := 15; Mc := 205; Corr := 1; end;
    2300..2399: begin N := 16; Mc := 206; Corr := 0; end;
  end;
  D := (Mc - (Year mod 19) * 11) mod 30;
  if Corr = 2 then
    if (D = 29) or (D = 28) then Dec(D);
  if Corr = 1 then
    if D = 29 then D := 28;
  E := (Year div 4 + Year + D - N) mod 7;
  EDay := D + 28 - E;
  EMonth := 3;
  if EDay > 31 then
  begin
    EDay := EDay - 31;
    EMonth := 4;
  end;
  { Neujahr }
  D1 := 1;
  M1 := 1;
  WeekDay(Year, 1, S1, Base);
  { Ostersonntag }
  D5 := EDay;
  M5 := EMonth;
  DateToDayNo(Year, EMonth, EDay, MDays, DayNo, MonthName);
  EasterNo := DayNo;
  WeekDay(Year, EasterNo, S5, N2);
  { Ostermontag }
  N2 := Base - 1;
  WeekDay(22222, EasterNo + 1, S6, N2);
  DayNoToDate(EasterNo + 1, Year, M6, D6);
  { Heilige Drei Koenige }
  N2 := Base - 1;
  D2 := 6;
  M2 := 1;
  WeekDay(22222, 6, S2, N2);
  { Rosenmontag }
  N2 := Base - 1;
  WeekDay(22222, EasterNo - 48, S3, N2);
  DayNoToDate(EasterNo - 48, Year, M3, D3);
  { Karfreitag }
  N2 := Base - 1;
  WeekDay(22222, EasterNo - 2, S4, N2);
  DayNoToDate(EasterNo - 2, Year, M4, D4);
  { 1. Mai }
  D7 := 1;
  M7 := 5;
  DateToDayNo(Year, 5, 1, MDays, DayNo2, MonthName2);
  N2 := Base - 1;
  WeekDay(22222, DayNo2, S7, N2);
  { Christi Himmelfahrt }
  N2 := Base - 1;
  WeekDay(22222, EasterNo + 39, S8, N2);
  DayNoToDate(EasterNo + 39, Year, M8, D8);
  { Pfingstsonntag }
  N2 := Base - 1;
  WeekDay(22222, EasterNo + 49, S9, N2);
  DayNoToDate(EasterNo + 49, Year, M9, D9);
  { Pfingstmontag }
  N2 := Base - 1;
  WeekDay(22222, EasterNo + 50, S10, N2);
  DayNoToDate(EasterNo + 50, Year, M10, D10);
  { Fronleichnam }
  N2 := Base - 1;
  WeekDay(22222, EasterNo + 60, S11, N2);
  DayNoToDate(EasterNo + 60, Year, M11, D11);
  { Tag der Deutschen Einheit }
  D12 := 3;
  M12 := 10;
  DateToDayNo(Year, 10, 3, MDays, DayNo2, MonthName2);
  N2 := Base - 1;
  WeekDay(22222, DayNo2, S12, N2);
  { Allerheiligen }
  D13 := 1;
  M13 := 11;
  DateToDayNo(Year, 11, 1, MDays, DayNo2, MonthName2);
  N2 := Base - 1;
  WeekDay(22222, DayNo2, S13, N2);
  { 1. Weihnachtstag }
  D15 := 25;
  M15 := 12;
  DateToDayNo(Year, 12, 25, MDays, DayNo2, MonthName2);
  WeekDay(Year, DayNo2, S15, T);
  { 2. Weihnachtstag }
  D16 := 26;
  M16 := 12;
  DateToDayNo(Year, 12, 26, MDays, DayNo2, MonthName2);
  N2 := Base - 1;
  WeekDay(22222, DayNo2, S16, N2);
  { Silvester }
  N2 := Base - 1;
  D17 := 31;
  M17 := 12;
  WeekDay(22222, 1, S17, N2);
  { Buss- und Bettag: Wednesday before the last Sunday before Christmas }
  DayNo2 := T - T mod 7 - (Base - 1) - 32;
  if T mod 7 = 0 then DayNo2 := DayNo2 - 7;
  N2 := Base - 1;
  WeekDay(22222, DayNo2, S14, N2);
  DayNoToDate(DayNo2, Year, M14, D14);
end;

function ParseDate(var S: Str12; var Year, Month, Day: Word): Boolean;
var
  C1, C2, C3: Integer;
  X: Word;
  T: Integer;
  Dow: Word;
  DS, MS, YS, W: string[12];
  Unused: Longint;
begin
  ParseDate := False;
  W := S;
  if LowerStr(W) = 'heute' then
  begin
    GetDate(Year, Month, Day, Dow);
    ParseDate := True;
    Str(Year, DS);
    S := LeadZero(Day) + '.' + LeadZero(Month) + '.' + DS;
    Exit;
  end;
  DS := Copy(W, 1, Pos('.', W) - 1);
  Delete(W, 1, Pos('.', W));
  MS := Copy(W, 1, Pos('.', W) - 1);
  Delete(W, 1, Pos('.', W));
  YS := W;
  Val(DS, Day, C1);
  Val(MS, Month, C2);
  Val(YS, Year, C3);
  if (C3 = 0) and (Year < 100) then Year := Year + 1900;
  if (C1 + C2 + C3 <> 0) or (Year > 2399) or (Year < 1900) or (Day < 1) or (Day > 31) or
    (Month < 1) or (Month > 12) then Exit;
  T := DaysInMonth(Year, Month);
  if Day > T then Exit;
  ParseDate := True;
  Str(Year, DS);
  S := LeadZero(Day) + '.' + LeadZero(Month) + '.' + DS;
end;

end.

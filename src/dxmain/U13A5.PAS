{$O+,F+,G+,S-,I-}
unit U13A5;
{ message boxes: red error boxes and green info boxes }

interface

procedure P13A5_3B2(N: Byte);
procedure P13A5_973(N: Byte; S: string);
procedure P13A5_1171(N: Byte);
procedure P13A5_149B(N: Byte; S: string);

implementation

uses DXGlob, Buttons, Mouse, Screen, Windows, ScrSave, Status;

procedure RedBox(S1, S2: string);
var
  B: TButton;
  Key: Word;
  Stack: TScrStack;
begin
  InitStack(Stack);
  MouseHide;
  PushScreen(Stack);
  ScreenMask := $40FF;
  CursorMask := $4C00;
  MouseDefCursor;
  Frame(13, 7, 55, 8, 15, 4, 0, 1);
  WriteCenterXYF(1, 2, 55, 15, S1);
  WriteCenterXYF(1, 4, 55, 14, S2);
  InitButton(True, 19, 6, 15, 15, 15, 4, '     Weiter    ', B);
  MouseShow;
  repeat
    GetKey(Key);
  until (Key <> 0) or Buttons.MouseButton(B) or (MouseButton = 2);
  PopScreen(Stack);
  ClearStack(Stack);
  repeat
    Idle;
  until MouseButton = 0;
end;

procedure GreenBox(S1, S2: string);
var
  B: TButton;
  Key: Word;
  Stack: TScrStack;
begin
  InitStack(Stack);
  MouseHide;
  PushScreen(Stack);
  ScreenMask := $40FF;
  CursorMask := $4C00;
  MouseDefCursor;
  Frame(13, 7, 55, 8, 2, 5, 0, 1);
  WriteCenterXYFB(1, 2, 55, 0, 5, S1);
  WriteCenterXYFB(1, 4, 55, 4, 5, S2);
  InitButton(True, 3, 6, 0, 2, 2, 5, '                       OK                      ', B);
  MouseShow;
  repeat
    GetKey(Key);
  until (Key <> 0) or Buttons.MouseButton(B) or (MouseButton = 2) or MouseOutside(13, 69, 7, 16);
  PopScreen(Stack);
  ClearStack(Stack);
  repeat
    Idle;
  until MouseButton = 0;
end;

procedure P13A5_3B2(N: Byte);
begin
  case N of
    1: RedBox('Das Programm mem.exe wurde nicht gefunden!', 'Es mu'#$E1' im Pfad vorhanden sein!');
    2: RedBox('Umbenennen:', 'Umbenennen nicht m'#$94'glich!');
    3: RedBox('Bewegen in ein anderes Verzeichnis nicht m'#$94'glich!', 'Benutzen Sie F5.');
    4: RedBox('Fehler beim L'#$94'schen!', 'Diskette ist schreibgesch'#$81'tzt!');
    5: RedBox('Fehler!', 'Kein CD-ROM Laufwerk gefunden!');
    6: RedBox('Es wurde Untbr (Strg-Pause) gedr'#$81'ckt!', 'Programmabbruch!');
  end;
end;

procedure P13A5_973(N: Byte; S: string);
begin
  case N of
    1: RedBox('Fehler beim '#$99'ffnen der Datei:', S);
    2: RedBox('Fehler: Nicht genug Speicher!', S);
    3: RedBox('Diskette ist schreibgesch'#$81'tzt!', S);
    4: RedBox('Fehler beim Erstellen der Datei:', S);
    5: RedBox('Fehler beim Kopieren. Sektor nicht gefunden!', S);
    6: RedBox('Schreibfehler beim Zugriff auf Ger'#$84't', S);
    7: RedBox('Drucker hat kein Papier!', S);
    8: RedBox('Fehler beim Lesen von der Diskette', S);
    9: RedBox('Kopiervorgang wurde abgebrochen', S);
    10: RedBox('Fehler beim Kopieren!', S);
    11: RedBox('Fehler beim Kopieren. Datentr'#$84'ger ist voll!', S);
    12: RedBox('Fehler beim Kopieren der Datei:', S);
    13: RedBox('Fehler beim Vergleich der Dateien!', S);
    14: RedBox('Fehler beim Speichern der Einstellungen!', S);
    15: RedBox(' Fehler beim Laden der Einstellungen!', S);
    16: RedBox('Sorry, interner Fehler Nr.: ', S);
    17: RedBox(' Ein Verzeichnis gleichen Namens existiert bereits!', S);
    18: RedBox('Fehler beim Umbenennen!', S);
    19: RedBox('Fehler beim Erstellen des Verzeichnisses', S);
    20: RedBox(' Punkte im Directory sind nicht erlaubt!', S);
    21: RedBox(' Sie k'#$94'nnen eine Datei nicht in sich selbst kopieren!', S);
    22: RedBox('Fehler beim Bewegen!', S);
    23: RedBox('Das Verzeichnis existiert bereits!', S);
    24: RedBox('Eine Datei gleichen Namens existiert bereits!', S);
    25: RedBox('Kopieren der Verzeichnisstruktur wurde abgebrochen!', S);
    26: RedBox('Fehler beim Kopieren der Verzeichnisstruktur!', S);
    27: RedBox('Mehrere Dateien k'#$94'nnen nicht den selben', S);
    28: RedBox('Mehrere Dateien in eine Datei kopieren?!', S);
    29: RedBox('Fehler beim L'#$94'schen von:', S);
    30: RedBox('Fehler beim '#$8E'ndern des Attributes!', S);
    31: RedBox('Fehler beim '#$8E'ndern von Zeit und Datum!', S);
    32: RedBox('Es werden nicht alle Dateien angezeigt!', S);
    33: RedBox('Verzeichnis in sich selbst kopieren nicht m'#$94'glich!', S);
  end;
end;

procedure P13A5_1171(N: Byte);
var
  S: string;
begin
  case N of
    1: GreenBox('Dateizeit und Datum '#$84'ndern:', 'Im Archiv nicht m'#$94'glich!');
    2: GreenBox('Dateizeit und Datum '#$84'ndern:', 'Bei Verzeichnissen nicht m'#$94'glich!');
    5: GreenBox('Es wurde noch kein externer Viewer angegeben!', 'Nehmen Sie den Eintrag in der Konfiguration vor.');
    6: GreenBox('Verzeichnis erstellen:', 'Im Archiv nicht m'#$94'glich!');
    7: GreenBox('Anzeige des Archiv-Inhaltes:', 'In beiden Fenster nicht m'#$94'glich!');
    8: GreenBox('Attribute '#$84'ndern:', 'Im Archiv nicht m'#$94'glich!');
    9: GreenBox('Attribute '#$84'ndern:', 'Keine Datei ausgew'#$84'hlt!');
    10: GreenBox('Maus, Zeichensatz und Timer wurden zur'#$81'ckgesetzt.', 'Beide Verzeichnisse wurden neu eingelesen.');
    12: GreenBox('Men'#$81'befehl wiederholen:', 'Es ist kein g'#$81'ltiger Men'#$81'befehl gespeichert!');
    13: GreenBox('Es werden nicht alle Dateien angezeigt!', 'Maximale Anzahl erreicht. Benutzen Sie den Filter!');
    14: GreenBox('CD-Player nicht gefunden!', HomeDir + 'dxcd.exe');
    15: GreenBox('Quickview steht in der breiten Anzeige', 'nicht zur Verf'#$81'gung!');
    16: GreenBox('Die Unterst'#$81'tzung langer Dateinamen ist', 'nicht aktiv!');
    17: GreenBox('Textsuche in Verzeichnisb'#$84'umen kann mit', 'Alt-F7 = Dateisuche durchgef'#$81'hrt werden.');
    18: GreenBox('Die Datei pa'#$E1't nicht mehr auf die Diskette!', '');
    19:
      begin
        if ShowDirSizes then S := 'jetzt eingeschaltet.' else S := 'jetzt ausgeschaltet.';
        GreenBox('Die Anzeige der Gr'#$94#$E1'en markierter Verzeichnisse ist', S);
      end;
  end;
end;

procedure P13A5_149B(N: Byte; S: string);
begin
  case N of
    1: GreenBox('Alle Einstellungen wurden gespeichert!', S);
    2: GreenBox('Einstellungen wurden geladen!', S);
  end;
end;

end.

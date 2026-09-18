unit MicroConfig;

{ Microcosme — panneau de réglages : paramètres ajustables en cours de
  partie, valeurs par défaut au démarrage, sauvegarde microcosme.ini. }

interface

uses
  System.SysUtils, System.IniFiles;

const
  CN = 12;                 { nombre de paramètres réglables }
  BID_CFGSHOW = 200;       { bouton "réglages" }
  BID_CFGDEF  = 201;       { bouton "tout par défaut" }
  BID_CFGDEC  = 210;       { 210..210+CN-1 : boutons [-] }
  BID_CFGINC  = 230;       { 230..230+CN-1 : boutons [+] }

var
  { découvertes : probabilité par tentative }
  CfgFeu, CfgAgri, CfgStock, CfgPast, CfgPeche, CfgNav, CfgEcrit: Single;
  CfgGap: Integer;         { jours minimum entre deux inventions }
  { diffusion du savoir }
  CfgDiffu: Single;        { proba d'apprendre d'un voisin }
  CfgMemoire: Single;      { 0 = mémoire du peuple OFF, 1 = ON }
  { évolution }
  CfgMut: Single;          { multiplicateur du taux de mutation }
  { population }
  CfgImmig: Integer;       { immigrants sapiens par vague }

  FCfgShow: Boolean = False;   { panneau visible ? }

procedure ConfigAdjust(Idx, Dir: Integer);
procedure ResetCfg;
procedure LoadCfg;
procedure SaveCfg;
function CfgName(Idx: Integer): string;
function CfgText(Idx: Integer): string;

implementation

procedure Defaults;
begin
  CfgFeu := 0.002;   CfgAgri := 0.002;  CfgStock := 0.002;
  CfgPast := 0.002;  CfgPeche := 0.002;
  CfgNav := 0.0015;  CfgEcrit := 0.001;
  CfgGap := 3;
  CfgDiffu := 0.06;
  CfgMemoire := 1.0;
  CfgMut := 1.0;
  CfgImmig := 3;
end;

function CfgGet(Idx: Integer): Single;
begin
  case Idx of
    0: Result := CfgFeu;    1: Result := CfgAgri;
    2: Result := CfgStock;  3: Result := CfgPast;
    4: Result := CfgPeche;  5: Result := CfgNav;
    6: Result := CfgEcrit;  7: Result := CfgGap;
    8: Result := CfgDiffu;  9: Result := CfgMemoire;
   10: Result := CfgMut;   11: Result := CfgImmig;
  else Result := 0;
  end;
end;

procedure CfgSet(Idx: Integer; V: Single);
begin
  case Idx of
    0: CfgFeu := V;    1: CfgAgri := V;
    2: CfgStock := V;  3: CfgPast := V;
    4: CfgPeche := V;  5: CfgNav := V;
    6: CfgEcrit := V;  7: CfgGap := Round(V);
    8: CfgDiffu := V;  9: CfgMemoire := V;
   10: CfgMut := V;   11: CfgImmig := Round(V);
  end;
end;

function CfgStep(Idx: Integer): Single;
begin
  case Idx of
    0..6: Result := 0.001;
    7, 9, 11: Result := 1;
    8: Result := 0.01;
   10: Result := 0.25;
  else Result := 0.001;
  end;
end;

procedure CfgMinMax(Idx: Integer; out A, B: Single);
begin
  case Idx of
    0..6: begin A := 0;     B := 0.02 end;
    7:    begin A := 0;     B := 10   end;
    8:    begin A := 0;     B := 0.5  end;
    9:    begin A := 0;     B := 1    end;
   10:    begin A := 0.25;  B := 4    end;
   11:    begin A := 0;     B := 8    end;
  else begin A := 0; B := 1 end;
  end;
end;

procedure ConfigAdjust(Idx, Dir: Integer);
var V, A, B: Single;
begin
  if (Idx < 0) or (Idx >= CN) then Exit;
  V := CfgGet(Idx) + Dir * CfgStep(Idx);
  CfgMinMax(Idx, A, B);
  if V < A then V := A;
  if V > B then V := B;
  V := Round(V * 1000) / 1000;
  CfgSet(Idx, V);
end;

procedure ResetCfg;
begin
  Defaults;
end;

function CfgName(Idx: Integer): string;
begin
  case Idx of
    0: Result := 'inv. feu';
    1: Result := 'inv. agriculture';
    2: Result := 'inv. réserves';
    3: Result := 'inv. pastoralisme';
    4: Result := 'inv. pêche';
    5: Result := 'inv. navigation';
    6: Result := 'inv. écriture';
    7: Result := 'intervalle (jours)';
    8: Result := 'diffusion';
    9: Result := 'mémoire peuple';
   10: Result := 'mutations ×';
   11: Result := 'immigrants';
  else Result := '?';
  end;
end;

function CfgText(Idx: Integer): string;
begin
  case Idx of
    0..6: Result := Format('%.3f', [CfgGet(Idx)]);
    7, 11: Result := IntToStr(Round(CfgGet(Idx)));
    8: Result := Format('%.2f', [CfgGet(Idx)]);
    9: if CfgGet(Idx) >= 0.5 then Result := 'oui' else Result := 'non';
   10: Result := Format('%.2f ×', [CfgGet(Idx)]);
  else Result := '?';
  end;
end;

function IniPath: string;
begin
  Result := ExtractFilePath(ParamStr(0)) + 'microcosme.ini';
end;

procedure SaveCfg;
var INI: TIniFile;
begin
  INI := TIniFile.Create(IniPath);
  try
    INI.WriteFloat('Reglages', 'Feu', CfgFeu);
    INI.WriteFloat('Reglages', 'Agri', CfgAgri);
    INI.WriteFloat('Reglages', 'Stock', CfgStock);
    INI.WriteFloat('Reglages', 'Past', CfgPast);
    INI.WriteFloat('Reglages', 'Peche', CfgPeche);
    INI.WriteFloat('Reglages', 'Nav', CfgNav);
    INI.WriteFloat('Reglages', 'Ecrit', CfgEcrit);
    INI.WriteInteger('Reglages', 'Gap', CfgGap);
    INI.WriteFloat('Reglages', 'Diffu', CfgDiffu);
    INI.WriteFloat('Reglages', 'Memoire', CfgMemoire);
    INI.WriteFloat('Reglages', 'Mut', CfgMut);
    INI.WriteInteger('Reglages', 'Immig', CfgImmig);
  finally INI.Free end;
end;

procedure LoadCfg;
var INI: TIniFile;
begin
  Defaults;
  if not FileExists(IniPath) then Exit;
  INI := TIniFile.Create(IniPath);
  try
    CfgFeu := INI.ReadFloat('Reglages', 'Feu', CfgFeu);
    CfgAgri := INI.ReadFloat('Reglages', 'Agri', CfgAgri);
    CfgStock := INI.ReadFloat('Reglages', 'Stock', CfgStock);
    CfgPast := INI.ReadFloat('Reglages', 'Past', CfgPast);
    CfgPeche := INI.ReadFloat('Reglages', 'Peche', CfgPeche);
    CfgNav := INI.ReadFloat('Reglages', 'Nav', CfgNav);
    CfgEcrit := INI.ReadFloat('Reglages', 'Ecrit', CfgEcrit);
    CfgGap := INI.ReadInteger('Reglages', 'Gap', CfgGap);
    CfgDiffu := INI.ReadFloat('Reglages', 'Diffu', CfgDiffu);
    CfgMemoire := INI.ReadFloat('Reglages', 'Memoire', CfgMemoire);
    CfgMut := INI.ReadFloat('Reglages', 'Mut', CfgMut);
    CfgImmig := INI.ReadInteger('Reglages', 'Immig', CfgImmig);
  finally INI.Free end;
end;

initialization
  Defaults;
end.

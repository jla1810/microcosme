unit MicroConfig;

{ Microcosme — réglages v19 : le système à DESCRIPTEURS.
  Chaque réglage = UNE ligne AddDef. Les fonctions génériques lisent
  la liste. Fin des cases à maintenir et des décalages d'indice. }

interface

uses
  System.SysUtils, System.IniFiles;

const
  CN = 13;
  BID_CFGSHOW = 200;
  BID_CFGDEF = 201;
  BID_CFGDEC = 210;
  BID_CFGINC = 230;

  O_DEC = 1;
  O_MONDE = 2;
  O_VILLES = 3;
  O_CHEF = 4;
  O_CITES = 5;
  O_AUDIO = 6;
  O_INO = 7;
  O_CER = 8;
  O_FAU = 9;
  O_LANG = 10;

var
  CfgFeu, CfgAgri, CfgStock, CfgPast, CfgPeche, CfgNav, CfgEcrit: Single;
  CfgGap: Integer;
  CfgDiffu: Single;
  CfgMemoire: Single;
  CfgMut: Single;
  CfgImmig: Integer;
  CfgEreAuto: Single = 0;
  FCfgShow: Boolean = False;
  CNALL: Integer = 0;

procedure ConfigAdjust(Idx, Dir: Integer);
procedure ResetCfg;
procedure LoadCfg;
procedure SaveCfg;
function CfgName(Idx: Integer): string;
function CfgText(Idx: Integer): string;
procedure OuvreReglages;

implementation

{$OVERFLOWCHECKS OFF}
{$RANGECHECKS OFF}

uses
  System.Math, System.Classes, System.Types,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.ComCtrls, Vcl.StdCtrls,
  MicroTypes, MicroLang;

type
  TVarKind = (vkFloat, vkInt);
  TForme = (fSimple, fOuiNon, fAutoManuel, fFois, fSecondes);

  TCfgDef = record
    VarPtr: Pointer;
    Kind: TVarKind;
    Nom: string;
    Min, Max, Step: Single;
    Dec: Integer;
    Forme: TForme;
    Onglet: Integer;
    Section: string;
    Cle: string;
  end;

var
  CfgDefs: array of TCfgDef;

procedure AddDef(AVar: Pointer; AKind: TVarKind; const ANom: string;
  AMin, AMax, AStep: Single; ADec: Integer; AForme: TForme; AOnglet: Integer;
  const ASection, ACle: string);
var
  N: Integer;
begin
  N := Length(CfgDefs);
  SetLength(CfgDefs, N + 1);
  CfgDefs[N].VarPtr := AVar;
  CfgDefs[N].Kind := AKind;
  CfgDefs[N].Nom := ANom;
  CfgDefs[N].Min := AMin;
  CfgDefs[N].Max := AMax;
  CfgDefs[N].Step := AStep;
  CfgDefs[N].Dec := ADec;
  CfgDefs[N].Forme := AForme;
  CfgDefs[N].Onglet := AOnglet;
  CfgDefs[N].Section := ASection;
  CfgDefs[N].Cle := ACle;
end;

procedure BuildDefs;
begin
  SetLength(CfgDefs, 0);
  AddDef(@CfgFeu, vkFloat, L(183), 0, 0.02, 0.001, 3, fSimple, O_DEC,
    'Reglages', 'Feu');
  AddDef(@CfgAgri, vkFloat, L(184), 0, 0.02, 0.001, 3, fSimple, O_DEC,
    'Reglages', 'Agri');
  AddDef(@CfgStock, vkFloat, L(185), 0, 0.02, 0.001, 3, fSimple, O_DEC,
    'Reglages', 'Stock');
  AddDef(@CfgPast, vkFloat, L(186), 0, 0.02, 0.001, 3, fSimple, O_DEC,
    'Reglages', 'Past');
  AddDef(@CfgPeche, vkFloat, L(187), 0, 0.02, 0.001, 3, fSimple, O_DEC,
    'Reglages', 'Peche');
  AddDef(@CfgNav, vkFloat, L(188), 0, 0.02, 0.001, 3, fSimple, O_DEC,
    'Reglages', 'Nav');
  AddDef(@CfgEcrit, vkFloat, L(189), 0, 0.02, 0.001, 3, fSimple, O_DEC,
    'Reglages', 'Ecrit');
  AddDef(@CfgGap, vkInt, L(190), 0, 10, 1, 0, fSimple, O_DEC,
    'Reglages', 'Gap');
  AddDef(@CfgDiffu, vkFloat, L(191), 0, 0.5, 0.01, 2, fSimple, O_DEC,
    'Reglages', 'Diffu');
  AddDef(@CfgMemoire, vkFloat, L(192), 0, 1, 1, 0, fOuiNon, O_DEC, 'Reglages',
    'Memoire');
  AddDef(@CfgMut, vkFloat, L(193), 0.25, 4, 0.25, 2, fFois, O_DEC,
    'Reglages', 'Mut');
  AddDef(@CfgImmig, vkInt, L(194), 0, 8, 1, 0, fSimple, O_DEC,
    'Reglages', 'Immig');
  AddDef(@CfgEreAuto, vkFloat, L(195), 0, 1, 1, 0, fAutoManuel, O_DEC,
    'Reglages', 'EreAuto');
  AddDef(@CDAY, vkFloat, L(196), 5, 120, 5, 0, fSecondes, O_MONDE,
    'Monde', 'Cday');
  AddDef(@HUTCAP, vkInt, L(197), 20, 200, 1, 0, fSimple, O_MONDE, 'Monde',
    'HutCap');
  AddDef(@MAXDOG, vkInt, L(198), 0, 30, 1, 0, fSimple, O_MONDE, 'Monde',
    'MaxDog');
  AddDef(@MAXO, vkInt, L(199), 0, 12, 1, 0, fSimple, O_MONDE, 'Monde',
    'MaxOurs');
  AddDef(@MAXM, vkInt, L(200), 5, 120, 1, 0, fSimple, O_MONDE, 'Monde',
    'MaxMout');
  AddDef(@VILLE_SEUIL, vkInt, L(201), 5, 30, 1, 0, fSimple, O_VILLES,
    'Villes', 'Seuil');
  AddDef(@VILLE_NIVEAU3, vkInt, L(202), 10, 40, 1, 0, fSimple, O_VILLES,
    'Villes', 'Niveau3');
  AddDef(@VILLE_NIVEAU4, vkInt, L(203), 15, 60, 1, 0, fSimple, O_VILLES,
    'Villes', 'Niveau4');
  AddDef(@VILLE_RAYON, vkFloat, L(204), 8, 24, 1, 0, fSimple, O_VILLES,
    'Villes', 'Rayon');
  AddDef(@HAMEAU_DIST, vkFloat, L(205), 6, 20, 1, 0, fSimple, O_VILLES,
    'Villes', 'Hameau');
  AddDef(@MIGR_DIST, vkFloat, L(206), 20, 120, 1, 0, fSimple, O_VILLES,
    'Villes', 'MigrDist');
  AddDef(@EXODE_2, vkFloat, L(207), 0, 0.6, 0.01, 2, fSimple, O_VILLES,
    'Villes', 'Exode2');
  AddDef(@EXODE_3, vkFloat, L(208), 0, 0.6, 0.01, 2, fSimple, O_VILLES,
    'Villes', 'Exode3');
  AddDef(@EXODE_4, vkFloat, L(209), 0, 0.6, 0.01, 2, fSimple, O_VILLES,
    'Villes', 'Exode4');
  AddDef(@EXODE_5, vkFloat, L(210), 0, 0.6, 0.01, 2, fSimple, O_VILLES,
    'Villes', 'Exode5');
  AddDef(@EXODE_6, vkFloat, L(211), 0, 0.6, 0.01, 2, fSimple, O_VILLES,
    'Villes', 'Exode6');
  AddDef(@ROAD_DIST, vkFloat, L(213), 100, 4000, 10, 0, fSimple, O_VILLES,
    'Villes', 'RoadDist');
  AddDef(@ROAD_CROISSANCE, vkInt, L(214), 1, 10, 1, 0, fSimple, O_VILLES,
    'Villes', 'RoadCroiss');
  AddDef(@ROUTE_MAX, vkInt, L(215), 2, 30, 1, 0, fSimple, O_VILLES, 'Villes',
    'RoadMax');
  AddDef(@EXODE_7, vkFloat, L(212), 0, 0.6, 0.01, 2, fSimple, O_VILLES,
    'Villes', 'Exode7');
  AddDef(@CHEF_TECH, vkFloat, L(216), 0, 20, 0.5, 1, fFois, O_CHEF,
    'Chef', 'Techs');
  AddDef(@CHEF_INNO, vkFloat, L(217), 0, 20, 0.5, 1, fFois, O_CHEF, 'Chef',
    'Inventions');
  AddDef(@CHEF_CULT, vkFloat, L(218), 0, 20, 0.5, 1, fFois, O_CHEF, 'Chef',
    'Culture');
  AddDef(@CHEF_SAGE, vkFloat, L(219), 0, 20, 0.5, 1, fFois, O_CHEF, 'Chef',
    'Sagesse');
  AddDef(@CHILDHOOD, vkInt, L(220), 5, 30, 1, 0, fSimple, O_CHEF, 'Monde',
    'Majorite');
  AddDef(@CITES_FINAL, vkInt, L(246), 1, 8, 1, 0, fSimple, O_CITES, 'Monde',
    'CitesFinal');
  AddDef(@VoxVoix, vkFloat, L(238), 0, 1, 0.01, 2, fSimple, O_AUDIO,
    'Audio', 'Voix');
  AddDef(@VoxTamb, vkFloat, L(239), 0, 1, 0.01, 2, fSimple, O_AUDIO, 'Audio',
    'Tambour');
  AddDef(@VoxAmbi, vkFloat, L(240), 0, 1, 0.01, 2, fSimple, O_AUDIO, 'Audio',
    'Ambiance');
  AddDef(@VoxFeu, vkFloat, L(241), 0, 1, 0.01, 2, fSimple, O_AUDIO,
    'Audio', 'Feu');
  AddDef(@VoxGril, vkFloat, L(242), 0, 1, 0.01, 2, fSimple, O_AUDIO, 'Audio',
    'Grillons');
  AddDef(@VoxEvent, vkFloat, L(243), 0, 1, 0.01, 2, fSimple, O_AUDIO, 'Audio',
    'Events');
  AddDef(@NB_SAPIENS0, vkInt, L(245), 0, 50, 1, 0, fSimple, O_MONDE, 'Monde',
    'Sapiens0');
  // ── onglet Inventions (le tempo culturel) ──
  AddDef(@INNO_CHANCE_V, vkFloat, L(253), 0.001, 0.10, 0.001, 3, fSimple, O_INO,
    'Inventions', 'Chance');
  AddDef(@TORCHE_NUIT, vkFloat, L(254), 0.1, 0.9, 0.05, 2, fSimple, O_INO,
    'Inventions', 'TorcheNuit');
  AddDef(@PEAUSS_NUIT, vkFloat, L(255), 0.1, 0.9, 0.05, 2, fSimple, O_INO,
    'Inventions', 'PeaussNuit');
  AddDef(@BROCHETTE_NUIT, vkFloat, L(256), 0.1, 0.9, 0.05, 2, fSimple, O_INO,
    'Inventions', 'BrochetteNuit');
  AddDef(@BOUGIE_NUIT, vkFloat, L(257), 0.1, 0.9, 0.05, 2, fSimple, O_INO,
    'Inventions', 'BougieNuit');
  AddDef(@BOSSOLE_NUIT, vkFloat, L(258), 0.1, 0.9, 0.05, 2, fSimple, O_INO,
    'Inventions', 'BossoleNuit');
  AddDef(@PARCHEMIN_NUIT, vkFloat, L(259), 0.1, 0.9, 0.05, 2, fSimple, O_INO,
    'Inventions', 'ParcheminNuit');
  AddDef(@LUNETTE_NUIT, vkFloat, L(260), 0.1, 0.9, 0.05, 2, fSimple, O_INO,
    'Inventions', 'LunetteNuit');
  AddDef(@VIOLON_NUIT, vkFloat, L(261), 0.1, 0.9, 0.05, 2, fSimple, O_INO,
    'Inventions', 'ViolonNuit');
  AddDef(@THEATRE_FOULE, vkInt, L(262), 2, 10, 1, 0, fSimple, O_INO,
    'Inventions', 'TheatreFoule');
  AddDef(@VIOLON_FOULE, vkInt, L(263), 2, 10, 1, 0, fSimple, O_INO,
    'Inventions', 'ViolonFoule');
  AddDef(@RADIO_FOULE, vkInt, L(264), 2, 10, 1, 0, fSimple, O_INO, 'Inventions',
    'RadioFoule');
  AddDef(@TAMBOUR_EAU, vkInt, L(265), 1, 5, 1, 0, fSimple, O_INO, 'Inventions',
    'TambourEau');
  // ── onglet Cerveau (le tempo neuronal) ──
  AddDef(@BRAIN_BASE, vkFloat, L(267), 0, 1, 0.01, 2, fSimple, O_CER, 'Cerveau', 'Base');
  AddDef(@BRAIN_SAUT, vkFloat, L(268), 0, 0.5, 0.01, 2, fSimple, O_CER, 'Cerveau', 'Saut');
  AddDef(@BRAIN_VOIX, vkFloat, L(269), 0, 1, 0.01, 2, fSimple, O_CER, 'Cerveau', 'Voix');
  AddDef(@BRAIN_SAUT2, vkFloat, L(270), 0, 0.5, 0.01, 2, fSimple, O_CER, 'Cerveau', 'SautVoix');
  AddDef(@BRAIN_MENTOR, vkFloat, L(271), 0, 1, 0.05, 2, fSimple, O_CER, 'Cerveau', 'Mentor');
  AddDef(@BRAIN_GLISSE, vkFloat, L(272), 0, 1, 0.01, 2, fSimple, O_CER, 'Cerveau', 'Glisse');
  AddDef(@BRAIN_GAIN, vkFloat, L(273), 0, 0.5, 0.005, 3, fSimple, O_CER, 'Cerveau', 'Gain');
  AddDef(@MEMLIFE, vkFloat, L(274), 10, 300, 10, 0, fSimple, O_CER, 'Cerveau', 'MemLife');
  AddDef(@MEMMAX, vkInt, L(275), 1, 20, 1, 0, fSimple, O_CER, 'Cerveau', 'MemMax');
    // ── onglet Faune & langage ──
  AddDef(@MORD_LOUP, vkFloat, L(277), 10, 150, 5, 0, fSimple, O_FAU, 'Faune', 'MordLoup');
  AddDef(@MORD_OURS, vkFloat, L(278), 10, 200, 5, 0, fSimple, O_FAU, 'Faune', 'MordOurs');
  AddDef(@ATK_CD, vkFloat, L(279), 0.3, 5, 0.1, 1, fSimple, O_FAU, 'Faune', 'AtkCd');
  AddDef(@REPRO_VACHE, vkFloat, L(280), 50, 120, 2, 0, fSimple, O_FAU, 'Faune', 'ReproVache');
  AddDef(@REPRO_LOUP, vkFloat, L(281), 50, 150, 2, 0, fSimple, O_FAU, 'Faune', 'ReproLoup');
  AddDef(@REPRO_OURS, vkFloat, L(282), 60, 200, 5, 0, fSimple, O_FAU, 'Faune', 'ReproOurs');
  AddDef(@CRI_PORTEE, vkFloat, L(283), 5, 40, 1, 0, fSimple, O_FAU, 'Langage', 'CriPortee');
  AddDef(@CRI_SEUIL, vkFloat, L(284), 0.1, 0.6, 0.05, 2, fSimple, O_FAU, 'Langage', 'CriSeuil');

  CNALL := Length(CfgDefs);
end;

function GetVar(const D: TCfgDef): Single;
begin
  if D.Kind = vkInt then
    Result := PInteger(D.VarPtr)^
  else
    Result := PSingle(D.VarPtr)^;
end;

procedure SetVar(const D: TCfgDef; V: Single);
begin
  if D.Kind = vkInt then
    PInteger(D.VarPtr)^ := Round(V)
  else
    PSingle(D.VarPtr)^ := V;
end;

procedure Defaults;
begin
  CfgFeu := 0.002;
  CfgAgri := 0.002;
  CfgStock := 0.002;
  CfgPast := 0.002;
  CfgPeche := 0.002;
  CfgNav := 0.0015;
  CfgEcrit := 0.001;
  CfgGap := 3;
  CfgDiffu := 0.06;
  CfgMemoire := 1.0;
  CfgMut := 1.0;
  CfgImmig := 3;
  CfgEreAuto := 0;
  CDAY := 40;
  CHILDHOOD := 10;
  HUTCAP := 84;
  MAXDOG := 12;
  MAXO := 6;
  MAXM := 60;
  VILLE_SEUIL := 10;
  VILLE_NIVEAU3 := 18;
  VILLE_NIVEAU4 := 28;
  VILLE_RAYON := 14.0;
  HAMEAU_DIST := 12.0;
  MIGR_DIST := 60.0;
  EXODE_2 := 0.04;
  EXODE_3 := 0.08;
  EXODE_4 := 0.14;
  EXODE_5 := 0.20;
  EXODE_6 := 0.28;
  EXODE_7 := 0.35;
  ROAD_DIST := 200.0;
  ROAD_CROISSANCE := 3;
  ROUTE_MAX := 12;
  CHEF_TECH := 1.0;
  CHEF_INNO := 1.5;
  CHEF_CULT := 8.0;
  CHEF_SAGE := 3.0;
end;

function CfgGet(Idx: Integer): Single;
begin
  if (Idx >= 0) and (Idx < Length(CfgDefs)) then
    Result := GetVar(CfgDefs[Idx])
  else
    Result := 0;
end;

procedure CfgSet(Idx: Integer; V: Single);
begin
  if (Idx >= 0) and (Idx < Length(CfgDefs)) then
    SetVar(CfgDefs[Idx], V);
end;

function CfgStep(Idx: Integer): Single;
begin
  if (Idx >= 0) and (Idx < Length(CfgDefs)) then
    Result := CfgDefs[Idx].Step
  else
    Result := 0.001;
end;

procedure CfgMinMax(Idx: Integer; out A, B: Single);
begin
  if (Idx >= 0) and (Idx < Length(CfgDefs)) then
  begin
    A := CfgDefs[Idx].Min;
    B := CfgDefs[Idx].Max;
  end
  else
  begin
    A := 0;
    B := 1;
  end;
end;

procedure ConfigAdjust(Idx, Dir: Integer);
var
  V, A, B: Single;
begin
  if (Idx < 0) or (Idx >= CNALL) then
    Exit;
  V := CfgGet(Idx) + Dir * CfgStep(Idx);
  CfgMinMax(Idx, A, B);
  if V < A then
    V := A;
  if V > B then
    V := B;
  V := Round(V * 1000) / 1000;
  CfgSet(Idx, V);
end;

procedure ResetCfg;
begin
  Defaults;
end;

function CfgName(Idx: Integer): string;
begin
  if (Idx >= 0) and (Idx < Length(CfgDefs)) then
    Result := CfgDefs[Idx].Nom
  else
    Result := '?';
end;

function CfgText(Idx: Integer): string;
var
  D: TCfgDef;
  V: Single;
begin
  if (Idx < 0) or (Idx >= Length(CfgDefs)) then
  begin
    Result := '?';
    Exit;
  end;
  D := CfgDefs[Idx];
  V := GetVar(D);
  case D.Forme of
    fOuiNon:
      if V >= 0.5 then
        Result := L(225)
      else
        Result := L(226);
    fAutoManuel:
      if V >= 0.5 then
        Result := L(227)
      else
        Result := L(228);
    fFois:
      Result := Format('%.*f ×', [D.Dec, V]);
    fSecondes:
      Result := Format('%.0f s', [V]);
  else
    if D.Dec = 0 then
      Result := IntToStr(Round(V))
    else
      Result := Format('%.*f', [D.Dec, V]);
  end;
end;

function IniPath: string;
begin
  Result := ExtractFilePath(ParamStr(0)) + 'microcosme.ini';
end;

procedure SaveCfg;
var
  INI: TIniFile;
  I: Integer;
  D: TCfgDef;
  V: Single;
begin
  INI := TIniFile.Create(IniPath);
  try
    for I := 0 to High(CfgDefs) do
    begin
      D := CfgDefs[I];
      V := GetVar(D);
      if D.Kind = vkInt then
        INI.WriteInteger(D.Section, D.Cle, Round(V))
      else
        INI.WriteFloat(D.Section, D.Cle, V);
    end;
  finally
    INI.Free;
  end;
end;

procedure LoadCfg;
var
  INI: TIniFile;
  I: Integer;
  D: TCfgDef;
  V: Single;
begin
  Defaults;
  if not FileExists(IniPath) then
    Exit;
  INI := TIniFile.Create(IniPath);
  try
    for I := 0 to High(CfgDefs) do
    begin
      D := CfgDefs[I];
      V := GetVar(D);
      if D.Kind = vkInt then
        SetVar(D, INI.ReadInteger(D.Section, D.Cle, Round(V)))
      else
        SetVar(D, INI.ReadFloat(D.Section, D.Cle, V));
    end;
  finally
    INI.Free;
  end;
end;

type
  TRegForm = class(TForm)
  public
    Vals: array of TLabel;
    procedure MoinsClick(Sender: TObject);
    procedure PlusClick(Sender: TObject);
    procedure DefClick(Sender: TObject);
    procedure FermeClick(Sender: TObject);
    procedure FermeForm(Sender: TObject; var Action: TCloseAction);
    procedure RefreshVals;
  end;

var
  FReg: TRegForm = nil;

procedure TRegForm.RefreshVals;
var
  I: Integer;
begin
  for I := 0 to High(Vals) do
    if Vals[I] <> nil then
      Vals[I].Caption := CfgText(I);
end;

procedure TRegForm.MoinsClick(Sender: TObject);
begin
  ConfigAdjust(TComponent(Sender).Tag, -1);
  RefreshVals;
  SaveCfg;
end;

procedure TRegForm.PlusClick(Sender: TObject);
begin
  ConfigAdjust(TComponent(Sender).Tag, 1);
  RefreshVals;
  SaveCfg;
end;

procedure TRegForm.DefClick(Sender: TObject);
begin
  ResetCfg;
  RefreshVals;
  SaveCfg;
end;

procedure TRegForm.FermeClick(Sender: TObject);
begin
  Close;
end;

procedure TRegForm.FermeForm(Sender: TObject; var Action: TCloseAction);
begin
  Action := caFree;
  FReg := nil;
end;

function LigneReg(SH: TWinControl; Y, Idx: Integer; out LV: TLabel): Integer;
var
  LN, LT: TLabel;
  BM, BP: TButton;
begin
  LN := TLabel.Create(SH);
  LN.Parent := SH;
  LN.Left := 14;
  LN.Top := Y + 5;
  LN.Caption := CfgName(Idx);
  LT := TLabel.Create(SH);
  LT.Parent := SH;
  LT.Left := 226;
  LT.Top := Y + 5;
  LT.Width := 96;
  LT.Alignment := taRightJustify;
  LT.Caption := CfgText(Idx);
  LV := LT;
  BM := TButton.Create(SH);
  BM.Parent := SH;
  BM.Left := 336;
  BM.Top := Y;
  BM.Width := 36;
  BM.Height := 25;
  BM.Caption := '-';
  BM.Tag := Idx;
  BM.OnClick := TRegForm(FReg).MoinsClick;
  BP := TButton.Create(SH);
  BP.Parent := SH;
  BP.Left := 376;
  BP.Top := Y;
  BP.Width := 36;
  BP.Height := 25;
  BP.Caption := '+';
  BP.Tag := Idx;
  BP.OnClick := TRegForm(FReg).PlusClick;
  Result := Y + 31;
end;

function TitreOnglet(O: Integer): string;
begin
  case O of
    O_DEC:
      Result := L(221);
    O_MONDE:
      Result := L(222);
    O_VILLES:
      Result := L(223);
    O_CHEF:
      Result := L(224);
    O_CITES:
      Result := L(247);
    O_AUDIO:
      Result := 'Audio';
    O_INO:
      Result := L(266);
    O_CER:
      Result := L(276);   // 'cerveau' (à créer en L275 — voir plus bas)
    O_FAU:
      Result := L(285);
  else
    Result := '?';
  end;
end;

procedure OngletAuto(PC: TPageControl; O: Integer);
var
  SH: TTabSheet;
  Y, I: Integer;
begin
  SH := TTabSheet.Create(PC);
  SH.PageControl := PC;
  SH.Caption := TitreOnglet(O);
  Y := 12;
  for I := 0 to High(CfgDefs) do
    if CfgDefs[I].Onglet = O then
      Y := LigneReg(SH, Y, I, FReg.Vals[I]);
end;

procedure OuvreReglages;
var
  PC: TPageControl;
  BD, BF: TButton;
begin
  if FReg <> nil then
  begin
    FReg.BringToFront;
    Exit;
  end;
  FReg := TRegForm.CreateNew(nil);
  with FReg do
  begin
    Caption := L(231);
    ClientWidth := 600;
    ClientHeight := 560;
    Position := poScreenCenter;
    BorderStyle := bsSingle;
    BorderIcons := [biSystemMenu];
    OnClose := FermeForm;
  end;
  SetLength(FReg.Vals, Length(CfgDefs));
  PC := TPageControl.Create(FReg);
  PC.Parent := FReg;
  PC.Left := 8;
  PC.Top := 8;
  PC.Width := 600;
  PC.Height := 504;
  OngletAuto(PC, O_DEC);
  OngletAuto(PC, O_MONDE);
  OngletAuto(PC, O_VILLES);
  OngletAuto(PC, O_CHEF);
  OngletAuto(PC, O_CITES);
  OngletAuto(PC, O_AUDIO);
  OngletAuto(PC, O_INO);
  OngletAuto(PC, O_CER);
  OngletAuto(PC, O_FAU);
  BD := TButton.Create(FReg);
  BD.Parent := FReg;
  BD.Left := 8;
  BD.Top := 520;
  BD.Width := 180;
  BD.Caption := L(229);
  BD.OnClick := FReg.DefClick;
  BF := TButton.Create(FReg);
  BF.Parent := FReg;
  BF.Left := 352;
  BF.Top := 520;
  BF.Width := 80;
  BF.Caption := L(230);
  BF.OnClick := FReg.FermeClick;
  FReg.RefreshVals;
  FReg.Show;
end;

initialization

BuildDefs;
Defaults;

end.

unit MicroConfig;

{ Microcosme — réglages : le moteur (indices 0..12 = le panneau carnet
  historique ; 13..36 = les paramètres du monde), la fenêtre à onglets
  (F2 / bouton « réglages »), la sauvegarde microcosme.ini.
  v16 : + OuvreReglages — 4 onglets (Découvertes / Le monde /
        Villes & routes / Le chef) ; CDAY, CHILDHOOD, VILLE_*, ROAD_*,
        HAMEAU_DIST, MIGR_DIST, EXODE_*, HUTCAP, MAXDOG/MAXO/MAXM et les
        poids du chef deviennent réglables EN DIRECT (variables de
        MicroTypes, lues par la sim au tic suivant). }

interface

uses
  System.SysUtils, System.IniFiles;

const
  CN = 13;                 { les paramètres historiques du panneau carnet }
  CNALL = 37;              { tous les paramètres (0..36) }
  BID_CFGSHOW = 200;       { bouton "réglages" → ouvre la fenêtre }
  BID_CFGDEF  = 201;       { bouton "tout par défaut" }
  BID_CFGDEC  = 210;       { 210..210+CN-1 : boutons [-] du panneau }
  BID_CFGINC  = 230;       { 230..230+CN-1 : boutons [+] du panneau }

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
  { ères }
  CfgEreAuto: Single = 0;  { 0 = passage manuel (bouton doré) · 1 = automatique }

  FCfgShow: Boolean = False;   { panneau carnet visible ? }

procedure ConfigAdjust(Idx, Dir: Integer);
procedure ResetCfg;
procedure LoadCfg;
procedure SaveCfg;
function CfgName(Idx: Integer): string;
function CfgText(Idx: Integer): string;
procedure OuvreReglages;     { ★v16 : la fenêtre à onglets }

implementation

{$OVERFLOWCHECKS OFF}
{$RANGECHECKS OFF}

uses
  System.Math, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.ComCtrls, Vcl.StdCtrls,
  MicroTypes;    // les variables du monde — AUCUN cycle possible

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
  CfgEreAuto := 0;
  { les paramètres du monde vivent dans MicroTypes }
  CDAY := 40;   CHILDHOOD := 10;
  HUTCAP := 84; MAXDOG := 12; MAXO := 6; MAXM := 60;
  VILLE_SEUIL := 10; VILLE_NIVEAU3 := 18; VILLE_NIVEAU4 := 28;
  VILLE_RAYON := 14.0; HAMEAU_DIST := 12.0; MIGR_DIST := 60.0;
  EXODE_2 := 0.04; EXODE_3 := 0.08; EXODE_4 := 0.14;
  EXODE_5 := 0.20; EXODE_6 := 0.28;
  ROAD_DIST := 200.0; ROAD_CROISSANCE := 3; ROUTE_MAX := 12;
  CHEF_TECH := 1.0; CHEF_INNO := 1.5; CHEF_CULT := 8.0; CHEF_SAGE := 3.0;
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
   12: Result := CfgEreAuto;
   13: Result := CDAY;     14: Result := HUTCAP;
   15: Result := MAXDOG;   16: Result := MAXO;
   17: Result := MAXM;     18: Result := VILLE_SEUIL;
   19: Result := VILLE_NIVEAU3;  20: Result := VILLE_NIVEAU4;
   21: Result := VILLE_RAYON;    22: Result := HAMEAU_DIST;
   23: Result := MIGR_DIST;      24: Result := EXODE_2;
   25: Result := EXODE_3;        26: Result := EXODE_4;
   27: Result := EXODE_5;        28: Result := EXODE_6;
   29: Result := ROAD_DIST;      30: Result := ROAD_CROISSANCE;
   31: Result := ROUTE_MAX;      32: Result := CHEF_TECH;
   33: Result := CHEF_INNO;      34: Result := CHEF_CULT;
   35: Result := CHEF_SAGE;      36: Result := CHILDHOOD;
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
   12: CfgEreAuto := V;
   13: CDAY := V;          14: HUTCAP := Round(V);
   15: MAXDOG := Round(V); 16: MAXO := Round(V);
   17: MAXM := Round(V);   18: VILLE_SEUIL := Round(V);
   19: VILLE_NIVEAU3 := Round(V);  20: VILLE_NIVEAU4 := Round(V);
   21: VILLE_RAYON := V;   22: HAMEAU_DIST := V;
   23: MIGR_DIST := V;     24: EXODE_2 := V;
   25: EXODE_3 := V;       26: EXODE_4 := V;
   27: EXODE_5 := V;       28: EXODE_6 := V;
   29: ROAD_DIST := V;     30: ROAD_CROISSANCE := Round(V);
   31: ROUTE_MAX := Round(V);      32: CHEF_TECH := V;
   33: CHEF_INNO := V;     34: CHEF_CULT := V;
   35: CHEF_SAGE := V;     36: CHILDHOOD := V;
  end;
end;

function CfgStep(Idx: Integer): Single;
begin
  case Idx of
    0..6: Result := 0.001;
    7, 9, 11, 12: Result := 1;
    8: Result := 0.01;
   10: Result := 0.25;
   13: Result := 5;                 // la durée du jour
   14, 18, 19, 20: Result := 1;     // les seuils, le plafond de huttes
   15..17: Result := 1;             // les plafonds de faune
   21, 22, 23: Result := 1;         // rayon, hameau, exode (cases)
   24..28: Result := 0.01;          // les probas d'exode
   29: Result := 10;                // la portée des routes
   30, 31: Result := 1;             // vitesse et plafond de routes
   32..35: Result := 0.5;           // les poids du chef
   36: Result := 1;                 // la majorité
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
   12:    begin A := 0;     B := 1    end;
   13:    begin A := 5;     B := 120  end;
   14:    begin A := 20;    B := 200  end;
   15:    begin A := 0;     B := 30   end;
   16:    begin A := 0;     B := 12   end;
   17:    begin A := 5;     B := 120  end;
   18:    begin A := 5;     B := 30   end;
   19:    begin A := 10;    B := 40   end;
   20:    begin A := 15;    B := 60   end;
   21:    begin A := 8;     B := 24   end;
   22:    begin A := 6;     B := 20   end;
   23:    begin A := 20;    B := 120  end;
   24..28: begin A := 0;    B := 0.6  end;
   29:    begin A := 50;    B := 400  end;
   30:    begin A := 1;     B := 10   end;
   31:    begin A := 2;     B := 30   end;
   32..35: begin A := 0;    B := 20   end;
   36:    begin A := 5;     B := 30   end;
  else begin A := 0; B := 1 end;
  end;
end;

procedure ConfigAdjust(Idx, Dir: Integer);
var V, A, B: Single;
begin
  if (Idx < 0) or (Idx >= CNALL) then Exit;
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
   12: Result := 'ère auto';
   13: Result := 'durée du jour (s)';
   14: Result := 'plafond huttes';
   15: Result := 'chiens max';
   16: Result := 'ours max';
   17: Result := 'moutons max';
   18: Result := 'seuil bourg (foyers)';
   19: Result := 'seuil ville';
   20: Result := 'seuil cité';
   21: Result := 'rayon de ville';
   22: Result := 'hameau : portée';
   23: Result := 'exode : distance';
   24: Result := 'exode ère 2';
   25: Result := 'exode ère 3';
   26: Result := 'exode ère 4';
   27: Result := 'exode ère 5';
   28: Result := 'exode ère 6';
   29: Result := 'routes : portée';
   30: Result := 'routes : vitesse';
   31: Result := 'routes : plafond';
   32: Result := 'chef : techs ×';
   33: Result := 'chef : inventions ×';
   34: Result := 'chef : culture ×';
   35: Result := 'chef : sagesse ×';
   36: Result := 'majorité (âge)';
  else Result := '?';
  end;
end;

function CfgText(Idx: Integer): string;
begin
  case Idx of
    0..6: Result := Format('%.3f', [CfgGet(Idx)]);
    7, 11, 14, 15, 16, 17, 18, 19, 20, 30, 31, 36:
        Result := IntToStr(Round(CfgGet(Idx)));
    8, 24..28: Result := Format('%.2f', [CfgGet(Idx)]);
    9: if CfgGet(Idx) >= 0.5 then Result := 'oui' else Result := 'non';
   10: Result := Format('%.2f ×', [CfgGet(Idx)]);
   12: if CfgGet(Idx) >= 0.5 then Result := 'auto' else Result := 'manuel';
   13: Result := Format('%.0f s', [CfgGet(Idx)]);
   21, 22, 23, 29: Result := Format('%.0f', [CfgGet(Idx)]);
   32..35: Result := Format('%.1f ×', [CfgGet(Idx)]);
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
    INI.WriteInteger('Reglages', 'EreAuto', Round(CfgEreAuto));
    INI.WriteFloat('Monde', 'Cday', CDAY);
    INI.WriteFloat('Monde', 'Majorite', CHILDHOOD);
    INI.WriteInteger('Monde', 'HutCap', HUTCAP);
    INI.WriteInteger('Monde', 'MaxDog', MAXDOG);
    INI.WriteInteger('Monde', 'MaxOurs', MAXO);
    INI.WriteInteger('Monde', 'MaxMout', MAXM);
    INI.WriteInteger('Villes', 'Seuil', VILLE_SEUIL);
    INI.WriteInteger('Villes', 'Niveau3', VILLE_NIVEAU3);
    INI.WriteInteger('Villes', 'Niveau4', VILLE_NIVEAU4);
    INI.WriteFloat('Villes', 'Rayon', VILLE_RAYON);
    INI.WriteFloat('Villes', 'Hameau', HAMEAU_DIST);
    INI.WriteFloat('Villes', 'MigrDist', MIGR_DIST);
    INI.WriteFloat('Villes', 'Exode2', EXODE_2);
    INI.WriteFloat('Villes', 'Exode3', EXODE_3);
    INI.WriteFloat('Villes', 'Exode4', EXODE_4);
    INI.WriteFloat('Villes', 'Exode5', EXODE_5);
    INI.WriteFloat('Villes', 'Exode6', EXODE_6);
    INI.WriteFloat('Villes', 'RoadDist', ROAD_DIST);
    INI.WriteInteger('Villes', 'RoadCroiss', ROAD_CROISSANCE);
    INI.WriteInteger('Villes', 'RoadMax', ROUTE_MAX);
    INI.WriteFloat('Chef', 'Techs', CHEF_TECH);
    INI.WriteFloat('Chef', 'Inventions', CHEF_INNO);
    INI.WriteFloat('Chef', 'Culture', CHEF_CULT);
    INI.WriteFloat('Chef', 'Sagesse', CHEF_SAGE);
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
    CfgEreAuto := INI.ReadInteger('Reglages', 'EreAuto', Round(CfgEreAuto));
    CDAY := INI.ReadFloat('Monde', 'Cday', CDAY);
    CHILDHOOD := INI.ReadFloat('Monde', 'Majorite', CHILDHOOD);
    HUTCAP := INI.ReadInteger('Monde', 'HutCap', HUTCAP);
    MAXDOG := INI.ReadInteger('Monde', 'MaxDog', MAXDOG);
    MAXO := INI.ReadInteger('Monde', 'MaxOurs', MAXO);
    MAXM := INI.ReadInteger('Monde', 'MaxMout', MAXM);
    VILLE_SEUIL := INI.ReadInteger('Villes', 'Seuil', VILLE_SEUIL);
    VILLE_NIVEAU3 := INI.ReadInteger('Villes', 'Niveau3', VILLE_NIVEAU3);
    VILLE_NIVEAU4 := INI.ReadInteger('Villes', 'Niveau4', VILLE_NIVEAU4);
    VILLE_RAYON := INI.ReadFloat('Villes', 'Rayon', VILLE_RAYON);
    HAMEAU_DIST := INI.ReadFloat('Villes', 'Hameau', HAMEAU_DIST);
    MIGR_DIST := INI.ReadFloat('Villes', 'MigrDist', MIGR_DIST);
    EXODE_2 := INI.ReadFloat('Villes', 'Exode2', EXODE_2);
    EXODE_3 := INI.ReadFloat('Villes', 'Exode3', EXODE_3);
    EXODE_4 := INI.ReadFloat('Villes', 'Exode4', EXODE_4);
    EXODE_5 := INI.ReadFloat('Villes', 'Exode5', EXODE_5);
    EXODE_6 := INI.ReadFloat('Villes', 'Exode6', EXODE_6);
    ROAD_DIST := INI.ReadFloat('Villes', 'RoadDist', ROAD_DIST);
    ROAD_CROISSANCE := INI.ReadInteger('Villes', 'RoadCroiss', ROAD_CROISSANCE);
    ROUTE_MAX := INI.ReadInteger('Villes', 'RoadMax', ROUTE_MAX);
    CHEF_TECH := INI.ReadFloat('Chef', 'Techs', CHEF_TECH);
    CHEF_INNO := INI.ReadFloat('Chef', 'Inventions', CHEF_INNO);
    CHEF_CULT := INI.ReadFloat('Chef', 'Culture', CHEF_CULT);
    CHEF_SAGE := INI.ReadFloat('Chef', 'Sagesse', CHEF_SAGE);
  finally INI.Free end;
end;

{ ★v16 — la fenêtre à onglets. 100 % code (CreateNew, conv. du projet),
  live : chaque clic ajuste UNE variable que la sim lit au tic suivant,
  et sauvegarde l'INI. }

type
  TRegForm = class(TForm)
  public
    Vals: array[0..CNALL - 1] of TLabel;
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
var I: Integer;
begin
  for I := 0 to CNALL - 1 do
    if Vals[I] <> nil then Vals[I].Caption := CfgText(I);
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

{ construit une ligne : nom · valeur · [-] [+] — renvoie le Y du bas }
function LigneReg(SH: TWinControl; Y, Idx: Integer; out LV: TLabel): Integer;
var LN, LT: TLabel;
    BM, BP: TButton;
begin
  LN := TLabel.Create(SH);
  LN.Parent := SH; LN.Left := 14; LN.Top := Y + 5;
  LN.Caption := CfgName(Idx);
  LT := TLabel.Create(SH);
  LT.Parent := SH; LT.Left := 226; LT.Top := Y + 5; LT.Width := 96;
  LT.Alignment := taRightJustify;
  LT.Caption := CfgText(Idx);
  LV := LT;
  BM := TButton.Create(SH);
  BM.Parent := SH; BM.Left := 336; BM.Top := Y; BM.Width := 36; BM.Height := 25;
  BM.Caption := '-'; BM.Tag := Idx; BM.OnClick := TRegForm(FReg).MoinsClick;
  BP := TButton.Create(SH);
  BP.Parent := SH; BP.Left := 376; BP.Top := Y; BP.Width := 36; BP.Height := 25;
  BP.Caption := '+'; BP.Tag := Idx; BP.OnClick := TRegForm(FReg).PlusClick;
  Result := Y + 31;
end;

procedure Onglet(PC: TPageControl; const Titre: string; D1, D2: Integer);
var SH: TTabSheet;
    Y, I: Integer;
begin
  SH := TTabSheet.Create(PC);
  SH.PageControl := PC;
  SH.Caption := Titre;
  Y := 12;
  for I := D1 to D2 do
    Y := LigneReg(SH, Y, I, FReg.Vals[I]);
end;

procedure OuvreReglages;
var PC: TPageControl;
    BD, BF: TButton;
begin
  if FReg <> nil then begin FReg.BringToFront; Exit end;
  FReg := TRegForm.CreateNew(nil);
  with FReg do begin
    Caption := 'Microcosme — Réglages du monde';
    ClientWidth := 440; ClientHeight := 530;
    Position := poScreenCenter;
    BorderStyle := bsSingle;
    BorderIcons := [biSystemMenu];
    OnClose := FermeForm;
  end;
  PC := TPageControl.Create(FReg);
  PC.Parent := FReg;
  PC.Left := 8; PC.Top := 8; PC.Width := 424; PC.Height := 474;
  Onglet(PC, 'Découvertes', 0, 12);
  Onglet(PC, 'Le monde', 13, 17);
  Onglet(PC, 'Villes & routes', 18, 31);
  Onglet(PC, 'Le chef', 32, 36);
  BD := TButton.Create(FReg);
  BD.Parent := FReg; BD.Left := 8; BD.Top := 490; BD.Width := 180;
  BD.Caption := 'Tout par défaut'; BD.OnClick := FReg.DefClick;
  BF := TButton.Create(FReg);
  BF.Parent := FReg; BF.Left := 352; BF.Top := 490; BF.Width := 80;
  BF.Caption := 'Fermer'; BF.OnClick := FReg.FermeClick;
  FReg.RefreshVals;
  FReg.Show;
end;

initialization
  Defaults;
end.

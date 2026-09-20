unit MicroTypes;

{ Microcosme — types, constantes, état global.
  v15 (Phase A villes) : TCity (centre, nom du lexique, niveau, rayon),
  Cities globale, THut.Ville (rattachement). Set techs 64 bits inchangé. }

interface

uses
  System.SysUtils, System.Classes, System.Math, System.Generics.Collections,
  Winapi.Windows, Vcl.Graphics, System.SyncObjs, Vcl.ExtCtrls;

type

  THut = class;
  TFish = class;
  TMark = class;
  TCity = class;

  TPlant = class
    X, Y, S: Single;
    Cell: Integer;
  end;

  THut = class
    X, Y: Single;
    Fire: Boolean;
    Cult: Boolean;
    Stock: Single;
    Ville: TCity;          // ★A1 : ville de rattachement (nil = isolée)
  end;

  TCity = class
    X, Y: Single;          // centre (moyenne des huttes rattachées)
    Nom: string;           // du lexique émergent du monde
    Niveau: Integer;       // 2 bourg · 3 ville · 4 cité
    Jour: Integer;         // jour de fondation
    Rayon: Single;         // rayon de rattachement
  end;

  TFish = class
    X, Y: Single;
    Angle: Single;
    Deep: Boolean;
    S: Single;
  end;

  TMark = class
    X, Y: Single;
    WordI: Integer;
    Sense: Integer;
    Age: Single;
  end;

  TMemRec = record
    X, Y: Single;
    K: Integer;
    T: Single;
  end;

  // ── 64 techs : ordre GELÉ. ──
  TEcode = (
    tFeu, tAgri, tStock, tPast, tPeche, tNav, tEcrit,                                // ère 1 (0..6)
    teCharrue, teRoue, teIrrig, teMetal, teVoile, teMonnaie, teArchives, teScience,  // ère 2 (7..14)
    teFer, teAqueduc, teIngenierie, tePhilosophie, teMedecine, teMaths,
    teAstronomie, teEcole,                                                           // ère 3 (15..22)
    teCite, teGeometrie, teLegislation, teRhetorique, teGaleres, teAgronomie,
    teHygiene, teCartographie,                                                       // ère 4 Antiquité (23..30)
    teMoulins, teFerrure, teUniversites, teCorporations, teAssolement, teElevage,
    teMedArabe, teHauturiere,                                                        // ère 5 Moyen Âge (31..38)
    teImprimerie, teOptique, teAnatomie, teCaravelles, tePoudre, teBanque,
    teMethode, teHumanites,                                                          // ère 6 Renaissance (39..46)
    teVapeur, teTelegraphe, teEngrais, teVaccination, teGaz, teUsines,
    teFerroviaire, teHygPub,                                                         // ère 7 Industrielle (47..54)
    teElectricite, teAntibios, teInformatique, teInternet, teAgro, teEcoleTous,
    teMedMod, teEcologie,                                                            // ère 8 Moderne (55..62)
    te_G64);                                                                         // garde (63)
  TTechs = set of TEcode;
  TTech  = TEcode;
  TTechInfo = record
    Who: string;
    Day: Integer;
  end;

const
  NB_IN = 34;  NB_H1 = 9;  NB_H2 = 9;  NB_OUT = 10;

type
  TBrain = record
    W1: array[0..NB_H1-1, 0..NB_IN-1] of Single;
    W2: array[0..NB_H2-1, 0..NB_H1-1] of Single;
    W3: array[0..NB_OUT-1, 0..NB_H2-1] of Single;
    B1: array[0..NB_H1-1] of Single;
    B2: array[0..NB_H2-1] of Single;
    B3: array[0..NB_OUT-1] of Single;
  end;

  TCreature = class
    Kind: Integer;
    X, Y, Angle, WAngle: Single;
    Sp, Se, Sz: Single;
    Energy, MaxE: Single;
    Age, MaxAge: Single;
    Gen: Integer;
    Alive: Boolean;
    State: string;
    TargetC: TCreature;
    TargetP: TPlant;
    Fleeing: Boolean;
    FleeA: Single;
    ThinkT, BiteT, AtkCd, RepCd, Flash: Single;
    Name: string;
    Born: Single;
    Orn, Pref, Hue: Single;
    HueCol: TColor;
    Word: Integer;
    WordT: Single;
    SPred: TCreature;
    SFood: TPlant;
    SHerb: TCreature;
    GuardC: TCreature;
    Master: TCreature;
    SPeer: TCreature;
    Dna: TArray<Single>;
    Mem: TArray<TMemRec>;
    Cult: Single;
    Mentor: TCreature;
    MentorT: Single;
    BuildCd: Single;
    Tech: TTechs;
    InventT: Single;
    Tame: Single;
    Trust: Single;
    Dom: Boolean;
    HomeH: THut;
    MilkCd: Single;
    CatchT: Single;
    PrevOo: TArray<Single>;
    MutRate: Single;
    Net: TArray<Single>;
    Inp: TArray<Single>;
    Hid: TArray<Single>;
    Hid2: TArray<Single>;
    Oo: TArray<Single>;
    CId, ParentId: Integer;
    InnoK: Integer;
    Bio: TStringList;
    Brn: TBrain;
    Vocab: array[0..9] of string;
    WordS: string;
    WordC: Integer;
    SpeechCD, DrumCD, InnoCD: Single;
    HearW: string;
    HearC: Integer;
    HearTTL: Single;
  end;

type
  TEff = (efAucun,
    efCharrue, efRoue, efIrrig, efMetal, efVoile, efMonnaie, efArchives, efScience,
    efFer, efAqueduc, efIngenierie, efPhilosophie, efMedecine, efMaths,
    efAstronomie, efEcole);

  TEchDef = record
    Code: TEcode;
    Era: Integer;
    Nom: string;
    Dep: array[0..1] of Integer;
    Eff: TEff;
    P: Single;
    Desc: string;
  end;

const
  TECH_COUNT = 47;

function  TechBits(const T: TTechs): UInt64;
procedure BitsToTech(M: UInt64; out T: TTechs);
function  HasTech(const T: TTechs; C: TEcode): Boolean;
function  TechIdx(Code: TEcode): Integer;
function  TechNom(Code: TEcode): string;
procedure InitTechBase;

const
  GW = 400;
  GH = 250;
  NC = GW * GH;
  TAU = 2 * PI;
  CDAY: Single = 40;
  MAXP = 16800; MAXH = 600; MAXC = 160; MAXS = 64;
  MAXDOG = 12;
  MAXFS = 680;
  MAXFD = 480;
  HUTCAP = 84;
  NIN = 34; NHID = 9; NHID2 = 9; NOUT = 10;
  IDX_H1B = NIN * NHID;
  IDX_H2 = IDX_H1B + NHID;
  IDX_H2B = IDX_H2 + NHID * NHID2;
  IDX_HO = IDX_H2B + NHID2;
  IDX_SO = IDX_HO + NHID2 * NOUT;
  IDX_OB = IDX_SO + NIN * NOUT;
  NW = IDX_OB + NOUT;
  SIGR = 14;
  WORDS: array[0..3] of string = ('α','β','γ','δ');
  WORDCOL: array[0..3] of TColor =
    ($00C4AE82, $00C98EB4, $00A3B86F, $0069C0D8);
  TECHNAMES: array[0..6] of string =
    ('feu','agriculture','réserves','pastoralisme','pêche','navigation','écriture');
  MEMLIFE = 70;
  MEMMAX = 6;
  MARKLIFE = 400;
  STEPDT: Single = 1 / 60;
  TEXS = 8;
  PANELW = 302;
  HISTMAX = 340;
  CGS = 8;
  CGWC = (GW + CGS - 1) div CGS;
  CGHC = (GH + CGS - 1) div CGS;
  CHILDHOOD = 10;
  BRH = 220;
  T_DEEP = 0; T_SHAL = 1; T_SAND = 2; T_GRASS = 3; T_FOR = 4; T_ROCK = 5; T_SNOW = 6;
  TOOL_INSPECT = 0; TOOL_SEED = 1; TOOL_HERB = 2; TOOL_PRED = 3; TOOL_SAP = 4;
  BID_START = 1; BID_PLAY = 2; BID_S1 = 3; BID_S2 = 4; BID_S4 = 5;
  BID_TI = 10; BID_TS = 11; BID_TH = 12; BID_TP = 13; BID_TSA = 14; BID_NEW = 15;
  BID_SAVE = 20; BID_LOAD = 21;
  BID_ERE  = 22;
  SVERSION = 13;

const
  SYL: array[0..21] of string = ('ka','ro','mi','ta','lu','se','no','va','pi',
    'zu','fe','ol','an','yr','bre','shi','do','na','el','mu','ki','ra');
  SMAGIC: array[0..3] of AnsiChar = ('M','C','R','1');

type
  THistRec = record P, H, C, S: Integer; end;
  TBtn = record R: TRect; Cap: string; Id: Integer; Active: Boolean; end;
  TLexRec = record N, Pred, Food: Single; end;

var
  SX, SY: Integer;
  TerrType: TArray<Byte>;
  Fert, Elev, Humid: TArray<Single>;
  Plants: TList<TPlant>;
  PlantGrid: TArray<TPlant>;
  Huts: TList<THut>;
  Cities: TList<TCity>;          // ★A1 les villes du monde
  Fishes: TList<TFish>;
  FsN, FdN: Integer;
  Marks: TList<TMark>;
  Creatures: TList<TCreature>;
  CountH, CountP, CountS, CountD: Integer;
  UidH, UidP, UidS: Integer;
  Buckets: array of TList<TCreature>;
  NB: TList<TCreature>;
  FSimTime, FDayT, FDayLight: Single;
  SampleT: Single;
  FZoom: Single = 1;
  FCamX, FCamY: Single;
  FScale: Single = 8;
  FRunning, FStarted: Boolean;
  FSpeed: Integer = 1;
  FTool: Integer = TOOL_INSPECT;
  FSelected: TCreature;
  FMsg: string;
  FMsgT: Single;
  FVP: TRect;
  FTerrain, FThumb, FWorld, FTintN, FTintW: TBitmap;
  FPanelBM: TBitmap;
  FPanelScroll: Integer;
  FPanelH: Integer;
  FBtns: array of TBtn;
  FHist: array of THistRec;
  FDrag: Boolean;
  FDragX, FDragY: Integer;
  FDragCX, FDragCY: Single;
  FTimer: TTimer;
  FSimCS: TCriticalSection;
  FSimThread: TThread;
  Lex: array[0..3] of TLexRec;
  FieldGrid: TArray<Byte>;
  TechInfo: array[TTech] of TTechInfo;
  TechLost: array[TTech] of Boolean;
  FHomeX, FHomeY: Single;
  FHomeSet: Boolean;
  FDiag: TFileStream;
  TECHBASE: array[0..TECH_COUNT-1] of TEchDef;
  FVue: Integer = 0;       // ★ 0 normal · 1 monde plein écran (F5) · 2 carnet plein écran (F7)
  FPanelW: Integer = PANELW; // ★ largeur courante du carnet (302 · pleine largeur en F7)

implementation

function TechBits(const T: TTechs): UInt64;
begin
  Move(T, Result, SizeOf(Result));
end;

procedure BitsToTech(M: UInt64; out T: TTechs);
begin
  Move(M, T, SizeOf(M));
end;

function HasTech(const T: TTechs; C: TEcode): Boolean;
begin
  Result := C in T;
end;

function TechIdx(Code: TEcode): Integer;
begin
  Result := Ord(Code);
end;

function TechNom(Code: TEcode): string;
var
  i: Integer;
begin
  i := Ord(Code);
  if (i >= 0) and (i < TECH_COUNT) then
    Result := TECHBASE[i].Nom
  else
    Result := '?';
end;

var
  FCount: Integer = 0;

procedure AddTech(aCode: TEcode; aEra: Integer; const aNom: string;
                  D1, D2: Integer; aEff: TEff; aP: Single; const aDesc: string);
begin
  with TECHBASE[FCount] do
  begin
    Code := aCode; Era := aEra; Nom := aNom;
    Dep[0] := D1; Dep[1] := D2; Eff := aEff; P := aP; Desc := aDesc;
  end;
  Inc(FCount);
end;

procedure InitTechBase;
begin
  FCount := 0;
  AddTech(tFeu,   1, 'Feu',          -1, -1, efAucun, 0.00020, 'dompter la flamme');
  AddTech(tAgri,  1, 'Agriculture',   0, -1, efAucun, 0.00020, 'semer au lieu de cueillir');
  AddTech(tStock, 1, 'Stockage',      1, -1, efAucun, 0.00020, 'greniers pour les mauvais jours');
  AddTech(tPast,  1, 'Pastoralisme',  2, -1, efAucun, 0.00020, 'lait et troupeaux');
  AddTech(tPeche, 1, 'Pêche',         3, -1, efAucun, 0.00020, 'harpons et patience');
  AddTech(tNav,   1, 'Navigation',    4, -1, efAucun, 0.00020, 'pirogues creusées');
  AddTech(tEcrit, 1, 'Écriture',      5, -1, efAucun, 0.00020, 'la mémoire du peuple');
  AddTech(teCharrue,  2, 'Charrue',      1, -1, efCharrue,  0.00016, 'labourer, récolter plus');
  AddTech(teRoue,     2, 'Roue',         7, -1, efRoue,     0.00016, 'porter plus, aller plus vite');
  AddTech(teIrrig,    2, 'Irrigation',   7, -1, efIrrig,    0.00016, 'l''eau mène aux champs');
  AddTech(teMetal,    2, 'Métallurgie',  0, -1, efMetal,    0.00016, 'le bronze mord la chair');
  AddTech(teVoile,    2, 'Voile',        5, -1, efVoile,    0.00016, 'le vent pousse les pirogues');
  AddTech(teMonnaie,  2, 'Monnaie',      6, -1, efMonnaie,  0.00016, 'les idées circulent plus vite');
  AddTech(teArchives, 2, 'Archives',     6, -1, efArchives, 0.00016, 'mémoire qui ne meurt jamais');
  AddTech(teScience,  2, 'Science',     13, -1, efScience,  0.00012, 'savoir appelle savoir');
  AddTech(teFer,         3, 'Fer',           10, -1, efFer,        0.00012, 'le fer remplace le bronze');
  AddTech(teAqueduc,     3, 'Aqueduc',        9, -1, efAqueduc,    0.00012, 'l''eau partout au village');
  AddTech(teIngenierie,  3, 'Ingénierie',    15, -1, efIngenierie, 0.00012, 'construire en pierre');
  AddTech(tePhilosophie, 3, 'Philosophie',   13, -1, efPhilosophie,0.00010, 'le savoir ne régresse plus');
  AddTech(teMedecine,    3, 'Médecine',      18, -1, efMedecine,   0.00012, 'vivre plus longtemps');
  AddTech(teMaths,       3, 'Mathématiques', 18, -1, efMaths,      0.00012, 'compter les étoiles');
  AddTech(teAstronomie,  3, 'Astronomie',    20, -1, efAstronomie, 0.00012, 'prédire les saisons');
  AddTech(teEcole,       3, 'École',         18, -1, efEcole,      0.00012, 'les aînés enseignent mieux');
  AddTech(teCite,        4, 'Cité',         17, -1, efAucun,      0.00011, 'la pierre s''assemble en ville');
  AddTech(teGeometrie,   4, 'Géométrie',    20, -1, efAucun,      0.00011, 'mesurer pour bâtir');
  AddTech(teLegislation, 4, 'Législation',   6, -1, efAucun,      0.00011, 'des lois, non des humeurs');
  AddTech(teRhetorique,  4, 'Rhétorique',   25, -1, efAucun,      0.00011, 'la parole qui persuade');
  AddTech(teGaleres,     4, 'Galères',       5, -1, efAucun,      0.00011, 'rames et éperons de bronze');
  AddTech(teAgronomie,   4, 'Agronomie',     1, -1, efAucun,      0.00011, 'la terre comprise, non subie');
  AddTech(teHygiene,     4, 'Hygiène',      18, -1, efAucun,      0.00011, 'l''eau claire, les mains propres');
  AddTech(teCartographie,4, 'Cartographie',  6, -1, efAucun,      0.00011, 'le monde dessiné sur une peau');
  AddTech(teMoulins,     5, 'Moulins',            16, -1, efAucun, 0.00010, 'l''eau moud le grain');
  AddTech(teFerrure,     5, 'Ferrure',            15, -1, efAucun, 0.00010, 'des pas sûrs sur tous chemins');
  AddTech(teUniversites, 5, 'Universités',        22, -1, efAucun, 0.00010, 'le savoir a ses maisons');
  AddTech(teCorporations,5, 'Corporations',       12, -1, efAucun, 0.00010, 'les métiers se transmettent');
  AddTech(teAssolement,  5, 'Assolement',         28, -1, efAucun, 0.00010, 'la terre se repose et rend plus');
  AddTech(teElevage,     5, 'Élevage sélectif',    3, -1, efAucun, 0.00010, 'choisir les meilleurs reproducteurs');
  AddTech(teMedArabe,    5, 'Médecine arabe',     29, -1, efAucun, 0.00010, 'les remèdes voyagent');
  AddTech(teHauturiere,  5, 'Navigation hauturière',30, -1, efAucun, 0.00010, 'perdre la côte de vue');
  AddTech(teImprimerie,  6, 'Imprimerie',            6, -1, efAucun, 0.00009, 'l''encre multiplie les mots');
  AddTech(teOptique,     6, 'Optique',               24, -1, efAucun, 0.00009, 'le verre grossit le monde');
  AddTech(teAnatomie,    6, 'Anatomie',              19, -1, efAucun, 0.00009, 'dessiner le corps de l''intérieur');
  AddTech(teCaravelles,  6, 'Caravelles',            38, -1, efAucun, 0.00009, 'des voiles contre tous vents');
  AddTech(tePoudre,      6, 'Poudre',                15, -1, efAucun, 0.00009, 'le feu captif hurle');
  AddTech(teBanque,      6, 'Banque',                12, -1, efAucun, 0.00009, 'l''argent prête et voyage');
  AddTech(teMethode,     6, 'Méthode',               18, -1, efAucun, 0.00009, 'observer, mesurer, recommencer');
  AddTech(teHumanites,   6, 'Humanités',              6, -1, efAucun, 0.00009, 'l''humain au centre des textes');
end;

initialization
  InitTechBase;

end.

                            unit MicrocosmeU;

{ Microcosme — socle Delphi 12 / VCL + sélection sexuelle + cerveau visualisé.
  Terrain interpolé continu · flore · herbivores grégaires · prédateurs ·
  sapiens neuroévolution + gènes de séduction (plume / goût / teinte) ·
  croisement sexuel · RÉSEAU NEURONAL DESSINÉ EN DIRECT dans la fiche ·
  jour/nuit · rescue effect · caméra · carnet.
  Simulation dans TSimThread · verrou critique · zéro scintillement ·
  sauvegarde/chargement v2 (microcosme.sav).
  Fiche 100 % code : aucune DFM. }

interface

uses
  System.SysUtils, System.Types, System.Classes, System.Math,
  System.Generics.Collections,
  Winapi.Windows, Winapi.Messages,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.ExtCtrls;

type
  TCreature = class;

  TPlant = class
    X, Y, S: Single;
    Cell: Integer;
  end;

  TCreature = class
    Kind: Integer;                       // 0 herbivore · 1 prédateur · 2 sapien
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
    // sélection sexuelle
    Orn: Single;                         // taille de plume (0..1)
    Pref: Single;                        // goût : plume désirée (0..1)
    Hue: Single;                         // teinte de lignée (0..1)
    HueCol: TColor;                      // couleur précalculée
    Net: TArray<Single>;
    Inp: TArray<Single>;
    Hid: TArray<Single>;
    Oo: TArray<Single>;
  end;

  TSimThread = class(TThread)
  protected
    procedure Execute; override;
  end;

  TMainForm = class(TForm)
    procedure FormPaint(Sender: TObject);
    procedure FormMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure FormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure FormMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure FormResize(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure TimerTick(Sender: TObject);
  private
    procedure WMEraseBkgnd(var Msg: TWMEraseBkgnd); message WM_ERASEBKGND;
  protected
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer;
      MousePos: TPoint): Boolean; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  MainForm: TMainForm;

implementation

uses
  System.Diagnostics, System.SyncObjs;

{$OVERFLOWCHECKS OFF}
{$RANGECHECKS OFF}
{$POINTERMATH ON}

type
  THistRec = record P, H, C, S: Integer; end;
  TBtn = record R: TRect; Cap: string; Id: Integer; Active: Boolean; end;

const
  GW = 200;
  GH = 125;
  NC = GW * GH;
  TAU = 2 * PI;
  CDAY: Single = 40;
  MAXP = 4200; MAXH = 300; MAXC = 110; MAXS = 64;
  NIN = 12; NHID = 9; NOUT = 5;
  IDX_HO = NIN * NHID;
  IDX_SO = IDX_HO + NHID * NOUT;
  IDX_OB = IDX_SO + NIN * NOUT;
  NW = IDX_OB + NOUT;
  STEPDT: Single = 1 / 60;
  TEXS = 8;
  PANELW = 302;
  HISTMAX = 340;
  CGS = 8;
  CGWC = (GW + CGS - 1) div CGS;
  CGHC = (GH + CGS - 1) div CGS;
  CHILDHOOD = 10;
  BRH = 118;                             // hauteur du panneau cerveau
  T_DEEP = 0; T_SHAL = 1; T_SAND = 2; T_GRASS = 3; T_FOR = 4; T_ROCK = 5; T_SNOW = 6;
  TOOL_INSPECT = 0; TOOL_SEED = 1; TOOL_HERB = 2; TOOL_PRED = 3; TOOL_SAP = 4;
  BID_START = 1; BID_PLAY = 2; BID_S1 = 3; BID_S2 = 4; BID_S4 = 5;
  BID_TI = 10; BID_TS = 11; BID_TH = 12; BID_TP = 13; BID_TSA = 14; BID_NEW = 15;
  BID_SAVE = 20; BID_LOAD = 21;
  SVERSION = 2;

const
  SYL: array[0..21] of string = ('ka','ro','mi','ta','lu','se','no','va','pi',
    'zu','fe','ol','an','yr','bre','shi','do','na','el','mu','ki','ra');
  SMAGIC: array[0..3] of AnsiChar = ('M','C','R','1');

var
  SX, SY: Integer;
  TerrType: TArray<Byte>;
  Fert, Elev, Humid: TArray<Single>;
  Plants: TList<TPlant>;
  PlantGrid: TArray<TPlant>;
  Creatures: TList<TCreature>;
  CountH, CountP, CountS: Integer;
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
  FBtns: array of TBtn;
  FHist: array of THistRec;
  FDrag: Boolean;
  FDragX, FDragY: Integer;
  FDragCX, FDragCY: Single;
  FTimer: TTimer;
  FSimCS: TCriticalSection;
  FSimThread: TSimThread;

// ---- déclarations anticipées ----
procedure RenderTerrainBmp; forward;
procedure ClampCam; forward;
function Hash2(IX, IY: Integer): Single; forward;

// ================= utilitaires =================

function Col(R, G, B: Integer): TColor;
begin
  Result := RGB(R, G, B);
end;

function AlphaColorBlend(A, B: TColor; Alpha: Byte): TColor;
var AR, AG, AB, BR, BG, BB, FR, FG, FB: Integer;
begin
  AR := GetRValue(A); AG := GetGValue(A); AB := GetBValue(A);
  BR := GetRValue(B); BG := GetGValue(B); BB := GetBValue(B);
  FR := AR * Alpha div 255 + BR * (255 - Alpha) div 255;
  FG := AG * Alpha div 255 + BG * (255 - Alpha) div 255;
  FB := AB * Alpha div 255 + BB * (255 - Alpha) div 255;
  Result := RGB(FR, FG, FB);
end;

function HueColor(H: Single): TColor;
var
  H6, F, P, Q, T: Double;
  I, R, G, B: Integer;
const
  SAT = 0.70;
  VAL = 0.86;
begin
  H6 := Frac(H) * 6;
  I := Floor(H6);
  F := H6 - I;
  P := VAL * (1 - SAT);
  Q := VAL * (1 - SAT * F);
  T := VAL * (1 - SAT * (1 - F));
  case I mod 6 of
    0: begin R := Trunc(VAL * 255); G := Trunc(T * 255); B := Trunc(P * 255) end;
    1: begin R := Trunc(Q * 255);   G := Trunc(VAL * 255); B := Trunc(P * 255) end;
    2: begin R := Trunc(P * 255);   G := Trunc(VAL * 255); B := Trunc(T * 255) end;
    3: begin R := Trunc(P * 255);   G := Trunc(Q * 255); B := Trunc(VAL * 255) end;
    4: begin R := Trunc(T * 255);   G := Trunc(P * 255); B := Trunc(VAL * 255) end;
  else begin R := Trunc(VAL * 255); G := Trunc(P * 255); B := Trunc(Q * 255) end;
  end;
  Result := RGB(R, G, B);
end;

function Hash2(IX, IY: Integer): Single;
var N: Cardinal;
begin
  N := Cardinal(IX) * 374761393 + Cardinal(IY) * 668265263 + $9E3779B9;
  N := (N xor (N shr 13)) * 1274126177;
  N := N xor (N shr 16);
  Result := N * (1.0 / 4294967296.0);
end;

function VNoise(X, Y: Single): Single;
var IX, IY: Integer; FX, FY, U, V, A, B, C, D: Single;
begin
  IX := Floor(X); IY := Floor(Y);
  FX := X - IX; FY := Y - IY;
  U := FX * FX * (3 - 2 * FX); V := FY * FY * (3 - 2 * FY);
  A := Hash2(IX, IY);     B := Hash2(IX + 1, IY);
  C := Hash2(IX, IY + 1); D := Hash2(IX + 1, IY + 1);
  Result := A + (B - A) * U + (C - A) * V + (A - B - C + D) * U * V;
end;

function FBM(X, Y: Single; Oct: Integer): Single;
var V, Amp, S, F: Single; I: Integer;
begin
  V := 0; Amp := 0.5; F := 1; S := 0;
  for I := 1 to Oct do begin
    V := V + Amp * VNoise(X * F, Y * F);
    S := S + Amp; Amp := Amp * 0.5; F := F * 2.03;
  end;
  Result := V / S;
end;

function RN: Single;
begin
  Result := (Random + Random + Random - 1.5) * 1.155;
end;

function ClampF(V, A, B: Single): Single;
begin
  if V < A then Exit(A);
  if V > B then Exit(B);
  Result := V;
end;

function CellIdx(X, Y: Single): Integer;
var XI, YI: Integer;
begin
  XI := Trunc(X); YI := Trunc(Y);
  if (XI < 0) or (YI < 0) or (XI >= GW) or (YI >= GH) then Exit(-1);
  Result := YI * GW + XI;
end;

function Walkable(X, Y: Single): Boolean;
var K: Integer;
begin
  K := CellIdx(X, Y);
  Result := (K >= 0) and (TerrType[K] >= T_SAND) and (TerrType[K] <= T_FOR);
end;

function D2(AX, AY, BX, BY: Single): Single;
begin
  Result := Sqr(AX - BX) + Sqr(AY - BY);
end;

function NormA(A: Single): Single;
begin
  Result := A - TAU * Floor((A + PI) / TAU);
end;

function DayCount: Integer;
begin
  Result := Floor(FSimTime / CDAY) + 1;
end;

procedure Toast(const Msg: string);
begin
  FMsg := Msg; FMsgT := 3;
end;

// ================= terrain =================

procedure GenTerrain;
var X, Y, I: Integer; E, Moist, DX, DY: Single;
begin
  SetLength(TerrType, NC); SetLength(Fert, NC);
  SetLength(Elev, NC); SetLength(Humid, NC);
  for Y := 0 to GH - 1 do
    for X := 0 to GW - 1 do begin
      I := Y * GW + X;
      E := FBM(X * 0.028 + SX, Y * 0.028 + SY, 4);
      DX := Min(X, GW - 1 - X) / (GW * 0.5);
      DY := Min(Y, GH - 1 - Y) / (GH * 0.5);
      E := E - Power(1 - Min(Min(DX, DY) * 1.9, 1), 3) * 0.55;
      Moist := FBM(X * 0.06 + SX + 77.7, Y * 0.06 + SY + 31.4, 3);
      Elev[I] := E; Humid[I] := Moist;
      if E < 0.34 then begin TerrType[I] := T_DEEP; Fert[I] := 0 end
      else if E < 0.40 then begin TerrType[I] := T_SHAL; Fert[I] := 0 end
      else if E < 0.435 then begin TerrType[I] := T_SAND; Fert[I] := 0.06 end
      else if E < 0.68 then
        if Moist > 0.57 then begin TerrType[I] := T_FOR; Fert[I] := 0.55 + Moist * 0.4 end
        else begin TerrType[I] := T_GRASS; Fert[I] := 0.25 + Moist * 0.75 end
      else if E < 0.79 then begin TerrType[I] := T_ROCK; Fert[I] := 0 end
      else begin TerrType[I] := T_SNOW; Fert[I] := 0 end;
    end;
end;

// ================= nettoyage =================

procedure ClearWorldObjects;
var I: Integer;
begin
  for I := 0 to Plants.Count - 1 do Plants[I].Free;
  Plants.Clear;
  SetLength(PlantGrid, NC);
  for I := 0 to NC - 1 do PlantGrid[I] := nil;
  for I := 0 to Creatures.Count - 1 do Creatures[I].Free;
  Creatures.Clear;
  CountH := 0; CountP := 0; CountS := 0;
  UidH := 0; UidP := 0; UidS := 0;
  FSelected := nil;
  FHist := nil;
end;

// ================= flore =================

function AddPlant(X, Y, S: Single): TPlant;
var CI: Integer;
begin
  Result := nil;
  if (PlantGrid = nil) or (Plants.Count >= MAXP) then Exit;
  CI := CellIdx(X, Y); if CI < 0 then Exit;
  if PlantGrid[CI] <> nil then Exit;
  if (TerrType[CI] < T_SAND) or (TerrType[CI] > T_FOR) or (Fert[CI] < 0.08) then Exit;
  Result := TPlant.Create;
  Result.X := X; Result.Y := Y; Result.S := S; Result.Cell := CI;
  Plants.Add(Result); PlantGrid[CI] := Result;
end;

procedure RemovePlant(P: TPlant);
var I, Last: Integer; Q: TPlant; C: TCreature;
begin
  I := Plants.IndexOf(P); if I < 0 then Exit;
  PlantGrid[P.Cell] := nil;
  Last := Plants.Count - 1;
  if I <> Last then begin Q := Plants[Last]; Plants[I] := Q end;
  Plants.Delete(Last);
  for C in Creatures do
    if C.TargetP = P then C.TargetP := nil;
  P.Free;
end;

procedure StepPlants(DT, DayF: Single);
var I: Integer; P: TPlant; A, R: Single;
begin
  for I := Plants.Count - 1 downto 0 do begin
    P := Plants[I];
    if P.S <= 0.03 then begin RemovePlant(P); Continue end;
    if P.S < 1 then
      P.S := Min(1, P.S + 0.042 * Fert[P.Cell] * DayF * DT);
    if (P.S > 0.5) and (Random < DT * 0.09 * DayF) then begin
      A := Random * TAU; R := 1.6 + Random * 2.2;
      AddPlant(P.X + Cos(A) * R, P.Y + Sin(A) * R, 0.06 + Random * 0.08);
    end;
  end;
end;

// ================= réseau neuronal =================

procedure FillInnateNet(var W: TArray<Single>);
var I: Integer;
  procedure SK(I, O: Integer; V: Single);
  begin W[IDX_SO + I * NOUT + O] := V end;
begin
  SetLength(W, NW);
  for I := 0 to NW - 1 do W[I] := RN * 0.3;
  SK(4, 0,  1.7 + RN * 0.25);
  SK(5, 1,  0.6);
  SK(0, 1,  0.7 + RN * 0.2);
  SK(10, 0, -1.4 + RN * 0.25);
  SK(11, 1, 0.7);
  SK(0, 2, -1.3); SK(0, 3, -0.5); SK(0, 4, -1.6);
end;

procedure MutateNet(var W: TArray<Single>);
var I: Integer;
begin
  for I := 0 to NW - 1 do
    if Random < 0.13 then W[I] := ClampF(W[I] + RN * 0.3, -4, 4)
    else if Random < 0.02 then W[I] := ClampF(RN * 1.2, -4, 4);
end;

procedure ThinkNet(C: TCreature);
var I, J, O: Integer; S: Single;
begin
  for J := 0 to NHID - 1 do begin
    S := C.Net[IDX_HO + J];
    for I := 0 to NIN - 1 do S := S + C.Net[I * NHID + J] * C.Inp[I];
    C.Hid[J] := Tanh(S);
  end;
  for O := 0 to NOUT - 1 do begin
    S := C.Net[IDX_OB + O];
    for J := 0 to NHID - 1 do S := S + C.Net[IDX_HO + J * NOUT + O] * C.Hid[J];
    for I := 0 to NIN - 1 do S := S + C.Net[IDX_SO + I * NOUT + O] * C.Inp[I];
    C.Oo[O] := Tanh(S);
  end;
end;

// ================= créatures =================

function MakeName: string;
var N, I: Integer;
begin
  N := 2; if Random < 0.35 then N := 3;
  Result := '';
  for I := 1 to N do Result := Result + SYL[Random(Length(SYL))];
  Result := UpCase(Result[1]) + Copy(Result, 2, MaxInt);
end;

procedure SpawnCreature(Kind: Integer; X, Y: Single;
  Parent, Parent2: TCreature; Gen: Integer);
var C: TCreature; T, I: Integer;
   RSp, RSe, RSz: array[0..1] of Single;
   Src: TCreature;
begin
  for T := 1 to 10 do
    if Walkable(X, Y) then Break
    else begin X := Random(GW); Y := Random(GH) end;

  C := TCreature.Create;
  C.Kind := Kind; C.X := X; C.Y := Y;
  C.Angle := Random * TAU; C.WAngle := Random * TAU;
  case Kind of
    0: begin RSp[0]:=2.2; RSp[1]:=5.4; RSe[0]:=4; RSe[1]:=9; RSz[0]:=0.6; RSz[1]:=1.5 end;
    1: begin RSp[0]:=3.0; RSp[1]:=6.4; RSe[0]:=5; RSe[1]:=11; RSz[0]:=0.7; RSz[1]:=1.5 end;
  else begin RSp[0]:=2.6; RSp[1]:=5.6; RSe[0]:=6; RSe[1]:=12; RSz[0]:=0.7; RSz[1]:=1.3 end;
  end;
  if Parent <> nil then begin
    if (Parent2 <> nil) and (Random < 0.5) then Src := Parent2 else Src := Parent;
    C.Sp := ClampF(Src.Sp * Exp(RN * 0.15), RSp[0], RSp[1]);
    C.Se := ClampF(Src.Se * Exp(RN * 0.15), RSe[0], RSe[1]);
    C.Sz := ClampF(Src.Sz * Exp(RN * 0.13), RSz[0], RSz[1]);
    if Kind = 2 then begin
      if (Parent2 <> nil) and (Random < 0.5) then Src := Parent2 else Src := Parent;
      C.Orn := ClampF(Src.Orn * Exp(RN * 0.18), 0.03, 1);
      C.Pref := ClampF(Src.Pref + RN * 0.12, 0, 1);
      C.Hue := Frac(Src.Hue + RN * 0.05);
    end else begin
      C.Orn := 0; C.Pref := 0; C.Hue := 0;
    end;
  end else begin
    C.Sp := RSp[0] + Random * (RSp[1] - RSp[0]);
    C.Se := RSe[0] + Random * (RSe[1] - RSe[0]);
    C.Sz := RSz[0] + Random * (RSz[1] - RSz[0]);
    if Kind = 2 then begin
      C.Orn := 0.08 + Random * 0.27;
      C.Pref := 0.10 + Random * 0.50;
      C.Hue := Random;
    end else begin
      C.Orn := 0; C.Pref := 0; C.Hue := 0;
    end;
  end;
  C.HueCol := HueColor(C.Hue);
  case Kind of
    0: begin
         C.Energy := 55 + Random * 20; C.MaxE := 60 + 52 * C.Sz;
         C.MaxAge := 150 + Random * 90; Inc(UidH); C.Name := 'H-' + IntToStr(UidH);
       end;
    1: begin
         C.Energy := 65 + Random * 20; C.MaxE := 80 + 60 * C.Sz;
         C.MaxAge := 230 + Random * 110; Inc(UidP); C.Name := 'P-' + IntToStr(UidP);
       end;
  else begin
         C.Energy := 75 + Random * 20; C.MaxE := 95 + 65 * C.Sz;
         C.MaxAge := 260 + Random * 120; Inc(UidS); C.Name := MakeName;
       end;
  end;
  C.Age := 0; C.Gen := Gen; C.Alive := True; C.State := 'rôde';
  C.ThinkT := Random * 0.3; C.RepCd := 6 + Random * 6;
  C.Born := FSimTime;
  if Kind = 2 then begin
    SetLength(C.Net, NW);
    if Parent <> nil then begin
      for I := 0 to NW - 1 do C.Net[I] := Parent.Net[I];
      MutateNet(C.Net);
    end else FillInnateNet(C.Net);
    SetLength(C.Inp, NIN); SetLength(C.Hid, NHID); SetLength(C.Oo, NOUT);
  end;
  Creatures.Add(C);
  case Kind of 0: Inc(CountH); 1: Inc(CountP); 2: Inc(CountS) end;
end;

procedure Kill(C: TCreature; const Cause: string);
begin
  if not C.Alive then Exit;
  C.Alive := False;
  case C.Kind of 0: Dec(CountH); 1: Dec(CountP); 2: Dec(CountS) end;
  if (Cause <> 'dévoré') and (Random < 0.85) and Walkable(C.X, C.Y) then
    AddPlant(C.X, C.Y, 0.35);
  if FSelected = C then FSelected := nil;
end;

// ================= grille spatiale =================

procedure RebuildGrid;
var I: Integer; C: TCreature;
begin
  for I := 0 to Length(Buckets) - 1 do Buckets[I].Clear;
  for C in Creatures do
    if C.Alive then
      Buckets[Min(CGHC - 1, Trunc(C.Y / CGS)) * CGWC +
              Min(CGWC - 1, Trunc(C.X / CGS))].Add(C);
end;

procedure CollectNear(X, Y, R: Single);
var X0, X1, Y0, Y1, GX, GY: Integer; C: TCreature;
begin
  NB.Clear;
  X0 := Max(0, Trunc((X - R) / CGS)); X1 := Min(CGWC - 1, Trunc((X + R) / CGS));
  Y0 := Max(0, Trunc((Y - R) / CGS)); Y1 := Min(CGHC - 1, Trunc((Y + R) / CGS));
  for GY := Y0 to Y1 do
    for GX := X0 to X1 do
      for C in Buckets[GY * CGWC + GX] do NB.Add(C);
end;

function CrowdCount(C: TCreature; R: Single): Integer;
var O: TCreature;
begin
  Result := 0;
  CollectNear(C.X, C.Y, R);
  for O in NB do
    if (O <> C) and O.Alive and (O.Kind = C.Kind) then Inc(Result);
end;

// ================= nourriture =================

function FindPlant(C: TCreature): TPlant;
var Best: TPlant; BS, S2, SC, D: Single;
   X0, X1, Y0, Y1, XX, YY, PIx: Integer; P: TPlant;
begin
  Best := nil; BS := 0; S2 := C.Se * C.Se;
  X0 := Max(0, Trunc(C.X - C.Se)); X1 := Min(GW - 1, Trunc(C.X + C.Se));
  Y0 := Max(0, Trunc(C.Y - C.Se)); Y1 := Min(GH - 1, Trunc(C.Y + C.Se));
  for YY := Y0 to Y1 do
    for XX := X0 to X1 do begin
      PIx := YY * GW + XX; P := PlantGrid[PIx];
      if P = nil then Continue;
      if P.S < 0.15 then Continue;
      D := Sqr(P.X - C.X) + Sqr(P.Y - C.Y);
      if D > S2 then Continue;
      SC := P.S / (1 + Sqrt(D));
      if SC > BS then begin BS := SC; Best := P end;
    end;
  Result := Best;
end;

// ================= cerveaux animaux =================

procedure ThinkHerb(C: TCreature);
var O: TCreature; Threat, Peer: TCreature;
   TD, PD, D, PA, S2: Single; CI: Integer;
begin
  C.Fleeing := False;
  Threat := nil; Peer := nil; TD := MaxSingle; PD := MaxSingle;
  S2 := C.Se * C.Se;
  CollectNear(C.X, C.Y, C.Se);
  for O in NB do begin
    if (not O.Alive) or (O = C) then Continue;
    D := D2(C.X, C.Y, O.X, O.Y);
    if (O.Kind = 1) and (D < S2) and (D < TD) then begin TD := D; Threat := O end
    else if (O.Kind = 0) and (D < PD) then begin PD := D; Peer := O end;
  end;
  if Threat <> nil then begin
    CI := CellIdx(C.X, C.Y);
    if (CI >= 0) and (TerrType[CI] = T_FOR) and (TD > 4.8 * 4.8) then begin
      C.State := 'caché'; C.TargetP := nil; Exit;
    end;
    C.Fleeing := True; C.State := 'en fuite'; C.TargetP := nil;
    C.FleeA := ArcTan2(C.Y - Threat.Y, C.X - Threat.X);
    Exit;
  end;
  if C.Energy < C.MaxE * 0.92 then begin
    C.TargetP := FindPlant(C);
    if C.TargetP <> nil then C.State := 'broute' else C.State := 'rôde';
    if C.TargetP = nil then begin
      if (Peer <> nil) and (PD < 100) then begin
        PA := ArcTan2(Peer.Y - C.Y, Peer.X - C.X);
        C.WAngle := C.WAngle + NormA(PA - C.WAngle) * 0.35;
      end else C.WAngle := C.WAngle + (Random - 0.5) * 2.2;
    end;
  end else begin
    C.TargetP := nil; C.State := 'rôde';
    if (Peer <> nil) and (PD < 100) then begin
      PA := ArcTan2(Peer.Y - C.Y, Peer.X - C.X);
      C.WAngle := C.WAngle + NormA(PA - C.WAngle) * 0.2;
    end else C.WAngle := C.WAngle + (Random - 0.5) * 1.2;
  end;
end;

procedure ThinkPred(C: TCreature);
var O: TCreature; Best: TCreature; BD, D, VR: Single; CI: Integer;
   P: TPlant;
begin
  Best := nil; BD := MaxSingle;
  CollectNear(C.X, C.Y, C.Se);
  for O in NB do begin
    if not O.Alive then Continue;
    if O.Kind = 0 then begin
      CI := CellIdx(O.X, O.Y);
      if (CI >= 0) and (TerrType[CI] = T_FOR) then VR := C.Se * 0.55 else VR := C.Se;
      D := D2(C.X, C.Y, O.X, O.Y);
      if (D < VR * VR) and (D < BD) then begin BD := D; Best := O end;
    end;
  end;
  if Best <> nil then begin
    C.State := 'chasse'; C.TargetC := Best; C.TargetP := nil;
    C.WAngle := ArcTan2(Best.Y - C.Y, Best.X - C.X);
  end else if C.Energy < C.MaxE * 0.34 then begin
    P := FindPlant(C);
    C.TargetP := P; C.TargetC := nil;
    if P <> nil then begin
      C.State := 'famine'; C.WAngle := ArcTan2(P.Y - C.Y, P.X - C.X);
    end else begin
      C.State := 'traque'; C.WAngle := C.WAngle + (Random - 0.5) * 1.5;
    end;
  end else begin
    C.TargetC := nil; C.TargetP := nil; C.State := 'traque';
    C.WAngle := C.WAngle + (Random - 0.5) * 1.5;
  end;
end;

// ================= pas générique animal =================

procedure StepCreature(C: TCreature; DT: Single);
var Want, Des, Turn, SP, SM, NX, NY, D, Esc, Eff, Gain, Amt, Crowd, Damp: Single;
   T: TPlant; O: TCreature;
begin
  C.Age := C.Age + DT; C.ThinkT := C.ThinkT - DT;
  C.AtkCd := C.AtkCd - DT; C.RepCd := C.RepCd - DT;
  if C.Flash > 0 then C.Flash := Max(0, C.Flash - DT);
  if C.ThinkT <= 0 then begin
    C.ThinkT := 0.22 + Random * 0.18;
    if C.Kind = 0 then ThinkHerb(C) else ThinkPred(C);
  end;
  if (C.TargetP <> nil) and (PlantGrid[C.TargetP.Cell] <> C.TargetP) then C.TargetP := nil;
  if (C.TargetC <> nil) and (not C.TargetC.Alive) then C.TargetC := nil;

  Want := C.WAngle;
  if C.State = 'caché' then Des := 0.07
  else if C.Fleeing then begin Want := C.FleeA; Des := C.Sp * 1.07 end
  else if C.TargetC <> nil then begin
    D := Sqrt(D2(C.X, C.Y, C.TargetC.X, C.TargetC.Y));
    if D > 1.05 then begin
      Want := ArcTan2(C.TargetC.Y - C.Y, C.TargetC.X - C.X); Des := C.Sp * 1.08;
    end else Des := 0.08;
  end else if C.TargetP <> nil then begin
    D := Sqrt(D2(C.X, C.Y, C.TargetP.X, C.TargetP.Y));
    if D > 1.05 then begin
      Want := ArcTan2(C.TargetP.Y - C.Y, C.TargetP.X - C.X); Des := C.Sp * 0.95;
    end else Des := 0.08;
  end else Des := C.Sp * 0.35;

  Turn := 5 * DT; if C.Fleeing then Turn := 9 * DT;
  C.Angle := C.Angle + ClampF(NormA(Want - C.Angle), -Turn, Turn);

  SM := 1;
  if Walkable(C.X, C.Y) and (TerrType[CellIdx(C.X, C.Y)] = T_FOR) then SM := 0.7;
  SP := Des * SM;
  NX := C.X + Cos(C.Angle) * SP * DT; NY := C.Y + Sin(C.Angle) * SP * DT;
  if Walkable(NX, NY) then begin C.X := NX; C.Y := NY end
  else if Walkable(NX, C.Y) then begin C.X := NX; C.Angle := C.Angle + (Random - 0.5) * 1.2 end
  else if Walkable(C.X, NY) then begin C.Y := NY; C.Angle := C.Angle + (Random - 0.5) * 1.2 end
  else C.Angle := C.Angle + 2.4 * DT;
  C.X := ClampF(C.X, 0.01, GW - 0.01); C.Y := ClampF(C.Y, 0.01, GH - 0.01);

  if C.TargetP <> nil then begin
    T := C.TargetP;
    D := Sqrt(D2(C.X, C.Y, T.X, T.Y));
    if D < 1.05 then begin
      C.BiteT := C.BiteT - DT;
      if C.BiteT <= 0 then begin
        C.BiteT := 0.24;
        Amt := Min(0.18, T.S); T.S := T.S - Amt;
        if C.Kind = 0 then Eff := 1 else Eff := 0.5;
        C.Energy := Min(C.MaxE, C.Energy + Amt * 32 * Eff);
      end;
    end;
  end;
  if (C.TargetC <> nil) and (C.Kind = 1) then begin
    O := C.TargetC;
    D := Sqrt(D2(C.X, C.Y, O.X, O.Y));
    if (D < 1.15) and (C.AtkCd <= 0) then begin
      C.AtkCd := 1.1; C.Flash := 0.6;
      Esc := ClampF(0.92 - (O.Sp - C.Sp) * 0.16, 0.32, 0.92);
      if Random < Esc then begin
        Gain := 32 + 26 * O.Sz + O.Energy * 0.2;
        Kill(O, 'dévoré');
        C.Energy := Min(C.MaxE, C.Energy + Gain);
        C.TargetC := nil;
      end else begin
        O.Fleeing := True; O.FleeA := ArcTan2(O.Y - C.Y, O.X - C.X);
        C.State := 'raté';
      end;
    end;
  end;

  if C.Kind = 0 then
    C.Energy := C.Energy - (0.45 + 0.10 * Des + 0.32 * C.Sz) * DT
  else
    C.Energy := C.Energy - (0.48 + 0.12 * Des + 0.50 * C.Sz) * DT;

  if (C.Energy > IfThen(C.Kind = 0, 76, 90)) and (C.Age > 8) and (C.RepCd <= 0) then
    if ((C.Kind = 0) and (CountH < MAXH)) or ((C.Kind = 1) and (CountP < MAXC)) then begin
      Crowd := CrowdCount(C, IfThen(C.Kind = 0, 5, 7));
      if C.Kind = 0 then Damp := 1 / (1 + Crowd * 0.22)
                    else Damp := 1 / (1 + Crowd * 0.45);
      if Random < Damp * DT * IfThen(C.Kind = 0, 0.85, 0.28) then begin
        SpawnCreature(C.Kind, C.X + Cos(C.Angle) * 1.3, C.Y + Sin(C.Angle) * 1.3,
                      C, nil, C.Gen + 1);
        if C.Kind = 0 then begin
          Creatures.Last.Energy := 38; C.Energy := C.Energy - 46; C.RepCd := 7;
        end else begin
          Creatures.Last.Energy := 45; C.Energy := C.Energy - 62; C.RepCd := 17;
        end;
      end else C.RepCd := 2;
    end;

  if C.Alive then begin
    if C.Energy <= 0 then Kill(C, 'famine')
    else if C.Age > C.MaxAge then Kill(C, 'vieillesse');
  end;
end;

// ================= sapiens =================

procedure SenseSapien(C: TCreature);
var I: Integer; FB: TPlant; Peer, Pred, O: TCreature;
   PD2, QD2, D: Single; Rel: Single;
begin
  for I := 0 to NIN - 1 do C.Inp[I] := 0;
  C.Inp[0] := 1;
  C.Inp[1] := ClampF(C.Energy / C.MaxE, 0, 1);
  C.Inp[2] := FDayLight;
  FB := FindPlant(C);
  if FB <> nil then begin
    Rel := NormA(ArcTan2(FB.Y - C.Y, FB.X - C.X) - C.Angle);
    D := Sqrt(D2(C.X, C.Y, FB.X, FB.Y));
    C.Inp[3] := Cos(Rel); C.Inp[4] := Sin(Rel);
    C.Inp[5] := 1 - D / C.Se;
  end;
  Peer := nil; Pred := nil; PD2 := MaxSingle; QD2 := MaxSingle;
  CollectNear(C.X, C.Y, C.Se);
  for O in NB do begin
    if (not O.Alive) or (O = C) then Continue;
    D := D2(C.X, C.Y, O.X, O.Y);
    if (O.Kind = 2) and (D < PD2) then begin PD2 := D; Peer := O end
    else if (O.Kind = 1) and (D < QD2) then begin QD2 := D; Pred := O end;
  end;
  if Peer <> nil then begin
    Rel := NormA(ArcTan2(Peer.Y - C.Y, Peer.X - C.X) - C.Angle);
    C.Inp[6] := Cos(Rel); C.Inp[7] := Sin(Rel);
    C.Inp[8] := 1 - Sqrt(PD2) / C.Se;
  end;
  if Pred <> nil then begin
    Rel := NormA(ArcTan2(Pred.Y - C.Y, Pred.X - C.X) - C.Angle);
    C.Inp[9] := Cos(Rel); C.Inp[10] := Sin(Rel);
    C.Inp[11] := 1 - Sqrt(QD2) / C.Se;
  end;
  C.Fleeing := False;
  if (Pred <> nil) and (QD2 < 13) then begin
    C.Fleeing := True;
    C.FleeA := ArcTan2(C.Y - Pred.Y, C.X - Pred.X);
  end;
end;

function ChooseMate(C: TCreature): TCreature;
var O: TCreature; Best: TCreature; BS, SC: Single;
begin
  Best := nil; BS := -1;
  CollectNear(C.X, C.Y, C.Se);
  for O in NB do begin
    if (not O.Alive) or (O = C) then Continue;
    if (O.Kind <> 2) or (O.Age < CHILDHOOD) then Continue;
    SC := (1 - Abs(O.Orn - C.Pref)) *
          (1 - Sqrt(D2(C.X, C.Y, O.X, O.Y)) / C.Se);
    if SC > BS then begin BS := SC; Best := O end;
  end;
  Result := Best;
end;

procedure StepSapien(C: TCreature; DT: Single);
var Des, SP, SM, NX, NY, Amt, Crowd, Damp, Thrust: Single;
   F: TPlant; Mate: TCreature;
begin
  C.Age := C.Age + DT; C.ThinkT := C.ThinkT - DT;
  C.AtkCd := C.AtkCd - DT; C.RepCd := C.RepCd - DT;
  if C.Flash > 0 then C.Flash := Max(0, C.Flash - DT);
  if C.ThinkT <= 0 then begin
    C.ThinkT := 0.1;
    SenseSapien(C); ThinkNet(C);
  end;

  if C.Fleeing then begin
    C.State := 'en fuite';
    Des := C.Sp * 1.08;
    C.Angle := C.Angle + ClampF(NormA(C.FleeA - C.Angle), -8 * DT, 8 * DT);
  end else begin
    Thrust := (C.Oo[1] + 1) / 2;
    Des := C.Sp * (0.18 + 0.9 * Thrust);
    C.Angle := C.Angle + C.Oo[0] * 4.5 * DT;
    F := FindPlant(C);
    if (F <> nil) and (F.S > 0.12) and (D2(C.X, C.Y, F.X, F.Y) < 1.2) then begin
      C.State := 'récolte';
      C.BiteT := C.BiteT - DT;
      if C.BiteT <= 0 then begin
        C.BiteT := 0.22;
        Amt := Min(0.2, F.S); F.S := F.S - Amt;
        C.Energy := Min(C.MaxE, C.Energy + Amt * 32 * 1.9);
      end;
    end else C.State := 'explore';
  end;

  SM := 1;
  if Walkable(C.X, C.Y) and (TerrType[CellIdx(C.X, C.Y)] = T_FOR) then SM := 0.7;
  SP := Des * SM;
  NX := C.X + Cos(C.Angle) * SP * DT; NY := C.Y + Sin(C.Angle) * SP * DT;
  if Walkable(NX, NY) then begin C.X := NX; C.Y := NY end
  else if Walkable(NX, C.Y) then begin C.X := NX; C.Angle := C.Angle + (Random - 0.5) * 1.2 end
  else if Walkable(C.X, NY) then begin C.Y := NY; C.Angle := C.Angle + (Random - 0.5) * 1.2 end
  else C.Angle := C.Angle + 2.4 * DT;
  C.X := ClampF(C.X, 0.01, GW - 0.01); C.Y := ClampF(C.Y, 0.01, GH - 0.01);

  C.Energy := C.Energy - (0.52 + 0.11 * Des + 0.34 * C.Sz + 0.20 * Sqr(C.Orn)) * DT;

  if (C.Energy > C.MaxE * 0.78) and (C.Age > CHILDHOOD) and
     (C.RepCd <= 0) and (CountS < MAXS) then begin
    Mate := ChooseMate(C);
    if Mate <> nil then begin
      Crowd := CrowdCount(C, 6);
      Damp := 1 / (1 + Crowd * 0.3);
      if Random < DT * 0.7 * ClampF((C.Oo[3] + 1) / 2, 0, 1) * Damp then begin
        SpawnCreature(2, C.X + Cos(C.Angle) * 1.3, C.Y + Sin(C.Angle) * 1.3,
                      C, Mate, C.Gen + 1);
        Creatures.Last.Energy := 50;
        C.Energy := C.Energy - 60; C.RepCd := 9;
        Mate.RepCd := Max(Mate.RepCd, 4);
      end;
    end else
      C.RepCd := 1.5;
  end;
  if C.Alive then begin
    if C.Energy <= 0 then Kill(C, 'famine')
    else if C.Age > C.MaxAge then Kill(C, 'vieillesse');
  end;
end;

// ================= boucle de simulation =================

procedure DoStep(DT: Single);
var I, T: Integer; C: TCreature;
begin
  FSimTime := FSimTime + DT;
  FDayT := FSimTime / CDAY - Floor(FSimTime / CDAY);
  FDayLight := ClampF(0.5 + Sin(FDayT * TAU) * 1.05, 0.05, 1);
  StepPlants(DT, 0.25 + 0.75 * FDayLight);
  RebuildGrid;
  for I := Creatures.Count - 1 downto 0 do begin
    C := Creatures[I];
    if not C.Alive then begin Creatures.Delete(I); C.Free; Continue end;
    if C.Kind = 2 then StepSapien(C, DT) else StepCreature(C, DT);
  end;
  SampleT := SampleT + DT;
  if SampleT >= 1 then begin
    SampleT := 0;
    if (CountH < 12) or (CountP < 4) or (CountS < 4) then
      for T := 1 to 60 do
        if Walkable(Random(GW), Random(GH)) then begin
          if CountH < 12 then for I := 1 to 2 do
            SpawnCreature(0, Random(GW), Random(GH), nil, nil, 0);
          if CountP < 4  then SpawnCreature(1, Random(GW), Random(GH), nil, nil, 0);
          if CountS < 4  then SpawnCreature(2, Random(GW), Random(GH), nil, nil, 0);
          Toast('des immigrants ont rejoint l''île');
          Break;
        end;
    if Length(FHist) >= HISTMAX then begin
      Move(FHist[1], FHist[0], (HISTMAX - 1) * SizeOf(THistRec));
      SetLength(FHist, HISTMAX);
      FHist[HISTMAX - 1].P := Plants.Count;
      FHist[HISTMAX - 1].H := CountH;
      FHist[HISTMAX - 1].C := CountP;
      FHist[HISTMAX - 1].S := CountS;
    end else begin
      SetLength(FHist, Length(FHist) + 1);
      FHist[High(FHist)].P := Plants.Count;
      FHist[High(FHist)].H := CountH;
      FHist[High(FHist)].C := CountP;
      FHist[High(FHist)].S := CountS;
    end;
  end;
  if FMsgT > 0 then FMsgT := FMsgT - DT;
end;

// ================= thread de simulation =================

procedure TSimThread.Execute;
var FC: TStopwatch; Elapsed, Acc: Double; N: Integer;
begin
  FC := TStopwatch.StartNew;
  while not Terminated do begin
    Elapsed := FC.ElapsedMilliseconds / 1000;
    FC := TStopwatch.StartNew;
    if Elapsed > 0.1 then Elapsed := 0.1;
    if FStarted and FRunning then begin
      Acc := Elapsed * FSpeed; N := 0;
      while (Acc >= STEPDT) and (N < 6) do begin
        FSimCS.Enter;
        try
          DoStep(STEPDT);
        finally
          FSimCS.Leave;
        end;
        Acc := Acc - STEPDT; Inc(N);
      end;
    end;
    Sleep(1);
  end;
end;

// ================= sauvegarde / chargement (v2) =================

function SavePath: string;
begin
  Result := ExtractFilePath(ParamStr(0)) + 'microcosme.sav';
end;

procedure WriteStr(FS: TFileStream; const S: string);
var L: Integer; B: TBytes;
begin
  B := TEncoding.UTF8.GetBytes(S);
  L := Length(B);
  FS.WriteBuffer(L, SizeOf(Integer));
  if L > 0 then FS.WriteBuffer(B[0], L);
end;

function ReadStr(FS: TFileStream): string;
var L: Integer; B: TBytes;
begin
  FS.ReadBuffer(L, SizeOf(Integer));
  if (L < 0) or (L > 10000) then raise Exception.Create('données corrompues');
  SetLength(B, L);
  if L > 0 then FS.ReadBuffer(B[0], L);
  Result := TEncoding.UTF8.GetString(B);
end;

procedure SaveWorld;
var FS: TFileStream; I, N: Integer; C: TCreature; P: TPlant;
   Ver: Integer; TmpS: Single;
begin
  FSimCS.Enter;
  try
    FS := TFileStream.Create(SavePath, fmCreate);
    try
      Ver := SVERSION;
      FS.WriteBuffer(SMAGIC, 4);
      FS.WriteBuffer(Ver, SizeOf(Integer));
      FS.WriteBuffer(SX, SizeOf(Integer));  FS.WriteBuffer(SY, SizeOf(Integer));
      FS.WriteBuffer(FSimTime, SizeOf(Single));
      FS.WriteBuffer(UidH, SizeOf(Integer)); FS.WriteBuffer(UidP, SizeOf(Integer));
      FS.WriteBuffer(UidS, SizeOf(Integer));
      FS.WriteBuffer(FZoom, SizeOf(Single)); FS.WriteBuffer(FCamX, SizeOf(Single));
      FS.WriteBuffer(FCamY, SizeOf(Single));
      N := Length(FHist);
      FS.WriteBuffer(N, SizeOf(Integer));
      if N > 0 then FS.WriteBuffer(FHist[0], N * SizeOf(THistRec));
      N := Plants.Count;
      FS.WriteBuffer(N, SizeOf(Integer));
      for P in Plants do begin
        FS.WriteBuffer(P.X, SizeOf(Single)); FS.WriteBuffer(P.Y, SizeOf(Single));
        FS.WriteBuffer(P.S, SizeOf(Single));
      end;
      N := 0;
      for C in Creatures do if C.Alive then Inc(N);
      FS.WriteBuffer(N, SizeOf(Integer));
      for C in Creatures do
        if C.Alive then begin
          FS.WriteBuffer(C.Kind, SizeOf(Integer));
          FS.WriteBuffer(C.X, SizeOf(Single));  FS.WriteBuffer(C.Y, SizeOf(Single));
          FS.WriteBuffer(C.Angle, SizeOf(Single)); FS.WriteBuffer(C.WAngle, SizeOf(Single));
          FS.WriteBuffer(C.Sp, SizeOf(Single)); FS.WriteBuffer(C.Se, SizeOf(Single));
          FS.WriteBuffer(C.Sz, SizeOf(Single));
          FS.WriteBuffer(C.Energy, SizeOf(Single)); FS.WriteBuffer(C.MaxE, SizeOf(Single));
          FS.WriteBuffer(C.Age, SizeOf(Single)); FS.WriteBuffer(C.MaxAge, SizeOf(Single));
          FS.WriteBuffer(C.Gen, SizeOf(Integer));
          FS.WriteBuffer(C.ThinkT, SizeOf(Single));
          FS.WriteBuffer(C.RepCd, SizeOf(Single));
          FS.WriteBuffer(C.Born, SizeOf(Single));
          TmpS := C.Orn;  FS.WriteBuffer(TmpS, SizeOf(Single));
          TmpS := C.Pref; FS.WriteBuffer(TmpS, SizeOf(Single));
          TmpS := C.Hue;  FS.WriteBuffer(TmpS, SizeOf(Single));
          WriteStr(FS, C.Name);
          WriteStr(FS, C.State);
          if C.Kind = 2 then
            for I := 0 to NW - 1 do begin
              TmpS := C.Net[I];
              FS.WriteBuffer(TmpS, SizeOf(Single));
            end;
        end;
    finally
      FS.Free;
    end;
    Toast('monde sauvegardé');
  finally
    FSimCS.Leave;
  end;
end;

procedure LoadWorld;
var FS: TFileStream; I, K, N: Integer; C: TCreature;
   Magic: array[0..3] of AnsiChar; VerI, SXi, SYi: Integer;
   FXs, FYs, FSz, TmpS: Single;
begin
  FSimCS.Enter;
  try
    if not FileExists(SavePath) then begin Toast('aucune sauvegarde trouvée'); Exit end;
    try
      FS := TFileStream.Create(SavePath, fmOpenRead or fmShareDenyWrite);
      try
        FS.ReadBuffer(Magic, 4);
        if not CompareMem(@Magic, @SMAGIC, 4) then begin
          Toast('fichier de sauvegarde invalide'); Exit;
        end;
        FS.ReadBuffer(VerI, SizeOf(Integer));
        if VerI <> SVERSION then begin Toast('version incompatible'); Exit end;
        ClearWorldObjects;
        FS.ReadBuffer(SXi, SizeOf(Integer)); SX := SXi;
        FS.ReadBuffer(SYi, SizeOf(Integer)); SY := SYi;
        GenTerrain; RenderTerrainBmp;
        FS.ReadBuffer(FSimTime, SizeOf(Single));
        FS.ReadBuffer(UidH, SizeOf(Integer)); FS.ReadBuffer(UidP, SizeOf(Integer));
        FS.ReadBuffer(UidS, SizeOf(Integer));
        FS.ReadBuffer(FZoom, SizeOf(Single)); FS.ReadBuffer(FCamX, SizeOf(Single));
        FS.ReadBuffer(FCamY, SizeOf(Single));
        ClampCam;
        FS.ReadBuffer(N, SizeOf(Integer));
        SetLength(FHist, N);
        if N > 0 then FS.ReadBuffer(FHist[0], N * SizeOf(THistRec));
        FS.ReadBuffer(N, SizeOf(Integer));
        for I := 1 to N do begin
          FS.ReadBuffer(FXs, SizeOf(Single)); FS.ReadBuffer(FYs, SizeOf(Single));
          FS.ReadBuffer(FSz, SizeOf(Single));
          AddPlant(FXs, FYs, FSz);
        end;
        FS.ReadBuffer(N, SizeOf(Integer));
        for I := 1 to N do begin
          C := TCreature.Create;
          FS.ReadBuffer(C.Kind, SizeOf(Integer));
          FS.ReadBuffer(C.X, SizeOf(Single));  FS.ReadBuffer(C.Y, SizeOf(Single));
          FS.ReadBuffer(C.Angle, SizeOf(Single)); FS.ReadBuffer(C.WAngle, SizeOf(Single));
          FS.ReadBuffer(C.Sp, SizeOf(Single)); FS.ReadBuffer(C.Se, SizeOf(Single));
          FS.ReadBuffer(C.Sz, SizeOf(Single));
          FS.ReadBuffer(C.Energy, SizeOf(Single)); FS.ReadBuffer(C.MaxE, SizeOf(Single));
          FS.ReadBuffer(C.Age, SizeOf(Single)); FS.ReadBuffer(C.MaxAge, SizeOf(Single));
          FS.ReadBuffer(C.Gen, SizeOf(Integer));
          FS.ReadBuffer(C.ThinkT, SizeOf(Single));
          FS.ReadBuffer(C.RepCd, SizeOf(Single));
          FS.ReadBuffer(C.Born, SizeOf(Single));
          FS.ReadBuffer(TmpS, SizeOf(Single)); C.Orn := TmpS;
          FS.ReadBuffer(TmpS, SizeOf(Single)); C.Pref := TmpS;
          FS.ReadBuffer(TmpS, SizeOf(Single)); C.Hue := TmpS;
          C.HueCol := HueColor(C.Hue);
          C.Name := ReadStr(FS);
          C.State := ReadStr(FS);
          C.Alive := True; C.TargetC := nil; C.TargetP := nil;
          C.Fleeing := False; C.FleeA := 0;
          C.BiteT := 0; C.AtkCd := 0; C.Flash := 0;
          if C.Kind = 2 then begin
            SetLength(C.Net, NW);
            SetLength(C.Inp, NIN); SetLength(C.Hid, NHID); SetLength(C.Oo, NOUT);
            for K := 0 to NW - 1 do begin
              FS.ReadBuffer(TmpS, SizeOf(Single));
              C.Net[K] := TmpS;
            end;
          end;
          Creatures.Add(C);
          case C.Kind of 0: Inc(CountH); 1: Inc(CountP); 2: Inc(CountS) end;
        end;
        FSelected := nil;
        FRunning := False; FStarted := True;
        Toast('monde chargé');
      finally
        FS.Free;
      end;
    except
      Toast('chargement impossible — fichier illisible');
    end;
  finally
    FSimCS.Leave;
  end;
end;

// ================= rendu terrain : texture interpolée continue =================

procedure RenderTerrainBmp;
const
  SS = 8;
var
  PX, PY, W, H, GX, GY, X0, X1, Y0, Y1, I, T: Integer;
  FX, FY, Ev, Hu, M, L, PrevE, Slope: Single;
  Row: PCardinal;
  Col32: Cardinal;
  E00, E10, E01, E11, H00, H10, H01, H11: Double;
const
  BaseCol: array[0..6] of array[0..2] of Integer = (
    (16,38,40),(37,73,67),(186,168,122),(110,131,79),
    (63,89,57),(118,113,100),(208,206,192));
begin
  W := GW * SS; H := GH * SS;
  FTerrain.PixelFormat := pf32bit;
  FTerrain.SetSize(W, H);
  PrevE := 0;
  for PY := 0 to H - 1 do begin
    Row := PCardinal(FTerrain.ScanLine[PY]);
    GY := PY div SS;
    FY := (PY - GY * SS) / SS;
    Y0 := GY; if Y0 > GH - 1 then Y0 := GH - 1;
    Y1 := Y0 + 1; if Y1 > GH - 1 then Y1 := GH - 1;
    for PX := 0 to W - 1 do begin
      GX := PX div SS;
      FX := (PX - GX * SS) / SS;
      X0 := GX; if X0 > GW - 1 then X0 := GW - 1;
      X1 := X0 + 1; if X1 > GW - 1 then X1 := GW - 1;
      E00 := Elev[Y0 * GW + X0];  E10 := Elev[Y0 * GW + X1];
      E01 := Elev[Y1 * GW + X0];  E11 := Elev[Y1 * GW + X1];
      Ev := (E00 + (E10 - E00) * FX) * (1 - FY) +
            (E01 + (E11 - E01) * FX) * FY;
      H00 := Humid[Y0 * GW + X0]; H10 := Humid[Y0 * GW + X1];
      H01 := Humid[Y1 * GW + X0]; H11 := Humid[Y1 * GW + X1];
      Hu := (H00 + (H10 - H00) * FX) * (1 - FY) +
            (H01 + (H11 - H01) * FX) * FY;
      if Ev < 0.34 then T := T_DEEP
      else if Ev < 0.40 then T := T_SHAL
      else if Ev < 0.435 then T := T_SAND
      else if Ev < 0.68 then begin
        if Hu > 0.57 then T := T_FOR else T := T_GRASS;
      end
      else if Ev < 0.79 then T := T_ROCK
      else T := T_SNOW;
      L := 1;
      if T >= T_SAND then begin
        Slope := PrevE - Ev;
        L := ClampF(1 + Slope * 12, 0.85, 1.25);
      end;
      PrevE := Ev;
      M := L * (1 + (Hash2(PX + SX * 13, PY + SY * 7) - 0.5) * 0.10);
      I := Y0 * GW + X0;
      if (T = T_SHAL) and (X0 > 0) and (X0 < GW - 1) and (Y0 > 0) and (Y0 < GH - 1) and
         ((TerrType[I - 1] >= T_SAND) or (TerrType[I + 1] >= T_SAND) or
          (TerrType[I - GW] >= T_SAND) or (TerrType[I + GW] >= T_SAND)) then
        M := M * 1.45;
      Col32 := (Cardinal(Trunc(ClampF(BaseCol[T][0] * M, 0, 255))) shl 16) or
               (Cardinal(Trunc(ClampF(BaseCol[T][1] * M, 0, 255))) shl 8) or
                Cardinal(Trunc(ClampF(BaseCol[T][2] * M, 0, 255)));
      Row[PX] := Col32;
    end;
  end;
  FThumb.SetSize(100, 62);
  FThumb.Canvas.StretchDraw(Rect(0, 0, 100, 62), FTerrain);
end;

// ================= rendu monde =================

procedure AlphaFill(C: TCanvas; W, H: Integer; Tint: TBitmap; Clr: TColor; A: Byte);
var BF: TBlendFunction;
begin
  if (Tint.Width <> W) or (Tint.Height <> H) or (Tint.PixelFormat <> pf32bit) then begin
    Tint.PixelFormat := pf32bit;
    Tint.SetSize(W, H);
    Tint.Canvas.Brush.Style := bsSolid;
    Tint.Canvas.Brush.Color := Clr;
    Tint.Canvas.FillRect(Rect(0, 0, W, H));
  end;
  BF.BlendOp := AC_SRC_OVER; BF.BlendFlags := 0;
  BF.SourceConstantAlpha := A; BF.AlphaFormat := 0;
  AlphaBlend(C.Handle, 0, 0, W, H, Tint.Canvas.Handle, 0, 0, W, H, BF);
end;

procedure RenderWorld;
var S, OX, OY, VX0, VY0, VX1, VY1: Double;
   W, H, PX, PY, RR, K: Integer;
   P: TPlant; C: TCreature;
   R, HR, HeadX, HeadY, Grow, CA, SA, SinD, Warm: Single;
   Poly: array[0..2] of TPoint;
   function InV(X, Y, M: Double): Boolean;
   begin
     Result := (X > VX0 - M) and (X < VX1 + M) and (Y > VY0 - M) and (Y < VY1 + M);
   end;
begin
  W := FVP.Width; H := FVP.Height;
  S := FScale * FZoom;
  OX := W / 2 - (FCamX + 0.5) * S;
  OY := H / 2 - (FCamY + 0.5) * S;
  VX0 := FCamX - W / (2 * S); VX1 := VX0 + W / S;
  VY0 := FCamY - H / (2 * S); VY1 := VY0 + H / S;

  with FWorld.Canvas do begin
    Brush.Style := bsSolid;
    Brush.Color := Col(11, 14, 11);
    FillRect(Rect(0, 0, W, H));
    StretchDraw(Rect(Trunc(OX), Trunc(OY), Trunc(OX + GW * S), Trunc(OY + GH * S)), FTerrain);

    Pen.Style := psClear;
    Brush.Style := bsSolid;
    for P in Plants do
      if InV(P.X, P.Y, 2) then begin
        PX := Trunc(OX + P.X * S); PY := Trunc(OY + P.Y * S);
        RR := Trunc(S * (0.30 + 0.45 * P.S));
        if RR < 1 then Continue;
        Brush.Color := Col(122, 168, 84);
        Ellipse(PX - RR, PY - RR, PX + RR, PY + RR);
        RR := RR * 55 div 100;
        if RR >= 1 then begin
          Brush.Color := Col(190, 214, 130);
          Ellipse(PX - RR, PY - RR, PX + RR, PY + RR);
        end;
      end;

    for C in Creatures do begin
      if not C.Alive then Continue;
      if not InV(C.X, C.Y, 3) then Continue;
      PX := Trunc(OX + C.X * S); PY := Trunc(OY + C.Y * S);
      Grow := 0.55 + 0.45 * Min(1, C.Age / 8);
      R := S * (0.55 + 0.55 * C.Sz) * Grow;
      CA := Cos(C.Angle); SA := Sin(C.Angle);
      Pen.Style := psSolid;
      Pen.Width := Max(1, Trunc(S * 0.09));
      if C.Kind = 2 then begin
        // plume ornementale : trois brins dans la teinte de lignée
        HR := R * (0.5 + 1.7 * C.Orn);
        if HR > 2 then begin
          Pen.Style := psSolid;
          Pen.Color := C.HueCol;
          Pen.Width := Max(1, Trunc(S * 0.13));
          for K := -1 to 1 do begin
            MoveTo(PX, PY - Trunc(R * 0.3));
            LineTo(PX + K * Trunc(R * 0.85),
                   PY - Trunc(R * 0.3) - Trunc(HR));
          end;
        end;
        Pen.Style := psSolid;
        Pen.Color := Col(40, 30, 14);
        Pen.Width := Max(1, Trunc(S * 0.1));
        MoveTo(PX - Trunc(SA * R * 0.15), PY + Trunc(CA * R * 0.15));
        LineTo(PX + Trunc(SA * R * 0.15), PY - Trunc(CA * R * 0.15));
        Brush.Style := bsSolid;
        Brush.Color := Col(208, 167, 92);
        HeadX := PX + CA * R * 0.38; HeadY := PY + SA * R * 0.38;
        RR := Trunc(R * 0.44); if RR < 1 then RR := 1;
        Ellipse(Trunc(HeadX) - RR, Trunc(HeadY) - RR, Trunc(HeadX) + RR, Trunc(HeadY) + RR);
      end else if C.Kind = 0 then begin
        Pen.Color := Col(30, 32, 22);
        Brush.Style := bsSolid;
        Brush.Color := Col(228, 220, 190);
        RR := Trunc(R * 0.8); if RR < 1 then RR := 1;
        Ellipse(PX - Trunc(R), PY - RR, PX + Trunc(R), PY + RR);
        HeadX := PX + CA * R * 0.95; HeadY := PY + SA * R * 0.95;
        RR := Trunc(R * 0.5); if RR < 1 then RR := 1;
        Ellipse(Trunc(HeadX) - RR, Trunc(HeadY) - RR, Trunc(HeadX) + RR, Trunc(HeadY) + RR);
      end else begin
        Pen.Color := Col(35, 20, 14);
        Brush.Style := bsSolid;
        Brush.Color := Col(194, 106, 69);
        Poly[0] := Point(PX + Trunc(CA * R * 1.35), PY + Trunc(SA * R * 1.35));
        Poly[1] := Point(PX + Trunc(-CA * R * 0.9 - SA * R * 0.8),
                         PY + Trunc(-SA * R * 0.9 + CA * R * 0.8));
        Poly[2] := Point(PX + Trunc(-CA * R * 0.9 + SA * R * 0.8),
                         PY + Trunc(-SA * R * 0.9 - CA * R * 0.8));
        Polygon(Poly);
        Brush.Color := Col(42, 28, 20);
        HeadX := PX + CA * R * 0.45; HeadY := PY + SA * R * 0.45;
        RR := Trunc(Max(0.7, R * 0.14)); if RR < 1 then RR := 1;
        Ellipse(Trunc(HeadX) - RR, Trunc(HeadY) - RR, Trunc(HeadX) + RR, Trunc(HeadY) + RR);
      end;
    end;

    if (FSelected <> nil) and FSelected.Alive then begin
      PX := Trunc(OX + FSelected.X * S); PY := Trunc(OY + FSelected.Y * S);
      R := S * (0.55 + 0.55 * FSelected.Sz) * (0.55 + 0.45 * Min(1, FSelected.Age / 8));
      Pen.Color := Col(240, 232, 205); Pen.Width := 1; Pen.Style := psDot;
      Brush.Style := bsClear;
      RR := Trunc(R + 5); if RR < 3 then RR := 3;
      Ellipse(PX - RR, PY - RR, PX + RR, PY + RR);
      Pen.Style := psSolid; Pen.Color := Col(90, 96, 80);
      RR := Trunc(FSelected.Se * S);
      if RR > 2 then Ellipse(PX - RR, PY - RR, PX + RR, PY + RR);
    end;

    if FDayLight < 0.98 then
      AlphaFill(FWorld.Canvas, W, H, FTintN, Col(7, 12, 16), Trunc((1 - FDayLight) * 105));
    SinD := Sin(FDayT * TAU);
    Warm := Max(0, 1 - Abs(SinD) * 2.5);
    if Warm > 0 then
      AlphaFill(FWorld.Canvas, W, H, FTintW, Col(255, 150, 70), Trunc(Warm * 15));
  end;
end;

// ================= panneau =================

procedure AddBtn(const R: TRect; const Cap: string; Id: Integer; Active: Boolean);
var N: Integer;
begin
  N := Length(FBtns); SetLength(FBtns, N + 1);
  FBtns[N].R := R; FBtns[N].Cap := Cap; FBtns[N].Id := Id; FBtns[N].Active := Active;
end;

procedure DrawBar(C: TCanvas; X, Y, W: Integer; Frac: Single; Clr: TColor);
begin
  C.Brush.Style := bsSolid;
  C.Brush.Color := Col(32, 37, 28);
  C.FillRect(Rect(X, Y, X + W, Y + 4));
  C.Brush.Color := Clr;
  C.FillRect(Rect(X, Y, X + Trunc(W * ClampF(Frac, 0, 1)), Y + 4));
end;

procedure DrawLine(C: TCanvas; const R: TRect; MaxV, Kind: Integer);
var I, X, Yv: Integer; Clr: TColor;
  function Val(const HR: THistRec): Integer;
  begin
    case Kind of
      0: Result := HR.P;
      1: Result := HR.H;
      2: Result := HR.C;
    else Result := HR.S;
    end;
  end;
begin
  case Kind of
    0: Clr := Col(157, 187, 107);
    1: Clr := Col(228, 220, 190);
    2: Clr := Col(201, 106, 69);
  else Clr := Col(208, 167, 92);
  end;
  C.Pen.Color := Clr; C.Pen.Width := 1; C.Pen.Style := psSolid;
  for I := 0 to High(FHist) - 1 do begin
    X := R.Left + Trunc(I / (High(FHist) - 1) * (R.Right - R.Left - 1));
    Yv := R.Bottom - 2 - Trunc(Val(FHist[I]) / MaxV * (R.Bottom - R.Top - 4));
    if I = 0 then C.MoveTo(X, Yv) else C.LineTo(X, Yv);
  end;
end;

procedure RenderTerrainBmp;
const
  SS = 8;
var
  PX, PY, W, H, GX, GY, X0, X1, Y0, Y1, I, T: Integer;
  FX, FY, Ev, Hu, M, L, PrevE, Slope: Single;
  Row: PCardinal;
  Col32: Cardinal;
  E00, E10, E01, E11, H00, H10, H01, H11: Double;
const
  BaseCol: array[0..6] of array[0..2] of Integer = (
    (16,38,40),(37,73,67),(186,168,122),(110,131,79),
    (63,89,57),(118,113,100),(208,206,192));
begin
  W := GW * SS; H := GH * SS;
  FTerrain.PixelFormat := pf32bit;
  FTerrain.SetSize(W, H);
  PrevE := 0;
  for PY := 0 to H - 1 do begin
    Row := PCardinal(FTerrain.ScanLine[PY]);
    GY := PY div SS;
    FY := (PY - GY * SS) / SS;
    Y0 := GY; if Y0 > GH - 1 then Y0 := GH - 1;
    Y1 := Y0 + 1; if Y1 > GH - 1 then Y1 := GH - 1;
    for PX := 0 to W - 1 do begin
      GX := PX div SS;
      FX := (PX - GX * SS) / SS;
      X0 := GX; if X0 > GW - 1 then X0 := GW - 1;
      X1 := X0 + 1; if X1 > GW - 1 then X1 := GW - 1;
      E00 := Elev[Y0 * GW + X0];  E10 := Elev[Y0 * GW + X1];
      E01 := Elev[Y1 * GW + X0];  E11 := Elev[Y1 * GW + X1];
      Ev := (E00 + (E10 - E00) * FX) * (1 - FY) +
            (E01 + (E11 - E01) * FX) * FY;
      H00 := Humid[Y0 * GW + X0]; H10 := Humid[Y0 * GW + X1];
      H01 := Humid[Y1 * GW + X0]; H11 := Humid[Y1 * GW + X1];
      Hu := (H00 + (H10 - H00) * FX) * (1 - FY) +
            (H01 + (H11 - H01) * FX) * FY;
      if Ev < 0.34 then T := T_DEEP
      else if Ev < 0.40 then T := T_SHAL
      else if Ev < 0.435 then T := T_SAND
      else if Ev < 0.68 then begin
        if Hu > 0.57 then T := T_FOR else T := T_GRASS;
      end
      else if Ev < 0.79 then T := T_ROCK
      else T := T_SNOW;
      L := 1;
      if T >= T_SAND then begin
        Slope := PrevE - Ev;
        L := ClampF(1 + Slope * 12, 0.85, 1.25);
      end;
      PrevE := Ev;
      M := L * (1 + (Hash2(PX + SX * 13, PY + SY * 7) - 0.5) * 0.10);
      I := Y0 * GW + X0;
      if (T = T_SHAL) and (X0 > 0) and (X0 < GW - 1) and (Y0 > 0) and (Y0 < GH - 1) and
         ((TerrType[I - 1] >= T_SAND) or (TerrType[I + 1] >= T_SAND) or
          (TerrType[I - GW] >= T_SAND) or (TerrType[I + GW] >= T_SAND)) then
        M := M * 1.45;
      Col32 := (Cardinal(Trunc(ClampF(BaseCol[T][0] * M, 0, 255))) shl 16) or
               (Cardinal(Trunc(ClampF(BaseCol[T][1] * M, 0, 255))) shl 8) or
                Cardinal(Trunc(ClampF(BaseCol[T][2] * M, 0, 255)));
      Row[PX] := Col32;
    end;
  end;
  FThumb.SetSize(100, 62);
  FThumb.Canvas.StretchDraw(Rect(0, 0, 100, 62), FTerrain);
end;

// ================= rendu monde =================

procedure AlphaFill(C: TCanvas; W, H: Integer; Tint: TBitmap; Clr: TColor; A: Byte);
var BF: TBlendFunction;
begin
  if (Tint.Width <> W) or (Tint.Height <> H) or (Tint.PixelFormat <> pf32bit) then begin
    Tint.PixelFormat := pf32bit;
    Tint.SetSize(W, H);
    Tint.Canvas.Brush.Style := bsSolid;
    Tint.Canvas.Brush.Color := Clr;
    Tint.Canvas.FillRect(Rect(0, 0, W, H));
  end;
  BF.BlendOp := AC_SRC_OVER; BF.BlendFlags := 0;
  BF.SourceConstantAlpha := A; BF.AlphaFormat := 0;
  AlphaBlend(C.Handle, 0, 0, W, H, Tint.Canvas.Handle, 0, 0, W, H, BF);
end;

procedure RenderWorld;
var S, OX, OY, VX0, VY0, VX1, VY1: Double;
   W, H, PX, PY, RR, K: Integer;
   P: TPlant; C: TCreature;
   R, HR, HeadX, HeadY, Grow, CA, SA, SinD, Warm: Single;
   Poly: array[0..2] of TPoint;
   function InV(X, Y, M: Double): Boolean;
   begin
     Result := (X > VX0 - M) and (X < VX1 + M) and (Y > VY0 - M) and (Y < VY1 + M);
   end;
begin
  W := FVP.Width; H := FVP.Height;
  S := FScale * FZoom;
  OX := W / 2 - (FCamX + 0.5) * S;
  OY := H / 2 - (FCamY + 0.5) * S;
  VX0 := FCamX - W / (2 * S); VX1 := VX0 + W / S;
  VY0 := FCamY - H / (2 * S); VY1 := VY0 + H / S;

  with FWorld.Canvas do begin
    Brush.Style := bsSolid;
    Brush.Color := Col(11, 14, 11);
    FillRect(Rect(0, 0, W, H));
    StretchDraw(Rect(Trunc(OX), Trunc(OY), Trunc(OX + GW * S), Trunc(OY + GH * S)), FTerrain);

    Pen.Style := psClear;
    Brush.Style := bsSolid;
    for P in Plants do
      if InV(P.X, P.Y, 2) then begin
        PX := Trunc(OX + P.X * S); PY := Trunc(OY + P.Y * S);
        RR := Trunc(S * (0.30 + 0.45 * P.S));
        if RR < 1 then Continue;
        Brush.Color := Col(122, 168, 84);
        Ellipse(PX - RR, PY - RR, PX + RR, PY + RR);
        RR := RR * 55 div 100;
        if RR >= 1 then begin
          Brush.Color := Col(190, 214, 130);
          Ellipse(PX - RR, PY - RR, PX + RR, PY + RR);
        end;
      end;

    for C in Creatures do begin
      if not C.Alive then Continue;
      if not InV(C.X, C.Y, 3) then Continue;
      PX := Trunc(OX + C.X * S); PY := Trunc(OY + C.Y * S);
      Grow := 0.55 + 0.45 * Min(1, C.Age / 8);
      R := S * (0.55 + 0.55 * C.Sz) * Grow;
      CA := Cos(C.Angle); SA := Sin(C.Angle);
      Pen.Style := psSolid;
      Pen.Width := Max(1, Trunc(S * 0.09));
      if C.Kind = 2 then begin
        // plume ornementale : trois brins dans la teinte de lignée
        HR := R * (0.5 + 1.7 * C.Orn);
        if HR > 2 then begin
          Pen.Style := psSolid;
          Pen.Color := C.HueCol;
          Pen.Width := Max(1, Trunc(S * 0.13));
          for K := -1 to 1 do begin
            MoveTo(PX, PY - Trunc(R * 0.3));
            LineTo(PX + K * Trunc(R * 0.85),
                   PY - Trunc(R * 0.3) - Trunc(HR));
          end;
        end;
        Pen.Style := psSolid;
        Pen.Color := Col(40, 30, 14);
        Pen.Width := Max(1, Trunc(S * 0.1));
        MoveTo(PX - Trunc(SA * R * 0.15), PY + Trunc(CA * R * 0.15));
        LineTo(PX + Trunc(SA * R * 0.15), PY - Trunc(CA * R * 0.15));
        Brush.Style := bsSolid;
        Brush.Color := Col(208, 167, 92);
        HeadX := PX + CA * R * 0.38; HeadY := PY + SA * R * 0.38;
        RR := Trunc(R * 0.44); if RR < 1 then RR := 1;
        Ellipse(Trunc(HeadX) - RR, Trunc(HeadY) - RR, Trunc(HeadX) + RR, Trunc(HeadY) + RR);
      end else if C.Kind = 0 then begin
        Pen.Color := Col(30, 32, 22);
        Brush.Style := bsSolid;
        Brush.Color := Col(228, 220, 190);
        RR := Trunc(R * 0.8); if RR < 1 then RR := 1;
        Ellipse(PX - Trunc(R), PY - RR, PX + Trunc(R), PY + RR);
        HeadX := PX + CA * R * 0.95; HeadY := PY + SA * R * 0.95;
        RR := Trunc(R * 0.5); if RR < 1 then RR := 1;
        Ellipse(Trunc(HeadX) - RR, Trunc(HeadY) - RR, Trunc(HeadX) + RR, Trunc(HeadY) + RR);
      end else begin
        Pen.Color := Col(35, 20, 14);
        Brush.Style := bsSolid;
        Brush.Color := Col(194, 106, 69);
        Poly[0] := Point(PX + Trunc(CA * R * 1.35), PY + Trunc(SA * R * 1.35));
        Poly[1] := Point(PX + Trunc(-CA * R * 0.9 - SA * R * 0.8),
                         PY + Trunc(-SA * R * 0.9 + CA * R * 0.8));
        Poly[2] := Point(PX + Trunc(-CA * R * 0.9 + SA * R * 0.8),
                         PY + Trunc(-SA * R * 0.9 - CA * R * 0.8));
        Polygon(Poly);
        Brush.Color := Col(42, 28, 20);
        HeadX := PX + CA * R * 0.45; HeadY := PY + SA * R * 0.45;
        RR := Trunc(Max(0.7, R * 0.14)); if RR < 1 then RR := 1;
        Ellipse(Trunc(HeadX) - RR, Trunc(HeadY) - RR, Trunc(HeadX) + RR, Trunc(HeadY) + RR);
      end;
    end;

    if (FSelected <> nil) and FSelected.Alive then begin
      PX := Trunc(OX + FSelected.X * S); PY := Trunc(OY + FSelected.Y * S);
      R := S * (0.55 + 0.55 * FSelected.Sz) * (0.55 + 0.45 * Min(1, FSelected.Age / 8));
      Pen.Color := Col(240, 232, 205); Pen.Width := 1; Pen.Style := psDot;
      Brush.Style := bsClear;
      RR := Trunc(R + 5); if RR < 3 then RR := 3;
      Ellipse(PX - RR, PY - RR, PX + RR, PY + RR);
      Pen.Style := psSolid; Pen.Color := Col(90, 96, 80);
      RR := Trunc(FSelected.Se * S);
      if RR > 2 then Ellipse(PX - RR, PY - RR, PX + RR, PY + RR);
    end;

    if FDayLight < 0.98 then
      AlphaFill(FWorld.Canvas, W, H, FTintN, Col(7, 12, 16), Trunc((1 - FDayLight) * 105));
    SinD := Sin(FDayT * TAU);
    Warm := Max(0, 1 - Abs(SinD) * 2.5);
    if Warm > 0 then
      AlphaFill(FWorld.Canvas, W, H, FTintW, Col(255, 150, 70), Trunc(Warm * 15));
  end;
end;
// ================= caméra & interaction =================

function ScreenToWorld(SXp, SYp: Single): TPointF;
var S: Single;
begin
  S := FScale * FZoom;
  Result.X := FCamX + (SXp - FVP.Left - FVP.Width / 2) / S + 0.5;
  Result.Y := FCamY + (SYp - FVP.Top - FVP.Height / 2) / S + 0.5;
end;

procedure ClampCam;
var S: Single;
begin
  S := FScale * FZoom;
  if GW * S <= FVP.Width then FCamX := (GW - 1) / 2
  else FCamX := ClampF(FCamX, FVP.Width / (2 * S) - 0.5, GW - FVP.Width / (2 * S) - 0.5);
  if GH * S <= FVP.Height then FCamY := (GH - 1) / 2
  else FCamY := ClampF(FCamY, FVP.Height / (2 * S) - 0.5, GH - FVP.Height / (2 * S) - 0.5);
end;

procedure ZoomAt(MX, MY: Integer; F: Single);
var S0, S1, WA, WB: Single;
begin
  S0 := FScale * FZoom;
  WA := FCamX + (MX - FVP.Left - FVP.Width / 2) / S0;
  WB := FCamY + (MY - FVP.Top - FVP.Height / 2) / S0;
  FZoom := ClampF(FZoom * F, 1, 6);
  S1 := FScale * FZoom;
  FCamX := WA - (MX - FVP.Left - FVP.Width / 2) / S1;
  FCamY := WB - (MY - FVP.Top - FVP.Height / 2) / S1;
  ClampCam;
end;

procedure Pick(X, Y: Single);
var C, Best: TCreature; BD, D: Single;
begin
  Best := nil; BD := 2.2 * 2.2;
  for C in Creatures do begin
    if not C.Alive then Continue;
    D := D2(X, Y, C.X, C.Y);
    if D < BD then begin BD := D; Best := C end;
  end;
  FSelected := Best;
end;

// ================= nouveau monde =================

procedure NewWorld;
var G, I: Integer; X, Y: Single;
begin
  FSimCS.Enter;
  try
    ClearWorldObjects;
    SX := Random(4096); SY := Random(4096);
    GenTerrain;
    RenderTerrainBmp;
    FSimTime := CDAY * 0.18; SampleT := 0;
    for I := 1 to 320 do AddPlant(Random(GW), Random(GH), 0.3 + Random * 0.6);
    for G := 1 to 4 do begin
      X := Random(GW); Y := Random(GH);
      for I := 1 to 15 do
        SpawnCreature(0, X + Random * 8 - 4, Y + Random * 8 - 4, nil, nil, 0);
    end;
    for G := 1 to 2 do begin
      X := Random(GW); Y := Random(GH);
      for I := 1 to 3 do
        SpawnCreature(1, X + Random * 6 - 3, Y + Random * 6 - 3, nil, nil, 0);
    end;
    X := GW / 2; Y := GH / 2;
    for I := 1 to 25 do
      if Walkable(X, Y) and (TerrType[CellIdx(X, Y)] >= T_GRASS) then Break
      else begin X := Random(GW); Y := Random(GH) end;
    for I := 1 to 6 do
      SpawnCreature(2, X + Random * 6 - 3, Y + Random * 6 - 3, nil, nil, 0);
    FZoom := 1; FCamX := (GW - 1) / 2; FCamY := (GH - 1) / 2;
    FRunning := False; FStarted := False;
    Toast('nouveau monde');
  finally
    FSimCS.Leave;
  end;
end;

// ================= méthodes de la fiche =================

procedure TMainForm.WMEraseBkgnd(var Msg: TWMEraseBkgnd);
begin
  Msg.Result := 1;
end;

procedure TMainForm.FormMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var I: Integer; WP: TPointF;
begin
  if Button = mbRight then begin
    if X >= PANELW then begin
      FDrag := True; FDragX := X; FDragY := Y; FDragCX := FCamX; FDragCY := FCamY;
    end;
    Exit;
  end;
  if X < PANELW then begin
    for I := 0 to High(FBtns) do
      if PtInRect(FBtns[I].R, Point(X, Y)) then begin
        case FBtns[I].Id of
          BID_START: begin FStarted := True; FRunning := True end;
          BID_PLAY:  FRunning := not FRunning;
          BID_S1: FSpeed := 1;
          BID_S2: FSpeed := 2;
          BID_S4: FSpeed := 4;
          BID_TI: FTool := TOOL_INSPECT;
          BID_TS: FTool := TOOL_SEED;
          BID_TH: FTool := TOOL_HERB;
          BID_TP: FTool := TOOL_PRED;
          BID_TSA: FTool := TOOL_SAP;
          BID_SAVE: SaveWorld;
          BID_LOAD: LoadWorld;
          BID_NEW: NewWorld;
        end;
        Invalidate;
        Exit;
      end;
    Exit;
  end;
  if not FStarted then begin
    FStarted := True; FRunning := True; Invalidate; Exit;
  end;
  WP := ScreenToWorld(X, Y);
  FSimCS.Enter;
  try
    case FTool of
      TOOL_INSPECT: Pick(WP.X, WP.Y);
      TOOL_SEED: AddPlant(WP.X + (Random - 0.5) * 2, WP.Y + (Random - 0.5) * 2,
                          0.25 + Random * 0.35);
      TOOL_HERB: SpawnCreature(0, WP.X, WP.Y, nil, nil, 0);
      TOOL_PRED: SpawnCreature(1, WP.X, WP.Y, nil, nil, 0);
      TOOL_SAP:  SpawnCreature(2, WP.X, WP.Y, nil, nil, 0);
    end;
  finally
    FSimCS.Leave;
  end;
  Invalidate;
end;

procedure TMainForm.FormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  if FDrag then begin
    FCamX := FDragCX - (X - FDragX) / (FScale * FZoom);
    FCamY := FDragCY - (Y - FDragY) / (FScale * FZoom);
    ClampCam;
    Invalidate;
  end;
end;

procedure TMainForm.FormMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  FDrag := False;
end;

function TMainForm.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer;
  MousePos: TPoint): Boolean;
var P: TPoint;
begin
  Result := inherited;
  P := ScreenToClient(MousePos);
  if (P.X >= FVP.Left) and FStarted then begin
    ZoomAt(P.X, P.Y, Exp(-WheelDelta * 0.0016));
    Invalidate;
    Result := True;
  end;
end;

procedure TMainForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_SPACE then begin
    if not FStarted then FStarted := True
    else FRunning := not FRunning;
    Key := 0; Invalidate;
  end;
end;

procedure TMainForm.FormResize(Sender: TObject);
begin
  FVP := Rect(PANELW, 0, Max(ClientWidth, PANELW + 8), Max(ClientHeight, 8));
  if (FVP.Width > 0) and (FVP.Height > 0) then begin
    FWorld.SetSize(FVP.Width, FVP.Height);
    FScale := Max(FVP.Width / GW, FVP.Height / GH);
    ClampCam;
  end;
  Invalidate;
end;

procedure TMainForm.FormPaint(Sender: TObject);
var BR: TRect;
begin
  if (FWorld.Width <> FVP.Width) or (FWorld.Height <> FVP.Height) then
    FormResize(Self);
  FSimCS.Enter;
  try
    RenderWorld;
    Canvas.Draw(FVP.Left, FVP.Top, FWorld);
    DrawPanel(Canvas, ClientHeight);
    if FMsgT > 0 then begin
      Canvas.Font.Name := 'Segoe UI'; Canvas.Font.Size := 9; Canvas.Font.Style := [];
      Canvas.Brush.Style := bsSolid; Canvas.Brush.Color := Col(17, 21, 15);
      Canvas.Pen.Style := psSolid; Canvas.Pen.Color := Col(38, 43, 33);
      Canvas.Rectangle(FVP.Left + 20, FVP.Bottom - 44,
                       FVP.Left + 20 + Canvas.TextWidth(FMsg) + 20, FVP.Bottom - 18);
      Canvas.Brush.Style := bsClear; Canvas.Font.Color := Col(230, 224, 205);
      Canvas.TextOut(FVP.Left + 30, FVP.Bottom - 39, FMsg);
    end;
  finally
    FSimCS.Leave;
  end;
  if not FStarted then begin
    Canvas.Brush.Style := bsSolid;
    Canvas.Brush.Color := Col(14, 17, 12);
    Canvas.FillRect(FVP);
    Canvas.Font.Name := 'Georgia'; Canvas.Font.Size := 34;
    Canvas.Font.Style := [fsItalic, fsBold]; Canvas.Font.Color := Col(230, 224, 205);
    Canvas.Brush.Style := bsClear;
    Canvas.TextOut(FVP.Left + (FVP.Width - Canvas.TextWidth('Microcosme')) div 2,
                   FVP.Top + FVP.Height div 2 - 60, 'Microcosme');
    BR := Rect(FVP.Left + FVP.Width div 2 - 100, FVP.Top + FVP.Height div 2 + 10,
               FVP.Left + FVP.Width div 2 + 100, FVP.Top + FVP.Height div 2 + 52);
    AddBtn(BR, 'Observer le monde', BID_START, True);
    Canvas.Brush.Style := bsSolid; Canvas.Brush.Color := Col(208, 167, 92);
    Canvas.FillRect(BR);
    Canvas.Brush.Style := bsClear; Canvas.Font.Name := 'Segoe UI';
    Canvas.Font.Size := 10; Canvas.Font.Style := [fsBold];
    Canvas.Font.Color := Col(20, 22, 16);
    Canvas.TextOut((BR.Left + BR.Right - Canvas.TextWidth('Observer le monde')) div 2,
                   BR.Top + 13, 'Observer le monde');
  end;
end;

procedure TMainForm.TimerTick(Sender: TObject);
begin
  Invalidate;
end;

constructor TMainForm.Create(AOwner: TComponent);
var I: Integer;
begin
  inherited CreateNew(AOwner);
  Caption := 'Microcosme';
  Width := 1200; Height := 760;
  Position := poScreenCenter;
  Color := Col(11, 14, 11);
  DoubleBuffered := True;
  KeyPreview := True;
  Randomize;

  FSimCS := TCriticalSection.Create;
  Plants := TList<TPlant>.Create;
  Creatures := TList<TCreature>.Create;
  NB := TList<TCreature>.Create;
  SetLength(Buckets, CGWC * CGHC);
  for I := 0 to Length(Buckets) - 1 do Buckets[I] := TList<TCreature>.Create;

  FTerrain := TBitmap.Create;
  FTerrain.PixelFormat := pf32bit;
  FThumb := TBitmap.Create;
  FWorld := TBitmap.Create;
  FTintN := TBitmap.Create;
  FTintW := TBitmap.Create;

  OnPaint := FormPaint;
  OnMouseDown := FormMouseDown;
  OnMouseMove := FormMouseMove;
  OnMouseUp := FormMouseUp;
  OnResize := FormResize;
  OnKeyDown := FormKeyDown;

  FTimer := TTimer.Create(Self);
  FTimer.Interval := 15;
  FTimer.OnTimer := TimerTick;
  FTimer.Enabled := True;

  NewWorld;
  FormResize(Self);

  FSimThread := TSimThread.Create(False);
end;

destructor TMainForm.Destroy;
begin
  if FSimThread <> nil then begin
    FSimThread.Terminate;
    FSimThread.WaitFor;
    FreeAndNil(FSimThread);
  end;
  ClearWorldObjects;
  FreeAndNil(FSimCS);
  Plants.Free; Creatures.Free; NB.Free;
  FTerrain.Free; FThumb.Free; FWorld.Free; FTintN.Free; FTintW.Free;
  inherited;
end;

end.

unit MicroGraph3D;

{ Microcosme — fenêtre 3D interactive :
  · mode TRAITS : chaque habitant est une étoile dans l'espace
    vitesse × vue × taille (évolution et spécialisations visibles)
  · mode POPULATIONS : les 4 courbes de l'histoire en 3D
  · mode YEUX DE SAPIENS : raycaster 100 % code — le monde vu depuis
    la tête d'un sapiens (S1), habité de billboards (S2), avec cités
    (S3), incarnation (S5), personnages articulés (S6), textures
    procédurales (S7) et modelé (S8).
  Clic droit : changer de mode · clic gauche (mode yeux) : sapiens suivant
  · ESPACE : incarner · flèches/ZQSD : marcher }

interface

uses
  System.SysUtils, System.Classes, System.Math, System.Types,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.ExtCtrls,
  MicroTypes, MicroBrain;

procedure OpenGraph3DWindow;

implementation

{$OVERFLOWCHECKS OFF}
{$RANGECHECKS OFF}

uses
  MicroVilles,   // ★S3 : SurRoute (la route au sol)
  MicroLang ,    // ★S6b : L() pour reconnaître les états de métier
  MicroEre;      // ★v17 : PeopleHas (la nuit devient jour, les cheminées)


const
  VK_LEFT   = $25;   // ★S5 : constantes clavier en local — Winapi.Windows
  VK_RIGHT  = $27;   //   écraserait TBitmap (Vcl.Graphics) par le record GDI
  VK_UP     = $26;
  VK_DOWN   = $28;
  VK_SPACE  = $20;
  VK_ESCAPE = $1B;

type
  TRGBTri = packed record               // un pixel 24 bits (ordre mémoire BGR)
    B, G, R: Byte;
  end;
  TRGBRow = array[0..0] of TRGBTri;
  PRGBRow = ^TRGBRow;

  TG3DForm = class(TForm)
  public
    procedure GPaint(Sender: TObject);
    procedure GTimer(Sender: TObject);
    procedure GClose(Sender: TObject; var Action: TCloseAction);
    procedure GDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure GMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure GUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure GWheel(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    procedure GKey(Sender: TObject; var Key: Word; Shift: TShiftState);
  end;

var
  G3: TG3DForm = nil;
  GYaw: Single = 0.7;
  GPitch: Single = 0.32;
  GZoom: Single = 1.0;
  GMode: Integer = 0;
  GDrag: Boolean = False;
  GLX, GLY: Integer;
  GTim: TTimer = nil;                   // le batteur (pour changer sa cadence)
  GBuf: TBitmap = nil;                  // l'écran du raycaster
  GFollowCId: Integer = 0;              // le sapiens suivi : un CId, JAMAIS un pointeur
  GTime: Single = 0;                    // ★S6 l'horloge d'animation
  GWalkT: Single = 0;                   // ★S6 la cadence des mains incarnées
  GLastSX: Single = 0;                  // ★S6 la position précédente du suivi
  GLastSY: Single = 0;                  //   (une initialisation par ligne : E2196 sinon)
  GLastInit: Boolean = False;

{ ★S7 — le bruit procédural : déterministe (même entrée = même grain),
  renvoie toujours dans [0,1). Hash entier, ~20× plus vite que le Sin.
  Les débordements de multiplication sont voulus et sûrs (conv. 1). }
function Bruit(A, B: Single): Single;
var H: Integer;
begin
  H := (Trunc(A) * 73856093) xor (Trunc(B) * 19349663);
  Result := (H and $FFFFFF) / $1000000;
end;

{ le sapiens suivi : par CId, jamais de pointeur stocké (leçon KillPlantEx) }
function SapienSuivant(Rot: Boolean): TCreature;
var I, J, N, Cur: Integer;
begin
  Result := nil;
  if (Creatures = nil) or (Creatures.Count = 0) then begin
    GFollowCId := 0; Exit;
  end;
  N := Creatures.Count;
  Cur := -1;
  if GFollowCId <> 0 then
    for I := 0 to N - 1 do
      if (Creatures[I] <> nil) and Creatures[I].Alive and
         (Creatures[I].Kind = 2) and (Creatures[I].CId = GFollowCId) then begin
        Cur := I; Break;
      end;
  if (not Rot) and (Cur >= 0) then begin
    Result := Creatures[Cur];            // le suivi tient bon
    Exit;
  end;
  for J := 1 to N do begin               // le suivant, en bouclant
    I := (Cur + J) mod N;
    if (Creatures[I] <> nil) and Creatures[I].Alive and
       (Creatures[I].Kind = 2) then begin
      Result := Creatures[I];
      GFollowCId := Result.CId;
      Exit;
    end;
  end;
  GFollowCId := 0;                       // plus aucun sapiens vivant
end;

procedure OpenGraph3DWindow;
var T: TTimer;
begin
  if G3 <> nil then begin G3.BringToFront; Exit end;
  G3 := TG3DForm.CreateNew(nil);
  with G3 do begin
    Caption := 'Microcosme — 3D · traits';
    Width := 980; Height := 640;
    Position := poScreenCenter;
    Color := Col(11, 14, 11);
    DoubleBuffered := True;
    OnPaint := GPaint;
    OnClose := GClose;
    OnMouseDown := GDown;
    OnMouseMove := GMove;
    OnMouseUp := GUp;
    OnMouseWheel := GWheel;
    KeyPreview := True;                       // ★S5 : la fenêtre 3D attrape les touches
    OnKeyDown := GKey;
  end;
  T := TTimer.Create(G3);
  T.Interval := 120;
  T.OnTimer := G3.GTimer;
  GTim := T;
  G3.Show;
end;

procedure TG3DForm.GTimer(Sender: TObject);
begin
  if not GDrag then GYaw := GYaw + 0.005;
  Invalidate;
end;

procedure TG3DForm.GClose(Sender: TObject; var Action: TCloseAction);
begin
  Action := caFree;
  GTim := nil;
  if GBuf <> nil then begin GBuf.Free; GBuf := nil end;
  GFollowCId := 0;
  G3 := nil;
end;

{ ★S5 — l'incarnation : les touches quand la fenêtre 3D a le focus.
  Flèches partout ; ZQSD marche aussi (les codes touche suivent la lettre
  produite, donc AZERTY inclus). Le pas est gardé par Walkable : pas d'eau. }
procedure TG3DForm.GKey(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  S5: TCreature;

  procedure Pas(Dist: Single);
  var TX5, TY5: Single;
  begin
    TX5 := S5.X + Cos(S5.Angle) * Dist;
    TY5 := S5.Y + Sin(S5.Angle) * Dist;
    if Walkable(TX5, TY5) then begin
      S5.X := ClampF(TX5, 0.01, GW - 0.01);
      S5.Y := ClampF(TY5, 0.01, GH - 0.01);
      GWalkT := GWalkT + 0.5;            // ★S6 : la cadence des mains
    end;
  end;

begin
  if GMode <> 2 then Exit;
  if (Creatures = nil) or (GFollowCId = 0) then Exit;
  S5 := SapienSuivant(False);
  if S5 = nil then Exit;
  FSimCS.Enter;                          // conv. 12 : on ÉCRIT dans la sim
  try
    case Key of
      VK_LEFT,  Ord('Q'): S5.Angle := S5.Angle - 0.12;
      VK_RIGHT, Ord('D'): S5.Angle := S5.Angle + 0.12;
      VK_UP,    Ord('Z'): Pas(0.6);
      VK_DOWN,  Ord('S'): Pas(-0.35);
      VK_SPACE:  S5.Piloted := not S5.Piloted;   // incarner / rendre le corps
      VK_ESCAPE: S5.Piloted := False;
    end;
  finally
    FSimCS.Leave;
  end;
end;

procedure TG3DForm.GDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbRight then begin
    GMode := (GMode + 1) mod 3;
    case GMode of
      0: Caption := 'Microcosme — 3D · traits';
      1: Caption := 'Microcosme — 3D · populations';
    else Caption := 'Microcosme — 3D · yeux de sapiens';
    end;
    if GTim <> nil then begin
      if GMode = 2 then GTim.Interval := 40
      else GTim.Interval := 120;
    end;
    Invalidate;
    Exit;
  end;
  if (GMode = 2) and (Button = mbLeft) then begin
    SapienSuivant(True);                 // clic gauche : le sapiens suivant
    Invalidate;
    Exit;
  end;
  GDrag := True; GLX := X; GLY := Y;
end;

procedure TG3DForm.GMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  if GDrag then begin
    GYaw := GYaw + (X - GLX) * 0.008;
    GPitch := ClampF(GPitch + (Y - GLY) * 0.006, -1.35, 1.35);
    GLX := X; GLY := Y;
  end;
end;

procedure TG3DForm.GUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  GDrag := False;
end;

procedure TG3DForm.GWheel(Sender: TObject; Shift: TShiftState;
  WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
begin
  GZoom := ClampF(GZoom * Exp(-WheelDelta * 0.0012), 0.35, 3);
  Handled := True;
  Invalidate;
end;

{ ★S1→S8b — les yeux d'un sapiens. Ordre imposé par Delphi (conv. 15) :
  const → type → var → procédures nichées → begin. }
procedure Yeux;
const
  RES_DIV = 1;                 // ★S6c+ : 1 = pleine résolution · 2 = moitié si ça rame
  FOV   = 1.55;
  EYE_H = 1.85;                // ★S8 : l'œil un peu haut, les bêtes moins massives
  FOG   = 26.0;
type
  TVpro = record
    VX, VY, RA: Single;
  end;
var
  S: TCreature;
  x, y, tx, ty, CI, Hor, I, NVc, K3: Integer;
  DirA, DirX, DirY, PlX, PlY, PlaneLen, Foc, T,
  WX0, WY0, StX, StY, wx, wy, Day, DM, FogM, FogA,
  zr, zg, zb, hr, hg, hb, f, sr, sg, sb, RX, RY, VB: Single;
  RES_W, RES_H: Integer;       // ★S6c+ : la résolution suit la fenêtre
  Row: PRGBRow;
  HandA: Single;  HandW: Integer;
  Vpro: array of TVpro;

  // ★S2/S3/S6/S7/S8 — les billboards : arbres, huttes, bêtes, remparts, tour.
  procedure Billboards;
  const
    NSEG = 24;                             // segments de rempart (1 porte sur 6)
  type
    TBb = record
      Z, SX, Pied, Haut: Single;
      Clr: TColor;
      Ty: Integer;                      // 0 arbre · 1 hutte · 2 créature · 3 mur · 4 tour
      Kd: Integer;                      // le Kind de la créature (-1 sinon)
      Cid: Integer;                     // le CId (phase d'animation), -1 sinon
      Feu: Boolean;                     // le feu de la hutte
      LW: Single;                       // la largeur du mur/tour, en cases
      Met: Integer;                     // ★S6b l'outil : 1 bâton · 2 lance · 3 canne
      Sem: Integer;                     // ★S7 la semelle de texture (stable par objet)
    end;
  var
    N, K, I, J, PX, PY, X0, X1, Y0, Y1, Demi, YT, YT2, Demi2, K4: Integer;
    P: TPlant;
    Hh: THut;
    O: TCreature;
    V3: TCity;
    RX, RY, ZD, SD, HMonde, Wd, FM, DM2,
    R1, G1, B1, Rf, Gf, Bf, Dy, CYm, CR2, RMur, LSeg, AA,
    ph, Amp, LGT, skinR, skinG, skinB,
    VF, NB, RGr, DXF, DYF, D2F, OmS, VB: Single;
    BY3, BX4, QH: Integer;
    Bbs: array of TBb;
    Tmp: TBb;

    procedure PutPix(PX, PY: Integer; Rf, Gf, Bf: Single);
    var Rw: PRGBRow;
    begin
      if (PX < 0) or (PX >= RES_W) or (PY < 0) or (PY >= RES_H) then Exit;
      Rw := GBuf.ScanLine[PY];
      Rw[PX].R := Trunc(Rf);
      Rw[PX].G := Trunc(Gf);
      Rw[PX].B := Trunc(Bf);
    end;

    procedure Rect5(X0, Y0, X1, Y1: Integer; r5, g5, b5: Single);
    var PX5, PY5: Integer;
    begin
      for PY5 := Max(0, Y0) to Min(RES_H - 1, Y1) do
        for PX5 := Max(0, X0) to Min(RES_W - 1, X1) do
          PutPix(PX5, PY5, r5, g5, b5);
    end;

    procedure Disque(CX5, CY5, RA5, r5, g5, b5: Single);
    var PX5, PY5: Integer; RR5: Single;
    begin
      if RA5 < 0.5 then Exit;
      RR5 := Sqr(RA5);
      for PY5 := Trunc(CY5 - RA5) to Trunc(CY5 + RA5) do
        for PX5 := Trunc(CX5 - RA5) to Trunc(CX5 + RA5) do
          if Sqr(PX5 - CX5) + Sqr(PY5 - CY5) <= RR5 then
            PutPix(PX5, PY5, r5, g5, b5);
    end;

    // ★S8 le rectangle modelé : dégradé relatif (0 bord gauche → 1 bord
    // droit) + bruit de matière + ombre latérale selon le soleil.
    procedure RectO(PX1, PY1, PX2, PY2, Prof: Integer;
                    r5, g5, b5: Single; Sem5: Integer);
    var PX5, PY5: Integer; VB, KD: Single;
    begin
      for PY5 := Max(0, PY1) to Min(RES_H - 1, PY2) do
        for PX5 := Max(0, PX1) to Min(RES_W - 1, PX2) do begin
          VB := 0.92 + 0.16 * Bruit(PX5 * 2.1 + Sem5 * 0.13, PY5 * 1.7);
          KD := (PX5 - PX1) / Max(1, PX2 - PX1);
          VB := VB * (0.86 + 0.28 * KD);
          if PX5 > Bbs[K].SX then VB := VB * OmS;
          PutPix(PX5, PY5, r5 * VB, g5 * VB, b5 * VB);
        end;
    end;

    // ★S8 la sphère éclairée : le point de lumière fuit le soleil.
    procedure Tete(CX5, CY5, RA5, r5, g5, b5: Single; Sem5: Integer);
    var PX5, PY5: Integer; DXF, DYF, D2F, VB, LD: Single;
    begin
      if RA5 < 1 then Exit;
      for PY5 := Trunc(CY5 - RA5) to Trunc(CY5 + RA5) do
        for PX5 := Trunc(CX5 - RA5) to Trunc(CX5 + RA5) do begin
          DXF := PX5 - CX5;  DYF := PY5 - CY5;
          D2F := DXF * DXF + DYF * DYF;
          if D2F > Sqr(RA5) then Continue;
          VB := 0.93 + 0.12 * Bruit(PX5 * 3.1 + Sem5 * 0.09, PY5 * 3.1);
          LD := 1 + (DXF / RA5) * (0.26 * (1 - OmS)) - (DYF / RA5) * 0.12;
          PutPix(PX5, PY5, r5 * VB * LD, g5 * VB * LD, b5 * VB * LD);
        end;
    end;

    // ★S6 l'ombre portée : on assombrit les pixels déjà posés (le sol),
    // donc elle épouse le terrain et vit avec le jour et la brume.
    procedure Ombre(CX5, CY5, RW5, RH5, FM5: Single);
    var PX5, PY5: Integer; K5: Single; Rw: PRGBRow;
    begin
      if (RW5 < 0.5) or (RH5 < 0.5) then Exit;
      K5 := 1 - 0.38 * Day * (1 - FM5);
      for PY5 := Trunc(CY5 - RH5) to Trunc(CY5 + RH5) do begin
        if (PY5 < 0) or (PY5 >= RES_H) then Continue;
        Rw := GBuf.ScanLine[PY5];
        for PX5 := Trunc(CX5 - RW5) to Trunc(CX5 + RW5) do
          if (PX5 >= 0) and (PX5 < RES_W) and
             (Sqr((PX5 - CX5) / RW5) + Sqr((PY5 - CY5) / RH5) <= 1) then begin
            Rw[PX5].R := Trunc(Rw[PX5].R * K5);
            Rw[PX5].G := Trunc(Rw[PX5].G * K5);
            Rw[PX5].B := Trunc(Rw[PX5].B * K5);
          end;
      end;
    end;

    // ★S6b : ce sapiens porte-t-il la charge d'une ville ? (par CId,
    // jamais de pointeur stocké — leçon KillPlantEx)
    function EstChef3(AId: Integer): Boolean;
    var Q: Integer;
    begin
      Result := False;
      if AId = 0 then Exit;
      for Q := 0 to Cities.Count - 1 do
        if Cities[Q].ChefCId = AId then Exit(True);
    end;

  begin
    OmS := 0.80 + 0.20 * Min(1.0, FDayLight * 2.2);  // ★S7 le soleil tourne
    N := 0;
    SetLength(Bbs, Plants.Count + Huts.Count + Creatures.Count +
                    Cities.Count * (NSEG + 1));
    for J := 0 to High(Bbs) do Bbs[J].Met := 0;   // pas d'outil par défaut

    for I := 0 to Plants.Count - 1 do begin          // les arbres
      P := Plants[I];
      if (P = nil) or P.Morte then Continue;
      RX := P.X - S.X;  RY := P.Y - S.Y;
      if (Abs(RX) > FOG) or (Abs(RY) > FOG) then Continue;
      ZD := RX * DirX + RY * DirY;
      if (ZD <> ZD) or (ZD < 0.4) or (ZD > FOG) then Continue;
      SD := RY * DirX - RX * DirY;
      HMonde := 1.8 + Frac(P.X * 0.37 + P.Y * 0.61) * 1.4;
      Bbs[N].Z := ZD;
      Bbs[N].SX := RES_W * 0.5 + (SD / ZD) * Foc;
      Bbs[N].Pied := Hor + (EYE_H * Foc / ZD);
      Bbs[N].Haut := HMonde * Foc / ZD;
      Bbs[N].Clr := Col(70, 104, 50);
      Bbs[N].Ty := 0;  Bbs[N].Kd := -1;  Bbs[N].Cid := -1;  Bbs[N].Feu := False;
      Bbs[N].LW := 0;
      Bbs[N].Sem := Trunc(P.X * 7.0 + P.Y * 13.0);
      Inc(N);
    end;

    for I := 0 to Huts.Count - 1 do begin            // les huttes
      Hh := Huts[I];
      if Hh = nil then Continue;
      RX := Hh.X - S.X;  RY := Hh.Y - S.Y;
      if (Abs(RX) > FOG) or (Abs(RY) > FOG) then Continue;
      ZD := RX * DirX + RY * DirY;
      if (ZD <> ZD) or (ZD < 0.4) or (ZD > FOG) then Continue;
      SD := RY * DirX - RX * DirY;
      Bbs[N].Z := ZD;
      Bbs[N].SX := RES_W * 0.5 + (SD / ZD) * Foc;
      Bbs[N].Pied := Hor + (EYE_H * Foc / ZD);
      Bbs[N].Haut := 1.5 * Foc / ZD;
      Bbs[N].Clr := Col(146, 98, 72);
      Bbs[N].Ty := 1;  Bbs[N].Kd := -1;  Bbs[N].Cid := -1;  Bbs[N].Feu := Hh.Fire;
      Bbs[N].LW := 0;
      Bbs[N].Sem := Trunc(Hh.X * 9.0 + Hh.Y * 5.0);
      Inc(N);
    end;

    for I := 0 to Creatures.Count - 1 do begin       // les bêtes (pas moi)
      O := Creatures[I];
      if (O = nil) or (not O.Alive) or (O = S) then Continue;
      RX := O.X - S.X;  RY := O.Y - S.Y;
      if (Abs(RX) > FOG) or (Abs(RY) > FOG) then Continue;
      ZD := RX * DirX + RY * DirY;
      if (ZD <> ZD) or (ZD < 0.4) or (ZD > FOG) then Continue;
      SD := RY * DirX - RX * DirY;
      Bbs[N].Z := ZD;
      Bbs[N].SX := RES_W * 0.5 + (SD / ZD) * Foc;
      Bbs[N].Pied := Hor + (EYE_H * Foc / ZD);
      Bbs[N].Haut := (0.55 + O.Sz * 0.5) * Foc / ZD;  // ★S8 les bêtes moins massives
      case O.Kind of
        0: Bbs[N].Clr := Col(228, 220, 190);
        1: Bbs[N].Clr := Col(201, 106, 69);
        3: Bbs[N].Clr := Col(206, 168, 104);
        4: Bbs[N].Clr := Col(118, 82, 54);
        5: Bbs[N].Clr := Col(238, 232, 222);
      else Bbs[N].Clr := O.HueCol;
      end;
      Bbs[N].Ty := 2;  Bbs[N].Kd := O.Kind;  Bbs[N].Cid := O.CId;
      Bbs[N].Feu := False;
      Bbs[N].LW := 0;
      Bbs[N].Sem := O.CId;
      Bbs[N].Met := 0;
      if tPast in O.Tech then Bbs[N].Met := 1;       // le berger porte le bâton
      if O.State = L(72) then Bbs[N].Met := 2;       // le chasseur, sa lance
      if O.State = L(143) then Bbs[N].Met := 3;      // le pêcheur, sa canne
      Inc(N);
    end;

    for I := 0 to Cities.Count - 1 do begin          // remparts + monument
      V3 := Cities[I];
      if V3.Niveau < 3 then Continue;
      RX := V3.X - S.X;  RY := V3.Y - S.Y;
      if (Abs(RX) > FOG + 12) or (Abs(RY) > FOG + 12) then Continue;
      if V3.Niveau >= 4 then begin                   // la tour
        ZD := RX * DirX + RY * DirY;
        if (ZD = ZD) and (ZD > 0.5) and (ZD <= FOG) then begin
          SD := RY * DirX - RX * DirY;
          Bbs[N].Z := ZD;
          Bbs[N].SX := RES_W * 0.5 + (SD / ZD) * Foc;
          Bbs[N].Pied := Hor + (EYE_H * Foc / ZD);
          Bbs[N].Haut := 4.2 * Foc / ZD;
          Bbs[N].LW := 1.6;
          Bbs[N].Clr := Col(140, 136, 128);
          Bbs[N].Ty := 4;  Bbs[N].Kd := -1;  Bbs[N].Cid := -1;  Bbs[N].Feu := False;
          Bbs[N].Sem := Trunc(V3.X * 3.0 + V3.Y * 7.0) + 11;
          Inc(N);
        end;
      end;
      RMur := 4.6 + V3.Niveau * 0.6;
      LSeg := 6.2831855 / NSEG;
      for K4 := 0 to NSEG - 1 do begin
        if (K4 mod 6) = 0 then Continue;             // les 4 portes
        AA := K4 * LSeg;
        RX := V3.X + Cos(AA) * RMur - S.X;
        RY := V3.Y + Sin(AA) * RMur - S.Y;
        if (Abs(RX) > FOG) or (Abs(RY) > FOG) then Continue;
        ZD := RX * DirX + RY * DirY;
        if (ZD <> ZD) or (ZD < 0.4) or (ZD > FOG) then Continue;
        SD := RY * DirX - RX * DirY;
        Bbs[N].Z := ZD;
        Bbs[N].SX := RES_W * 0.5 + (SD / ZD) * Foc;
        Bbs[N].Pied := Hor + (EYE_H * Foc / ZD);
        Bbs[N].Haut := 2.2 * Foc / ZD;
        Bbs[N].LW := LSeg * RMur;
        Bbs[N].Clr := Col(138, 132, 122);
        Bbs[N].Ty := 3;  Bbs[N].Kd := -1;  Bbs[N].Cid := -1;  Bbs[N].Feu := False;
        Bbs[N].Sem := Trunc((V3.X + Cos(AA) * RMur) * 7.0 +
                            (V3.Y + Sin(AA) * RMur) * 13.0);
        Inc(N);
      end;
    end;

    for I := 1 to N - 1 do begin                     // tri peintre : LOIN d'abord
      Tmp := Bbs[I]; J := I - 1;
      while (J >= 0) and (Bbs[J].Z < Tmp.Z) do begin
        Bbs[J + 1] := Bbs[J]; Dec(J);
      end;
      Bbs[J + 1] := Tmp;
    end;

    for K := 0 to N - 1 do begin
      FM := Bbs[K].Z / FOG;  FM := FM * FM;
      DM2 := Day * (1 - FM);
      R1 := Bbs[K].Clr and $FF;
      G1 := (Bbs[K].Clr shr 8) and $FF;
      B1 := (Bbs[K].Clr shr 16) and $FF;
      Rf := R1 * DM2 + hr * FM;
      Gf := G1 * DM2 + hg * FM;
      Bf := B1 * DM2 + hb * FM;
      skinR := 224 * DM2 + hr * FM;
      skinG := 182 * DM2 + hg * FM;
      skinB := 150 * DM2 + hb * FM;
      case Bbs[K].Ty of

        0: begin                                     // ★S7 l'arbre en houppier
             Ombre(Bbs[K].SX, Bbs[K].Pied, Bbs[K].Haut * 0.40, Bbs[K].Haut * 0.11, FM);
             X0 := Trunc(Bbs[K].SX - Bbs[K].Haut * 0.08);
             X1 := Trunc(Bbs[K].SX + Bbs[K].Haut * 0.08);
             Y0 := Trunc(Bbs[K].Pied - Bbs[K].Haut * 0.5);
             Y1 := Trunc(Bbs[K].Pied);
             Rect5(X0, Y0, Trunc(Bbs[K].SX), Y1,
                   92 * DM2 + hr * FM, 66 * DM2 + hg * FM, 46 * DM2 + hb * FM);
             Rect5(Trunc(Bbs[K].SX), Y0, X1, Y1,
                   92 * DM2 * OmS + hr * FM, 66 * DM2 * OmS + hg * FM,
                   46 * DM2 * OmS + hb * FM);
             CYm := Bbs[K].Pied - Bbs[K].Haut * 0.60;
             RGr := Bbs[K].Haut * 0.34;
             for PY := Max(0, Trunc(CYm - RGr - 2)) to Min(RES_H - 1, Trunc(CYm + RGr)) do
               for PX := Max(0, Trunc(Bbs[K].SX - RGr - 2)) to
                        Min(RES_W - 1, Trunc(Bbs[K].SX + RGr + 2)) do begin
                 DXF := PX - Bbs[K].SX;  DYF := PY - CYm;
                 D2F := DXF * DXF + DYF * DYF;
                 if D2F > Sqr(RGr) then Continue;
                 NB := Bruit(PX * 0.55 + Bbs[K].Sem * 0.07, PY * 0.55);
                 if D2F > Sqr(RGr * (0.78 + 0.25 * NB)) then Continue;
                 VB := 0.68 + 0.6 * NB;
                 if DYF > RGr * 0.25 then VB := VB * 0.84;
                 PutPix(PX, PY, Rf * VB, Gf * VB, Bf * VB);
               end;
             CYm := Bbs[K].Pied - Bbs[K].Haut * 0.88;
             RGr := Bbs[K].Haut * 0.24;
             for PY := Max(0, Trunc(CYm - RGr - 2)) to Min(RES_H - 1, Trunc(CYm + RGr)) do
               for PX := Max(0, Trunc(Bbs[K].SX - RGr - 2)) to
                        Min(RES_W - 1, Trunc(Bbs[K].SX + RGr + 2)) do begin
                 DXF := PX - Bbs[K].SX;  DYF := PY - CYm;
                 D2F := DXF * DXF + DYF * DYF;
                 if D2F > Sqr(RGr) then Continue;
                 NB := Bruit(PX * 0.55 + Bbs[K].Sem * 0.07, PY * 0.55);
                 if D2F > Sqr(RGr * (0.78 + 0.25 * NB)) then Continue;
                 VB := 0.74 + 0.55 * NB;
                 if DYF > RGr * 0.25 then VB := VB * 0.86;
                 PutPix(PX, PY, Rf * VB, Min(255, Gf * VB + 18 * DM2), Bf * VB);
               end;
           end;

        1: begin                                     // ★S7 la hutte en chaume
             Ombre(Bbs[K].SX, Bbs[K].Pied, Bbs[K].Haut * 0.55, Bbs[K].Haut * 0.13, FM);
             X0 := Trunc(Bbs[K].SX - Bbs[K].Haut * 0.45);
             X1 := Trunc(Bbs[K].SX + Bbs[K].Haut * 0.45);
             Y0 := Trunc(Bbs[K].Pied - Bbs[K].Haut * 0.55);
             Y1 := Trunc(Bbs[K].Pied);
             for PY := Max(0, Y0) to Min(RES_H - 1, Y1) do       // les planches
               for PX := Max(0, X0) to Min(RES_W - 1, X1) do begin
                 VB := 0.86 + 0.28 * Bruit(PX * 2.9 + Bbs[K].Sem * 0.05, PY * 0.35);
                 if ((PX - X0) mod 3) = 0 then VB := VB * 0.78;
                 if PX > Bbs[K].SX then VB := VB * OmS;
                 PutPix(PX, PY, Rf * VB, Gf * VB, Bf * VB);
               end;
             Y0 := Trunc(Bbs[K].Pied - Bbs[K].Haut);             // le chaume
             Y1 := Trunc(Bbs[K].Pied - Bbs[K].Haut * 0.55) - 1;
             for PY := Max(0, Y0) to Min(RES_H - 1, Y1) do begin
               Dy := (Bbs[K].Pied - Bbs[K].Haut * 0.55 - PY) /
                     Max(0.001, Bbs[K].Haut * 0.45);
               Demi := Trunc(Bbs[K].Haut * 0.55 * (1 - Dy));
               for PX := Max(0, Trunc(Bbs[K].SX) - Demi) to
                        Min(RES_W - 1, Trunc(Bbs[K].SX) + Demi) do begin
                 VB := 0.82 + 0.30 * Bruit(PX * 2.3 + Bbs[K].Sem * 0.09, PY * 1.1);
                 if ((PY + Bbs[K].Sem) and 1) = 0 then VB := VB * 0.87;
                 PutPix(PX, PY, 140 * VB * DM2 + hr * FM, 82 * VB * DM2 + hg * FM,
                        62 * VB * DM2 + hb * FM);
               end;
             end;
             if Bbs[K].Feu then begin               // ★S7 le feu qui vit
               Y0 := Trunc(Bbs[K].Pied - Bbs[K].Haut) - 2;
               VF := 0.72 + 0.28 * Sin(GTime * 9.0 + Bbs[K].Sem * 0.31);
               Rect5(Trunc(Bbs[K].SX) - 1, Y0, Trunc(Bbs[K].SX) + 1, Y0 + 2,
                     255 * VF, 170 * VF, 60 * VF);
               if Frac(GTime * 3.0 + Bbs[K].Sem * 0.13) < 0.6 then begin
                 PX := Trunc(Bbs[K].SX) + Trunc(Bruit(GTime * 2.5, Bbs[K].Sem) * 7) - 3;
                 PY := Y0 - 1 - Trunc(Bruit(Bbs[K].Sem, GTime * 3.5) * 4);
                 PutPix(PX, PY, 255, 205, 100);     // l'étincelle
               end;
             end;
                          if PeopleHas(teUsines) and (Hh.Ville <> nil) then begin
               // ★ère 7 : les cheminées fumantes des villes-usines
               YT := Trunc(Bbs[K].Pied - Bbs[K].Haut);
               for J := 1 to 6 do begin
                 PX := Trunc(Bbs[K].SX) + Trunc(Bruit(Bbs[K].Sem + J * 13,
                          Trunc(GTime * 1.5)) * 5) - 2;
                 PY := YT - 1 - J * 2;
                 VB := (0.55 + 0.3 * Bruit(J * 3.1 + Bbs[K].Sem, GTime * 0.7)) *
                       (1 - J / 9) * (1 - FM);
                 PutPix(PX, PY, 118 * VB + hr * FM, 116 * VB + hg * FM,
                        114 * VB + hb * FM);
               end;
             end;
           end;

        2: begin                                     // ★S6/S8 la créature articulée
             case Bbs[K].Kd of
               0, 5: Wd := Bbs[K].Haut * 0.50;
               1, 3, 4: Wd := Bbs[K].Haut * 0.30;
             else Wd := Bbs[K].Haut * 0.22;
             end;
             Amp := 1.0;
             if Bbs[K].Cid = S.CId then
               if GLastInit and
                  (Abs(S.X - GLastSX) + Abs(S.Y - GLastSY) < 0.02) then
                 Amp := 0.0;
             ph := Sin(GTime * 9.0 + Bbs[K].Cid * 1.7) * Amp;

             if Bbs[K].Kd = 2 then begin
               // —— le sapiens : jambes, tunique, bras, tête, chevelure ——
               Ombre(Bbs[K].SX, Bbs[K].Pied, Bbs[K].Haut * 0.15,
                     Bbs[K].Haut * 0.05, FM);
               Demi := Max(1, Trunc(Bbs[K].Haut * 0.05));
               RectO(Trunc(Bbs[K].SX - Bbs[K].Haut * 0.07) - Demi,
                     Trunc(Bbs[K].Pied - Bbs[K].Haut * 0.34 - Bbs[K].Haut * 0.05 * ph),
                     Trunc(Bbs[K].SX - Bbs[K].Haut * 0.07) + Demi, Trunc(Bbs[K].Pied),
                     Trunc(Bbs[K].Haut * 0.05) * 2 + 1,
                     skinR * 0.82, skinG * 0.82, skinB * 0.82, Bbs[K].Sem);
               RectO(Trunc(Bbs[K].SX + Bbs[K].Haut * 0.07) - Demi,
                     Trunc(Bbs[K].Pied - Bbs[K].Haut * 0.34 + Bbs[K].Haut * 0.05 * ph),
                     Trunc(Bbs[K].SX + Bbs[K].Haut * 0.07) + Demi, Trunc(Bbs[K].Pied),
                     Trunc(Bbs[K].Haut * 0.05) * 2 + 1,
                     skinR * 0.82, skinG * 0.82, skinB * 0.82, Bbs[K].Sem);
               RectO(Trunc(Bbs[K].SX - Bbs[K].Haut * 0.13),
                     Trunc(Bbs[K].Pied - Bbs[K].Haut * 0.66),
                     Trunc(Bbs[K].SX + Bbs[K].Haut * 0.13),
                     Trunc(Bbs[K].Pied - Bbs[K].Haut * 0.30),
                     Trunc(Bbs[K].Haut * 0.26) * 2 + 1, Rf, Gf, Bf, Bbs[K].Sem);
               Rect5(Trunc(Bbs[K].SX - Bbs[K].Haut * 0.13),   // l'ourlet de la tunique
                     Trunc(Bbs[K].Pied - Bbs[K].Haut * 0.33),
                     Trunc(Bbs[K].SX + Bbs[K].Haut * 0.13),
                     Trunc(Bbs[K].Pied - Bbs[K].Haut * 0.30),
                     Rf * 0.72, Gf * 0.72, Bf * 0.72);
               Demi := Max(1, Trunc(Bbs[K].Haut * 0.045));    // ★S8b des bras qui se voient
               RectO(Trunc(Bbs[K].SX - Bbs[K].Haut * 0.20) - Demi,
                     Trunc(Bbs[K].Pied - Bbs[K].Haut * 0.62 - Bbs[K].Haut * 0.04 * ph),
                     Trunc(Bbs[K].SX - Bbs[K].Haut * 0.20) + Demi,
                     Trunc(Bbs[K].Pied - Bbs[K].Haut * 0.36),
                     Demi * 2 + 1, skinR * 0.94, skinG * 0.94, skinB * 0.94, Bbs[K].Sem);
               RectO(Trunc(Bbs[K].SX + Bbs[K].Haut * 0.20) - Demi,
                     Trunc(Bbs[K].Pied - Bbs[K].Haut * 0.62 + Bbs[K].Haut * 0.04 * ph),
                     Trunc(Bbs[K].SX + Bbs[K].Haut * 0.20) + Demi,
                     Trunc(Bbs[K].Pied - Bbs[K].Haut * 0.36),
                     Demi * 2 + 1, skinR * 0.94, skinG * 0.94, skinB * 0.94, Bbs[K].Sem);
               Tete(Bbs[K].SX, Bbs[K].Pied - Bbs[K].Haut * 0.80,
                    Bbs[K].Haut * 0.12, skinR, skinG, skinB, Bbs[K].Sem);
               CYm := Bbs[K].Pied - Bbs[K].Haut * 0.80;
               CR2 := Sqr(Bbs[K].Haut * 0.12);
               for PY := Trunc(CYm - Bbs[K].Haut * 0.12) to
                        Trunc(CYm - Bbs[K].Haut * 0.04) do
                 for PX := Trunc(Bbs[K].SX - Bbs[K].Haut * 0.12) to
                          Trunc(Bbs[K].SX + Bbs[K].Haut * 0.12) do
                   if Sqr(PX - Bbs[K].SX) + Sqr(PY - CYm) <= CR2 then
                     PutPix(PX, PY, 72 * DM2 + hr * FM, 52 * DM2 + hg * FM,
                            38 * DM2 + hb * FM);
               // —— ★S6b les outils + l'étendard du chef ——
               Demi := Max(1, Trunc(Bbs[K].Haut * 0.035));
               if Bbs[K].Met = 1 then begin         // le bâton du berger
                 X0 := Trunc(Bbs[K].SX - Bbs[K].Haut * 0.26);
                 Rect5(X0 - Demi, Trunc(Bbs[K].Pied - Bbs[K].Haut * 1.06),
                       X0 + Demi, Trunc(Bbs[K].Pied),
                       120 * DM2 + hr * FM, 88 * DM2 + hg * FM, 54 * DM2 + hb * FM);
                 Rect5(X0, Trunc(Bbs[K].Pied - Bbs[K].Haut * 1.06),
                       X0 + Trunc(Bbs[K].Haut * 0.09),
                       Trunc(Bbs[K].Pied - Bbs[K].Haut * 1.06) + Demi * 2,
                       120 * DM2 + hr * FM, 88 * DM2 + hg * FM, 54 * DM2 + hb * FM);
               end;
               if Bbs[K].Met = 2 then begin         // la lance du chasseur
                 X0 := Trunc(Bbs[K].SX + Bbs[K].Haut * 0.24);
                 Rect5(X0 - Demi, Trunc(Bbs[K].Pied - Bbs[K].Haut * 1.28),
                       X0 + Demi, Trunc(Bbs[K].Pied - Bbs[K].Haut * 0.08),
                       130 * DM2 + hr * FM, 100 * DM2 + hg * FM, 66 * DM2 + hb * FM);
                 Rect5(X0 - Demi, Trunc(Bbs[K].Pied - Bbs[K].Haut * 1.28),
                       X0 + Demi * 2, Trunc(Bbs[K].Pied - Bbs[K].Haut * 1.20),
                       200 * DM2 + hr * FM, 200 * DM2 + hg * FM, 206 * DM2 + hb * FM);
               end;
               if Bbs[K].Met = 3 then begin         // la canne du pêcheur
                 X0 := Trunc(Bbs[K].SX + Bbs[K].Haut * 0.26);
                 Rect5(X0 - Demi, Trunc(Bbs[K].Pied - Bbs[K].Haut * 1.10),
                       X0 + Demi, Trunc(Bbs[K].Pied - Bbs[K].Haut * 0.14),
                       130 * DM2 + hr * FM, 100 * DM2 + hg * FM, 66 * DM2 + hb * FM);
                 Disque(X0 + Demi * 2, Bbs[K].Pied - Bbs[K].Haut * 0.42,
                        Bbs[K].Haut * 0.055,
                        205 * DM2 + hr * FM, 66 * DM2 + hg * FM, 52 * DM2 + hb * FM);
               end;
               if EstChef3(Bbs[K].Cid) then begin   // le chef : diadème + étendard
                 Disque(Bbs[K].SX, Bbs[K].Pied - Bbs[K].Haut * 0.90,
                        Bbs[K].Haut * 0.115,
                        208 * DM2 + hr * FM, 167 * DM2 + hg * FM, 92 * DM2 + hb * FM);
                 X0 := Trunc(Bbs[K].SX + Bbs[K].Haut * 0.27);
                 Rect5(X0 - Demi, Trunc(Bbs[K].Pied - Bbs[K].Haut * 1.50),
                       X0 + Demi, Trunc(Bbs[K].Pied - Bbs[K].Haut * 0.14),
                       110 * DM2 + hr * FM, 78 * DM2 + hg * FM, 48 * DM2 + hb * FM);
                 Y0 := Trunc(Bbs[K].Pied - Bbs[K].Haut * 1.50);
                 X1 := X0 + Trunc(Bbs[K].Haut *
                        (0.10 + 0.05 * Sin(GTime * 3.0 + Bbs[K].Cid * 0.7))) + Demi;
                 Rect5(X0, Y0, X1, Y0 + Trunc(Bbs[K].Haut * 0.10),
                       208 * DM2 + hr * FM, 167 * DM2 + hg * FM, 92 * DM2 + hb * FM);
               end;
             end else begin
               // —— les quadrupèdes : quatre pattes, corps, tête ——
               Ombre(Bbs[K].SX, Bbs[K].Pied, Wd * 1.3, Wd * 0.42, FM);
               Demi := Max(1, Trunc(Bbs[K].Haut * 0.05));
               if Bbs[K].Kd = 4 then
                 Demi := Max(1, Trunc(Bbs[K].Haut * 0.08));  // l'ours, massif
               LGT := Trunc(Bbs[K].Haut * 0.26);
               RectO(Trunc(Bbs[K].SX - Wd * 0.62) - Demi,
                     Trunc(Bbs[K].Pied - LGT - Bbs[K].Haut * 0.03 * ph),
                     Trunc(Bbs[K].SX - Wd * 0.62) + Demi, Trunc(Bbs[K].Pied),
                     Demi * 2 + 1, Rf * 0.72, Gf * 0.72, Bf * 0.72, Bbs[K].Sem);
               RectO(Trunc(Bbs[K].SX + Wd * 0.62) - Demi,
                     Trunc(Bbs[K].Pied - LGT + Bbs[K].Haut * 0.03 * ph),
                     Trunc(Bbs[K].SX + Wd * 0.62) + Demi, Trunc(Bbs[K].Pied),
                     Demi * 2 + 1, Rf * 0.72, Gf * 0.72, Bf * 0.72, Bbs[K].Sem);
               RectO(Trunc(Bbs[K].SX - Wd * 0.25) - Demi,
                     Trunc(Bbs[K].Pied - LGT + Bbs[K].Haut * 0.03 * ph),
                     Trunc(Bbs[K].SX - Wd * 0.25) + Demi, Trunc(Bbs[K].Pied),
                     Demi * 2 + 1, Rf * 0.72, Gf * 0.72, Bf * 0.72, Bbs[K].Sem);
               RectO(Trunc(Bbs[K].SX + Wd * 0.25) - Demi,
                     Trunc(Bbs[K].Pied - LGT - Bbs[K].Haut * 0.03 * ph),
                     Trunc(Bbs[K].SX + Wd * 0.25) + Demi, Trunc(Bbs[K].Pied),
                     Demi * 2 + 1, Rf * 0.72, Gf * 0.72, Bf * 0.72, Bbs[K].Sem);
               if Bbs[K].Kd = 5 then begin          // le mouton : un nuage de laine
                 Disque(Bbs[K].SX - Wd * 0.5, Bbs[K].Pied - Bbs[K].Haut * 0.42,
                        Wd * 0.55, Rf, Gf, Bf);
                 Disque(Bbs[K].SX, Bbs[K].Pied - Bbs[K].Haut * 0.45,
                        Wd * 0.60, Rf, Gf, Bf);
                 Disque(Bbs[K].SX + Wd * 0.5, Bbs[K].Pied - Bbs[K].Haut * 0.42,
                        Wd * 0.55, Rf, Gf, Bf);
                 Disque(Bbs[K].SX + Wd * 0.8, Bbs[K].Pied - Bbs[K].Haut * 0.32,
                        Bbs[K].Haut * 0.09,
                        96 * DM2 + hr * FM, 90 * DM2 + hg * FM, 84 * DM2 + hb * FM);
               end else begin
                 RectO(Trunc(Bbs[K].SX - Wd), Trunc(Bbs[K].Pied - Bbs[K].Haut * 0.62),
                       Trunc(Bbs[K].SX + Wd), Trunc(Bbs[K].Pied - Bbs[K].Haut * 0.24),
                       Trunc(Wd * 2) + 1, Rf, Gf, Bf, Bbs[K].Sem);
                 Tete(Bbs[K].SX + Wd * 0.85, Bbs[K].Pied - Bbs[K].Haut * 0.48,
                      Bbs[K].Haut * 0.13, Rf * 0.92, Gf * 0.92, Bf * 0.92, Bbs[K].Sem);
                 if Bbs[K].Kd = 0 then begin        // la vache : les cornes
                   Disque(Bbs[K].SX + Wd * 0.85 - Bbs[K].Haut * 0.11,
                          Bbs[K].Pied - Bbs[K].Haut * 0.58, Bbs[K].Haut * 0.045,
                          228 * DM2 + hr * FM, 222 * DM2 + hg * FM, 208 * DM2 + hb * FM);
                   Disque(Bbs[K].SX + Wd * 0.85 + Bbs[K].Haut * 0.11,
                          Bbs[K].Pied - Bbs[K].Haut * 0.58, Bbs[K].Haut * 0.045,
                          228 * DM2 + hr * FM, 222 * DM2 + hg * FM, 208 * DM2 + hb * FM);
                 end;
                 if (Bbs[K].Kd = 1) or (Bbs[K].Kd = 3) then begin
                   Rect5(Trunc(Bbs[K].SX + Wd * 0.80),
                         Trunc(Bbs[K].Pied - Bbs[K].Haut * 0.66),
                         Trunc(Bbs[K].SX + Wd * 0.80) + Demi,
                         Trunc(Bbs[K].Pied - Bbs[K].Haut * 0.56),
                         Rf * 0.8, Gf * 0.8, Bf * 0.8);
                   Rect5(Trunc(Bbs[K].SX + Wd * 0.95),
                         Trunc(Bbs[K].Pied - Bbs[K].Haut * 0.66),
                         Trunc(Bbs[K].SX + Wd * 0.95) + Demi,
                         Trunc(Bbs[K].Pied - Bbs[K].Haut * 0.56),
                         Rf * 0.8, Gf * 0.8, Bf * 0.8);
                   Rect5(Trunc(Bbs[K].SX - Wd * 1.35),
                         Trunc(Bbs[K].Pied - Bbs[K].Haut * 0.52),
                         Trunc(Bbs[K].SX - Wd * 1.0),
                         Trunc(Bbs[K].Pied - Bbs[K].Haut * 0.52) + Demi,
                         Rf * 0.85, Gf * 0.85, Bf * 0.85);
                 end;
                 if Bbs[K].Kd = 4 then begin        // l'ours : les oreilles rondes
                   Disque(Bbs[K].SX + Wd * 0.75, Bbs[K].Pied - Bbs[K].Haut * 0.66,
                          Bbs[K].Haut * 0.05, Rf * 0.8, Gf * 0.8, Bf * 0.8);
                   Disque(Bbs[K].SX + Wd * 0.98, Bbs[K].Pied - Bbs[K].Haut * 0.66,
                          Bbs[K].Haut * 0.05, Rf * 0.8, Gf * 0.8, Bf * 0.8);
                 end;
               end;
             end;
           end;

        3: begin                                     // ★S7 la pierre appareillée
             Demi := Trunc(Bbs[K].LW * Foc / Bbs[K].Z * 0.5) + 1;
             if Demi < 1 then Demi := 1;
             X0 := Trunc(Bbs[K].SX) - Demi;
             X1 := Trunc(Bbs[K].SX) + Demi;
             Y0 := Trunc(Bbs[K].Pied - Bbs[K].Haut);
             Y1 := Trunc(Bbs[K].Pied);
             for PY := Max(0, Y0) to Min(RES_H - 1, Y1) do begin
               BY3 := (PY - Y0) div 3;
               QH := (BY3 and 1) * 2;
               for PX := Max(0, X0) to Min(RES_W - 1, X1) do begin
                 BX4 := (PX - X0 + QH) div 4;
                 VB := 0.78 + 0.44 * Bruit(BX4 * 7.3 + Bbs[K].Sem * 0.11, BY3 * 4.9);
                 if ((PY - Y0) mod 3) = 2 then VB := VB * 0.58;
                 if ((PX - X0 + QH) mod 4) = 0 then VB := VB * 0.72;
                 if PX > Bbs[K].SX then VB := VB * OmS;
                 PutPix(PX, PY, Rf * VB, Gf * VB, Bf * VB);
               end;
             end;
             if Y0 >= 0 then                         // le chaperon, pierre claire
               for PX := Max(0, X0) to Min(RES_W - 1, X1) do begin
                 VB := 0.85 + 0.3 * Bruit(PX * 2.9 + Bbs[K].Sem * 0.07, 7.7);
                 if PX > Bbs[K].SX then VB := VB * OmS;
                 PutPix(PX, Y0, Rf * 0.7 * VB + (176 * DM2 + hr * FM) * 0.3,
                        Gf * 0.7 * VB + (170 * DM2 + hg * FM) * 0.3,
                        Bf * 0.7 * VB + (158 * DM2 + hb * FM) * 0.3);
               end;
           end;

        4: begin                                     // ★S7 la tour en grosses pierres
             Demi := Trunc(Bbs[K].LW * Foc / Bbs[K].Z * 0.5) + 1;
             if Demi < 1 then Demi := 1;
             X0 := Trunc(Bbs[K].SX) - Demi;
             X1 := Trunc(Bbs[K].SX) + Demi;
             Y0 := Trunc(Bbs[K].Pied - Bbs[K].Haut);
             Y1 := Trunc(Bbs[K].Pied);
             for PY := Max(0, Y0) to Min(RES_H - 1, Y1) do begin
               BY3 := (PY - Y0) div 5;
               QH := (BY3 and 1) * 3;
               for PX := Max(0, X0) to Min(RES_W - 1, X1) do begin
                 BX4 := (PX - X0 + QH) div 6;
                 VB := 0.80 + 0.40 * Bruit(BX4 * 5.7 + Bbs[K].Sem * 0.11, BY3 * 3.9);
                 if ((PY - Y0) mod 5) = 4 then VB := VB * 0.60;
                 if ((PX - X0 + QH) mod 6) = 0 then VB := VB * 0.74;
                 if PX > Bbs[K].SX then VB := VB * OmS;
                 PutPix(PX, PY, Rf * VB, Gf * VB, Bf * VB);
               end;
             end;
             YT := Trunc(Bbs[K].Pied - Bbs[K].Haut);       // la flèche, en pointe
             YT2 := Trunc(Bbs[K].Pied - Bbs[K].Haut * 0.7);
             for PY := Max(0, YT) to Min(RES_H - 1, YT2) do begin
               Dy := (PY - YT) / Max(0.001, YT2 - YT + 1);
               Demi2 := Trunc(Demi * Dy);
               for PX := Max(0, Trunc(Bbs[K].SX) - Demi2) to
                        Min(RES_W - 1, Trunc(Bbs[K].SX) + Demi2) do
                 PutPix(PX, PY, 84 * DM2 + hr * FM, 88 * DM2 + hg * FM,
                        96 * DM2 + hb * FM);
             end;
           end;
      end;  // case Ty
    end;    // for K
  end;

begin
  RES_W := Max(240, Min(G3.ClientWidth, 1920) div RES_DIV);   // ★S6c+ 1:1
  RES_H := Max(150, Min(G3.ClientHeight, 1200) div RES_DIV);
  if (GBuf = nil) or (GBuf.Width <> RES_W) or (GBuf.Height <> RES_H) then begin
    if GBuf = nil then GBuf := TBitmap.Create;
    GBuf.PixelFormat := pf24bit;
    GBuf.Width := RES_W;
    GBuf.Height := RES_H;
  end;
  S := SapienSuivant(False);
  if S = nil then begin
    G3.Canvas.Brush.Style := bsClear;
    G3.Canvas.Font.Name := 'Segoe UI';
    G3.Canvas.Font.Size := 10;
    G3.Canvas.Font.Color := Col(139, 138, 116);
    G3.Canvas.TextOut(24, 24, 'aucun sapiens vivant — clic droit pour changer de mode');
    Exit;
  end;
  if IsNan(S.X) or IsNan(S.Y) or IsNan(S.Angle) then begin
    SapienSuivant(True);
    Exit;
  end;

  NVc := 0;
  SetLength(Vpro, Cities.Count);
  for I := 0 to Cities.Count - 1 do begin
    RX := Cities[I].X - S.X;  RY := Cities[I].Y - S.Y;
    if (Abs(RX) > FOG + 8) or (Abs(RY) > FOG + 8) then Continue;
    Vpro[NVc].VX := Cities[I].X;
    Vpro[NVc].VY := Cities[I].Y;
    Vpro[NVc].RA := Sqr(2.6 + Cities[I].Niveau * 0.8);
    Inc(NVc);
  end;
  SetLength(Vpro, NVc);

  GTime := GTime + 0.04;
  if GTime > 6283 then GTime := 0;
  Day := 0.28 + 0.72 * FDayLight;
  if PeopleHas(teElectricite) then        // ★ère 8 : la nuit devient jour
  Day := Max(Day, 0.62);
  PlaneLen := Tan(FOV / 2);
  Foc := (RES_W * 0.5) / PlaneLen;
  DirA := S.Angle;
  DirX := Cos(DirA);
  DirY := Sin(DirA);
  PlX := -DirY * PlaneLen;
  PlY := DirX * PlaneLen;
  Hor := RES_H div 2;

  zr := 8  + (70  - 8)  * Day;
  zg := 10 + (100 - 10) * Day;
  zb := 16 + (140 - 16) * Day;
  hr := 22 + (176 - 22) * Day;
  hg := 24 + (174 - 24) * Day;
  hb := 26 + (148 - 26) * Day;
  for y := 0 to Hor - 1 do begin
    Row := GBuf.ScanLine[y];
    f := y / Max(1, Hor - 1);
    sr := zr + (hr - zr) * f;
    sg := zg + (hg - zg) * f;
    sb := zb + (hb - zb) * f;
    for x := 0 to RES_W - 1 do begin
      Row[x].B := Trunc(sb);
      Row[x].G := Trunc(sg);
      Row[x].R := Trunc(sr);
    end;
  end;

  for y := Hor to RES_H - 1 do begin
    Row := GBuf.ScanLine[y];
    T := EYE_H * Foc / (y - Hor + 0.5);
    FogM := T / FOG;
    if FogM > 1 then FogM := 1;
    FogM := FogM * FogM;
    FogA := 1 - FogM;
    DM := Day * FogA;
    WX0 := S.X + T * (DirX - PlX);
    WY0 := S.Y + T * (DirY - PlY);
    StX := 2 * T * PlX / RES_W;
    StY := 2 * T * PlY / RES_W;
    wx := WX0;  wy := WY0;
    for x := 0 to RES_W - 1 do begin
      tx := Trunc(wx);  ty := Trunc(wy);
      if (tx >= 0) and (tx < GW) and (ty >= 0) and (ty < GH) then begin
        CI := ty * GW + tx;
        if TerrType[CI] < T_SAND then begin
          VB := 0.88 + Bruit(wx * 28 + GTime * 2.0, wy * 28 - GTime * 1.4) * 0.24;
          sr := 40 * VB; sg := 66 * VB; sb := 86 * VB;
          if VB > 1.06 then begin sg := sg + 30; sb := sb + 40 end;
        end else if TerrType[CI] = T_SAND then begin
          VB := 0.93 + Bruit(wx * 34, wy * 34) * 0.13;
          sr := 176 * VB; sg := 160 * VB; sb := 118 * VB;
        end else begin
          VB := 0.92 + Bruit(wx * 41, wy * 41) * 0.16;
          case (tx * 7 + ty * 13) and 3 of
            0: begin sr := 100; sg := 128; sb := 70 end;
            1: begin sr := 94;  sg := 122; sb := 66 end;
            2: begin sr := 104; sg := 134; sb := 74 end;
          else begin sr := 90;  sg := 118; sb := 64 end;
          end;
          sr := sr * VB; sg := sg * VB; sb := sb * VB;
        end;
      end else begin
        sr := 90; sg := 118; sb := 64;
      end;
      if SurRoute(wx, wy) then begin
        VB := 0.95 + Bruit(wx * 71, wy * 71) * 0.10;
        sr := 152 * VB; sg := 126 * VB; sb := 86 * VB;
      end;
      for K3 := 0 to High(Vpro) do
        if Sqr(wx - Vpro[K3].VX) + Sqr(wy - Vpro[K3].VY) < Vpro[K3].RA then begin
          VB := 0.95 + Bruit(wx * 50, wy * 50) * 0.10;
          sr := 168 * VB; sg := 158 * VB; sb := 138 * VB;
          Break;
        end;
      Row[x].B := Trunc(sb * DM + hb * FogM);
      Row[x].G := Trunc(sg * DM + hg * FogM);
      Row[x].R := Trunc(sr * DM + hr * FogM);
      wx := wx + StX;
      wy := wy + StY;
    end;
  end;

  Billboards;
  GLastSX := S.X;  GLastSY := S.Y;  GLastInit := True;

  G3.Canvas.StretchDraw(Rect(0, 0, G3.ClientWidth, G3.ClientHeight), GBuf);
  G3.Canvas.Brush.Style := bsClear;
  G3.Canvas.Font.Name := 'Segoe UI';
  G3.Canvas.Font.Size := 9;
  G3.Canvas.Font.Color := Col(224, 218, 194);
  G3.Canvas.TextOut(12, 10, S.Name);
  G3.Canvas.Font.Color := Col(160, 156, 134);
  G3.Canvas.TextOut(12, 26, 'clic : autre sapiens');
  if S.Piloted then begin
    HandA := Sin(GWalkT) * G3.ClientHeight * 0.006;
    HandW := Max(3, Trunc(G3.ClientWidth * 0.010));
    G3.Canvas.Brush.Style := bsSolid;
    G3.Canvas.Pen.Style := psClear;
    G3.Canvas.Brush.Color := Col(Trunc(30 + 118 * Day), Trunc(24 + 96 * Day),
                                 Trunc(18 + 80 * Day));
    G3.Canvas.Ellipse(Trunc(G3.ClientWidth * 0.235) - HandW,
                      G3.ClientHeight - Trunc(G3.ClientHeight * 0.028) - Trunc(HandA),
                      Trunc(G3.ClientWidth * 0.235) + HandW, G3.ClientHeight + 2);
    G3.Canvas.Ellipse(Trunc(G3.ClientWidth * 0.765) - HandW,
                      G3.ClientHeight - Trunc(G3.ClientHeight * 0.028) + Trunc(HandA),
                      Trunc(G3.ClientWidth * 0.765) + HandW, G3.ClientHeight + 2);
    G3.Canvas.TextOut(12, 42, '★ incarné — flèches/ZQSD : marcher · ESPACE : rendre le corps');
  end else
    G3.Canvas.TextOut(12, 42, 'ESPACE : incarner ce sapiens');
end;

procedure TG3DForm.GPaint(Sender: TObject);
var
  C: TCanvas;
  W, H: Integer;

  function Proj(X, Y, Z: Single; out SX, SY: Integer;
    out SC, DZ: Single): Boolean;
  var Cy, Syn, Cp, Sp, X1, Y1, Z1, D, F: Single;
  begin
    Cy := Cos(GYaw); Syn := Sin(GYaw);
    Cp := Cos(GPitch); Sp := Sin(GPitch);
    X1 := X * Cy - Z * Syn;
    Z1 := X * Syn + Z * Cy;
    Y1 := Y * Cp - Z1 * Sp;
    Z1 := Y * Sp + Z1 * Cp;
    DZ := Z1;
    D := 3.6 - Z1;
    if D < 0.5 then begin Result := False; Exit end;
    F := Min(W, H) * 0.40 * GZoom / D;
    SX := W div 2 + Round(X1 * F);
    SY := H div 2 - Round(Y1 * F);
    SC := F;
    Result := True;
  end;

  procedure Box;
  const
    CV: array[0..7, 0..2] of Single =
      ((-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),
       (-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1));
    ED: array[0..11, 0..1] of Integer =
      ((0,1),(1,2),(2,3),(3,0),(4,5),(5,6),(6,7),(7,4),
       (0,4),(1,5),(2,6),(3,7));
  var
    I, A1, A2, B1, B2: Integer; SC, DZ: Single;
  begin
    C.Pen.Style := psSolid; C.Pen.Width := 1;
    C.Pen.Color := Col(46, 52, 40);
    for I := 0 to 11 do
      if Proj(CV[ED[I][0]][0], CV[ED[I][0]][1], CV[ED[I][0]][2], A1, A2, SC, DZ) and
         Proj(CV[ED[I][1]][0], CV[ED[I][1]][1], CV[ED[I][1]][2], B1, B2, SC, DZ) then begin
        C.MoveTo(A1, A2); C.LineTo(B1, B2);
      end;
  end;

  procedure Lab(X, Y, Z: Single; const TX: string; Clr: TColor);
  var SX, SY: Integer; SC, DZ: Single;
  begin
    if not Proj(X, Y, Z, SX, SY, SC, DZ) then Exit;
    C.Font.Name := 'Segoe UI'; C.Font.Size := 9; C.Font.Style := [];
    C.Brush.Style := bsClear;
    C.Font.Color := Clr;
    C.TextOut(SX - C.TextWidth(TX) div 2, SY - 6, TX);
  end;

  procedure Traits;
  type
    TStar = record SX, SY, Rad: Integer; Clr: TColor; Z: Single; end;
  var
    I, J, N: Integer;
    CR: TCreature;
    X, Y, Z, SC, DZ: Single;
    SX, SY: Integer;
    Stars: array of TStar;
    Tmp: TStar;
  begin
    N := 0;
    SetLength(Stars, Creatures.Count);
    for I := 0 to Creatures.Count - 1 do begin
      CR := Creatures[I];
      if (CR = nil) or (not CR.Alive) then Continue;
      X := ClampF((CR.Sp - 4.3) / 2.1, -1, 1);
      Y := ClampF((CR.Se - 8.0) / 4.0, -1, 1);
      Z := ClampF((CR.Sz - 1.05) / 0.45, -1, 1);
      if not Proj(X, Y, Z, SX, SY, SC, DZ) then Continue;
      Stars[N].SX := SX; Stars[N].SY := SY;
      Stars[N].Rad := Max(2, Round(SC * 0.05));
      Stars[N].Z := DZ;
      case CR.Kind of
        0: Stars[N].Clr := Col(228, 220, 190);
        1: Stars[N].Clr := Col(201, 106, 69);
        3: Stars[N].Clr := Col(206, 168, 104);
      else Stars[N].Clr := CR.HueCol;
      end;
      Inc(N);
    end;
    SetLength(Stars, N);
    for I := 1 to N - 1 do begin          // tri : plus lointaines d'abord
      Tmp := Stars[I]; J := I - 1;
      while (J >= 0) and (Stars[J].Z > Tmp.Z) do begin
        Stars[J + 1] := Stars[J]; Dec(J);
      end;
      Stars[J + 1] := Tmp;
    end;
    for I := 0 to N - 1 do begin
      C.Brush.Style := bsSolid; C.Pen.Style := psClear;
      C.Brush.Color := Stars[I].Clr;
      C.Ellipse(Stars[I].SX - Stars[I].Rad, Stars[I].SY - Stars[I].Rad,
                Stars[I].SX + Stars[I].Rad, Stars[I].SY + Stars[I].Rad);
    end;
    if N = 0 then begin
      C.Font.Name := 'Segoe UI'; C.Font.Size := 10; C.Font.Style := [];
      C.Brush.Style := bsClear; C.Font.Color := Col(139, 138, 116);
      C.TextOut(24, 24, 'aucun habitant — lance la simulation');
    end;
    Lab(1.28, -1, -1, 'vitesse →', Col(139, 138, 116));
    Lab(-1, 1.28, -1, '↑ vue', Col(139, 138, 116));
    Lab(-1, -1, 1.28, '↑ taille', Col(139, 138, 116));
    C.Pen.Style := psClear;
    C.Brush.Style := bsSolid; C.Brush.Color := Col(228, 220, 190);
    C.Rectangle(16, 16, 22, 22);
    C.Brush.Style := bsClear; C.Font.Size := 8;
    C.Font.Color := Col(139, 138, 116); C.TextOut(28, 16, 'herbivores');
    C.Brush.Style := bsSolid; C.Brush.Color := Col(201, 106, 69);
    C.Rectangle(16, 30, 22, 36);
    C.Brush.Style := bsClear; C.TextOut(28, 30, 'prédateurs');
    C.Brush.Style := bsSolid; C.Brush.Color := Col(208, 167, 92);
    C.Rectangle(16, 44, 22, 50);
    C.Brush.Style := bsClear; C.TextOut(28, 44, 'sapiens (couleur = lignée)');
  end;

  procedure Pops;
  const
    SERCLR: array[0..3] of array[0..2] of Integer =
      ((157,187,107),(228,220,190),(201,106,69),(208,167,92));
    SERNM: array[0..3] of string = ('flore','herbivores','prédateurs','sapiens');
  var
    K, I: Integer;
    V, MaxV, X, Y, Z, SC, DZ: Single;
    SX, SY, LXp, LYp: Integer;
    Clr: TColor;
  begin
    if Length(FHist) < 2 then begin
      C.Font.Name := 'Segoe UI'; C.Font.Size := 10; C.Font.Style := [];
      C.Brush.Style := bsClear; C.Font.Color := Col(139, 138, 116);
      C.TextOut(24, 24, 'lance la simulation : les courbes s''accumulent ici en 3D');
      Exit;
    end;
    for K := 0 to 3 do begin
      MaxV := 1;
      for I := 0 to High(FHist) do begin
        case K of
          0: V := FHist[I].P;
          1: V := FHist[I].H;
          2: V := FHist[I].C;
        else V := FHist[I].S;
        end;
        if V > MaxV then MaxV := V;
      end;
      Clr := Col(SERCLR[K][0], SERCLR[K][1], SERCLR[K][2]);
      C.Pen.Style := psSolid; C.Pen.Width := 2; C.Pen.Color := Clr;
      Z := (K - 1.5) * 0.45;
      LXp := 0; LYp := 0;
      for I := 0 to High(FHist) do begin
        case K of
          0: V := FHist[I].P;
          1: V := FHist[I].H;
          2: V := FHist[I].C;
        else V := FHist[I].S;
        end;
        X := I / High(FHist) * 2 - 1;
        Y := ClampF(V / MaxV, 0, 1) * 2 - 1;
        if Proj(X, Y, Z, SX, SY, SC, DZ) then begin
          if I = 0 then C.MoveTo(SX, SY) else C.LineTo(SX, SY);
          LXp := SX; LYp := SY;
        end;
      end;
      case K of
        0: V := FHist[High(FHist)].P;
        1: V := FHist[High(FHist)].H;
        2: V := FHist[High(FHist)].C;
      else V := FHist[High(FHist)].S;
      end;
      C.Font.Name := 'Segoe UI'; C.Font.Size := 9; C.Font.Style := [];
      C.Brush.Style := bsClear; C.Font.Color := Clr;
      C.TextOut(LXp + 6, LYp - 6, Format('%s %d', [SERNM[K], Round(V)]));
    end;
  end;

begin
  C := Canvas;
  W := ClientWidth; H := ClientHeight;
  FSimCS.Enter;
  try
    C.Brush.Style := bsSolid; C.Pen.Style := psClear;
    C.Brush.Color := Col(11, 14, 11);
    C.FillRect(Rect(0, 0, W, H));
    Box;
    case GMode of
      0: Traits;
      1: Pops;
    else
      try
        Yeux;                              // ★ mode 2 : les yeux d'un sapiens
      except
        on E: Exception do begin
          Toast('CRASH yeux : ' + E.Message);   // le filet nommé : le VRAI message
          GMode := 0;                           // plus de cascade
          Caption := 'Microcosme — 3D · traits';
          GFollowCId := 0;
        end;
      end;
    end;
    C.Font.Name := 'Segoe UI'; C.Font.Size := 8; C.Font.Style := [];
    C.Brush.Style := bsClear;
    C.Font.Color := Col(100, 105, 88);
    if GMode = 2 then
      C.TextOut(16, H - 24, 'clic : sapiens suivant · clic droit : changer de mode')
    else
      C.TextOut(16, H - 24, 'glisser : tourner · molette : zoom · clic droit : changer de mode');
  finally
    FSimCS.Leave;
  end;
end;

end.

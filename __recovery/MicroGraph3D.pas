unit MicroGraph3D;

{ Microcosme — fenêtre 3D interactive :
  · mode TRAITS : chaque habitant est une étoile dans l'espace
  vitesse × vue × taille (évolution et spécialisations visibles)
  · mode POPULATIONS : les 4 courbes de l'histoire en 3D
  Glisser : tourner · molette : zoom · clic droit : changer de mode }

interface

uses
  System.SysUtils, System.Classes, System.Math, System.Types,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.ExtCtrls,
  MicroTypes, MicroBrain;

procedure OpenGraph3DWindow;

implementation

uses
  MicroVilles; // ★S3 : SurRoute (la route au sol)


{$OVERFLOWCHECKS OFF}
{$RANGECHECKS OFF}

type
  TG3DForm = class(TForm)
  public
    procedure GPaint(Sender: TObject);
    procedure GTimer(Sender: TObject);
    procedure GClose(Sender: TObject; var Action: TCloseAction);
    procedure GDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer);
    procedure GMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure GUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer);
    procedure GWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer;
      MousePos: TPoint; var Handled: Boolean);
    procedure GKey(Sender: TObject; var Key: Word; Shift: TShiftState); // ★S5
  end;

type
  TRGBTri = packed record // un pixel 24 bits (ordre mémoire BGR)
    B, G, R: Byte;
  end;

  TRGBRow = array [0 .. 0] of TRGBTri;
  PRGBRow = ^TRGBRow;

var
  G3: TG3DForm = nil;
  GYaw: Single = 0.7;
  GPitch: Single = 0.32;
  GZoom: Single = 1.0;
  GMode: Integer = 0;
  GDrag: Boolean = False;
  GLX, GLY: Integer;
  GTim: TTimer = nil; // le batteur (pour changer sa cadence)
  GBuf: TBitmap = nil; // l'écran basse résolution du raycaster
  GFollowCId: Integer = 0; // le sapiens suivi : un CId, JAMAIS un pointeur
  GTime: Single = 0;                    // ★S6 : l'horloge d'animation
  GWalkT: Single = 0;                   // ★S6 : la cadence des mains incarnées
  GLastSX : Single = 0;
  GLastSY: Single = 0;         // ★S6 : la position précédente du suivi
  GLastInit: Boolean = False;

procedure OpenGraph3DWindow;
var
  T: TTimer;
begin
  if G3 <> nil then
  begin
    G3.BringToFront;
    Exit
  end;
  G3 := TG3DForm.CreateNew(nil);
  with G3 do
  begin
    Caption := 'Microcosme — 3D · traits';
    Width := 780;
    Height := 580;
    Position := poScreenCenter;
    Color := Col(11, 14, 11);
    DoubleBuffered := True;
    OnPaint := GPaint;
    OnClose := GClose;
    OnMouseDown := GDown;
    OnMouseMove := GMove;
    OnMouseUp := GUp;
    OnMouseWheel := GWheel;
    KeyPreview := True; // ★S5 : la fenêtre 3D attrape les touches
    OnKeyDown := GKey;
  end;
  T := TTimer.Create(G3);
  T.Interval := 120;
  T.OnTimer := G3.GTimer;
  G3.Show;
end;

procedure TG3DForm.GTimer(Sender: TObject);
begin
  if not GDrag then
    GYaw := GYaw + 0.005;
  Invalidate;
end;

const
  VK_LEFT   = $25;   // ★S5 : constantes clavier en local — Winapi.Windows
  VK_RIGHT  = $27;   //   écraserait TBitmap (Vcl.Graphics) par le record GDI
  VK_UP     = $26;
  VK_DOWN   = $28;
  VK_SPACE  = $20;
  VK_ESCAPE = $1B;
function SapienSuivant(Rot: Boolean): TCreature; forward;   // ★GKey l'appelle, définie plus bas

{ ★S5 — l'incarnation : les touches quand la fenêtre 3D a le focus.
  Flèches partout ; ZQSD marche aussi (les codes touche suivent la lettre
  produite, donc AZERTY inclus). Le pas est gardé par Walkable : pas d'eau. }
procedure TG3DForm.GKey(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  S5: TCreature;

  procedure Pas(Dist: Single);
  var
    TX5, TY5: Single;
  begin
    TX5 := S5.X + Cos(S5.Angle) * Dist;
    TY5 := S5.Y + Sin(S5.Angle) * Dist;
    if Walkable(TX5, TY5) then
    begin
      S5.X := ClampF(TX5, 0.01, GW - 0.01);
      S5.Y := ClampF(TY5, 0.01, GH - 0.01);
      GWalkT := GWalkT + 0.5;            // ★S6 : la cadence des mains
    end;
  end;

begin
  if GMode <> 2 then
    Exit;
  if (Creatures = nil) or (GFollowCId = 0) then
    Exit;
  S5 := SapienSuivant(False);
  if S5 = nil then
    Exit;
  FSimCS.Enter; // conv. 12 : on ÉCRIT dans la sim
  try
    case Key of
      VK_LEFT, Ord('Q'):
        S5.Angle := S5.Angle - 0.12;
      VK_RIGHT, Ord('D'):
        S5.Angle := S5.Angle + 0.12;
      VK_UP, Ord('Z'):
        Pas(0.6);
      VK_DOWN, Ord('S'):
        Pas(-0.35);
      VK_SPACE:
        S5.Piloted := not S5.Piloted; // incarner / rendre le corps
      VK_ESCAPE:
        S5.Piloted := False;
    end;
  finally
    FSimCS.Leave;
  end;
end;

procedure TG3DForm.GClose(Sender: TObject; var Action: TCloseAction);
begin
  Action := caFree;
  GTim := nil;
  if GBuf <> nil then
  begin
    GBuf.Free;
    GBuf := nil
  end;
  GFollowCId := 0;
  G3 := nil;
end;

{ ─── mode 2 : les yeux d'un sapiens (raycaster 100% code) ────────────────── }

function SapienSuivant(Rot: Boolean): TCreature;
var
  I, J, N, Cur: Integer;
begin
  Result := nil;
  if (Creatures = nil) or (Creatures.Count = 0) then
  begin
    GFollowCId := 0;
    Exit;
  end;
  N := Creatures.Count;
  Cur := -1;
  if GFollowCId <> 0 then
    for I := 0 to N - 1 do
      if (Creatures[I] <> nil) and Creatures[I].Alive and
        (Creatures[I].Kind = 2) and (Creatures[I].CId = GFollowCId) then
      begin
        Cur := I;
        Break;
      end;
  if (not Rot) and (Cur >= 0) then
  begin
    Result := Creatures[Cur]; // le suivi tient bon
    Exit;
  end;
  for J := 1 to N do
  begin // le suivant, en bouclant
    I := (Cur + J) mod N;
    if (Creatures[I] <> nil) and Creatures[I].Alive and (Creatures[I].Kind = 2)
    then
    begin
      Result := Creatures[I];
      GFollowCId := Result.CId;
      Exit;
    end;
  end;
  GFollowCId := 0; // plus aucun sapiens vivant
end;

procedure Yeux;
const
  RES_W = 240;
  RES_H = 150;
  FOV = 1.05;
  EYE_H = 1.55;
  FOG = 26.0;
type
  TVpro = record
    VX, VY, RA: Single;
  end;
var
  S: TCreature;
  X, Y, tx, ty, CI, Hor, I, NVc, K3: Integer;
  DirA, DirX, DirY, PlX, PlY, PlaneLen, Foc, T, WX0, WY0, StX, StY, wx, wy, Day,
    DM, FogM, FogA, zr, zg, zb, hr, hg, hb, f, sr, sg, sb, RX, RY: Single;
  Row: PRGBRow;
  Vpro: array of TVpro;
  HandA: Single;  HandW: Integer;             // ★S6 les mains incarnées

  // ★S2/S3 — les billboards : ce qui se dresse au-dessus du sol. Nichée
  // APRÈS le var (règle Delphi : elle ne voit que ce qui est déclaré avant).
    procedure Billboards;
  const
    NSEG = 24;                             // segments de rempart (1 porte sur 6)
  type
    TBb = record
      Z, SX, Pied, Haut: Single;
      Clr: TColor;
      Ty: Integer;                      // 0 arbre · 1 hutte · 2 créature · 3 mur · 4 tour
      Kd: Integer;                      // le Kind de la créature (-1 sinon)
      Cid: Integer;                     // ★S6 le CId (phase d'animation), -1 sinon
      Feu: Boolean;                     // le feu de la hutte
      LW: Single;                       // la largeur du mur/tour, en cases
    end;
  var
    N, K, I, J, PX, PY, X0, X1, Y0, Y1, Demi, YT, YT2, Demi2, K4: Integer;
    P: TPlant;
    Hh: THut;
    O: TCreature;
    V3: TCity;
    RX, RY, ZD, SD, HMonde, Wd, FM, DM2,
    R1, G1, B1, Rf, Gf, Bf, Dy, CYm, CR2, RMur, LSeg, AA,
    ph, Amp, LGT, skinR, skinG, skinB: Single;
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

    // ★S6 l'ombre portée : on ASSOMBrit les pixels déjà posés (le sol),
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

  begin
    N := 0;
    SetLength(Bbs, Plants.Count + Huts.Count + Creatures.Count +
                    Cities.Count * (NSEG + 1));

    for I := 0 to Plants.Count - 1 do begin          // les arbres
      P := Plants[I];
      if (P = nil) or P.Morte then Continue;
      RX := P.X - S.X;  RY := P.Y - S.Y;
      if (Abs(RX) > FOG) or (Abs(RY) > FOG) then Continue;
      ZD := RX * DirX + RY * DirY;                   // devant moi ?
      if (ZD <> ZD) or (ZD < 0.4) or (ZD > FOG) then Continue;
      SD := RY * DirX - RX * DirY;                   // sur le côté ?
      HMonde := 1.8 + Frac(P.X * 0.37 + P.Y * 0.61) * 1.4;   // fixe par arbre
      Bbs[N].Z := ZD;
      Bbs[N].SX := RES_W * 0.5 + (SD / ZD) * Foc;
      Bbs[N].Pied := Hor + (EYE_H * Foc / ZD);
      Bbs[N].Haut := HMonde * Foc / ZD;
      Bbs[N].Clr := Col(70, 104, 50);
      Bbs[N].Ty := 0;  Bbs[N].Kd := -1;  Bbs[N].Cid := -1;  Bbs[N].Feu := False;
      Bbs[N].LW := 0;
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
      Bbs[N].Haut := (0.8 + O.Sz * 0.7) * Foc / ZD;
      case O.Kind of
        0: Bbs[N].Clr := Col(228, 220, 190);         // la vache
        1: Bbs[N].Clr := Col(201, 106, 69);          // le loup
        3: Bbs[N].Clr := Col(206, 168, 104);         // le chien
        4: Bbs[N].Clr := Col(118, 82, 54);           // l'ours
        5: Bbs[N].Clr := Col(238, 232, 222);         // le mouton
      else Bbs[N].Clr := O.HueCol;                   // le sapiens : sa lignée
      end;
      Bbs[N].Ty := 2;  Bbs[N].Kd := O.Kind;  Bbs[N].Cid := O.CId;
      Bbs[N].Feu := False;
      Bbs[N].LW := 0;
      Inc(N);
    end;

    for I := 0 to Cities.Count - 1 do begin          // remparts + monument
      V3 := Cities[I];
      if V3.Niveau < 3 then Continue;                // les murs : ville ou cité
      RX := V3.X - S.X;  RY := V3.Y - S.Y;
      if (Abs(RX) > FOG + 12) or (Abs(RY) > FOG + 12) then Continue;
      if V3.Niveau >= 4 then begin                   // le monument : la tour
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
          Inc(N);
        end;
      end;
      RMur := 4.6 + V3.Niveau * 0.6;                 // le rayon des remparts
      LSeg := 6.2831855 / NSEG;                      // le pas d'angle
      for K4 := 0 to NSEG - 1 do begin
        if (K4 mod 6) = 0 then Continue;             // les 4 portes (cardinaux)
        AA := K4 * LSeg;
        RX := V3.X + Cos(AA) * RMur - S.X;           // le centre du segment
        RY := V3.Y + Sin(AA) * RMur - S.Y;
        if (Abs(RX) > FOG) or (Abs(RY) > FOG) then Continue;
        ZD := RX * DirX + RY * DirY;
        if (ZD <> ZD) or (ZD < 0.4) or (ZD > FOG) then Continue;
        SD := RY * DirX - RX * DirY;
        Bbs[N].Z := ZD;
        Bbs[N].SX := RES_W * 0.5 + (SD / ZD) * Foc;
        Bbs[N].Pied := Hor + (EYE_H * Foc / ZD);
        Bbs[N].Haut := 2.2 * Foc / ZD;
        Bbs[N].LW := LSeg * RMur;                    // la largeur du segment
        Bbs[N].Clr := Col(138, 132, 122);
        Bbs[N].Ty := 3;  Bbs[N].Kd := -1;  Bbs[N].Cid := -1;  Bbs[N].Feu := False;
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
      FM := Bbs[K].Z / FOG;  FM := FM * FM;          // LE brouillard du sol
      DM2 := Day * (1 - FM);
      R1 := Bbs[K].Clr and $FF;                      // TColor = $00BBGGRR
      G1 := (Bbs[K].Clr shr 8) and $FF;
      B1 := (Bbs[K].Clr shr 16) and $FF;
      Rf := R1 * DM2 + hr * FM;
      Gf := G1 * DM2 + hg * FM;
      Bf := B1 * DM2 + hb * FM;
      skinR := 224 * DM2 + hr * FM;                  // la couleur de peau, brumée
      skinG := 182 * DM2 + hg * FM;
      skinB := 150 * DM2 + hb * FM;
      case Bbs[K].Ty of

        0: begin                                     // l'arbre : tronc + deux boules
             Ombre(Bbs[K].SX, Bbs[K].Pied, Bbs[K].Haut * 0.40, Bbs[K].Haut * 0.11, FM);
             Rect5(Trunc(Bbs[K].SX - Bbs[K].Haut * 0.08),
                   Trunc(Bbs[K].Pied - Bbs[K].Haut * 0.5),
                   Trunc(Bbs[K].SX + Bbs[K].Haut * 0.08), Trunc(Bbs[K].Pied),
                   92 * DM2 + hr * FM, 66 * DM2 + hg * FM, 46 * DM2 + hb * FM);
             Disque(Bbs[K].SX, Bbs[K].Pied - Bbs[K].Haut * 0.60,
                    Bbs[K].Haut * 0.34, Rf, Gf, Bf);
             Disque(Bbs[K].SX, Bbs[K].Pied - Bbs[K].Haut * 0.88,
                    Bbs[K].Haut * 0.24, Rf, Min(255, Gf + 20 * DM2), Bf);
           end;

        1: begin                                     // la hutte : murs + toit
             Ombre(Bbs[K].SX, Bbs[K].Pied, Bbs[K].Haut * 0.55, Bbs[K].Haut * 0.13, FM);
             Rect5(Trunc(Bbs[K].SX - Bbs[K].Haut * 0.45),
                   Trunc(Bbs[K].Pied - Bbs[K].Haut * 0.55),
                   Trunc(Bbs[K].SX + Bbs[K].Haut * 0.45), Trunc(Bbs[K].Pied),
                   Rf, Gf, Bf);
             for PY := Trunc(Bbs[K].Pied - Bbs[K].Haut) to
                      Trunc(Bbs[K].Pied - Bbs[K].Haut * 0.55) - 1 do begin
               Dy := (Bbs[K].Pied - Bbs[K].Haut * 0.55 - PY) /
                     Max(0.001, Bbs[K].Haut * 0.45);
               Demi := Trunc(Bbs[K].Haut * 0.55 * (1 - Dy));
               Rect5(Trunc(Bbs[K].SX) - Demi, PY, Trunc(Bbs[K].SX) + Demi, PY,
                     140 * DM2 + hr * FM, 82 * DM2 + hg * FM, 62 * DM2 + hb * FM);
             end;
             if Bbs[K].Feu then begin                // le feu : il perçe la brume
               Y0 := Trunc(Bbs[K].Pied - Bbs[K].Haut) - 2;
               Rect5(Trunc(Bbs[K].SX) - 1, Y0, Trunc(Bbs[K].SX) + 1, Y0 + 2,
                     255, 170, 60);
             end;
           end;

        2: begin                                     // ★S6 la créature articulée
             case Bbs[K].Kd of                       // la largeur, pour tous
               0, 5: Wd := Bbs[K].Haut * 0.50;
               1, 3, 4: Wd := Bbs[K].Haut * 0.30;
             else Wd := Bbs[K].Haut * 0.22;
             end;
             Amp := 1.0;                             // les sauvages marchent toujours
             if Bbs[K].Cid = S.CId then              // le suivi : immobile = au repos
               if GLastInit and
                  (Abs(S.X - GLastSX) + Abs(S.Y - GLastSY) < 0.02) then
                 Amp := 0.0;
             ph := Sin(GTime * 9.0 + Bbs[K].Cid * 1.7) * Amp;

             if Bbs[K].Kd = 2 then begin
               // —— le sapiens : jambes, tunique, bras, tête, chevelure ——
               Ombre(Bbs[K].SX, Bbs[K].Pied, Bbs[K].Haut * 0.15,
                     Bbs[K].Haut * 0.05, FM);
               Demi := Max(1, Trunc(Bbs[K].Haut * 0.05));
               Rect5(Trunc(Bbs[K].SX - Bbs[K].Haut * 0.07) - Demi,
                     Trunc(Bbs[K].Pied - Bbs[K].Haut * 0.34 - Bbs[K].Haut * 0.05 * ph),
                     Trunc(Bbs[K].SX - Bbs[K].Haut * 0.07) + Demi, Trunc(Bbs[K].Pied),
                     skinR * 0.82, skinG * 0.82, skinB * 0.82);
               Rect5(Trunc(Bbs[K].SX + Bbs[K].Haut * 0.07) - Demi,
                     Trunc(Bbs[K].Pied - Bbs[K].Haut * 0.34 + Bbs[K].Haut * 0.05 * ph),
                     Trunc(Bbs[K].SX + Bbs[K].Haut * 0.07) + Demi, Trunc(Bbs[K].Pied),
                     skinR * 0.82, skinG * 0.82, skinB * 0.82);
               Rect5(Trunc(Bbs[K].SX - Bbs[K].Haut * 0.13),
                     Trunc(Bbs[K].Pied - Bbs[K].Haut * 0.66),
                     Trunc(Bbs[K].SX + Bbs[K].Haut * 0.13),
                     Trunc(Bbs[K].Pied - Bbs[K].Haut * 0.30), Rf, Gf, Bf);
               Demi := Max(1, Trunc(Bbs[K].Haut * 0.035));
               Rect5(Trunc(Bbs[K].SX - Bbs[K].Haut * 0.17) - Demi,
                     Trunc(Bbs[K].Pied - Bbs[K].Haut * 0.62 - Bbs[K].Haut * 0.04 * ph),
                     Trunc(Bbs[K].SX - Bbs[K].Haut * 0.17) + Demi,
                     Trunc(Bbs[K].Pied - Bbs[K].Haut * 0.36), skinR, skinG, skinB);
               Rect5(Trunc(Bbs[K].SX + Bbs[K].Haut * 0.17) - Demi,
                     Trunc(Bbs[K].Pied - Bbs[K].Haut * 0.62 + Bbs[K].Haut * 0.04 * ph),
                     Trunc(Bbs[K].SX + Bbs[K].Haut * 0.17) + Demi,
                     Trunc(Bbs[K].Pied - Bbs[K].Haut * 0.36), skinR, skinG, skinB);
               Disque(Bbs[K].SX, Bbs[K].Pied - Bbs[K].Haut * 0.80,
                      Bbs[K].Haut * 0.12, skinR, skinG, skinB);
               CYm := Bbs[K].Pied - Bbs[K].Haut * 0.80;     // la chevelure
               CR2 := Sqr(Bbs[K].Haut * 0.12);
               for PY := Trunc(CYm - Bbs[K].Haut * 0.12) to
                        Trunc(CYm - Bbs[K].Haut * 0.04) do
                 for PX := Trunc(Bbs[K].SX - Bbs[K].Haut * 0.12) to
                          Trunc(Bbs[K].SX + Bbs[K].Haut * 0.12) do
                   if Sqr(PX - Bbs[K].SX) + Sqr(PY - CYm) <= CR2 then
                     PutPix(PX, PY, 72 * DM2 + hr * FM, 52 * DM2 + hg * FM,
                            38 * DM2 + hb * FM);
             end else begin
               // —— les quadrupèdes : quatre pattes, corps, tête ——
               Ombre(Bbs[K].SX, Bbs[K].Pied, Wd * 1.3, Wd * 0.42, FM);
               Demi := Max(1, Trunc(Bbs[K].Haut * 0.05));
               if Bbs[K].Kd = 4 then
                 Demi := Max(1, Trunc(Bbs[K].Haut * 0.08));  // l'ours, massif
               LGT := Trunc(Bbs[K].Haut * 0.26);
               Rect5(Trunc(Bbs[K].SX - Wd * 0.62) - Demi,
                     Trunc(Bbs[K].Pied - LGT - Bbs[K].Haut * 0.03 * ph),
                     Trunc(Bbs[K].SX - Wd * 0.62) + Demi, Trunc(Bbs[K].Pied),
                     Rf * 0.72, Gf * 0.72, Bf * 0.72);
               Rect5(Trunc(Bbs[K].SX + Wd * 0.62) - Demi,
                     Trunc(Bbs[K].Pied - LGT + Bbs[K].Haut * 0.03 * ph),
                     Trunc(Bbs[K].SX + Wd * 0.62) + Demi, Trunc(Bbs[K].Pied),
                     Rf * 0.72, Gf * 0.72, Bf * 0.72);
               Rect5(Trunc(Bbs[K].SX - Wd * 0.25) - Demi,
                     Trunc(Bbs[K].Pied - LGT + Bbs[K].Haut * 0.03 * ph),
                     Trunc(Bbs[K].SX - Wd * 0.25) + Demi, Trunc(Bbs[K].Pied),
                     Rf * 0.72, Gf * 0.72, Bf * 0.72);
               Rect5(Trunc(Bbs[K].SX + Wd * 0.25) - Demi,
                     Trunc(Bbs[K].Pied - LGT - Bbs[K].Haut * 0.03 * ph),
                     Trunc(Bbs[K].SX + Wd * 0.25) + Demi, Trunc(Bbs[K].Pied),
                     Rf * 0.72, Gf * 0.72, Bf * 0.72);
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
                 Rect5(Trunc(Bbs[K].SX - Wd), Trunc(Bbs[K].Pied - Bbs[K].Haut * 0.62),
                       Trunc(Bbs[K].SX + Wd), Trunc(Bbs[K].Pied - Bbs[K].Haut * 0.24),
                       Rf, Gf, Bf);
                 Disque(Bbs[K].SX + Wd * 0.85, Bbs[K].Pied - Bbs[K].Haut * 0.48,
                        Bbs[K].Haut * 0.13, Rf * 0.92, Gf * 0.92, Bf * 0.92);
                 if Bbs[K].Kd = 0 then begin        // la vache : les cornes claires
                   Disque(Bbs[K].SX + Wd * 0.85 - Bbs[K].Haut * 0.11,
                          Bbs[K].Pied - Bbs[K].Haut * 0.58, Bbs[K].Haut * 0.045,
                          228 * DM2 + hr * FM, 222 * DM2 + hg * FM, 208 * DM2 + hb * FM);
                   Disque(Bbs[K].SX + Wd * 0.85 + Bbs[K].Haut * 0.11,
                          Bbs[K].Pied - Bbs[K].Haut * 0.58, Bbs[K].Haut * 0.045,
                          228 * DM2 + hr * FM, 222 * DM2 + hg * FM, 208 * DM2 + hb * FM);
                 end;
                 if (Bbs[K].Kd = 1) or (Bbs[K].Kd = 3) then begin
                   // le loup et le chien : oreilles + queue
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

        3: begin                                     // le mur de rempart
             Demi := Trunc(Bbs[K].LW * Foc / Bbs[K].Z * 0.5) + 1;
             if Demi < 1 then Demi := 1;
             X0 := Trunc(Bbs[K].SX) - Demi;
             X1 := Trunc(Bbs[K].SX) + Demi;
             Y0 := Trunc(Bbs[K].Pied - Bbs[K].Haut);
             Y1 := Trunc(Bbs[K].Pied);
             for PY := Max(0, Y0) to Min(RES_H - 1, Y1) do
               for PX := Max(0, X0) to Min(RES_W - 1, X1) do
                 PutPix(PX, PY, Rf, Gf, Bf);
             if Y0 >= 0 then                         // le chaperon, plus clair
               for PX := Max(0, X0) to Min(RES_W - 1, X1) do
                 PutPix(PX, Y0, Rf * 0.7 + (176 * DM2 + hr * FM) * 0.3,
                        Gf * 0.7 + (170 * DM2 + hg * FM) * 0.3,
                        Bf * 0.7 + (158 * DM2 + hb * FM) * 0.3);
           end;

        4: begin                                     // la tour du monument
             Demi := Trunc(Bbs[K].LW * Foc / Bbs[K].Z * 0.5) + 1;
             if Demi < 1 then Demi := 1;
             X0 := Trunc(Bbs[K].SX) - Demi;
             X1 := Trunc(Bbs[K].SX) + Demi;
             Y0 := Trunc(Bbs[K].Pied - Bbs[K].Haut);
             Y1 := Trunc(Bbs[K].Pied);
             for PY := Max(0, Y0) to Min(RES_H - 1, Y1) do
               for PX := Max(0, X0) to Min(RES_W - 1, X1) do
                 PutPix(PX, PY, Rf, Gf, Bf);
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
  if GBuf = nil then
  begin
    GBuf := TBitmap.Create;
    GBuf.PixelFormat := pf24bit;
    GBuf.Width := RES_W;
    GBuf.Height := RES_H;
  end;
  S := SapienSuivant(False);
  if S = nil then
  begin
    G3.Canvas.Brush.Style := bsClear;
    G3.Canvas.Font.Name := 'Segoe UI';
    G3.Canvas.Font.Size := 10;
    G3.Canvas.Font.Color := Col(139, 138, 116);
    G3.Canvas.TextOut(24, 24,
      'aucun sapiens vivant — clic droit pour changer de mode');
    Exit;
  end;
  if IsNan(S.X) or IsNan(S.Y) or IsNan(S.Angle) then
  begin
    SapienSuivant(True); // données corrompues : au suivant
    Exit;
  end;

  // ★S3 : les villes proches — l'assiette urbaine teintera le sol
  NVc := 0;
  SetLength(Vpro, Cities.Count);
  for I := 0 to Cities.Count - 1 do
  begin
    RX := Cities[I].X - S.X;
    RY := Cities[I].Y - S.Y;
    if (Abs(RX) > FOG + 8) or (Abs(RY) > FOG + 8) then
      Continue;
    Vpro[NVc].VX := Cities[I].X;
    Vpro[NVc].VY := Cities[I].Y;
    Vpro[NVc].RA := Sqr(2.6 + Cities[I].Niveau * 0.8);
    Inc(NVc);
  end;
  SetLength(Vpro, NVc);
  Day := 0.28 + 0.72 * FDayLight;
  GTime := GTime + 0.04;                 // ★S6 l'horloge d'animation (~1 tour/s)
  if GTime > 6283 then GTime := 0;       // la remise à zéro (précision de Sin)
  PlaneLen := Tan(FOV / 2);
  Foc := (RES_W * 0.5) / PlaneLen;
  DirA := S.Angle;
  DirX := Cos(DirA);
  DirY := Sin(DirA);
  PlX := -DirY * PlaneLen;
  PlY := DirX * PlaneLen;
  Hor := RES_H div 2;

  // le ciel, du zénith à l'horizon
  zr := 8 + (70 - 8) * Day;
  zg := 10 + (100 - 10) * Day;
  zb := 16 + (140 - 16) * Day;
  hr := 22 + (176 - 22) * Day;
  hg := 24 + (174 - 24) * Day;
  hb := 26 + (148 - 26) * Day;
  for Y := 0 to Hor - 1 do
  begin
    Row := GBuf.ScanLine[Y];
    f := Y / Max(1, Hor - 1);
    sr := zr + (hr - zr) * f;
    sg := zg + (hg - zg) * f;
    sb := zb + (hb - zb) * f;
    for X := 0 to RES_W - 1 do
    begin
      Row[X].B := Trunc(sb);
      Row[X].G := Trunc(sg);
      Row[X].R := Trunc(sr);
    end;
  end;

  // le sol : un rayon par colonne, la couleur du terrain + le brouillard
  for Y := Hor to RES_H - 1 do
  begin
    Row := GBuf.ScanLine[Y];
    T := EYE_H * Foc / (Y - Hor + 0.5);
    FogM := T / FOG;
    if FogM > 1 then
      FogM := 1;
    FogM := FogM * FogM;
    FogA := 1 - FogM;
    DM := Day * FogA;
    WX0 := S.X + T * (DirX - PlX);
    WY0 := S.Y + T * (DirY - PlY);
    StX := 2 * T * PlX / RES_W;
    StY := 2 * T * PlY / RES_W;
    wx := WX0;
    wy := WY0;
    for X := 0 to RES_W - 1 do
    begin
      tx := Trunc(wx);
      ty := Trunc(wy);
      if (tx >= 0) and (tx < GW) and (ty >= 0) and (ty < GH) then
      begin
        CI := ty * GW + tx;
        if TerrType[CI] < T_SAND then
        begin
          sr := 40;
          sg := 66;
          sb := 86;
        end
        else if TerrType[CI] = T_SAND then
        begin
          sr := 176;
          sg := 160;
          sb := 118;
        end
        else
        begin
          case (tx * 7 + ty * 13) and 3 of
            0:
              begin
                sr := 100;
                sg := 128;
                sb := 70
              end;
            1:
              begin
                sr := 94;
                sg := 122;
                sb := 66
              end;
            2:
              begin
                sr := 104;
                sg := 134;
                sb := 74
              end;
          else
            begin
              sr := 90;
              sg := 118;
              sb := 64
            end;
          end;
        end;
      end
      else
      begin
        sr := 90;
        sg := 118;
        sb := 64;
      end;
      // ★S3 : la route écrase le terrain…
      if SurRoute(wx, wy) then
      begin
        sr := 152;
        sg := 126;
        sb := 86;
      end;
      // …et la terre battue de la ville écrase tout
      for K3 := 0 to High(Vpro) do
        if Sqr(wx - Vpro[K3].VX) + Sqr(wy - Vpro[K3].VY) < Vpro[K3].RA then
        begin
          sr := 168;
          sg := 158;
          sb := 138;
          Break;
        end;
      Row[X].B := Trunc(sb * DM + hb * FogM);
      Row[X].G := Trunc(sg * DM + hg * FogM);
      Row[X].R := Trunc(sr * DM + hr * FogM);
      wx := wx + StX;
      wy := wy + StY;
    end;
  end;

  Billboards;
  // ★S2/S3 : ce qui se dresse — arbres, huttes, bêtes, remparts, tour
  GLastSX := S.X;  GLastSY := S.Y;  GLastInit := True;   // ★S6 : pour l'animation

  // l'agrandissement plein écran + le bandeau
  G3.Canvas.StretchDraw(Rect(0, 0, G3.ClientWidth, G3.ClientHeight), GBuf);
  G3.Canvas.Brush.Style := bsClear;
  G3.Canvas.Font.Name := 'Segoe UI';
  G3.Canvas.Font.Size := 9;
  G3.Canvas.Font.Color := Col(224, 218, 194);
  G3.Canvas.TextOut(12, 10, S.Name);
  G3.Canvas.Font.Color := Col(160, 156, 134);
  G3.Canvas.TextOut(12, 26, 'clic : autre sapiens');
      if S.Piloted then begin                // ★S6 : tes mains en vue subjective
    HandA := Sin(GWalkT) * G3.ClientHeight * 0.018;      // le balancement du pas
    HandW := Max(6, Trunc(G3.ClientWidth * 0.045));
    G3.Canvas.Brush.Style := bsSolid;
    G3.Canvas.Pen.Style := psClear;
    G3.Canvas.Brush.Color := Col(Trunc(46 + 178 * Day), Trunc(36 + 146 * Day),
                                 Trunc(28 + 122 * Day));
    G3.Canvas.Rectangle(Trunc(G3.ClientWidth * 0.28) - HandW,
                        Trunc(G3.ClientHeight * 0.86 + HandA),
                        Trunc(G3.ClientWidth * 0.28) + HandW, G3.ClientHeight + 4);
    G3.Canvas.Rectangle(Trunc(G3.ClientWidth * 0.72) - HandW,
                        Trunc(G3.ClientHeight * 0.86 - HandA),
                        Trunc(G3.ClientWidth * 0.72) + HandW, G3.ClientHeight + 4);
  end;
  if S.Piloted then
    G3.Canvas.TextOut(12, 42,
      '★ incarné — flèches/ZQSD : marcher · ESPACE : rendre le corps')
  else
    G3.Canvas.TextOut(12, 42, 'ESPACE : incarner ce sapiens');
end;

procedure TG3DForm.GDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbRight then
  begin
    GMode := (GMode + 1) mod 3;
    case GMode of
      0:
        Caption := 'Microcosme — 3D · traits';
      1:
        Caption := 'Microcosme — 3D · populations';
    else
      Caption := 'Microcosme — 3D · yeux de sapiens';
    end;
    if GTim <> nil then
    begin
      if GMode = 2 then
        GTim.Interval := 40
      else
        GTim.Interval := 120;
    end;
    Invalidate;
    Exit;
  end;
  if (GMode = 2) and (Button = mbLeft) then
  begin
    SapienSuivant(True); // clic gauche : le sapiens suivant
    Invalidate;
    Exit;
  end;
  GDrag := True;
  GLX := X;
  GLY := Y;
end;

procedure TG3DForm.GMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  if GDrag then
  begin
    GYaw := GYaw + (X - GLX) * 0.008;
    GPitch := ClampF(GPitch + (Y - GLY) * 0.006, -1.35, 1.35);
    GLX := X;
    GLY := Y;
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

procedure TG3DForm.GPaint(Sender: TObject);
var
  C: TCanvas;
  W, H: Integer;

  function Proj(X, Y, Z: Single; out SX, SY: Integer;
    out SC, DZ: Single): Boolean;
  var
    Cy, Syn, Cp, Sp, X1, Y1, Z1, D, f: Single;
  begin
    Cy := Cos(GYaw);
    Syn := Sin(GYaw);
    Cp := Cos(GPitch);
    Sp := Sin(GPitch);
    X1 := X * Cy - Z * Syn;
    Z1 := X * Syn + Z * Cy;
    Y1 := Y * Cp - Z1 * Sp;
    Z1 := Y * Sp + Z1 * Cp;
    DZ := Z1;
    D := 3.6 - Z1;
    if D < 0.5 then
    begin
      Result := False;
      Exit
    end;
    f := Min(W, H) * 0.40 * GZoom / D;
    SX := W div 2 + Round(X1 * f);
    SY := H div 2 - Round(Y1 * f);
    SC := f;
    Result := True;
  end;

  procedure Box;
  const
    CV: array [0 .. 7, 0 .. 2] of Single = ((-1, -1, -1), (1, -1, -1),
      (1, 1, -1), (-1, 1, -1), (-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1));
    ED: array [0 .. 11, 0 .. 1] of Integer = ((0, 1), (1, 2), (2, 3), (3, 0),
      (4, 5), (5, 6), (6, 7), (7, 4), (0, 4), (1, 5), (2, 6), (3, 7));
  var
    I, A1, A2, B1, B2: Integer;
    SC, DZ: Single;
  begin
    C.Pen.Style := psSolid;
    C.Pen.Width := 1;
    C.Pen.Color := Col(46, 52, 40);
    for I := 0 to 11 do
      if Proj(CV[ED[I][0]][0], CV[ED[I][0]][1], CV[ED[I][0]][2], A1, A2, SC, DZ)
        and Proj(CV[ED[I][1]][0], CV[ED[I][1]][1], CV[ED[I][1]][2], B1, B2,
        SC, DZ) then
      begin
        C.MoveTo(A1, A2);
        C.LineTo(B1, B2);
      end;
  end;

  procedure Lab(X, Y, Z: Single; const tx: string; Clr: TColor);
  var
    SX, SY: Integer;
    SC, DZ: Single;
  begin
    if not Proj(X, Y, Z, SX, SY, SC, DZ) then
      Exit;
    C.Font.Name := 'Segoe UI';
    C.Font.Size := 9;
    C.Font.Style := [];
    C.Brush.Style := bsClear;
    C.Font.Color := Clr;
    C.TextOut(SX - C.TextWidth(tx) div 2, SY - 6, tx);
  end;

  procedure Traits;
  type
    TStar = record
      SX, SY, Rad: Integer;
      Clr: TColor;
      Z: Single;
    end;
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
    for I := 0 to Creatures.Count - 1 do
    begin
      CR := Creatures[I];
      if (CR = nil) or (not CR.Alive) then
        Continue;
      X := ClampF((CR.Sp - 4.3) / 2.1, -1, 1);
      Y := ClampF((CR.Se - 8.0) / 4.0, -1, 1);
      Z := ClampF((CR.Sz - 1.05) / 0.45, -1, 1);
      if not Proj(X, Y, Z, SX, SY, SC, DZ) then
        Continue;
      Stars[N].SX := SX;
      Stars[N].SY := SY;
      Stars[N].Rad := Max(2, Round(SC * 0.05));
      Stars[N].Z := DZ;
      case CR.Kind of
        0:
          Stars[N].Clr := Col(228, 220, 190);
        1:
          Stars[N].Clr := Col(201, 106, 69);
        3:
          Stars[N].Clr := Col(206, 168, 104);
      else
        Stars[N].Clr := CR.HueCol;
      end;
      Inc(N);
    end;
    SetLength(Stars, N);
    for I := 1 to N - 1 do
    begin // tri : plus lointaines d'abord
      Tmp := Stars[I];
      J := I - 1;
      while (J >= 0) and (Stars[J].Z > Tmp.Z) do
      begin
        Stars[J + 1] := Stars[J];
        Dec(J);
      end;
      Stars[J + 1] := Tmp;
    end;
    for I := 0 to N - 1 do
    begin
      C.Brush.Style := bsSolid;
      C.Pen.Style := psClear;
      C.Brush.Color := Stars[I].Clr;
      C.Ellipse(Stars[I].SX - Stars[I].Rad, Stars[I].SY - Stars[I].Rad,
        Stars[I].SX + Stars[I].Rad, Stars[I].SY + Stars[I].Rad);
    end;
    if N = 0 then
    begin
      C.Font.Name := 'Segoe UI';
      C.Font.Size := 10;
      C.Font.Style := [];
      C.Brush.Style := bsClear;
      C.Font.Color := Col(139, 138, 116);
      C.TextOut(24, 24, 'aucun habitant — lance la simulation');
    end;
    Lab(1.28, -1, -1, 'vitesse →', Col(139, 138, 116));
    Lab(-1, 1.28, -1, '↑ vue', Col(139, 138, 116));
    Lab(-1, -1, 1.28, '↑ taille', Col(139, 138, 116));
    C.Pen.Style := psClear;
    C.Brush.Style := bsSolid;
    C.Brush.Color := Col(228, 220, 190);
    C.Rectangle(16, 16, 22, 22);
    C.Brush.Style := bsClear;
    C.Font.Size := 8;
    C.Font.Color := Col(139, 138, 116);
    C.TextOut(28, 16, 'herbivores');
    C.Brush.Style := bsSolid;
    C.Brush.Color := Col(201, 106, 69);
    C.Rectangle(16, 30, 22, 36);
    C.Brush.Style := bsClear;
    C.TextOut(28, 30, 'prédateurs');
    C.Brush.Style := bsSolid;
    C.Brush.Color := Col(208, 167, 92);
    C.Rectangle(16, 44, 22, 50);
    C.Brush.Style := bsClear;
    C.TextOut(28, 44, 'sapiens (couleur = lignée)');
  end;

  procedure Pops;
  const
    SERCLR: array [0 .. 3] of array [0 .. 2] of Integer = ((157, 187, 107),
      (228, 220, 190), (201, 106, 69), (208, 167, 92));
    SERNM: array [0 .. 3] of string = ('flore', 'herbivores', 'prédateurs',
      'sapiens');
  var
    K, I: Integer;
    V, MaxV, X, Y, Z, SC, DZ: Single;
    SX, SY, LXp, LYp: Integer;
    Clr: TColor;
  begin
    if Length(FHist) < 2 then
    begin
      C.Font.Name := 'Segoe UI';
      C.Font.Size := 10;
      C.Font.Style := [];
      C.Brush.Style := bsClear;
      C.Font.Color := Col(139, 138, 116);
      C.TextOut(24, 24,
        'lance la simulation : les courbes s''accumulent ici en 3D');
      Exit;
    end;
    for K := 0 to 3 do
    begin
      MaxV := 1;
      for I := 0 to High(FHist) do
      begin
        case K of
          0:
            V := FHist[I].P;
          1:
            V := FHist[I].H;
          2:
            V := FHist[I].C;
        else
          V := FHist[I].S;
        end;
        if V > MaxV then
          MaxV := V;
      end;
      Clr := Col(SERCLR[K][0], SERCLR[K][1], SERCLR[K][2]);
      C.Pen.Style := psSolid;
      C.Pen.Width := 2;
      C.Pen.Color := Clr;
      Z := (K - 1.5) * 0.45;
      LXp := 0;
      LYp := 0;
      for I := 0 to High(FHist) do
      begin
        case K of
          0:
            V := FHist[I].P;
          1:
            V := FHist[I].H;
          2:
            V := FHist[I].C;
        else
          V := FHist[I].S;
        end;
        X := I / High(FHist) * 2 - 1;
        Y := ClampF(V / MaxV, 0, 1) * 2 - 1;
        if Proj(X, Y, Z, SX, SY, SC, DZ) then
        begin
          if I = 0 then
            C.MoveTo(SX, SY)
          else
            C.LineTo(SX, SY);
          LXp := SX;
          LYp := SY;
        end;
      end;
      case K of
        0:
          V := FHist[High(FHist)].P;
        1:
          V := FHist[High(FHist)].H;
        2:
          V := FHist[High(FHist)].C;
      else
        V := FHist[High(FHist)].S;
      end;
      C.Font.Name := 'Segoe UI';
      C.Font.Size := 9;
      C.Font.Style := [];
      C.Brush.Style := bsClear;
      C.Font.Color := Clr;
      C.TextOut(LXp + 6, LYp - 6, Format('%s %d', [SERNM[K], Round(V)]));
    end;
  end;

begin
  C := Canvas;
  W := ClientWidth;
  H := ClientHeight;
  FSimCS.Enter;
  try
    C.Brush.Style := bsSolid;
    C.Pen.Style := psClear;
    C.Brush.Color := Col(11, 14, 11);
    C.FillRect(Rect(0, 0, W, H));
    Box;
    case GMode of
      0:
        Traits;
      1:
        Pops;
    else
      Yeux;
    end;
    C.Font.Name := 'Segoe UI';
    C.Font.Size := 8;
    C.Font.Style := [];
    C.Brush.Style := bsClear;
    C.Font.Color := Col(100, 105, 88);
    if GMode = 2 then
      C.TextOut(16, H - 24,
        'clic : sapiens suivant · clic droit : changer de mode')
    else
      C.TextOut(16, H - 24,
        'glisser : tourner · molette : zoom · clic droit : changer de mode');
  finally
    FSimCS.Leave;
  end;
end;

end.

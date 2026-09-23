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

type
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
  end;

   type
  TRGBTri = packed record               // un pixel 24 bits (ordre mémoire BGR)
    B, G, R: Byte;
  end;
  TRGBRow = array[0..0] of TRGBTri;
  PRGBRow = ^TRGBRow;

var
  G3: TG3DForm = nil;
  GYaw: Single = 0.7;
  GPitch: Single = 0.32;
  GZoom: Single = 1.0;
  GMode: Integer = 0;
  GDrag: Boolean = False;
  GLX, GLY: Integer;
  GTim: TTimer = nil;                   // le batteur (pour changer sa cadence)
  GBuf: TBitmap = nil;                  // l'écran basse résolution du raycaster
  GFollowCId: Integer = 0;              // le sapiens suivi : un CId, JAMAIS un pointeur

procedure OpenGraph3DWindow;
var T: TTimer;
begin
  if G3 <> nil then begin G3.BringToFront; Exit end;
  G3 := TG3DForm.CreateNew(nil);
  with G3 do begin
    Caption := 'Microcosme — 3D · traits';
    Width := 780; Height := 580;
    Position := poScreenCenter;
    Color := Col(11, 14, 11);
    DoubleBuffered := True;
    OnPaint := GPaint;
    OnClose := GClose;
    OnMouseDown := GDown;
    OnMouseMove := GMove;
    OnMouseUp := GUp;
    OnMouseWheel := GWheel;
  end;
  T := TTimer.Create(G3);
  T.Interval := 120;
  T.OnTimer := G3.GTimer;
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

    {─── mode 2 : les yeux d'un sapiens (raycaster 100% code) ──────────────────}

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

procedure Yeux;
const
  RES_W = 240;   RES_H = 150;   // la basse résolution, agrandie après
  FOV   = 1.05;                 // ~60°
  EYE_H = 1.55;                 // la hauteur des yeux, en cases
  FOG   = 26.0;                 // la portée du brouillard, en cases
var
  S: TCreature;
  x, y, tx, ty, CI, Hor: Integer;
  DirA, DirX, DirY, PlX, PlY, PlaneLen, Foc, T,
  WX0, WY0, StX, StY, wx, wy, Day, DM, FogM, FogA,
  zr, zg, zb, hr, hg, hb, f, sr, sg, sb: Single;
  Row: PRGBRow;
begin
  if GBuf = nil then begin
    GBuf := TBitmap.Create;
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
    SapienSuivant(True);                 // données corrompues : au suivant
    Exit;
  end;

  Day := 0.28 + 0.72 * FDayLight;        // la nuit assombrit, n'éteint pas
  PlaneLen := Tan(FOV / 2);
  Foc := (RES_W * 0.5) / PlaneLen;
  DirA := S.Angle;                       // le regard = la direction de marche
  DirX := Cos(DirA);
  DirY := Sin(DirA);
  PlX := -DirY * PlaneLen;               // le plan caméra, perpendiculaire
  PlY := DirX * PlaneLen;
  Hor := RES_H div 2;

  // le ciel, du zénith à l'horizon
  zr := 8  + (70  - 8)  * Day;
  zg := 10 + (100 - 10) * Day;
  zb := 16 + (140 - 16) * Day;
  hr := 22 + (176 - 22) * Day;           // la teinte d'horizon = le brouillard
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

  // le sol : un rayon par colonne, la couleur du terrain + le brouillard
  for y := Hor to RES_H - 1 do begin
    Row := GBuf.ScanLine[y];
    T := EYE_H * Foc / (y - Hor + 0.5);  // la distance du sol vu sur cette ligne
    FogM := T / FOG;
    if FogM > 1 then FogM := 1;
    FogM := FogM * FogM;                 // quadratique : doux au loin
    FogA := 1 - FogM;
    DM := Day * FogA;
    WX0 := S.X + T * (DirX - PlX);       // le point de sol de la colonne 0
    WY0 := S.Y + T * (DirY - PlY);
    StX := 2 * T * PlX / RES_W;          // le pas d'une colonne à l'autre
    StY := 2 * T * PlY / RES_W;
    wx := WX0;  wy := WY0;
    for x := 0 to RES_W - 1 do begin
      tx := Trunc(wx);  ty := Trunc(wy);
      if (tx >= 0) and (tx < GW) and (ty >= 0) and (ty < GH) then begin
        CI := ty * GW + tx;
        if TerrType[CI] < T_SAND then begin      // l'eau, plate comme un sol
          sr := 40; sg := 66; sb := 86;
        end else if TerrType[CI] = T_SAND then begin
          sr := 176; sg := 160; sb := 118;       // le sable
        end else begin                           // l'herbe, varie par cellule
          case (tx * 7 + ty * 13) and 3 of
            0: begin sr := 100; sg := 128; sb := 70 end;
            1: begin sr := 94;  sg := 122; sb := 66 end;
            2: begin sr := 104; sg := 134; sb := 74 end;
          else begin sr := 90;  sg := 118; sb := 64 end;
          end;
        end;
      end else begin
        sr := 90; sg := 118; sb := 64;           // hors monde : herbe sombre
      end;
      Row[x].B := Trunc(sb * DM + hb * FogM);
      Row[x].G := Trunc(sg * DM + hg * FogM);
      Row[x].R := Trunc(sr * DM + hr * FogM);
      wx := wx + StX;
      wy := wy + StY;
    end;
  end;

  // l'agrandissement plein écran + le bandeau
  G3.Canvas.StretchDraw(Rect(0, 0, G3.ClientWidth, G3.ClientHeight), GBuf);
  G3.Canvas.Brush.Style := bsClear;
  G3.Canvas.Font.Name := 'Segoe UI';
  G3.Canvas.Font.Size := 9;
  G3.Canvas.Font.Color := Col(224, 218, 194);
  G3.Canvas.TextOut(12, 10, S.Name);
  G3.Canvas.Font.Color := Col(160, 156, 134);
  G3.Canvas.TextOut(12, 26, 'clic : autre sapiens');
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
    else Yeux;
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

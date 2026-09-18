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

var
  G3: TG3DForm = nil;
  GYaw: Single = 0.7;
  GPitch: Single = 0.32;
  GZoom: Single = 1.0;
  GMode: Integer = 0;
  GDrag: Boolean = False;
  GLX, GLY: Integer;

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
  G3 := nil;
end;

procedure TG3DForm.GDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbRight then begin
    GMode := 1 - GMode;
    if GMode = 0 then Caption := 'Microcosme — 3D · traits'
    else Caption := 'Microcosme — 3D · populations';
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
    if GMode = 0 then Traits else Pops;
    C.Font.Name := 'Segoe UI'; C.Font.Size := 8; C.Font.Style := [];
    C.Brush.Style := bsClear;
    C.Font.Color := Col(100, 105, 88);
    C.TextOut(16, H - 24, 'glisser : tourner · molette : zoom · clic droit : changer de mode');
  finally
    FSimCS.Leave;
  end;
end;

end.

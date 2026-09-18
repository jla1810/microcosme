                               unit MicroRenderPro;

{ Microcosme — rendu "pro" des créatures : corps orientés anti-aliasés (GDI+),
  ombre, pattes animées, tête, museau, oreilles, yeux. 100% code, 0 ressource. }

interface

uses
  System.SysUtils, System.Math, Winapi.Windows, Winapi.GDIPOBJ, Winapi.GDIPAPI,
  Vcl.Graphics;

const
  PR_HUNT = 2;   // prédateur en chasse -> yeux rouges

procedure ProRender(cv: TCanvas; Kind: Integer; SX, SY, Angle, SzPx: Single;
  Body, Accent: TColor; Phase: Single; Flags: Integer);
procedure ProFlush;

implementation

var
  gG: TGPGraphics = nil;
  gLastHDC: HDC = 0;

procedure ProFlush;
begin
  FreeAndNil(gG);
  gLastHDC := 0;
end;

function Graph(cv: TCanvas): TGPGraphics;
begin
  ProFlush;                                          // jamais vivant entre deux appels
  gG := TGPGraphics.Create(cv.Handle);
  gG.SetSmoothingMode(SmoothingModeAntiAlias);
  Result := gG;
end;

function GPC(C: TColor; A: Byte = 255): Cardinal;
begin
  C := ColorToRGB(C);
  Result := (Cardinal(A) shl 24) or (Cardinal(GetRValue(C)) shl 16) or
            (Cardinal(GetGValue(C)) shl 8) or Cardinal(GetBValue(C));
end;

function Shade(C: TColor; F: Single): TColor;
begin
  C := ColorToRGB(C);
  Result := RGB(Round(GetRValue(C)*F), Round(GetGValue(C)*F), Round(GetBValue(C)*F));
end;

procedure ProRender(cv: TCanvas; Kind: Integer; SX, SY, Angle, SzPx: Single;
  Body, Accent: TColor; Phase: Single; Flags: Integer);
var g: TGPGraphics;
    bFill, bDark, bShad, bAcc, bEye: TGPSolidBrush;
    pLine: TGPPen;
    S: Single;
begin
  if SzPx < 3 then Exit;                 // trop petit à l'écran : on ne dessine pas
  S := SzPx;
  g := Graph(cv);
  bShad := TGPSolidBrush.Create(GPC(0, 45));
  bFill := TGPSolidBrush.Create(GPC(Body));
  bDark := TGPSolidBrush.Create(GPC(Shade(Body, 0.55)));
  bAcc  := TGPSolidBrush.Create(GPC(Accent));
  if (Flags and PR_HUNT) <> 0 then
    bEye := TGPSolidBrush.Create(GPC(RGB(230, 70, 45)))
  else
    bEye := TGPSolidBrush.Create(GPC(RGB(18, 16, 14)));
  pLine := TGPPen.Create(GPC(Shade(Body, 0.40)), Max(1.0, S*0.12));
  try
    g.TranslateTransform(SX, SY);
    // ombre au sol (non tournée)
    g.FillEllipse(bShad, -S*0.80, -S*0.40 + S*0.20, S*1.75, S*0.85);
    g.RotateTransform(Angle * 180 / Pi);   // +X = avant

    case Kind of
      0: begin // HERBIVORE
           g.FillEllipse(bDark, -S*1.05, -S*0.10, S*0.34, S*0.20);          // queue
           g.FillEllipse(bDark,  S*0.26, -S*0.44 + Sin(Phase)*S*0.14, S*0.20, S*0.20);
           g.FillEllipse(bDark,  S*0.26,  S*0.24 + Sin(Phase)*S*0.14, S*0.20, S*0.20);
           g.FillEllipse(bDark, -S*0.52, -S*0.44 + Sin(Phase+Pi)*S*0.14, S*0.20, S*0.20);
           g.FillEllipse(bDark, -S*0.52,  S*0.24 + Sin(Phase+Pi)*S*0.14, S*0.20, S*0.20);
           g.FillEllipse(bFill, -S*0.72, -S*0.40, S*1.48, S*0.80);          // corps
           g.DrawEllipse(pLine, -S*0.72, -S*0.40, S*1.48, S*0.80);
           g.FillEllipse(bFill,  S*0.52, -S*0.26, S*0.56, S*0.52);          // tête
           g.DrawEllipse(pLine,  S*0.52, -S*0.26, S*0.56, S*0.52);
           g.FillEllipse(bDark,  S*0.56, -S*0.32, S*0.14, S*0.14);          // oreilles
           g.FillEllipse(bDark,  S*0.56,  S*0.18, S*0.14, S*0.14);
           g.FillEllipse(bDark,  S*0.98, -S*0.08, S*0.14, S*0.16);          // museau
           g.FillEllipse(bEye,   S*0.80, -S*0.16, S*0.08, S*0.08);
           g.FillEllipse(bEye,   S*0.80,  S*0.08, S*0.08, S*0.08);
         end;
      1: begin // PRÉDATEUR
           g.FillEllipse(bDark, -S*1.30, -S*0.07 + Sin(Phase*0.8)*S*0.10,
                                 S*0.70, S*0.14);                            // queue
           g.FillEllipse(bDark,  S*0.28, -S*0.40 + Sin(Phase)*S*0.16, S*0.18, S*0.18);
           g.FillEllipse(bDark,  S*0.28,  S*0.22 + Sin(Phase)*S*0.16, S*0.18, S*0.18);
           g.FillEllipse(bDark, -S*0.55, -S*0.40 + Sin(Phase+Pi)*S*0.16, S*0.18, S*0.18);
           g.FillEllipse(bDark, -S*0.55,  S*0.22 + Sin(Phase+Pi)*S*0.16, S*0.18, S*0.18);
           g.FillEllipse(bFill, -S*0.90, -S*0.34, S*1.80, S*0.68);          // corps long
           g.DrawEllipse(pLine, -S*0.90, -S*0.34, S*1.80, S*0.68);
           g.FillEllipse(bFill,  S*0.72, -S*0.22, S*0.50, S*0.44);          // tête
           g.DrawEllipse(pLine,  S*0.72, -S*0.22, S*0.50, S*0.44);
           g.FillEllipse(bDark,  S*0.78, -S*0.28, S*0.16, S*0.10);          // oreilles
           g.FillEllipse(bDark,  S*0.78,  S*0.18, S*0.16, S*0.10);
           g.FillEllipse(bDark,  S*1.12, -S*0.07, S*0.12, S*0.14);          // museau
           g.FillEllipse(bEye,   S*0.98, -S*0.13, S*0.07, S*0.07);          // yeux rouges
           g.FillEllipse(bEye,   S*0.98,  S*0.06, S*0.07, S*0.07);          // si chasse
         end;
      2: begin // SAPIEN
           g.FillEllipse(bDark, -S*0.10 + Sin(Phase)*S*0.16,     S*0.28, S*0.16, S*0.34);
           g.FillEllipse(bDark, -S*0.10 + Sin(Phase+Pi)*S*0.16, -S*0.62, S*0.16, S*0.34);
           g.FillEllipse(bFill, -S*0.34, -S*0.50, S*0.72, S*1.00);          // torse
           g.DrawEllipse(pLine, -S*0.34, -S*0.50, S*0.72, S*1.00);
           g.FillEllipse(bDark,  S*0.16 + Sin(Phase+Pi)*S*0.12, -S*0.48, S*0.30, S*0.14);
           g.FillEllipse(bDark,  S*0.16 + Sin(Phase)*S*0.12,     S*0.34, S*0.30, S*0.14);
           g.FillEllipse(bAcc,  -S*0.18, -S*0.22, S*0.40, S*0.44);          // pagne (HueCol)
           g.FillEllipse(bFill,  S*0.10, -S*0.27, S*0.50, S*0.54);          // tête
           g.DrawEllipse(pLine,  S*0.10, -S*0.27, S*0.50, S*0.54);
           g.FillEllipse(bDark, -S*0.02, -S*0.26, S*0.30, S*0.52);          // cheveux
           g.FillEllipse(bEye,   S*0.46, -S*0.16, S*0.07, S*0.07);
           g.FillEllipse(bEye,   S*0.46,  S*0.09, S*0.07, S*0.07);
         end;
      3: begin // CHIEN
           g.FillEllipse(bDark, -S*0.95, -S*0.06 + Sin(Phase*0.9)*S*0.08,
                                 S*0.42, S*0.12);                            // queue
           g.FillEllipse(bDark,  S*0.22, -S*0.32 + Sin(Phase)*S*0.12, S*0.14, S*0.14);
           g.FillEllipse(bDark,  S*0.22,  S*0.18 + Sin(Phase)*S*0.12, S*0.14, S*0.14);
           g.FillEllipse(bDark, -S*0.42, -S*0.32 + Sin(Phase+Pi)*S*0.12, S*0.14, S*0.14);
           g.FillEllipse(bDark, -S*0.42,  S*0.18 + Sin(Phase+Pi)*S*0.12, S*0.14, S*0.14);
           g.FillEllipse(bFill, -S*0.65, -S*0.30, S*1.30, S*0.60);          // corps
           g.DrawEllipse(pLine, -S*0.65, -S*0.30, S*1.30, S*0.60);
           g.FillEllipse(bFill,  S*0.52, -S*0.20, S*0.44, S*0.40);          // tête
           g.DrawEllipse(pLine,  S*0.52, -S*0.20, S*0.44, S*0.40);
           g.FillEllipse(bDark,  S*0.56, -S*0.24, S*0.12, S*0.10);          // oreilles
           g.FillEllipse(bDark,  S*0.56,  S*0.14, S*0.12, S*0.10);
           g.FillEllipse(bAcc,   S*0.40, -S*0.20, S*0.09, S*0.40);          // collier
           g.FillEllipse(bDark,  S*0.88, -S*0.06, S*0.10, S*0.12);          // museau
           g.FillEllipse(bEye,   S*0.78, -S*0.11, S*0.06, S*0.06);
           g.FillEllipse(bEye,   S*0.78,  S*0.05, S*0.06, S*0.06);
         end;
    end;
    g.ResetTransform
          finally
    bShad.Free; bFill.Free; bDark.Free; bAcc.Free; bEye.Free; pLine.Free;
    ProFlush;                    // <<< ajouter : relâche le DC immédiatement
    end;
end;

end.

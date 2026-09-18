unit MicroLogo;

{ Microcosme — logo GDI+ anti-aliasé : île vue du ciel, soleil doré à halo,
  houle, sapins, sapiens silhouette. 100% code, export PNG. }

interface

uses
  System.SysUtils, System.Math, System.Types, System.Classes,
  Winapi.Windows, Vcl.Graphics, Vcl.Imaging.pngimage,
  Winapi.GDIPOBJ, Winapi.GDIPAPI;

procedure DrawLogo(C: TCanvas; X, Y, Size: Integer);
procedure SaveLogoPNG(const FileName: string; Size: Integer);

implementation

function GP(R, G, B: Integer; A: Byte = 255): Cardinal;
begin
  Result := (Cardinal(A) shl 24) or (Cardinal(R) shl 16) or
            (Cardinal(G) shl 8) or Cardinal(B);
end;

procedure DrawLogo(C: TCanvas; X, Y, Size: Integer);
var G: TGPGraphics;
    F: Single;

  procedure Ell(B: TGPSolidBrush; cx, cy, rx, ry: Single);
  begin
    G.FillEllipse(B, X + (cx - rx) * F, Y + (cy - ry) * F, rx * 2 * F, ry * 2 * F);
  end;

  procedure Sapin(cx, cy, H: Single; R, Gr, B: Integer);
  var Br: TGPSolidBrush;
      p: array[0..2] of TGPPointF;
  begin
    Br := TGPSolidBrush.Create(GP(R, Gr, B));
    try
      p[0].X := X + cx * F;               p[0].Y := Y + (cy - H) * F;
      p[1].X := X + (cx - H * 0.42) * F;  p[1].Y := Y + cy * F;
      p[2].X := X + (cx + H * 0.42) * F;  p[2].Y := Y + cy * F;
      G.FillPolygon(Br, PGPPointF(@p), 3);
    finally Br.Free; end;
  end;

var bOcean, bIle, bRock, bSnow, bSand, bSun, bHalo, bSapi, bOmbre: TGPSolidBrush;
    pen: TGPPen;
    p: array[0..2] of TGPPointF;
begin
  if Size <= 0 then Exit;
  F := Size / 256;
  G := TGPGraphics.Create(C.Handle);
  G.SetSmoothingMode(SmoothingModeAntiAlias);
  try
    bHalo  := TGPSolidBrush.Create(GP(208, 167, 92, 38));
    bSun   := TGPSolidBrush.Create(GP(208, 167, 92));
    bOmbre := TGPSolidBrush.Create(GP(0, 0, 0, 60));
    bOcean := TGPSolidBrush.Create(GP(13, 34, 40));
    bIle   := TGPSolidBrush.Create(GP(74, 102, 62));
    bRock  := TGPSolidBrush.Create(GP(120, 115, 102));
    bSnow  := TGPSolidBrush.Create(GP(214, 212, 198));
    bSand  := TGPSolidBrush.Create(GP(186, 168, 122));
    bSapi  := TGPSolidBrush.Create(GP(16, 20, 14));
    pen    := TGPPen.Create(GP(159, 196, 207, 170), 2.2 * F);
    try
      // fond nuit + ombre portée du médaillon + océan
      G.FillEllipse(bOmbre, X + 8 * F, Y + 12 * F, 244 * F, 244 * F);
      G.FillEllipse(bOcean, X + 4 * F, Y + 4 * F, 248 * F, 248 * F);

      // halo du soleil (2 cercles dégressifs) + soleil
      Ell(bHalo, 62, 62, 46, 46);
      Ell(bHalo, 62, 62, 36, 36);
      Ell(bSun, 62, 62, 24, 24);

      // reflets du soleil sur l'eau
      pen.SetWidth(2.0 * F);
      G.DrawArc(pen, X + 30 * F, Y + 96 * F, 64 * F, 10 * F, 180, 180);
      G.DrawArc(pen, X + 44 * F, Y + 112 * F, 40 * F, 8 * F, 180, 180);

      // plage puis île
      Ell(bSand, 132, 140, 78, 62);
      Ell(bIle, 130, 132, 66, 52);

      // relief : roche + neige
      Ell(bRock, 152, 100, 20, 14);
      Ell(bSnow, 152, 96, 11, 7);

      // forêts : bosquets de sapins (2 tons)
      Sapin(96, 128, 16, 46, 72, 48);   Sapin(108, 118, 13, 46, 72, 48);
      Sapin(120, 134, 15, 46, 72, 48);  Sapin(160, 138, 16, 46, 72, 48);
      Sapin(172, 128, 13, 46, 72, 48);  Sapin(140, 152, 14, 46, 72, 48);
      Sapin(104, 140, 12, 30, 48, 34);  Sapin(166, 148, 12, 30, 48, 34);

      // houle : arcs concentriques en bas
      pen.SetWidth(2.4 * F);
      G.DrawArc(pen, X + 20 * F, Y + 30 * F, 216 * F, 216 * F, 55, 70);
      pen.SetWidth(1.6 * F);
      G.DrawArc(pen, X + 8 * F, Y + 18 * F, 240 * F, 240 * F, 60, 60);

      // le sapiens silhouette (bas droite, bras levé vers le soleil)
      Ell(bSapi, 196, 196, 9, 9);        // tête
      Ell(bSapi, 196, 216, 7, 12);       // corps
      p[0].X := X + 202 * F; p[0].Y := Y + 208 * F;
      p[1].X := X + 210 * F; p[1].Y := Y + 184 * F;
      p[2].X := X + 206 * F; p[2].Y := Y + 182 * F;
      G.FillPolygon(bSapi, PGPPointF(@p), 3);   // bras levé
      Ell(bSapi, 191, 232, 3, 8);        // jambe gauche
      Ell(bSapi, 201, 232, 3, 8);        // jambe droite

      // oiseaux
      pen.SetWidth(1.8 * F);
      pen.SetColor(GP(230, 224, 205, 220));
      G.DrawArc(pen, X + 108 * F, Y + 34 * F, 16 * F, 8 * F, 200, 140);
      G.DrawArc(pen, X + 128 * F, Y + 26 * F, 14 * F, 7 * F, 200, 140);
      G.DrawArc(pen, X + 144 * F, Y + 40 * F, 12 * F, 6 * F, 200, 140);
    finally
      bHalo.Free; bSun.Free; bOmbre.Free; bOcean.Free; bIle.Free;
      bRock.Free; bSnow.Free; bSand.Free; bSapi.Free; pen.Free;
    end;
  finally
    G.Free;
  end;
end;

procedure SaveLogoPNG(const FileName: string; Size: Integer);
var Bmp: TBitmap;
    Png: TPngImage;
    Begin
  Bmp := TBitmap.Create;
  try
    Bmp.PixelFormat := pf32bit;
    Bmp.SetSize(Size, Size);
    DrawLogo(Bmp.Canvas, 0, 0, Size);
    Png := TPngImage.Create;
    try
      Png.Assign(Bmp);
      Png.SaveToFile(FileName);
    finally
      Png.Free;
    end;
  finally
    Bmp.Free;
  end;
end;

end.

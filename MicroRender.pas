                   unit MicroRender;

{ Microcosme — rendu terrain interpolé (îlots), poissons, pirogues,
  huttes (feu, réserves, champs), maisons de pierre (ère 2+), fanion,
  colonne (Antiquité), donjon (Moyen Âge), façades peintes (Renaissance),
  carte mentale, liens mentors, bulles vocales, carnet à largeur variable
  i18n (F8 FR/EN), Observatoire F7 (cerveau géant, clic = sapiens suivant). }

interface

uses
  System.SysUtils, System.Classes, System.Math, System.Generics.Collections,
  Winapi.Windows, Vcl.Graphics, System.Types, System.UITypes, System.SyncObjs,
  MicroTypes, MicroBrain, MicroConfig, MicroEvo, MicroIno, MicroChrono,Microvilles;

const
  BID_BRAIN = 202;
  BID_Info = 203;
  BID_G3D = 204;
  BID_RELIEF = 205;
  BID_CHRON = 206;

procedure RenderTerrainBmp;
procedure RenderWorld;
procedure DrawBrain(C: TCanvas; Y: Integer);
procedure DrawLine(C: TCanvas; const R: TRect; MaxV, Kind: Integer);
procedure DrawPanel(C: TCanvas; H: Integer);
procedure AddBtn(const R: TRect; const Cap: string; Id: Integer; Active: Boolean);
procedure DrawBrainBig(C: TCanvas; W, H: Integer);
procedure DrawObservatoire(C: TCanvas; W, H: Integer);
procedure SetRelief(AOn: Boolean);
function ReliefOn: Boolean;
function SaisonFroid: Single;

implementation

uses MicroSim, MicroRenderPro, MicroHelp, MicroEre, MicroLang;

{$OVERFLOWCHECKS OFF}
{$RANGECHECKS OFF}
{$POINTERMATH ON}

var
  FRelief: Boolean = True;

procedure SetRelief(AOn: Boolean);
begin
  if FRelief <> AOn then begin
    FRelief := AOn;
    RenderTerrainBmp;
  end;
end;

function ReliefOn: Boolean;
begin
  Result := FRelief;
end;

// <<< SAISONS : 1 an = JOURS_ANNEE jours · 4 saisons · hiver bleuté, été doré
const
  JOURS_ANNEE = 24;
  SAISNOM: array[0..3] of string = ('printemps','été','automne','hiver');

function SaisonFroid: Single;      // 0 = plein été · 1 = plein hiver
begin
  Result := (1 - Cos(TAU * (Frac(DayCount / JOURS_ANNEE) - 0.25))) / 2;
end;

procedure RenderTerrainBmp;
const
  SS = 8;
var
  PX, PY, W, H, GX, GY, X0, X1, Y0, Y1, I, T: Integer;
  FX, FY, Ev, Hu, M, L, PrevE, Slope, DXr, DYr: Single;
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
      if FRelief and (X0 > 0) and (X0 < GW - 1) and (Y0 > 0) and (Y0 < GH - 1) then begin
        DXr := (Elev[Y0 * GW + X0 + 1] - Elev[Y0 * GW + X0 - 1]) * 14;
        DYr := (Elev[(Y0 + 1) * GW + X0] - Elev[(Y0 - 1) * GW + X0]) * 14;
        M := L * ClampF(1 - DXr - DYr + 0.15, 0.55, 1.5);
      end else
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

procedure AlphaFill(C: TCanvas; W, H: Integer; Tint: TBitmap; Clr: TColor; A: Byte);
var BF: TBlendFunction;
begin
  if Tint.PixelFormat <> pf32bit then
    Tint.PixelFormat := pf32bit;
  if (Tint.Width <> W) or (Tint.Height <> H) then
    Tint.SetSize(W, H);
  Tint.Canvas.Brush.Style := bsSolid;
  Tint.Canvas.Brush.Color := Clr;
  Tint.Canvas.FillRect(Rect(0, 0, W, H));
  BF.BlendOp := AC_SRC_OVER; BF.BlendFlags := 0;
  BF.SourceConstantAlpha := A; BF.AlphaFormat := 0;
  AlphaBlend(C.Handle, 0, 0, W, H, Tint.Canvas.Handle, 0, 0, W, H, BF);
end;

procedure RenderWorld;
{ ★FIX5 : le rendu des villes était dupliqué inline (6e collage fantôme,
  avec dérive Niveau>=6 vs EreCourante>=6 — facades Renaissance mortes)
  et DrawRoads n'était JAMAIS appelé (routes invisibles).
  Désormais : délégation à MicroVilles (source unique) :
    terrain → routes → huttes isolées → villes → camp → poissons →
    flore → faune → sélection → teintes. }
var S, OX, OY, VX0, VY0, VX1, VY1: Double;
   W, H, PX, PY, RR, RR2, K, I, MO, MK, Flags: Integer;
   P: TPlant; C: TCreature;
   R, HR, HeadX, HeadY, Grow, CA, SA, SinD, Warm, A, Froid, Phase: Single;
   HHut: THut;
   FF: TFish;
   CA2, SA2: Single;
   MXp, MYp: Integer;
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

    // ===== ROUTES — ★FIX5 : enfin dessinées (sous tout le bâti) =====
    DrawRoads(FWorld.Canvas, OX, OY, S, VX0, VY0, VX1, VY1);

    // ===== HUTTES ISOLÉES (les foyers des villes sont dessinés par DrawVilles) =====
    for I := 0 to Huts.Count - 1 do begin
      HHut := Huts[I];
      if not InV(HHut.X, HHut.Y, 10) then Continue;
        if HHut.Ville <> nil then begin
        // ★Exode — dans la couronne dense (< 4.5 cases) : la ville dessine
        // en stylisé ; au-delà (banlieue, 8-20 cases) : vraie maison dessinée
        // ci-dessous avec tout le décor existant (feu, fumée, fanion…)
        if Sqr(HHut.X - HHut.Ville.X) + Sqr(HHut.Y - HHut.Ville.Y) < Sqr(4.5) then
          Continue;
      end;
      PX := Trunc(OX + HHut.X * S); PY := Trunc(OY + HHut.Y * S);
      if HHut.Cult then begin
        Brush.Style := bsSolid; Pen.Style := psClear;
        RR := Trunc(S * 9);
        Brush.Color := AlphaColorBlend(Col(157,187,107), Col(11,14,11), 14);
        Ellipse(PX - RR, PY - RR, PX + RR, PY + RR);
      end;
      if HHut.Fire then begin
        Brush.Style := bsSolid; Pen.Style := psClear;
        RR := Trunc(S * 6.5);
        if FDayLight < 0.5 then
          Brush.Color := AlphaColorBlend(Col(255,165,70), Col(11,14,11), 140)
        else
          Brush.Color := AlphaColorBlend(Col(255,165,70), Col(11,14,11), 45);
        Ellipse(PX - RR, PY - RR, PX + RR, PY + RR);
        RR := Max(2, Trunc(S * 0.55));
        Brush.Color := Col(240, 180, 95);
        Ellipse(PX - RR, PY - RR * 2, PX + RR, PY + RR);
        Brush.Color := Col(232, 133, 59);
        RR := RR * 55 div 100;
        Ellipse(PX - RR, PY - RR, PX + RR, PY + RR);
      end;
      if HHut.Stock > 1 then begin
        Pen.Style := psSolid; Pen.Width := 2;
        Pen.Color := Col(240, 180, 95);
        Brush.Style := bsClear;
        RR := Trunc(S * 2);
        Arc(PX - RR, PY - RR, PX + RR, PY + RR,
            PX, PY - RR,
            PX + Trunc(RR * Sin(HHut.Stock / 240 * TAU)),
            PY - Trunc(RR * Cos(HHut.Stock / 240 * TAU)));
      end;
      // ★ERE5 — corps : maison de pierre (ère 2+), hutte ronde en ère 1
      if FEra >= 2 then begin
        RR := Max(3, Trunc(S * 1.4));
        Brush.Style := bsSolid;
        Pen.Style := psSolid;
        Pen.Color := Col(44, 42, 40);
        Pen.Width := 1;
        if FEra >= 3 then Brush.Color := Col(150, 148, 140)
        else Brush.Color := Col(123, 117, 108);
        if FEra >= 6 then begin
          // 1c-ter — la Renaissance peint ses façades
          case (Trunc(HHut.X) * 7 + Trunc(HHut.Y) * 13) mod 4 of
            0: Brush.Color := Col(198, 168, 130);   // ocre
            1: Brush.Color := Col(172, 178, 150);   // sauge
            2: Brush.Color := Col(186, 152, 148);   // rose de Sienne
          else Brush.Color := Col(158, 170, 182);   // azur pâle
          end;
        end;
        Rectangle(PX - RR, PY - RR div 2, PX + RR, PY + RR);
        Brush.Color := Col(164, 90, 68);                        // toit tuile
        Poly[0] := Point(PX - RR - 1, PY - RR div 2);
        Poly[1] := Point(PX + RR + 1, PY - RR div 2);
        Poly[2] := Point(PX, PY - RR - Max(2, RR div 2));
        Polygon(Poly);
        if HHut.Fire then begin                                 // fanion doré
          Pen.Color := Col(70, 62, 50);
          MoveTo(PX, PY - RR - Max(2, RR div 2));
          LineTo(PX, PY - RR * 2 - Max(2, RR));
          Brush.Color := Col(208, 167, 92);
          Poly[0] := Point(PX, PY - RR * 2 - Max(2, RR));
          Poly[1] := Point(PX + Max(3, RR),
                           PY - RR * 2 - Max(2, RR) + Max(2, RR div 2));
          Poly[2] := Point(PX, PY - RR * 2 - Max(2, RR) + Max(3, RR));
          Polygon(Poly);
        end;
        // 1c/1c-bis — colonne (Antiquité), donjon (Moyen Âge)
        if (FEra >= 4) and HHut.Fire and PeopleHas(teCite) then begin
          Brush.Style := bsSolid;
          Pen.Style := psSolid;
          Pen.Color := Col(226, 220, 205);
          Pen.Width := 1;
          RR2 := Max(2, Trunc(S * 0.35));
          if FEra >= 5 then begin
            Brush.Color := Col(118, 116, 110);                  // donjon
            Rectangle(PX - RR2 - 1, PY - RR * 4, PX + RR2 + 1, PY - RR * 2);
            Rectangle(PX - RR2 - 1, PY - RR * 4 - 2, PX - RR2 + 1, PY - RR * 4);
            Rectangle(PX - 1, PY - RR * 4 - 2, PX + 1, PY - RR * 4);
            Rectangle(PX + RR2 - 1, PY - RR * 4 - 2, PX + RR2 + 1, PY - RR * 4);
          end else begin
            Rectangle(PX - RR2, PY - RR * 3, PX + RR2, PY - RR * 2);   // colonne
            Rectangle(PX - RR2 - 1, PY - RR * 3 - 1, PX + RR2 + 1, PY - RR * 3);
            Rectangle(PX - RR2 - 1, PY - RR * 2, PX + RR2 + 1, PY - RR * 2 + 1);
          end;
        end;
      end else begin
        Brush.Style := bsSolid;
        Pen.Style := psSolid;
        Pen.Color := Col(46, 37, 23);
        Pen.Width := 1;
        RR := Max(3, Trunc(S * 1.4));
        Ellipse(PX - RR, PY - RR, PX + RR, PY + RR);
        Brush.Color := Col(138, 109, 66);
        RR := RR * 55 div 100;
        Ellipse(PX - RR, PY - RR, PX + RR, PY + RR);
      end;

      // tablettes écrites
      for MK := 0 to Marks.Count - 1 do
        if Sqr(Marks[MK].X - HHut.X) + Sqr(Marks[MK].Y - HHut.Y) < 9 then begin
          MXp := Trunc(OX + Marks[MK].X * S);
          MYp := Trunc(OY + Marks[MK].Y * S);
          Pen.Style := psSolid; Pen.Width := 1;
          Pen.Color := Col(235, 232, 215);
          Brush.Style := bsClear;
          MoveTo(MXp - 2, MYp); LineTo(MXp + 2, MYp);
          MoveTo(MXp, MYp - 2); LineTo(MXp, MYp + 2);
        end;
    end; // fin boucle HUTTES

    // ===== ★VILLES — délégué à MicroVilles (source unique du rendu) =====
    DrawVilles(FWorld.Canvas, OX, OY, S, VX0, VY0, VX1, VY1);

    // ===== CAMP ANCESTRAL =====
    if FHomeSet and (Huts.Count = 0) then begin
      PX := Trunc(OX + FHomeX * S); PY := Trunc(OY + FHomeY * S);
      Brush.Style := bsClear;
      Pen.Style := psDot; Pen.Width := 1; Pen.Color := Col(120, 130, 100);
      RR := Trunc(S * 3);
      Ellipse(PX - RR, PY - RR, PX + RR, PY + RR);
      Pen.Style := psSolid;
    end;

    // ===== POISSONS =====
    Brush.Style := bsSolid;
    Pen.Style := psClear;
    for I := 0 to Fishes.Count - 1 do begin
      FF := Fishes[I];
      if not InV(FF.X, FF.Y, 2) then Continue;
      PX := Trunc(OX + FF.X * S); PY := Trunc(OY + FF.Y * S);
      RR := Max(2, Trunc(S * (0.28 + 0.2 * FF.S)));
      if FF.Deep then Brush.Color := Col(127, 166, 181)
      else Brush.Color := Col(188, 216, 210);
      CA2 := Cos(FF.Angle); SA2 := Sin(FF.Angle);
      Polygon([Point(PX + Trunc(CA2 * RR), PY + Trunc(SA2 * RR)),
               Point(PX - Trunc(CA2 * RR * 0.8 - SA2 * RR * 0.5),
                     PY - Trunc(SA2 * RR * 0.8 + CA2 * RR * 0.5)),
               Point(PX - Trunc(CA2 * RR * 0.8 + SA2 * RR * 0.5),
                     PY - Trunc(SA2 * RR * 0.8 - CA2 * RR * 0.5))]);
      Pen.Style := psSolid; Pen.Width := 1;
      Pen.Color := Brush.Color;
      MoveTo(PX - Trunc(CA2 * RR * 0.8), PY - Trunc(SA2 * RR * 0.8));
      LineTo(PX - Trunc(CA2 * RR * 1.4), PY - Trunc(SA2 * RR * 1.4) + Trunc(RR * 0.4));
      LineTo(PX - Trunc(CA2 * RR * 1.4), PY - Trunc(SA2 * RR * 1.4) - Trunc(RR * 0.4));
      LineTo(PX - Trunc(CA2 * RR * 0.8), PY - Trunc(SA2 * RR * 0.8));
    end;

    // ===== FLORE =====
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

    // ===== FAUNE =====
    for C in Creatures do begin
      if not C.Alive then Continue;
      if not InV(C.X, C.Y, 3) then Continue;
      PX := Trunc(OX + C.X * S); PY := Trunc(OY + C.Y * S);
      Grow := 0.55 + 0.45 * Min(1, C.Age / 8);
      R := S * (0.55 + 0.55 * C.Sz) * Grow;
      CA := Cos(C.Angle); SA := Sin(C.Angle);

      if (C.State = L(57)) or (C.State = L(53)) or (C.State = L(54)) or
         (C.State = L(51)) or (C.State = L(55)) then
        Phase := 0
      else
        Phase := FSimTime * 11 + C.CId * 0.7;
      Flags := 0;
      if C.State = L(72) then Flags := PR_HUNT;                // ★i18n 'chasse'/'hunting'

      if C.Kind = 2 then begin
        // — en mer : pirogue —
        if IsWater(C.X, C.Y) then begin
          Brush.Style := bsSolid;
          Pen.Style := psSolid;
          Pen.Color := Col(46, 37, 23);
          Pen.Width := 1;
          Brush.Color := Col(93, 74, 48);
          Ellipse(PX - Trunc(R * 1.7), PY - Trunc(R * 0.62),
                  PX + Trunc(R * 1.7), PY + Trunc(R * 0.62));
          Brush.Color := Col(138, 109, 66);
          Ellipse(PX - Trunc(R * 1.15), PY - Trunc(R * 0.36),
                  PX + Trunc(R * 1.15), PY + Trunc(R * 0.36));
          if (C.WordT > 0) and (C.Word >= 0) and (C.Word <= 3) then begin
            RR := Max(5, Trunc(S * 1.0));
            PY := PY - Trunc(R + 10);
            Brush.Style := bsSolid;
            Brush.Color := Col(14, 17, 12);
            Ellipse(PX - RR, PY - RR, PX + RR, PY + RR);
            Brush.Style := bsClear;
            Pen.Color := WORDCOL[C.Word];
            Ellipse(PX - RR, PY - RR, PX + RR, PY + RR);
            Font.Name := 'Segoe UI'; Font.Size := Max(7, Trunc(S * 1.1));
            Font.Color := WORDCOL[C.Word];
            TextOut(PX - TextWidth(WORDS[C.Word]) div 2, PY - 6, WORDS[C.Word]);
          end;
          Continue;
        end;
        // — CARTE MENTALE —
        if (FSelected = C) and (Length(C.Mem) > 0) then begin
          for MO := 0 to High(C.Mem) do begin
            A := 1 - C.Mem[MO].T / 70;
            if A <= 0 then Continue;
            MXp := Trunc(OX + C.Mem[MO].X * S);
            MYp := Trunc(OY + C.Mem[MO].Y * S);
            Pen.Style := psSolid;
            Pen.Width := 1;
            if C.Mem[MO].K = 0 then begin
              Pen.Color := AlphaColorBlend(Col(201,106,69), Col(11,14,11), Trunc(A*255));
              RR := Max(3, Trunc(S * 0.7));
              MoveTo(MXp - RR, MYp - RR); LineTo(MXp + RR, MYp + RR);
              MoveTo(MXp + RR, MYp - RR); LineTo(MXp - RR, MYp + RR);
            end else begin
              Pen.Color := AlphaColorBlend(Col(157,187,107), Col(11,14,11), Trunc(A*255));
              RR := Max(3, Trunc(S * 0.7));
              Brush.Style := bsClear;
              Ellipse(MXp - RR, MYp - RR, MXp + RR, MYp + RR);
            end;
          end;
        end;
        // — LIEN MENTOR —
        if (C.Age < CHILDHOOD) and (C.Mentor <> nil) and (C.Mentor.Alive) then begin
          Pen.Style := psDash;
          Pen.Width := 1;
          if FSelected = C then
            Pen.Color := Col(208,167,92)
          else
            Pen.Color := AlphaColorBlend(Col(208,167,92), Col(11,14,11), 60);
          MoveTo(PX, PY);
          LineTo(Trunc(OX + C.Mentor.X * S), Trunc(OY + C.Mentor.Y * S));
          Pen.Style := psSolid;
        end;
        // — corps détaillé —
        ProRender(FWorld.Canvas, 2, PX, PY, C.Angle, R,
                  Col(211, 172, 138), C.HueCol, Phase, Flags);
        // — plume —
        HR := R * (0.5 + 1.7 * C.Orn);
        if HR > 2 then begin
          Pen.Style := psSolid;
          Pen.Color := C.HueCol;
          Pen.Width := Max(1, Trunc(S * 0.13));
          for K := -1 to 1 do begin
            MoveTo(PX, PY - Trunc(R * 0.5));
            LineTo(PX + K * Trunc(R * 0.85),
                   PY - Trunc(R * 0.5) - Trunc(HR));
          end;
        end;
        // — bulle vocale —
        if (C.WordT > 0) and (C.Word >= 0) and (C.Word <= 3) then begin
          RR := Max(5, Trunc(S * 1.0));
          PY := PY - Trunc(R + HR + 6);
          Brush.Style := bsSolid;
          Brush.Color := Col(14, 17, 12);
          Ellipse(PX - RR, PY - RR, PX + RR, PY + RR);
          Brush.Style := bsClear;
          Pen.Color := WORDCOL[C.Word];
          Pen.Width := 1;
          Ellipse(PX - RR, PY - RR, PX + RR, PY + RR);
          Font.Name := 'Segoe UI';
          Font.Size := Max(7, Trunc(S * 1.1));
          Font.Color := WORDCOL[C.Word];
          TextOut(PX - TextWidth(WORDS[C.Word]) div 2, PY - 6, WORDS[C.Word]);
          PY := Trunc(OY + C.Y * S);
        end;
      end else if C.Kind = 0 then begin
        ProRender(FWorld.Canvas, 0, PX, PY, C.Angle, R,
                  Col(228, 222, 206), Col(150, 140, 120), Phase, Flags);
        if C.Dom then begin
          Pen.Style := psSolid; Pen.Width := 1;
          Pen.Color := Col(240, 180, 95);
          Brush.Style := bsClear;
          RR := Trunc(R * 0.8) + 2;
          Ellipse(PX - RR, PY - RR, PX + RR, PY + RR);
          if (C.MilkCd <= 0) and (C.Age > 8) then begin
            Brush.Style := bsSolid;
            Brush.Color := Col(245, 234, 208);
            Ellipse(PX - 2, PY - RR - 6, PX + 2, PY - RR - 3);
          end;
        end else if C.Trust > 0 then begin
          Pen.Style := psSolid; Pen.Width := 1;
          Pen.Color := AlphaColorBlend(Col(240,180,95), Col(11,14,11),
                       Trunc(60 + 160 * Min(1, C.Trust)));
          Brush.Style := bsClear;
          RR := Trunc(R * 0.8) + 2;
          Ellipse(PX - RR, PY - RR, PX + RR, PY + RR);
        end;
      end else if C.Kind = 1 then begin
        ProRender(FWorld.Canvas, 1, PX, PY, C.Angle, R,
                  Col(194, 106, 69), Col(230, 220, 200), Phase, Flags);
        if C.Trust > 0 then begin
          Pen.Style := psSolid; Pen.Width := 1;
          Pen.Color := AlphaColorBlend(Col(240,180,95), Col(11,14,11),
                       Trunc(60 + 160 * Min(1, C.Trust)));
          Brush.Style := bsClear;
          RR := Trunc(R * 1.1) + 2;
          Ellipse(PX - RR, PY - RR, PX + RR, PY + RR);
          Pen.Style := psSolid;
        end;
      end else begin
        ProRender(FWorld.Canvas, 3, PX, PY, C.Angle, R,
                  Col(206, 168, 104), Col(90, 60, 40), Phase, Flags);
        if (C.Master <> nil) and C.Master.Alive then begin
          Pen.Style := psDot;
          Pen.Color := AlphaColorBlend(Col(208,167,92), Col(11,14,11), 110);
          MoveTo(PX, PY);
          LineTo(Trunc(OX + C.Master.X * S), Trunc(OY + C.Master.Y * S));
          Pen.Style := psSolid;
        end;
      end;
    end;
    ProFlush;

    // ===== SÉLECTION =====
    if (FSelected <> nil) and FSelected.Alive then begin
      PX := Trunc(OX + FSelected.X * S); PY := Trunc(OY + FSelected.Y * S);
      R := S * (0.55 + 0.55 * FSelected.Sz) * (0.55 + 0.45 * Min(1, FSelected.Age / 8));
      Brush.Style := bsClear;
      Pen.Style := psDot; Pen.Width := 1; Pen.Color := Col(240, 232, 205);
      RR := Trunc(R + 5); if RR < 3 then RR := 3;
      Ellipse(PX - RR, PY - RR, PX + RR, PY + RR);
      Brush.Style := bsClear;
      Pen.Style := psSolid; Pen.Width := 1; Pen.Color := Col(90, 96, 80);
      RR := Trunc(FSelected.Se * S);
      if RR > 2 then Ellipse(PX - RR, PY - RR, PX + RR, PY + RR);
    end;

    if FDayLight < 0.98 then
      AlphaFill(FWorld.Canvas, W, H, FTintN, Col(7, 12, 16), Trunc((1 - FDayLight) * 105));
    SinD := Sin(FDayT * TAU);
    Warm := Max(0, 1 - Abs(SinD) * 2.5);
    if Warm > 0 then
      AlphaFill(FWorld.Canvas, W, H, FTintW, Col(255, 150, 70), Trunc(Warm * 15));
    Froid := SaisonFroid;
    if Froid > 0.03 then
      AlphaFill(FWorld.Canvas, W, H, FTintN, Col(148, 172, 205), Trunc(Froid * 38));
    if Froid < 0.97 then
      AlphaFill(FWorld.Canvas, W, H, FTintW, Col(255, 205, 90), Trunc((1 - Froid) * 14));
  end;
end;
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
var I, X, Yv, Den: Integer; Clr: TColor;
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
  Den := Max(1, High(FHist));
  for I := 0 to High(FHist) do begin
    X := R.Left + Trunc(I / Den * (R.Right - R.Left - 1));
    Yv := R.Bottom - 2 - Trunc(Val(FHist[I]) / MaxV * (R.Bottom - R.Top - 4));
    if I = 0 then C.MoveTo(X, Yv) else C.LineTo(X, Yv);
  end;
end;

procedure DrawBrain(C: TCanvas; Y: Integer);
const
  INLBL: array[0..33] of string = ('biais','énergie','lumière',
    'nour.x','nour.y','nour.d','pair.x','pair.y','pair.d',
    'préd.x','préd.y','préd.d','α','β','γ','δ','src.x','src.y',
    'm.dan.x','m.dan.y','m.dan.d','m.nou.x','m.nou.y','m.nou.d',
    'r.tour','r.vit','r.bât','r.rep','r.cha','r.α','r.β','r.γ','r.δ',
    'biais2');
  OUTLBL: array[0..9] of string = ('tourner','vitesse','BÂTIR','reprod','chasse',
    'α','β','γ','δ','REPOS');
var
  I, J, K, O: Integer;
  XIn, XH1, XH2, XOut, W: Integer;
  Wv, A: Single;
  function YI(Idx: Integer): Integer;
  begin Result := Y + 6 + Round(Idx * (BRH - 12) / (NIN - 1)) end;
  function YH(Idx: Integer): Integer;
  begin Result := Y + BRH div 2 + Round((Idx - (NHID - 1) / 2) * ((BRH - 20) / (NHID - 1))) end;
  function YO(Idx: Integer): Integer;
  begin Result := Y + BRH div 2 + Round((Idx - (NOUT - 1) / 2) * ((BRH - 70) / (NOUT - 1))) end;
begin
  W := FPanelW - 40;
  XIn := 56; XH1 := 116; XH2 := 180; XOut := 244;
  C.Brush.Style := bsSolid;
  C.Brush.Color := Col(17, 21, 15);
  C.Pen.Style := psClear;
  C.FillRect(Rect(20, Y, 20 + W, Y + BRH));
  for I := 0 to NIN - 1 do
    for J := 0 to NHID - 1 do begin
      Wv := FSelected.Net[I * NHID + J];
      if Abs(Wv) < 0.5 then Continue;
      A := Min(0.8, Abs(Wv) * Abs(FSelected.Inp[I]) * 0.55);
      if A < 0.05 then Continue;
      C.Pen.Style := psSolid; C.Pen.Width := 1;
      if Wv > 0 then
        C.Pen.Color := AlphaColorBlend(Col(157,187,107), Col(17,21,15), Trunc(A*255))
      else
        C.Pen.Color := AlphaColorBlend(Col(201,106,69), Col(17,21,15), Trunc(A*255));
      C.MoveTo(XIn, YI(I)); C.LineTo(XH1, YH(J));
    end;
  for J := 0 to NHID - 1 do
    for K := 0 to NHID2 - 1 do begin
      Wv := FSelected.Net[IDX_H2 + J * NHID2 + K];
      if Abs(Wv) < 0.5 then Continue;
      A := Min(0.8, Abs(Wv) * Abs(FSelected.Hid[J]) * 0.55);
      if A < 0.05 then Continue;
      C.Pen.Style := psSolid; C.Pen.Width := 1;
      if Wv > 0 then
        C.Pen.Color := AlphaColorBlend(Col(157,187,107), Col(17,21,15), Trunc(A*255))
      else
        C.Pen.Color := AlphaColorBlend(Col(201,106,69), Col(17,21,15), Trunc(A*255));
      C.MoveTo(XH1, YH(J)); C.LineTo(XH2, YH(K));
    end;
  for K := 0 to NHID2 - 1 do
    for O := 0 to NOUT - 1 do begin
      Wv := FSelected.Net[IDX_HO + K * NOUT + O];
      if Abs(Wv) < 0.5 then Continue;
      A := Min(0.8, Abs(Wv) * Abs(FSelected.Hid2[K]) * 0.55);
      if A < 0.05 then Continue;
      C.Pen.Style := psSolid; C.Pen.Width := 1;
      if Wv > 0 then
        C.Pen.Color := AlphaColorBlend(Col(157,187,107), Col(17,21,15), Trunc(A*255))
      else
        C.Pen.Color := AlphaColorBlend(Col(201,106,69), Col(17,21,15), Trunc(A*255));
      C.MoveTo(XH2, YH(K)); C.LineTo(XOut, YO(O));
    end;
  for I := 0 to NIN - 1 do
    for O := 0 to NOUT - 1 do begin
      Wv := FSelected.Net[IDX_SO + I * NOUT + O];
      if Abs(Wv) < 0.6 then Continue;
      A := Min(0.75, Abs(Wv) * Abs(FSelected.Inp[I]) * 0.4);
      if A < 0.05 then Continue;
      C.Pen.Style := psDash;
      C.Pen.Color := AlphaColorBlend(Col(120,130,100), Col(17,21,15), Trunc(A*255));
      C.MoveTo(XIn, YI(I)); C.LineTo(XOut, YO(O));
      C.Pen.Style := psSolid;
    end;
  C.Font.Name := 'Segoe UI'; C.Font.Size := 6; C.Font.Style := [];
  for I := 0 to NIN - 1 do begin
    A := Min(1, Abs(FSelected.Inp[I]));
    C.Pen.Style := psSolid;
    C.Pen.Color := Col(80, 86, 72); C.Pen.Width := 1;
    C.Brush.Style := bsSolid;
    if FSelected.Inp[I] >= 0 then
      C.Brush.Color := AlphaColorBlend(Col(208,167,92), Col(30,34,27), Trunc((0.15+0.85*A)*255))
    else
      C.Brush.Color := Col(60, 58, 50);
    C.Ellipse(XIn - 3, YI(I) - 3, XIn + 3, YI(I) + 3);
    C.Brush.Style := bsClear;
    if (I >= 12) and (I <= 15) and (FSelected.Inp[I] > 0.05) then
      C.Font.Color := WORDCOL[I - 12]
    else if (I >= 18) and (I <= 20) and (FSelected.Inp[I] > 0.05) then
      C.Font.Color := Col(201, 106, 69)
    else if (I >= 21) and (I <= 23) and (FSelected.Inp[I] > 0.05) then
      C.Font.Color := Col(157, 187, 107)
    else
      C.Font.Color := Col(139, 138, 116);
    C.TextOut(4, YI(I) - 4, INLBL[I]);
  end;
  for J := 0 to NHID - 1 do begin
    A := Min(1, Abs(FSelected.Hid[J]));
    C.Pen.Style := psSolid;
    C.Pen.Color := Col(80, 86, 72);
    C.Brush.Style := bsSolid;
    C.Brush.Color := AlphaColorBlend(Col(208,167,92), Col(30,34,27), Trunc((0.15+0.85*A)*255));
    C.Ellipse(XH1 - 3, YH(J) - 3, XH1 + 3, YH(J) + 3);
  end;
  for K := 0 to NHID2 - 1 do begin
    A := Min(1, Abs(FSelected.Hid2[K]));
    C.Pen.Style := psSolid;
    C.Pen.Color := Col(80, 86, 72);
    C.Brush.Style := bsSolid;
    C.Brush.Color := AlphaColorBlend(Col(208,167,92), Col(30,34,27), Trunc((0.15+0.85*A)*255));
    C.Ellipse(XH2 - 3, YH(K) - 3, XH2 + 3, YH(K) + 3);
  end;
  for O := 0 to NOUT - 1 do begin
    A := Min(1, Abs(FSelected.Oo[O]));
    C.Pen.Style := psSolid;
    C.Pen.Color := Col(80, 86, 72);
    C.Brush.Style := bsSolid;
    if FSelected.Oo[O] >= 0 then
      C.Brush.Color := AlphaColorBlend(Col(208,167,92), Col(30,34,27), Trunc((0.15+0.85*A)*255))
    else
      C.Brush.Color := Col(60, 58, 50);
    C.Ellipse(XOut - 4, YO(O) - 4, XOut + 4, YO(O) + 4);
    C.Brush.Style := bsClear;
    if (O >= 5) and (FSelected.Oo[O] > 0.25) then
      C.Font.Color := WORDCOL[O - 5]
    else
      C.Font.Color := Col(139, 138, 116);
    C.TextOut(XOut + 8, YO(O) - 4, OUTLBL[O]);
  end;
  C.Font.Size := 7;
  C.Font.Color := Col(100, 105, 88);
  C.TextOut(20, Y + BRH + 2, 'RÉSEAU NEURONAL · 34 → 9 → 9 → 10 · PENSÉE, MÉMOIRE & LANGAGE');
end;

procedure DrawBrainBig(C: TCanvas; W, H: Integer);
const
  INLBL: array[0..33] of string = ('biais','énergie','lumière',
    'nour.x','nour.y','nour.d','pair.x','pair.y','pair.d',
    'préd.x','préd.y','préd.d','α','β','γ','δ','src.x','src.y',
    'm.dan.x','m.dan.y','m.dan.d','m.nou.x','m.nou.y','m.nou.d',
    'r.tour','r.vit','r.bât','r.rep','r.cha','r.α','r.β','r.γ','r.δ',
    'biais2');
  OUTLBL: array[0..9] of string = ('tourner','vitesse','BÂTIR','reprod','chasse',
    'α','β','γ','δ','REPOS');
var
  I, J, K, O, XIn, XH1, XH2, XOut, Y1, Y2: Integer;
  Wv, A: Single;

  function NY(Idx, N, Top, Bot: Integer): Integer;
  begin
    Result := Top + Round((Idx + 0.5) * (Bot - Top) / N);
  end;

begin
  C.Brush.Style := bsSolid;
  C.Brush.Color := Col(17, 21, 15);
  C.Pen.Style := psClear;
  C.FillRect(Rect(0, 0, W, H));
  if (FSelected = nil) or (FSelected.Kind <> 2) or (Length(FSelected.Net) < NW) then begin
    C.Font.Name := 'Segoe UI'; C.Font.Size := 11; C.Font.Style := [];
    C.Brush.Style := bsClear;
    C.Font.Color := Col(139, 138, 116);
    C.TextOut(24, 24, L(73));      // ★i18n 'Aucun sapien sélectionné.'
    C.TextOut(24, 46, L(74));      // ★i18n
    C.TextOut(24, 66, L(75));      // ★i18n
    Exit;
  end;
  XIn := 158; XOut := W - 158;
  // ★F7 : les 2 couches cachées coupent l'espace en 3 intervalles égaux
  XH1 := XIn + (XOut - XIn) div 3;
  XH2 := XIn + 2 * (XOut - XIn) div 3;

  for I := 0 to NIN - 1 do
    for J := 0 to NHID - 1 do begin
      Wv := FSelected.Net[I * NHID + J];
      if Abs(Wv) < 0.35 then Continue;
      A := Min(0.85, Abs(Wv) * Abs(FSelected.Inp[I]) * 0.55);
      if A < 0.04 then Continue;
      C.Pen.Style := psSolid; C.Pen.Width := 1;
      if Wv > 0 then
        C.Pen.Color := AlphaColorBlend(Col(157,187,107), Col(17,21,15), Trunc(A*255))
      else
        C.Pen.Color := AlphaColorBlend(Col(201,106,69), Col(17,21,15), Trunc(A*255));
      Y1 := NY(I, NIN, 20, H - 56);
      Y2 := NY(J, NHID, 56, H - 96);
      C.MoveTo(XIn, Y1); C.LineTo(XH1, Y2);
    end;

  for J := 0 to NHID - 1 do
    for K := 0 to NHID2 - 1 do begin
      Wv := FSelected.Net[IDX_H2 + J * NHID2 + K];
      if Abs(Wv) < 0.35 then Continue;
      A := Min(0.85, Abs(Wv) * Abs(FSelected.Hid[J]) * 0.55);
      if A < 0.04 then Continue;
      C.Pen.Style := psSolid; C.Pen.Width := 1;
      if Wv > 0 then
        C.Pen.Color := AlphaColorBlend(Col(157,187,107), Col(17,21,15), Trunc(A*255))
      else
        C.Pen.Color := AlphaColorBlend(Col(201,106,69), Col(17,21,15), Trunc(A*255));
      Y1 := NY(J, NHID, 56, H - 96);
      Y2 := NY(K, NHID2, 56, H - 96);
      C.MoveTo(XH1, Y1); C.LineTo(XH2, Y2);
    end;

  for K := 0 to NHID2 - 1 do
    for O := 0 to NOUT - 1 do begin
      Wv := FSelected.Net[IDX_HO + K * NOUT + O];
      if Abs(Wv) < 0.35 then Continue;
      A := Min(0.85, Abs(Wv) * Abs(FSelected.Hid2[K]) * 0.55);
      if A < 0.04 then Continue;
      C.Pen.Style := psSolid; C.Pen.Width := 1;
      if Wv > 0 then
        C.Pen.Color := AlphaColorBlend(Col(157,187,107), Col(17,21,15), Trunc(A*255))
      else
        C.Pen.Color := AlphaColorBlend(Col(201,106,69), Col(17,21,15), Trunc(A*255));
      Y1 := NY(K, NHID2, 56, H - 96);
      Y2 := NY(O, NOUT, 20, H - 56);
      C.MoveTo(XH2, Y1); C.LineTo(XOut, Y2);
    end;

  for I := 0 to NIN - 1 do
    for O := 0 to NOUT - 1 do begin
      Wv := FSelected.Net[IDX_SO + I * NOUT + O];
      if Abs(Wv) < 0.5 then Continue;
      A := Min(0.7, Abs(Wv) * Abs(FSelected.Inp[I]) * 0.4);
      if A < 0.05 then Continue;
      C.Pen.Style := psDash;
      C.Pen.Color := AlphaColorBlend(Col(120,130,100), Col(17,21,15), Trunc(A*255));
      C.MoveTo(XIn, NY(I, NIN, 20, H - 56));
      C.LineTo(XOut, NY(O, NOUT, 20, H - 56));
      C.Pen.Style := psSolid;
    end;

  C.Font.Name := 'Segoe UI'; C.Font.Size := 8; C.Font.Style := [];
  for I := 0 to NIN - 1 do begin
    A := Min(1, Abs(FSelected.Inp[I]));
    Y1 := NY(I, NIN, 20, H - 56);
    C.Pen.Style := psSolid; C.Pen.Color := Col(80, 86, 72); C.Pen.Width := 1;
    C.Brush.Style := bsSolid;
    if FSelected.Inp[I] >= 0 then
      C.Brush.Color := AlphaColorBlend(Col(208,167,92), Col(30,34,27), Trunc((0.15+0.85*A)*255))
    else
      C.Brush.Color := Col(60, 58, 50);
    C.Ellipse(XIn - 7, Y1 - 7, XIn + 7, Y1 + 7);
    C.Brush.Style := bsClear;
    if (I >= 12) and (I <= 15) and (FSelected.Inp[I] > 0.05) then
      C.Font.Color := WORDCOL[I - 12]
    else if (I >= 18) and (I <= 20) and (FSelected.Inp[I] > 0.05) then
      C.Font.Color := Col(201, 106, 69)
    else if (I >= 21) and (I <= 23) and (FSelected.Inp[I] > 0.05) then
      C.Font.Color := Col(157, 187, 107)
    else
      C.Font.Color := Col(139, 138, 116);
    C.TextOut(8, Y1 - 6, INLBL[I]);
  end;

  for J := 0 to NHID - 1 do begin
    A := Min(1, Abs(FSelected.Hid[J]));
    Y1 := NY(J, NHID, 56, H - 96);
    C.Pen.Style := psSolid; C.Pen.Color := Col(80, 86, 72);
    C.Brush.Style := bsSolid;
    C.Brush.Color := AlphaColorBlend(Col(208,167,92), Col(30,34,27), Trunc((0.15+0.85*A)*255));
    C.Ellipse(XH1 - 8, Y1 - 8, XH1 + 8, Y1 + 8);
  end;

  for K := 0 to NHID2 - 1 do begin
    A := Min(1, Abs(FSelected.Hid2[K]));
    Y1 := NY(K, NHID2, 56, H - 96);
    C.Pen.Style := psSolid; C.Pen.Color := Col(80, 86, 72);
    C.Brush.Style := bsSolid;
    C.Brush.Color := AlphaColorBlend(Col(208,167,92), Col(30,34,27), Trunc((0.15+0.85*A)*255));
    C.Ellipse(XH2 - 8, Y1 - 8, XH2 + 8, Y1 + 8);
  end;

  for O := 0 to NOUT - 1 do begin
    A := Min(1, Abs(FSelected.Oo[O]));
    Y1 := NY(O, NOUT, 20, H - 56);
    C.Pen.Style := psSolid; C.Pen.Color := Col(80, 86, 72);
    C.Brush.Style := bsSolid;
    if FSelected.Oo[O] >= 0 then
      C.Brush.Color := AlphaColorBlend(Col(208,167,92), Col(30,34,27), Trunc((0.15+0.85*A)*255))
    else
      C.Brush.Color := Col(60, 58, 50);
    C.Ellipse(XOut - 7, Y1 - 7, XOut + 7, Y1 + 7);
    C.Brush.Style := bsClear;
    if (O >= 5) and (FSelected.Oo[O] > 0.25) then
      C.Font.Color := WORDCOL[O - 5]
    else
      C.Font.Color := Col(139, 138, 116);
    C.TextOut(XOut + 12, Y1 - 6, OUTLBL[O]);
  end;

  C.Font.Color := Col(100, 105, 88);
  C.TextOut(20, H - 30, L(76));      // ★i18n légende
end;

{ ★F7 — l'Observatoire : réseau neuronal en géant au centre, fiche du
  spécimen à gauche, technologies/inventions/annales à droite.
  Le clic (MicroMain) passe au sapiens suivant. }
procedure DrawObservatoire(C: TCanvas; W, H: Integer);
var Y, I, J, Car, GN, XR, YInv, YChr: Integer;
   S, Ln: string;
   TT: TTech;
   Items: TStringList;
begin
  C.Brush.Style := bsSolid; C.Pen.Style := psClear;
  C.Brush.Color := Col(11, 14, 11);
  C.FillRect(Rect(0, 0, W, H));

  // ── bandeau ──
  C.Font.Name := 'Georgia'; C.Font.Size := 24; C.Font.Style := [fsItalic, fsBold];
  C.Font.Color := Col(208, 167, 92);
  C.TextOut(30, 16, EreLabel);
  C.Font.Name := 'Segoe UI'; C.Font.Size := 12; C.Font.Style := [];
  C.Font.Color := Col(230, 224, 205);
  S := Format('JOUR %.2d   %.2d:%.2d   %s · an %d     —     %s',
    [DayCount, Trunc(FDayT * 24), Trunc(Frac(FDayT * 24) * 60),
     SAISNOM[(DayCount mod JOURS_ANNEE) * 4 div JOURS_ANNEE],
     DayCount div JOURS_ANNEE + 1, L(77)]);      // ★i18n 'clic : sapiens suivant · F7 : revenir'
  C.TextOut(30, 58, S);
  C.Brush.Color := Col(38, 43, 33);
  C.FillRect(Rect(30, 86, W - 30, 88));

  // ── colonne gauche : spécimen ──
  Y := 106;
  C.Font.Name := 'Segoe UI'; C.Font.Size := 11; C.Font.Style := [];
  C.Font.Color := Col(139, 138, 116);
  C.TextOut(30, Y, AnsiUpperCase(L(12)));
  Inc(Y, 26);
  if (FSelected <> nil) and FSelected.Alive then begin
    C.Font.Name := 'Georgia'; C.Font.Size := 26; C.Font.Style := [fsItalic, fsBold];
    C.Font.Color := FSelected.HueCol;
    C.TextOut(30, Y, FSelected.Name);
    Inc(Y, 38);
    C.Font.Name := 'Segoe UI'; C.Font.Size := 11; C.Font.Style := [];
    C.Font.Color := Col(139, 138, 116);
    case FSelected.Kind of
      0: S := L(21); 1: S := L(22);
    else S := L(23);
    end;
    C.TextOut(30, Y, Format('gén. %d · %s · %s', [FSelected.Gen, S, FSelected.State]));
    Inc(Y, 26);
    C.Brush.Style := bsClear;
    DrawBar(C, 30, Y, 320, FSelected.Energy / FSelected.MaxE, Col(228, 220, 190));
    C.Brush.Style := bsClear;
    C.TextOut(362, Y - 5, L(78));  Inc(Y, 24);           // ★i18n 'énergie'
    if FSelected.Kind = 2 then begin
      DrawBar(C, 30, Y, 320, FSelected.Cult, Col(157, 187, 107));
      C.Brush.Style := bsClear;
      C.TextOut(362, Y - 5, L(67));  Inc(Y, 24);         // ★i18n 'savoir'
    end;
    DrawBar(C, 30, Y, 320, (FSelected.Sp - 2.2) / 3.2, Col(208, 167, 92));
    C.Brush.Style := bsClear;
    C.TextOut(362, Y - 5, L(64));  Inc(Y, 24);           // ★i18n 'vitesse'
    DrawBar(C, 30, Y, 320, (FSelected.Se - 4) / 8, Col(208, 167, 92));
    C.Brush.Style := bsClear;
    C.TextOut(362, Y - 5, L(65));  Inc(Y, 24);           // ★i18n 'perception'
    DrawBar(C, 30, Y, 320, (FSelected.Sz - 0.6) / 0.9, Col(208, 167, 92));
    C.Brush.Style := bsClear;
    C.TextOut(362, Y - 5, L(66));  Inc(Y, 28);           // ★i18n 'taille'
    if FSelected.Kind = 2 then begin
      Items := TStringList.Create;
      try
        for I := 0 to TECH_COUNT - 1 do
          if TECHBASE[I].Code in FSelected.Tech then
            Items.Add(TechNom(TECHBASE[I].Code));
        C.Font.Size := 10; C.Font.Color := Col(240, 180, 95);
        C.Brush.Style := bsClear;
        if Items.Count = 0 then
          C.TextOut(30, Y, L(79))                        // ★i18n 'aucune technologie'
        else begin
          Ln := '';
          for I := 0 to Items.Count - 1 do begin
            if Ln = '' then Ln := Items[I]
            else if C.TextWidth(Ln + ' · ' + Items[I]) <= 400 then Ln := Ln + ' · ' + Items[I]
            else begin C.TextOut(30, Y, Ln); Inc(Y, 19); Ln := Items[I]; end;
          end;
          if Ln <> '' then C.TextOut(30, Y, Ln);
        end;
      finally
        Items.Free;
      end;
      Inc(Y, 30);
      C.Font.Size := 11; C.Font.Color := Col(139, 138, 116);
      C.Brush.Style := bsClear;
      S := '';
      for I := 0 to 3 do
        if FSelected.Inp[12 + I] > 0.05 then
          S := S + L(63) + ' ' + WORDS[I] + '  ';        // ★i18n 'entend'
      if S = '' then S := L(80);                         // ★i18n 'n''entend rien'
      C.TextOut(30, Y, S);
      Inc(Y, 30);
    end;
  end else begin
    C.Font.Name := 'Segoe UI'; C.Font.Size := 12; C.Font.Style := [];
    C.Font.Color := Col(139, 138, 116);
    C.TextOut(30, Y, L(81));                             // ★i18n 'aucun spécimen'
  end;

  // populations en bas
  Y := H - 60;
  C.Font.Size := 11; C.Font.Color := Col(100, 105, 88);
  C.Brush.Style := bsClear;
  C.TextOut(30, Y, Format(L(82),                         // ★i18n ligne populations
    [CountS, EreMaxS, CountH, CountP, FsN + FdN, Plants.Count]));

  // ── centre : le réseau neuronal EN GRAND ──
  if W > 1000 then begin
    SetViewportOrgEx(C.Handle, 430, 100, nil);           // ★ fix : viewport (pas window)
    DrawBrainBig(C, W - 430 - 410, H - 100 - 40);
    SetViewportOrgEx(C.Handle, 0, 0, nil);
  end;

  // ── colonne droite : technologies (2 sous-colonnes) ──
  Y := 106;
  XR := W - 420;
  C.Font.Name := 'Segoe UI'; C.Font.Size := 11; C.Font.Style := [];
  C.Font.Color := Col(139, 138, 116);
  C.Brush.Style := bsClear;
  C.TextOut(XR, Y, AnsiUpperCase(L(7)));
  Inc(Y, 24);
  C.Font.Size := 8;
  GN := 0;
  for I := 0 to Creatures.Count - 1 do
    if Creatures[I].Alive and (Creatures[I].Kind = 2) then Inc(GN);
  J := 0;
  for I := 0 to TECH_COUNT - 1 do begin
    TT := TECHBASE[I].Code;
    if TECHBASE[I].Era > EreCourante then Continue;
    Car := 0;
    for YChr := 0 to Creatures.Count - 1 do
      if Creatures[YChr].Alive and (Creatures[YChr].Kind = 2) and (TT in Creatures[YChr].Tech) then
        Inc(Car);
    if GN > 0 then Car := Round(Car / GN * 100) else Car := 0;
    YInv := Y + (J div 2) * 16;
    C.Font.Color := Col(240, 180, 95);
    C.TextOut(XR + (J mod 2) * 205, YInv, TechNom(TT));
    C.Brush.Style := bsSolid; C.Brush.Color := Col(32, 37, 28);
    C.FillRect(Rect(XR + 118 + (J mod 2) * 205, YInv + 3,
                    XR + 178 + (J mod 2) * 205, YInv + 5));
    if Car > 0 then begin
      C.Brush.Color := Col(240, 180, 95);
      C.FillRect(Rect(XR + 118 + (J mod 2) * 205, YInv + 3,
                      XR + 118 + Trunc(60 * Car / 100) + (J mod 2) * 205, YInv + 5));
    end;
    C.Brush.Style := bsClear; C.Font.Color := Col(139, 138, 116);
    C.TextOut(XR + 182 + (J mod 2) * 205, YInv - 2, IntToStr(Car) + '%');
    Inc(J);
  end;
  Inc(Y, ((J + 1) div 2) * 16 + 14);

  // inventions récentes
  YInv := Y;
  C.Font.Size := 11; C.Font.Color := Col(139, 138, 116);
  C.TextOut(XR, YInv, AnsiUpperCase(L(11)));
  Inc(YInv, 22);
  C.Font.Size := 9;
  if Length(InnoLog) = 0 then
    C.TextOut(XR, YInv, '—')
  else
    for I := Max(0, High(InnoLog) - 7) to High(InnoLog) do begin
      if (InnoLog[I].Word >= 0) and (InnoLog[I].Word <= 3) then
        C.Font.Color := WORDCOL[InnoLog[I].Word]
      else
        C.Font.Color := Col(208, 167, 92);
      C.TextOut(XR, YInv, Format('%s — %s (j.%d)',
        [InnoLog[I].Base, InnoLog[I].Who, InnoLog[I].Day]));
      Inc(YInv, 16);
    end;

  // annales
  YChr := YInv + 16;
  C.Font.Size := 11; C.Font.Color := Col(139, 138, 116);
  C.TextOut(XR, YChr, AnsiUpperCase(L(15)));
  Inc(YChr, 22);
  C.Font.Size := 9;
  if Length(Chronicle) > 0 then
    for I := Max(0, Length(Chronicle) - 10) to Length(Chronicle) - 1 do begin
      if YChr > H - 30 then Break;
      case Chronicle[I].Kind of
        CK_TECH: C.Font.Color := Col(240, 180, 95);
        CK_INNO: C.Font.Color := Col(208, 167, 92);
        CK_LIFE: C.Font.Color := Col(170, 160, 140);
      else C.Font.Color := Col(157, 187, 107);
      end;
      C.TextOut(XR, YChr, Format('j.%d · %s', [Chronicle[I].Day, Chronicle[I].Text]));
      Inc(YChr, 15);
    end;

  // toast
  if FMsgT > 0 then begin
    C.Font.Name := 'Segoe UI'; C.Font.Size := 12; C.Font.Style := [];
    C.Brush.Style := bsClear;
    C.Font.Color := Col(230, 224, 205);
    C.TextOut(30, H - 30, FMsg);
  end;
end;

procedure DrawPanel(C: TCanvas; H: Integer);
var
  Y, I, BX, Car, J, V, Nv, AtSea, IdxS, LastEra: Integer;
  Mesuring: Boolean;
  S, Gl: string;
  R: TRect;
  MaxV: Integer;
  OS, CS: Single;
  GN: Integer;
  Has: Boolean;
  PP, FF: Integer;
  TT: TTech;
  PW: Integer;

  procedure Section(const Sect: string);
  begin
    C.Font.Name := 'Segoe UI'; C.Font.Size := IfThen(FPanelW > 320, 10, 8); C.Font.Style := [];
    C.Font.Color := Col(139, 138, 116);
    C.Brush.Style := bsClear;
    C.TextOut(20, Y, AnsiUpperCase(Sect));
    Inc(Y, IfThen(FPanelW > 320, 24, 20));
  end;

  procedure Btn(const Cap: string; Id, Wd: Integer; Active: Boolean);
  var R2: TRect;
  begin
    R2 := Rect(BX, Y, BX + Wd, Y + 26);
    if not Mesuring then
      AddBtn(Rect(BX, Y - FPanelScroll, BX + Wd, Y - FPanelScroll + 26), Cap, Id, Active);
    C.Font.Name := 'Segoe UI'; C.Font.Size := 9; C.Font.Style := [];
    if Active then begin
      C.Brush.Style := bsSolid; C.Brush.Color := Col(208, 167, 92);
      C.Pen.Style := psClear;
      C.FillRect(R2);
      C.Font.Color := Col(20, 22, 16);
    end else begin
      C.Brush.Style := bsSolid; C.Brush.Color := Col(20, 24, 17);
      C.Pen.Style := psSolid; C.Pen.Color := Col(38, 43, 33); C.Pen.Width := 1;
      C.Rectangle(R2);
      C.Font.Color := Col(139, 138, 116);
    end;
    C.Brush.Style := bsClear;
    C.TextOut((R2.Left + R2.Right - C.TextWidth(Cap)) div 2, R2.Top + 6, Cap);
    Inc(BX, Wd + 6);
  end;

begin
  Mesuring := (H = 0);
  FBtns := nil;
  PW := FPanelW;

  SetWindowOrgEx(C.Handle, 0, 0, nil);

  C.Brush.Style := bsSolid;
  C.Brush.Color := Col(20, 24, 17);
  C.FillRect(Rect(0, 0, PW, H));
  C.Pen.Style := psSolid; C.Pen.Color := Col(38, 43, 33); C.Pen.Width := 1;
  C.MoveTo(PW - 1, 0);
  C.LineTo(PW - 1, H);

  Y := 18;
  C.Font.Name := 'Segoe UI'; C.Font.Size := IfThen(FPanelW > 320, 13, 10); C.Font.Style := [];
  C.Font.Color := Col(230, 224, 205);
  IdxS := (DayCount mod JOURS_ANNEE) * 4 div JOURS_ANNEE;
  S := Format('JOUR %.2d   %.2d:%.2d   %s · an %d', [DayCount,
    Trunc(FDayT * 24), Trunc(Frac(FDayT * 24) * 60),
    SAISNOM[IdxS], DayCount div JOURS_ANNEE + 1]);
  C.TextOut(20, Y, S);
  Inc(Y, IfThen(FPanelW > 320, 26, 20));

  C.Font.Name := 'Georgia'; C.Font.Size := IfThen(FPanelW > 320, 15, 11); C.Font.Style := [fsItalic, fsBold];
  C.Font.Color := Col(208, 167, 92);
  C.TextOut(20, Y, EreLabel);
  C.Font.Name := 'Segoe UI'; C.Font.Size := 8; C.Font.Style := [];
  Inc(Y, IfThen(FPanelW > 320, 26, 20));
  if (FEra < ERE_MAX) and (not CanPassEre) then begin
    C.Font.Color := Col(100, 105, 88);
    S := Format(L(32), [CountTechEre(FEra), IfThen(FEra = 1, 7, 8), CountS, CountInno, InnoTotal]);
    C.TextOut(20, Y, S);
    Inc(Y, IfThen(FPanelW > 320, 18, 14));
  end;

  C.Font.Color := Col(139, 138, 116);
  C.TextOut(20, Y, L(5));
  Inc(Y, IfThen(FPanelW > 320, 18, 14));
  C.Brush.Style := bsSolid;
  C.Brush.Color := Col(38, 43, 33);
  C.FillRect(Rect(20, Y + 8, PW - 20, Y + 10));
  C.Brush.Color := Col(208, 167, 92);
  C.FillRect(Rect(20, Y + 8, 20 + Trunc((PW - 40) * FDayT), Y + 10));
  Inc(Y, 26);

  Section(L(6));
  C.Font.Size := IfThen(FPanelW > 320, 11, 9);
  for I := 0 to 4 do begin
    V := 0;
    case I of
      0: begin S := L(20); V := Plants.Count; C.Brush.Color := Col(157, 187, 107) end;
      1: begin S := L(21); V := CountH; C.Brush.Color := Col(228, 220, 190) end;
      2: begin S := L(22); V := CountP; C.Brush.Color := Col(201, 106, 69) end;
      3: begin S := L(23); V := CountS; C.Brush.Color := Col(208, 167, 92) end;
    else begin S := L(24); V := FsN + FdN; C.Brush.Color := Col(159, 196, 207) end;
    end;
    C.Brush.Style := bsSolid;
    C.FillRect(Rect(20, Y + 5, 26, Y + 11));
    C.Brush.Style := bsClear; C.Font.Color := Col(139, 138, 116);
    C.TextOut(34, Y, S);
    S := IntToStr(V);
    C.Font.Color := Col(230, 224, 205);
    C.TextOut(PW - 20 - C.TextWidth(S), Y, S);
    Inc(Y, IfThen(FPanelW > 320, 20, 17));
  end;
  Inc(Y, 6);

  OS := 0; GN := 0;
  for I := 0 to Creatures.Count - 1 do
    if Creatures[I].Alive and (Creatures[I].Kind = 2) then begin
      OS := OS + Creatures[I].Orn; Inc(GN);
    end;
  C.Font.Size := IfThen(FPanelW > 320, 11, 9); C.Brush.Style := bsClear;
  C.Font.Color := Col(208, 167, 92);
  if GN > 0 then S := Format(L(25), [Round(OS / GN * 100)])
  else S := L(26);
  C.TextOut(20, Y, S);
  Inc(Y, IfThen(FPanelW > 320, 18, 14));

  CS := 0; GN := 0;
  for I := 0 to Creatures.Count - 1 do
    if Creatures[I].Alive and (Creatures[I].Kind = 2) then begin
      CS := CS + Creatures[I].Cult; Inc(GN);
    end;
  C.Font.Color := Col(157, 187, 107);
  if GN > 0 then S := Format(L(27), [Round(CS / GN * 100)])
  else S := L(28);
  C.TextOut(20, Y, S);
  Inc(Y, IfThen(FPanelW > 320, 10, 8));

  Nv := 0; AtSea := 0;
  for I := 0 to Creatures.Count - 1 do
    if Creatures[I].Alive and (Creatures[I].Kind = 2) then begin
      if tNav in Creatures[I].Tech then Inc(Nv);
      if IsWater(Creatures[I].X, Creatures[I].Y) then Inc(AtSea);
    end;
  C.Font.Color := Col(159, 196, 207);
  S := Format(L(29), [Nv, AtSea]);
  C.TextOut(20, Y, S);
  Inc(Y, IfThen(FPanelW > 320, 22, 18));

  Section(L(7));
  C.Font.Size := IfThen(FPanelW > 320, 11, 9);
    LastEra := 0;
  for I := 0 to TECH_COUNT - 1 do begin
    TT := TECHBASE[I].Code;
    if TECHBASE[I].Era > EreCourante then Continue;
    // ★ les ères PASSÉES ne montrent que leur nom, pas le détail
    if TECHBASE[I].Era < EreCourante then begin
      if TECHBASE[I].Era <> LastEra then begin
        LastEra := TECHBASE[I].Era;
        C.Font.Size := 8;
        C.Font.Color := Col(120, 126, 106);           // gris discret : histoire
        C.TextOut(20, Y, '· ' + ERE_NOM(LastEra));
        C.Font.Size := IfThen(FPanelW > 320, 11, 9);
        Inc(Y, 15);
      end;
      Continue;
    end;
    // ── l'ère EN COURS : sous-titre doré + liste détaillée ──
    if TECHBASE[I].Era <> LastEra then begin
      LastEra := TECHBASE[I].Era;
      if LastEra > 1 then begin
        C.Font.Size := 8;
        C.Font.Color := Col(208, 167, 92);
        C.TextOut(20, Y, '— ' + ERE_NOM(LastEra) + ' —');
        C.Font.Size := IfThen(FPanelW > 320, 11, 9);
        Inc(Y, 15);
      end;
    end;
    Car := 0;
    for J := 0 to Creatures.Count - 1 do
      if Creatures[J].Alive and (Creatures[J].Kind = 2) and (TT in Creatures[J].Tech) then
        Inc(Car);
    if GN > 0 then Car := Round(Car / GN * 100) else Car := 0;
    if TechInfo[TT].Who <> '' then begin
      if Car > 0 then
        Gl := Format('%s · j.%d', [TechInfo[TT].Who, TechInfo[TT].Day])
      else
        Gl := L(31);
    end else
      Gl := L(30);
    C.Font.Color := Col(240, 180, 95);
    C.TextOut(20, Y, TechNom(TT));
    C.Font.Color := Col(208, 167, 92);
    C.TextOut(PW div 3, Y, Gl);
    C.Font.Color := Col(139, 138, 116);
    S := Format('%d%%', [Car]);
    C.TextOut(PW - 20 - C.TextWidth(S), Y, S);
    Inc(Y, IfThen(FPanelW > 320, 18, 15));
    C.Brush.Style := bsSolid;
    C.Brush.Color := Col(32, 37, 28);
    C.FillRect(Rect(20, Y, PW - 20, Y + 3));
    C.Brush.Color := Col(240, 180, 95);
    C.FillRect(Rect(20, Y, 20 + Trunc((PW - 40) * Car / 100), Y + 3));
    C.Brush.Style := bsClear;
    Inc(Y, IfThen(FPanelW > 320, 16, 14));
  end;
  Inc(Y, 6);
  Section(L(8));
  R := Rect(20, Y, PW - 20, Y + 74);
  C.Brush.Style := bsSolid; C.Brush.Color := Col(17, 21, 15);
  C.Pen.Style := psClear;
  C.FillRect(R);
  if Length(FHist) > 1 then begin
    MaxV := 10;
    for I := 0 to High(FHist) do begin
      if FHist[I].P > MaxV then MaxV := FHist[I].P;
      if FHist[I].H > MaxV then MaxV := FHist[I].H;
      if FHist[I].C > MaxV then MaxV := FHist[I].C;
      if FHist[I].S > MaxV then MaxV := FHist[I].S;
    end;
    for I := 0 to 3 do DrawLine(C, R, MaxV, I);
  end;
  Inc(Y, 82);
  Section(L(9));
  DrawEvo(C, Y);
  Section(L(10));
  C.Font.Size := IfThen(FPanelW > 320, 11, 9);
  for I := 0 to 3 do begin
    Has := Lex[I].N > 0.8;
    if Has then PP := Round(Lex[I].Pred / Lex[I].N * 100)
    else PP := 0;
    if Has then FF := Round(Lex[I].Food / Lex[I].N * 100)
    else FF := 0;
    Gl := '—';
    if Has then begin
      if (PP > 55) and (PP >= FF) then Gl := L(60)
      else if FF > 55 then Gl := L(61)
      else if (PP < 22) and (FF < 22) then Gl := L(62);
    end;
    C.Font.Color := WORDCOL[I];
    C.TextOut(20, Y, WORDS[I]);
    C.Font.Color := Col(208, 167, 92);
    C.TextOut(44, Y, Gl);
    C.Font.Color := Col(139, 138, 116);
    S := Format('%d/min', [Round(Lex[I].N * 1.2)]);
    C.TextOut(PW - 20 - C.TextWidth(S), Y, S);
    Inc(Y, IfThen(FPanelW > 320, 16, 13));
    C.Brush.Style := bsSolid;
    C.Brush.Color := Col(32, 37, 28);
    C.FillRect(Rect(44, Y, PW - 46, Y + 3));
    if Has then begin
      C.Brush.Color := Col(201, 106, 69);
      C.FillRect(Rect(44, Y, 44 + Trunc((PW - 90) * PP / 100), Y + 3));
    end;
    Inc(Y, 5);
    C.Brush.Style := bsSolid;
    C.Brush.Color := Col(32, 37, 28);
    C.FillRect(Rect(44, Y, PW - 46, Y + 3));
    if Has then begin
      C.Brush.Color := Col(157, 187, 107);
      C.FillRect(Rect(44, Y, 44 + Trunc((PW - 90) * FF / 100), Y + 3));
    end;
    C.Brush.Style := bsClear;
    C.Font.Color := Col(100, 105, 88);
    C.TextOut(PW - 46, Y - 2, 'pr/n');
    Inc(Y, IfThen(FPanelW > 320, 11, 9));
  end;
  Inc(Y, 4);
  Section(L(11));
  C.Font.Size := IfThen(FPanelW > 320, 11, 9);
  if Length(InnoLog) = 0 then begin
    C.Font.Color := Col(100, 105, 88);
    C.Brush.Style := bsClear;
    C.TextOut(20, Y, L(16));
    Inc(Y, 18);
  end else begin
    for I := Max(0, High(InnoLog) - 11) to High(InnoLog) do begin
      C.Brush.Style := bsClear;
      if (InnoLog[I].Word >= 0) and (InnoLog[I].Word <= 3) then
        C.Font.Color := WORDCOL[InnoLog[I].Word]
      else
        C.Font.Color := Col(208, 167, 92);
      C.TextOut(20, Y, InnoLog[I].Base);
      C.Font.Color := Col(139, 138, 116);
      C.TextOut(PW div 3, Y, L(83) + InnoLog[I].Who);      // ★i18n 'par '
      C.Font.Color := Col(100, 105, 88);
      S := 'j.' + IntToStr(InnoLog[I].Day);
      C.TextOut(PW - 20 - C.TextWidth(S), Y, S);
      Inc(Y, IfThen(FPanelW > 320, 18, 15));
    end;
    Inc(Y, 6);
  end;
  if FSelected <> nil then begin
    Section(L(12));
    C.Font.Name := 'Georgia'; C.Font.Size := IfThen(FPanelW > 320, 18, 14); C.Font.Style := [fsItalic, fsBold];
    C.Font.Color := FSelected.HueCol;
    C.TextOut(20, Y, FSelected.Name);
    if not Mesuring then begin
      AddBtn(Rect(PW - 84, Y - FPanelScroll + 2, PW - 20, Y - FPanelScroll + 24),
             L(19), BID_INFO, False);
      C.Brush.Style := bsSolid; C.Pen.Style := psSolid; C.Pen.Width := 1;
      C.Pen.Color := Col(38, 43, 33);
      C.Brush.Color := Col(20, 24, 17);
      C.Rectangle(PW - 84, Y + 2, PW - 20, Y + 24);
      C.Font.Name := 'Segoe UI'; C.Font.Size := 9; C.Font.Style := [];
      C.Brush.Style := bsClear;
      C.Font.Color := Col(139, 138, 116);
      C.TextOut(PW - 84 + ((64 - C.TextWidth(L(19))) div 2), Y + 8, L(19));
    end;
    Inc(Y, IfThen(FPanelW > 320, 24, 20));
    C.Font.Name := 'Segoe UI'; C.Font.Size := 8; C.Font.Style := [];
    C.Font.Color := Col(139, 138, 116);
    case FSelected.Kind of
      0: S := L(21);
      1: S := L(22);
    else S := L(23);
    end;
    S := Format('gén. %d · %s · %s', [FSelected.Gen, S, FSelected.State]);
    if FSelected.Kind = 2 then
      S := S + Format(' · mut %d%%', [Round(FSelected.MutRate * 100)]);
    if FSelected.Kind = 2 then begin
      for I := 0 to 3 do
        if FSelected.Inp[12 + I] > 0.05 then
          S := S + ' · ' + L(63) + ' ' + WORDS[I];
    end;
    C.TextOut(20, Y, S);
    Inc(Y, 20);
    DrawBar(C, 20, Y, PW - 74, FSelected.Energy / FSelected.MaxE, Col(228, 220, 190));
    C.Font.Color := Col(139, 138, 116); C.Brush.Style := bsClear;
    C.TextOut(PW - 50, Y - 4, IntToStr(Trunc(Max(0, FSelected.Energy))));
    Inc(Y, 12);
    C.TextOut(20, Y, L(64));
    DrawBar(C, 94, Y + 2, PW - 148, (FSelected.Sp - 2.2) / 3.2, Col(208, 167, 92));
    Inc(Y, 12);
    C.TextOut(20, Y, L(65));
    DrawBar(C, 94, Y + 2, PW - 148, (FSelected.Se - 4) / 8, Col(208, 167, 92));
    Inc(Y, 12);
    C.TextOut(20, Y, L(66));
    DrawBar(C, 94, Y + 2, PW - 148, (FSelected.Sz - 0.6) / 0.9, Col(208, 167, 92));
    Inc(Y, 12);
    if FSelected.Kind = 2 then begin
      C.TextOut(20, Y, L(67));
      DrawBar(C, 94, Y + 2, PW - 148, FSelected.Cult, Col(157, 187, 107));
      Inc(Y, 12);
      S := '';
      if tFeu in FSelected.Tech then S := S + TechNom(tFeu) + ' ';
      if tAgri in FSelected.Tech then S := S + TechNom(tAgri) + ' ';
      if tStock in FSelected.Tech then S := S + TechNom(tStock) + ' ';
      if tPast in FSelected.Tech then S := S + TechNom(tPast) + ' ';
      if tPeche in FSelected.Tech then S := S + TechNom(tPeche) + ' ';
      if tNav in FSelected.Tech then S := S + TechNom(tNav) + ' ';
      if S <> '' then begin
        C.TextOut(20, Y, L(71) + ' ' + S);
        Inc(Y, 12);
      end;
      C.TextOut(20, Y, AnsiUpperCase(L(49)));
      Inc(Y, 18);
      DrawBrain(C, Y);
      if not Mesuring then
        AddBtn(Rect(20, Y - FPanelScroll, PW - 20, Y - FPanelScroll + BRH),
               '', BID_BRAIN, False);
      Inc(Y, BRH + 22);
    end;
  end;

  Section(L(13));
  if CanPassEre then begin
    BX := 20;
    Btn(L(34), BID_ERE, PW - 40, True);
    Inc(Y, 32);
  end;
  BX := 20;
  if FRunning then Btn('II', BID_PLAY, (PW - 58) div 4, True)
              else Btn('>', BID_PLAY, (PW - 58) div 4, False);
  Btn('1x', BID_S1, (PW - 58) div 4, FSpeed = 1);
  Btn('2x', BID_S2, (PW - 58) div 4, FSpeed = 2);
  Btn('4x', BID_S4, (PW - 58) div 4, FSpeed = 4);
  Inc(Y, 32);

  BX := 20;
  Btn(L(35), BID_TI, (PW - 64) div 5, FTool = TOOL_INSPECT);
  Btn(L(36), BID_TS, (PW - 64) div 5, FTool = TOOL_SEED);
  Btn(L(37), BID_TH, (PW - 64) div 5, FTool = TOOL_HERB);
  Btn(L(38), BID_TP, (PW - 64) div 5, FTool = TOOL_PRED);
  Btn(L(39), BID_TSA, (PW - 64) div 5, FTool = TOOL_SAP);
  Inc(Y, 32);

  BX := 20;
  Btn(L(40), BID_SAVE, (PW - 46) div 2, False);
  Btn(L(41), BID_LOAD, (PW - 46) div 2, False);
  Inc(Y, 32);

  BX := 20;
  Btn(L(42), BID_NEW, PW - 40, False);
  Inc(Y, 32);

  BX := 20;
  Btn(L(43), BID_HELP, (PW - 52) div 3, False);
  Btn(L(44), BID_CFGSHOW, (PW - 52) div 3, FCfgShow);
  Btn(L(45), BID_CHRON, (PW - 52) div 3, FChronShow);
  Inc(Y, 32);

  BX := 20;
  Btn('3D', BID_G3D, (PW - 46) div 2, False);
  Btn(L(46), BID_RELIEF, (PW - 46) div 2, FRelief);
  Inc(Y, 32);
   if FCfgShow then begin
    Section(L(14));
    for I := 0 to CN - 1 do begin
      C.Font.Name := 'Segoe UI'; C.Font.Size := IfThen(FPanelW > 320, 11, 9); C.Font.Style := [];
      C.Brush.Style := bsClear;
      C.Font.Color := Col(139, 138, 116);
      C.TextOut(20, Y + 5, CfgName(I));
      // ★ boutons - / + juste après le nom, valeur alignée à droite
      BX := 150;
      Btn('-', BID_CFGDEC + I, 26, False);
      Btn('+', BID_CFGINC + I, 26, False);
      C.Font.Color := Col(230, 224, 205);
      S := CfgText(I);
      C.TextOut(PW - 20 - C.TextWidth(S), Y + 5, S);   // aligné à droite
      Inc(Y, IfThen(FPanelW > 320, 32, 28));
    end;
    BX := 20;
    Btn(L(47), BID_CFGDEF, PW - 60, False);
    Inc(Y, 36);
  end;
  if FChronShow then begin
    Section(L(15));
    C.Font.Size := IfThen(FPanelW > 320, 10, 8);
    if Length(Chronicle) = 0 then begin
      C.Brush.Style := bsClear;
      C.Font.Color := Col(100, 105, 88);
      C.TextOut(20, Y, L(17));
      Inc(Y, 18);
    end else begin
      for J := Max(0, Length(Chronicle) - 14) to Length(Chronicle) - 1 do begin
        C.Brush.Style := bsClear;
        case Chronicle[J].Kind of
          CK_TECH: C.Font.Color := Col(240, 180, 95);
          CK_INNO: C.Font.Color := Col(208, 167, 92);
          CK_LIFE: C.Font.Color := Col(170, 160, 140);
        else C.Font.Color := Col(157, 187, 107);
        end;
        C.TextOut(20, Y, Format('j.%d · %s', [Chronicle[J].Day, Chronicle[J].Text]));
        Inc(Y, IfThen(FPanelW > 320, 18, 14));
      end;
      Inc(Y, 8);
    end;
  end;
  C.Font.Size := 8; C.Font.Color := Col(139, 138, 116); C.Brush.Style := bsClear;
  case FTool of
    TOOL_INSPECT: S := L(58);
    TOOL_SEED:    S := L(59);
    TOOL_HERB:    S := L(68);
    TOOL_PRED:    S := L(69);
  else            S := L(70);
  end;
  C.TextOut(20, Y, S);
  Inc(Y, 20);

  if FThumb.Width > 0 then begin
    C.StretchDraw(Rect(20, Y, 20 + IfThen(FPanelW > 320, 160, 100),
                       Y + IfThen(FPanelW > 320, 99, 62)), FThumb);
    C.Brush.Style := bsSolid;
    for I := 0 to Creatures.Count - 1 do begin
      if not Creatures[I].Alive then Continue;
      case Creatures[I].Kind of
        0: C.Brush.Color := Col(228, 220, 190);
        1: C.Brush.Color := Col(201, 106, 69);
        3: C.Brush.Color := Col(206, 168, 104);
      else C.Brush.Color := Col(208, 167, 92);
      end;
      C.FillRect(Rect(20 + Trunc(Creatures[I].X / GW * IfThen(FPanelW > 320, 160, 100)) - 1,
                      Y + Trunc(Creatures[I].Y / GH * IfThen(FPanelW > 320, 99, 62)) - 1,
                      20 + Trunc(Creatures[I].X / GW * IfThen(FPanelW > 320, 160, 100)) + 1,
                      Y + Trunc(Creatures[I].Y / GH * IfThen(FPanelW > 320, 99, 62)) + 1));
    end;
  end;
  Inc(Y, IfThen(FPanelW > 320, 107, 70));

  FPanelH := Y;
end;

end.

unit MicroBrain;

{ Microcosme — utilitaires, bruit, terrain (îlots), poissons, flore,
  réseau neuronal v3 (récurrences, biais, voie vocale labile, mutisme
  fondateur, mutation à taux variable), grille spatiale, noms, caméra,
  lexique, champs, feu. }

interface

uses
  System.SysUtils, System.Classes, System.Math, System.Generics.Collections,
  Winapi.Windows, Vcl.Graphics,
  MicroTypes,MicroVilles;

function Col(R, G, B: Integer): TColor;
function HueColor(H: Single): TColor;
function AlphaColorBlend(A, B: TColor; Alpha: Byte): TColor;
function Hash2(IX, IY: Integer): Single;
function VNoise(X, Y: Single): Single;
function FBM(X, Y: Single; Oct: Integer): Single;
function RN: Single;
function ClampF(V, A, B: Single): Single;
function CellIdx(X, Y: Single): Integer;
function Walkable(X, Y: Single): Boolean;
function D2(AX, AY, BX, BY: Single): Single;
function NormA(A: Single): Single;
function DayCount: Integer;
procedure Toast(const Msg: string);
procedure GenTerrain;
procedure ClearWorldObjects;
function AddPlant(X, Y, S: Single): TPlant;
procedure RemovePlant(P: TPlant);
procedure StepPlants(DT, DayF: Single);
procedure FillInnateNet(var W: TArray<Single>);
procedure MutateNet(var W: TArray<Single>; const AMutRate: Single);
procedure ThinkNet(C: TCreature);
function MakeName: string;
procedure RebuildGrid;
procedure CollectNear(X, Y, R: Single);
function CrowdCount(C: TCreature; R: Single): Integer;
function FindPlant(C: TCreature): TPlant;
procedure ClampCam;
procedure ResetLex;
procedure RebuildFields;
function NearFireHut(X, Y: Single): Boolean;
function IsWater(X, Y: Single): Boolean;
function NavOK(X, Y: Single): Boolean;
procedure SeedFish;
procedure StepFish(DT, DayF: Single);
procedure KillFish(Idx: Integer);
procedure AddFishAt(X, Y: Single; Deep: Boolean);
procedure AddMark(X, Y: Single; WordI, Sense: Integer);

implementation

{$OVERFLOWCHECKS OFF}
{$RANGECHECKS OFF}
{$POINTERMATH OFF}

function Col(R, G, B: Integer): TColor;
begin
  Result := RGB(R, G, B);
end;

function HueColor(H: Single): TColor;
var
  H6, F, P, Q, T: Double;
  I, R, G, B: Integer;
const
  SAT = 0.70; VAL = 0.86;
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

procedure GenTerrain;
var X, Y, I: Integer; E, Moist, DX, DY: Single;
   Made, Tries, Cx, Cy, CI: Integer;
   Rr, D: Single; Ok: Boolean;
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
  // îlots volcaniques au large
  Made := 0; Tries := 0;
  while (Made < 3) and (Tries < 60) do begin
    Inc(Tries);
    Cx := 12 + Random(GW - 24); Cy := 12 + Random(GH - 24);
    CI := Cy * GW + Cx;
    if Elev[CI] > 0.12 then Continue;
    Rr := 4.5 + Random * 3;
    Ok := True;
    for Y := Max(0, Trunc(Cy - Rr - 2)) to Min(GH - 1, Trunc(Cy + Rr + 2)) do
      for X := Max(0, Trunc(Cx - Rr - 2)) to Min(GW - 1, Trunc(Cx + Rr + 2)) do
        if (Sqr(X - Cx) + Sqr(Y - Cy) < Sqr(Rr + 2)) and (Elev[Y * GW + X] > 0.2) then
          Ok := False;
    if not Ok then Continue;
    for Y := Max(0, Trunc(Cy - Rr)) to Min(GH - 1, Trunc(Cy + Rr)) do
      for X := Max(0, Trunc(Cx - Rr)) to Min(GW - 1, Trunc(Cx + Rr)) do begin
        D := Sqrt(Sqr(X - Cx) + Sqr(Y - Cy));
        if D > Rr then Continue;
        I := Y * GW + X;
        E := 0.62 - (D / Rr) * (D / Rr) * 0.30 + FBM(X * 0.2 + SX + 5, Y * 0.2 + SY + 5, 2) * 0.08;
        if E > Elev[I] then begin
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
    Inc(Made);
  end;
end;

procedure ClearWorldObjects;
var I: Integer; TT: TTech;
begin
  for I := 0 to Plants.Count - 1 do Plants[I].Free;
  Plants.Clear;
  SetLength(PlantGrid, NC);
  for I := 0 to NC - 1 do PlantGrid[I] := nil;
  for I := 0 to Huts.Count - 1 do Huts[I].Free;
  Huts.Clear;
  if Cities <> nil then begin
    for I := 0 to Cities.Count - 1 do Cities[I].Free;
    Cities.Clear;
  end;
  for I := 0 to Fishes.Count - 1 do Fishes[I].Free;
  Fishes.Clear;
  FsN := 0; FdN := 0;
  for I := 0 to Marks.Count - 1 do Marks[I].Free;
  Marks.Clear;
  for I := 0 to Creatures.Count - 1 do Creatures[I].Free;
  Creatures.Clear;
  CountH := 0; CountP := 0; CountS := 0;
  UidH := 0; UidP := 0; UidS := 0;
  FSelected := nil;
  FHist := nil;
  ResetLex;
  if Length(FieldGrid) <> NC then SetLength(FieldGrid, NC);
  for I := 0 to NC - 1 do FieldGrid[I] := 0;
  for TT := Low(TTech) to High(TTech) do begin
    TechInfo[TT].Who := '';
    TechInfo[TT].Day := 0;
    TechLost[TT] := False;
  end;
  FHomeSet := False;
end;

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
  for C in Creatures do begin
    if C.TargetP = P then C.TargetP := nil;
    if C.SFood = P then C.SFood := nil;
  end;
  P.Free;
end;

procedure StepPlants(DT, DayF: Single);
var I: Integer; P: TPlant; A, R, GB: Single;
begin
  for I := Plants.Count - 1 downto 0 do begin
    P := Plants[I];
    if P.Morte then Continue;                        // ★ garde : plante marquée
    if P.S <= 0.03 then begin KillPlantEx(P); Continue end;
    GB := 1;
    if (Length(FieldGrid) = NC) and (FieldGrid[P.Cell] = 1) then GB := 1.6;
    if P.S < 1 then
      P.S := Min(1, P.S + 0.042 * Fert[P.Cell] * DayF * DT * GB);
    if (P.S > 0.5) and (Random < DT * 0.09 * DayF * GB) then begin
      A := Random * TAU; R := 1.6 + Random * 2.2;
      AddPlant(P.X + Cos(A) * R, P.Y + Sin(A) * R, 0.06 + Random * 0.08);
    end;
  end;
end;

function IsVoiceIdx(K: Integer): Boolean;
var I, O: Integer;
begin
  if K < IDX_HO then
    Result := (K div NHID) >= 12
  else if K < IDX_SO then begin
    O := (K - IDX_HO) mod NOUT;
    Result := O >= 5;
  end
  else if K < IDX_OB then begin
    I := (K - IDX_SO) div NOUT;
    O := (K - IDX_SO) mod NOUT;
    Result := (I >= 12) or (O >= 5);
  end
  else
    Result := (K - IDX_OB) >= 5;
end;

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
  for I := 5 to 8 do W[IDX_OB + I] := -0.5;
end;

procedure MutateNet(var W: TArray<Single>; const AMutRate: Single);
var I: Integer;
begin
  for I := 0 to NW - 1 do
    if IsVoiceIdx(I) then begin
      if Random < 0.26 * AMutRate then W[I] := ClampF(W[I] + RN * 0.3, -4, 4)
      else if Random < 0.04 * AMutRate then W[I] := ClampF(RN * 1.2, -4, 4);
    end else begin
      if Random < 0.13 * AMutRate then W[I] := ClampF(W[I] + RN * 0.3, -4, 4)
      else if Random < 0.02 * AMutRate then W[I] := ClampF(RN * 1.2, -4, 4);
    end;
end;

procedure ThinkNet(C: TCreature);
var I, J, O: Integer; S: Single;
begin
  // récurrences : les sorties précédentes alimentent les entrées 24-32
  for O := 0 to NOUT - 2 do
    C.Inp[24 + O] := C.PrevOo[O];
  C.Inp[33] := 1;
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
  for O := 0 to NOUT - 1 do C.PrevOo[O] := C.Oo[O];
end;

function MakeName: string;
var N, I: Integer;
begin
  N := 2; if Random < 0.35 then N := 3;
  Result := '';
  for I := 1 to N do Result := Result + SYL[Random(Length(SYL))];
  Result := UpCase(Result[1]) + Copy(Result, 2, MaxInt);
end;

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

procedure ClampCam;
var S: Single;
begin
  S := FScale * FZoom;
  if GW * S <= FVP.Width then FCamX := (GW - 1) / 2
  else FCamX := ClampF(FCamX, FVP.Width / (2 * S) - 0.5, GW - FVP.Width / (2 * S) - 0.5);
  if GH * S <= FVP.Height then FCamY := (GH - 1) / 2
  else FCamY := ClampF(FCamY, FVP.Height / (2 * S) - 0.5, GH - FVP.Height / (2 * S) - 0.5);
end;

procedure ResetLex;
var I: Integer;
begin
  for I := 0 to 3 do begin
    Lex[I].N := 0; Lex[I].Pred := 0; Lex[I].Food := 0;
  end;
end;

procedure RebuildFields;
var I, X0, X1, Y0, Y1, X, Y, CI: Integer;
begin
  if Length(FieldGrid) <> NC then SetLength(FieldGrid, NC);
  for I := 0 to NC - 1 do FieldGrid[I] := 0;
  for I := 0 to Huts.Count - 1 do
    if Huts[I].Cult then begin
      X0 := Max(0, Trunc(Huts[I].X - 9)); X1 := Min(GW - 1, Trunc(Huts[I].X + 9));
      Y0 := Max(0, Trunc(Huts[I].Y - 9)); Y1 := Min(GH - 1, Trunc(Huts[I].Y + 9));
      for Y := Y0 to Y1 do
        for X := X0 to X1 do begin
          CI := Y * GW + X;
          if Sqr(X + 0.5 - Huts[I].X) + Sqr(Y + 0.5 - Huts[I].Y) < 81 then
            FieldGrid[CI] := 1;
        end;
    end;
end;

function NearFireHut(X, Y: Single): Boolean;
var I: Integer;
begin
  Result := False;
  if Huts = nil then Exit;
  for I := 0 to Huts.Count - 1 do
    if Huts[I].Fire and
       (Sqr(Huts[I].X - X) + Sqr(Huts[I].Y - Y) < Sqr(7.5)) then begin
      Result := True; Exit;
    end;
end;

function IsWater(X, Y: Single): Boolean;
var K: Integer;
begin
  K := CellIdx(X, Y);
  Result := (K >= 0) and (TerrType[K] <= T_SHAL);
end;

function NavOK(X, Y: Single): Boolean;
var K: Integer;
begin
  K := CellIdx(X, Y);
  Result := (K >= 0) and (TerrType[K] <= T_SHAL);
end;

procedure AddFishAt(X, Y: Single; Deep: Boolean);
var F: TFish;
begin
  if Deep and (FdN >= MAXFD) then Exit;
  if (not Deep) and (FsN >= MAXFS) then Exit;
  F := TFish.Create;
  F.X := X; F.Y := Y;
  F.Angle := Random * TAU;
  F.Deep := Deep;
  F.S := 0.5 + Random * 0.5;
  Fishes.Add(F);
  if Deep then Inc(FdN) else Inc(FsN);
end;

procedure SeedFish;
var X, Y: Integer;
begin
  for X := 0 to GW - 1 do
    for Y := 0 to GH - 1 do begin
      if (TerrType[Y * GW + X] = T_SHAL) and (Random < 0.028) then
        AddFishAt(X + 0.5, Y + 0.5, False)
      else if (TerrType[Y * GW + X] = T_DEEP) and (Random < 0.006) then
        AddFishAt(X + 0.5, Y + 0.5, True);
    end;
end;

procedure KillFish(Idx: Integer);
var F: TFish;
begin
  if (Idx < 0) or (Idx >= Fishes.Count) then Exit;
  F := Fishes[Idx];
  if F.Deep then Dec(FdN) else Dec(FsN);
  Fishes.Delete(Idx);
  F.Free;
end;

procedure StepFish(DT, DayF: Single);
var I: Integer; F: TFish;
   NX, NY: Single; Cap, N: Integer;
   Spd: Single;
begin
  for I := Fishes.Count - 1 downto 0 do begin
    F := Fishes[I];
    F.Angle := F.Angle + RN * 2.4 * DT;
    if F.Deep then Spd := 1.15 * 1.15 else Spd := 1.15;
    NX := F.X + Cos(F.Angle) * Spd * DT;
    NY := F.Y + Sin(F.Angle) * Spd * DT;
    if IsWater(NX, NY) and
       (TerrType[CellIdx(NX, NY)] = IfThen(F.Deep, T_DEEP, T_SHAL)) then begin
      F.X := NX; F.Y := NY;
    end else
      F.Angle := F.Angle + PI * (0.5 + Random);
    if F.Deep then begin Cap := MAXFD; N := FdN end
    else begin Cap := MAXFS; N := FsN end;
    if (N < Cap) and
       (Random < DT * (0.028 + 0.11 * (1 - N / Cap)) * DayF) then
      AddFishAt(F.X + Random * 3 - 1.5, F.Y + Random * 3 - 1.5, F.Deep);
  end;
end;

procedure AddMark(X, Y: Single; WordI, Sense: Integer);
var M: TMark;
begin
  M := TMark.Create;
  M.X := X; M.Y := Y;
  M.WordI := WordI; M.Sense := Sense; M.Age := 0;
  Marks.Add(M);
end;

end.

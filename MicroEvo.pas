unit MicroEvo;

{ Microcosme — suivi de l'évolution : moyennes des traits des sapiens
  (vitesse, vue, taille, plume, culture, mutations, génération),
  historique, courbes dans le carnet. }

interface

uses
  System.SysUtils, System.Math,System.Types,
  Vcl.Graphics,
  MicroTypes, MicroBrain;

type
  TEvoRec = record
    Sp, Se, Sz, Orn, Cult, Mut, Gen: Single;
  end;

const
  EVOHIST = 240;    { échantillons conservés }
  EVOTICK = 5.0;    { secondes simulées entre deux échantillons }

procedure StepEvo(DT: Single);
procedure ResetEvo;
procedure DrawEvo(C: TCanvas; var Y: Integer);

var
  FEvo: array of TEvoRec;

implementation

var
  EvoT: Single = 0;

function ClampF(v, lo, hi: Single): Single; inline;
begin
  if v < lo then Result := lo
  else if v > hi then Result := hi
  else Result := v;
end;

function Col(R, G, B: Byte): TColor; inline;
begin
  Result := TColor((B shl 16) or (G shl 8) or R);
end;


procedure ResetEvo;
begin
  SetLength(FEvo, 0);
  EvoT := 0;
end;

procedure StepEvo(DT: Single);
var I, N: Integer; C: TCreature; R: TEvoRec;
begin
  EvoT := EvoT + DT;
  if EvoT < EVOTICK then Exit;
  EvoT := 0;
  R.Sp := 0; R.Se := 0; R.Sz := 0;
  R.Orn := 0; R.Cult := 0; R.Mut := 0; R.Gen := 0;
  N := 0;
  for I := 0 to Creatures.Count - 1 do begin
    C := Creatures[I];
    if (C <> nil) and C.Alive and (C.Kind = 2) then begin
      R.Sp := R.Sp + C.Sp;
      R.Se := R.Se + C.Se;
      R.Sz := R.Sz + C.Sz;
      R.Orn := R.Orn + C.Orn;
      R.Cult := R.Cult + C.Cult;
      R.Mut := R.Mut + C.MutRate;
      R.Gen := R.Gen + C.Gen;
      Inc(N);
    end;
  end;
  if N = 0 then Exit;
  R.Sp := R.Sp / N;   R.Se := R.Se / N;   R.Sz := R.Sz / N;
  R.Orn := R.Orn / N; R.Cult := R.Cult / N;
  R.Mut := R.Mut / N; R.Gen := R.Gen / N;
  if Length(FEvo) >= EVOHIST then begin
    Move(FEvo[1], FEvo[0], (EVOHIST - 1) * SizeOf(TEvoRec));
    SetLength(FEvo, EVOHIST);
    FEvo[EVOHIST - 1] := R;
  end else begin
    SetLength(FEvo, Length(FEvo) + 1);
    FEvo[High(FEvo)] := R;
  end;
end;

procedure DrawEvo(C: TCanvas; var Y: Integer);
const
  NCUR = 6;
  { bornes min/max de chaque courbe (normalisation fixe) }
  RG: array[0..NCUR - 1, 0..1] of Single =
    ((2.6, 5.6), (6, 12), (0.7, 1.3), (0, 1), (0, 1), (0.5, 2));
var
  GX0, GY0, GX1, GY1, I, K, PX, PY, LX: Integer;
  Fr: Single;
  L: TEvoRec;
  Cl: array[0..NCUR - 1] of TColor;

  procedure Leg(Clr: TColor; const Txt: string);
  begin
    C.Brush.Style := bsSolid; C.Pen.Style := psClear;
    C.Brush.Color := Clr;
    C.Rectangle(LX, Y + 3, LX + 6, Y + 9);
    C.Brush.Style := bsClear;
    C.Font.Color := Col(139, 138, 116);
    C.TextOut(LX + 10, Y, Txt);
    LX := LX + 18 + C.TextWidth(Txt);
  end;

begin
  GX0 := 20; GX1 := PANELW - 20; GY0 := Y; GY1 := Y + 62;
  Cl[0] := Col(208, 167, 92);    { vitesse }
  Cl[1] := Col(228, 220, 190);   { vue }
  Cl[2] := Col(157, 187, 107);   { taille }
  Cl[3] := Col(201, 106, 69);    { plume }
  Cl[4] := Col(159, 196, 207);   { culture }
  Cl[5] := Col(176, 140, 210);   { mutations }
  C.Brush.Style := bsSolid;
  C.Brush.Color := Col(17, 21, 15);
  C.Pen.Style := psClear;
  C.FillRect(Rect(GX0, GY0, GX1, GY1));
  if Length(FEvo) > 1 then
    for K := 0 to NCUR - 1 do begin
      C.Pen.Style := psSolid;
      C.Pen.Width := 1;
      C.Pen.Color := Cl[K];
      for I := 0 to High(FEvo) do begin
        case K of
          0: Fr := FEvo[I].Sp;
          1: Fr := FEvo[I].Se;
          2: Fr := FEvo[I].Sz;
          3: Fr := FEvo[I].Orn;
          4: Fr := FEvo[I].Cult;
        else Fr := FEvo[I].Mut;
        end;
        Fr := ClampF((Fr - RG[K][0]) / (RG[K][1] - RG[K][0]), 0, 1);
        PX := GX0 + Round(I / High(FEvo) * (GX1 - GX0 - 1));
        PY := GY1 - 2 - Round(Fr * (GY1 - GY0 - 4));
        if I = 0 then C.MoveTo(PX, PY) else C.LineTo(PX, PY);
      end;
    end;
  Inc(Y, 66);
  C.Font.Name := 'Segoe UI'; C.Font.Size := 8; C.Font.Style := [];
  if Length(FEvo) > 0 then begin
    L := FEvo[High(FEvo)];
    LX := 20;
    Leg(Cl[0], Format('vit %.1f', [L.Sp]));
    Leg(Cl[1], Format('vue %.1f', [L.Se]));
    Leg(Cl[2], Format('tai %.2f', [L.Sz]));
    Leg(Cl[5], Format('mut %.2f×', [L.Mut]));
    Y := Y + 15;
    LX := 20;
    Leg(Cl[3], Format('plume %d%%', [Round(L.Orn * 100)]));
    Leg(Cl[4], Format('cult %d%%', [Round(L.Cult * 100)]));
    Leg(Col(120, 130, 100), Format('gén moyenne %.1f', [L.Gen]));
  end else begin
    C.Brush.Style := bsClear;
    C.Font.Color := Col(100, 105, 88);
    C.TextOut(20, Y, 'en attente de données…');
  end;
  Inc(Y, 22);
end;

end.

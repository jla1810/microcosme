unit MicroVilles;

{ Microcosme — l'urbanisme : émergence des villes, niveaux, spirale d'or,
  empreinte écologique, routes qui poussent, rendu des structures urbaines.
  Les DONNÉES (TCity, TRoad, listes Cities/Roads) vivent dans MicroTypes ;
  toute la LOGIQUE est ici. MicroSim appelle VeilleUrbaine(DT) une fois
  par jour de sim, et SurRoute pour les effets de vitesse/diffusion.

  v15.2 — FIX4 :
    ★ DefricherVilles supprime via KillPlantEx (le P.Free nu laissait un
      pointeur fantôme dans Plants → AV StepPlants en boucle) ;
    ★ CheminRoute en BFS terrestre : plus court chemin garanti, tableau VIDE
      si la cible est inatteignable (île) — fini les tronçons morts du glouton ;
    ★ VeilleRoutes purge les routes fantômes (Chemin qui n'atteint pas B)
      et ne fonde plus que sur chemin viable (>= 2 points) ;
    ★ retrait des toasts DEBUG (veille urbaine + DBG villes). }

interface

uses
  System.SysUtils, System.Math, System.Types, System.Classes,
  System.Generics.Collections, Vcl.Graphics,
  MicroTypes;

procedure VeilleUrbaine(DT: Single);               // à appeler chaque DoStep
function  CheminRoute(x1, y1, x2, y2: Integer): TArray<TPoint>;
function  RouteEntre(VA, VB: TCity): TRoad;
function  SurRoute(X, Y: Single): Boolean;
procedure DrawVilles(C: TCanvas; OX, OY, S, VX0, VY0, VX1, VY1: Double);
procedure DrawRoads(C: TCanvas; OX, OY, S, VX0, VY0, VX1, VY1: Double);
procedure KillPlantEx(P: TPlant);

implementation


{$OVERFLOWCHECKS OFF}
{$RANGECHECKS OFF}


uses
  MicroBrain,   // Toast, DayCount, Walkable, Col, AlphaColorBlend, ClampF
  MicroEre,     // EreCourante, PeopleHas
  MicroLang,    // L()
  MicroChrono;  // ChronAdd, CK_PEOPLE

const
  VILLE_SEUIL   = 10;    // huttes pour fonder (naît bourg, niveau 2)
  VILLE_NIVEAU3 = 18;    // ville
  VILLE_NIVEAU4 = 28;    // cité
  VILLE_RAYON   = 14.0;
  ROAD_DIST       = 200.0;  // distance max ville-ville pour fonder une route
  ROAD_CROISSANCE = 3;     // cellules construites par jour
  MIGR_DIST       = 60.0;  // ★Exode : au-delà, les pionniers restent aux frontières

var
  VilleT: Single = 0;
  gCitadinDit: Boolean = False;   // ★Exode : annale « peuple citadin », une seule fois
  RouteGrid: TArray<Byte>;    // ★FIX3 : 1 = cellule couverte par une route

{─── noms ─────────────────────────────────────────────────────────────────}

function SyllabesNom: string;
var N, I: Integer;
begin
  N := 2 + Random(2);
  Result := '';
  for I := 1 to N do
    Result := Result + SYL[Random(Length(SYL))];
  Result[1] := UpCase(Result[1]);
end;

{─── villes : placement en spirale d'or ───────────────────────────────────}

procedure PlaceHutInVille(H: THut; V: TCity);
var Nb, T: Integer;
   A, R, NX, NY: Single;
begin
  Nb := 0;
  for T := 0 to Huts.Count - 1 do
    if (Huts[T].Ville = V) and (Huts[T] <> H) then Inc(Nb);
  A := Nb * 2.399963;                        // l'angle d'or
  R := 1.1 + 0.30 * Sqrt(Nb);                // spirale de Fermat
  for T := 0 to 6 do begin
    NX := V.X + Cos(A + T * 0.7) * (R + T * 0.35);
    NY := V.Y + Sin(A + T * 0.7) * (R + T * 0.35);
    NX := ClampF(NX, 0.5, GW - 0.5);
    NY := ClampF(NY, 0.5, GH - 0.5);
    if Walkable(NX, NY) then begin
      H.X := NX; H.Y := NY;
      Exit;
    end;
  end;
end;

procedure VeilleVilles;
var I, K, Nb: Integer;
   H: THut;
   V, Best, NewV: TCity;
   D, BD: Single;
begin
  // 1) rattacher les huttes isolées à la ville la plus proche
  for I := 0 to Huts.Count - 1 do begin
    H := Huts[I];
    if H.Ville <> nil then Continue;
    Best := nil; BD := 1e9;
    for K := 0 to Cities.Count - 1 do begin
      V := Cities[K];
      D := Sqrt(Sqr(H.X - V.X) + Sqr(H.Y - V.Y));
      if (D < V.Rayon) and (D < BD) then begin BD := D; Best := V end;
    end;
    if Best <> nil then begin
      H.Ville := Best;
      PlaceHutInVille(H, Best);
    end;
  end;

  // 2) fonder une ville si un amas de huttes isolées atteint le seuil
  if Cities.Count < 8 then
    for I := 0 to Huts.Count - 1 do begin
      H := Huts[I];
      if H.Ville <> nil then Continue;
      Nb := 0;
      for K := 0 to Huts.Count - 1 do
        if (Huts[K].Ville = nil) and
           (Sqr(Huts[K].X - H.X) + Sqr(Huts[K].Y - H.Y) < Sqr(VILLE_RAYON)) then
          Inc(Nb);
      if Nb >= VILLE_SEUIL then begin
        NewV := TCity.Create;
        NewV.Nom := SyllabesNom;
        NewV.Niveau := 2;
        NewV.Jour := DayCount;
        NewV.Rayon := VILLE_RAYON + 2;
        NewV.X := 0; NewV.Y := 0;
        for K := 0 to Huts.Count - 1 do
          if (Huts[K].Ville = nil) and
             (Sqr(Huts[K].X - H.X) + Sqr(Huts[K].Y - H.Y) < Sqr(VILLE_RAYON)) then begin
            Huts[K].Ville := NewV;
            NewV.X := NewV.X + Huts[K].X;
            NewV.Y := NewV.Y + Huts[K].Y;
          end;
        NewV.X := NewV.X / Max(1, Nb);
        NewV.Y := NewV.Y / Max(1, Nb);
        Cities.Add(NewV);
        for K := 0 to Huts.Count - 1 do
          if Huts[K].Ville = NewV then
            PlaceHutInVille(Huts[K], NewV);
        Toast(Format(L(150), [NewV.Nom]));
        ChronAdd(CK_PEOPLE, Format(L(151), [NewV.Nom, Nb, DayCount]));
        Break;
      end;
    end;

  // 3) montées de niveau + recentrage
  for K := 0 to Cities.Count - 1 do begin
    V := Cities[K];
    Nb := 0;
    V.X := 0; V.Y := 0;
    for I := 0 to Huts.Count - 1 do
      if Huts[I].Ville = V then begin
        Inc(Nb);
        V.X := V.X + Huts[I].X;
        V.Y := V.Y + Huts[I].Y;
      end;
    if Nb > 0 then begin
      V.X := V.X / Nb;
      V.Y := V.Y / Nb;
    end;
    if (Nb >= VILLE_NIVEAU4) and (V.Niveau < 4) then begin
      V.Niveau := 4;
      V.Rayon := VILLE_RAYON + 6;
      Toast(Format(L(154), [V.Nom, Nb]));
      ChronAdd(CK_PEOPLE, Format(L(155), [V.Nom, Nb]));
    end else if (Nb >= VILLE_NIVEAU3) and (V.Niveau < 3) then begin
      V.Niveau := 3;
      V.Rayon := VILLE_RAYON + 4;
      Toast(Format(L(152), [V.Nom, Nb]));
      ChronAdd(CK_PEOPLE, Format(L(153), [V.Nom, Nb]));
    end;
  end;

  // 4) huttes orphelines (défensif)
  for I := 0 to Huts.Count - 1 do
    if (Huts[I].Ville <> nil) and (Cities.IndexOf(Huts[I].Ville) < 0) then
      Huts[I].Ville := nil;
end;

{─── empreinte écologique ──────────────────────────────────────────────────}

{ Supprime une plante PROPREMENT : panneau "morte" AVANT tout,
  puis liste, puis grille, puis tous les pointeurs vivants des créatures.
  ★RÈGLE : TOUTE suppression de plante passe ICI — jamais de P.Free nu,
  jamais de fragment recopié de ce corps (leçon DefricherVilles/AV StepPlants). }
procedure KillPlantEx(P: TPlant);
var I, CI: Integer;
   O: TCreature;
begin
  if (P = nil) or P.Morte then Exit;   // déjà morte : rien à faire (anti double-kill)
  P.Morte := True;                     // ★ le panneau est posé PREMIER
  CI := P.Cell;
  I := Plants.IndexOf(P);
  if I >= 0 then Plants.Delete(I);
  if (CI >= 0) and (CI < Length(PlantGrid)) and (PlantGrid[CI] = P) then
    PlantGrid[CI] := nil;
  if Creatures <> nil then
    for O in Creatures do
      if O.Alive then begin
        if O.TargetP = P then O.TargetP := nil;
        if O.SFood = P then O.SFood := nil;
      end;
  P.Free;
end;

{ ★FIX4 — toute la suppression passe par KillPlantEx : liste, grille,
  TargetP/SFood purge's, panneau Morte. L'ancien corps (P.Free sans
  Plants.Delete + CI jamais assignée) fabriquait des fantômes dans Plants. }
procedure DefricherVilles;
var I, K: Integer;
   P: TPlant;
   V: TCity;
   R: Single;
begin
  if Cities.Count = 0 then Exit;
  for I := Plants.Count - 1 downto 0 do begin
    P := Plants[I];
    for K := 0 to Cities.Count - 1 do begin
      V := Cities[K];
      R := 3.0 + V.Niveau * 2.5;               // la clairière (au-delà du bâti)
      if Sqr(P.X - V.X) + Sqr(P.Y - V.Y) < Sqr(R) then begin
        KillPlantEx(P);        // ★ la suppression PROPRE — on appelle, on n'imite pas
        Break;
      end;
    end;
  end;
end;


{─── exode rural : la campagne se vide dans les villes ────────────────────}
{ ★Zéro Free, zéro suppression : la hutte DÉMÉNAGE (Ville + spirale).
  Les HomeH des bêtes restent valides — les troupeaux suivent (ou
  s'échappent en route : émergence gratuite). }
procedure ExodeRural;
var I, K, Nb: Integer;
   H: THut;
   V, Best: TCity;
   D, BD, Proba: Single;
begin
  if Cities.Count = 0 then Exit;
  case EreCourante of           // l'urbanisation s'accélère avec les ères
    2: Proba := 0.04;
    3: Proba := 0.08;
    4: Proba := 0.14;
    5: Proba := 0.20;
    6: Proba := 0.28;
  else Exit;                    // ère 1 : le monde est encore dispersé
  end;
  Nb := 0;
  for I := 0 to Huts.Count - 1 do begin
    H := Huts[I];
    if H.Ville <> nil then Continue;           // déjà citadine
    if Random >= Proba then Continue;          // cette famille reste encore
    Best := nil; BD := 1e9;
    for K := 0 to Cities.Count - 1 do begin    // la ville la plus proche
      V := Cities[K];
      D := Sqr(H.X - V.X) + Sqr(H.Y - V.Y);
      if D < BD then begin BD := D; Best := V end;
    end;
    if (Best = nil) or (BD > Sqr(MIGR_DIST)) then Continue;
    H.Ville := Best;             // la famille déménage…
    PlaceHutInVille(H, Best);    // …et rebâtit dans la spirale
    Inc(Nb);
  end;
  if Nb > 0 then begin
    Toast(Format(L(158), [Nb]));
    ChronAdd(CK_PEOPLE, Format(L(158), [Nb]));
  end;
end;

{ l'annale du basculement : plus de la moitié des foyers sont urbains }
procedure VeilleCitadin;
var I, NbU: Integer;
begin
  if gCitadinDit or (EreCourante < 2) or (Cities.Count < 2) then Exit;
  NbU := 0;
  for I := 0 to Huts.Count - 1 do
    if Huts[I].Ville <> nil then Inc(NbU);
  if (Huts.Count > 0) and (NbU * 2 >= Huts.Count) then begin
    gCitadinDit := True;
    Toast(L(159));
    ChronAdd(CK_PEOPLE, L(159));
  end;
end;

{─── routes ────────────────────────────────────────────────────────────────}

{ ★FIX4 — BFS terrestre 8-connexe : plus court chemin garanti s'il existe,
  tableau VIDE si la cible est inatteignable (île). L'ancien glouton
  fabriquait des tronçons morts (coincés sur une rive) = routes fantômes
  qui bloquaient RouteEntre à jamais. }
function CheminRoute(x1, y1, x2, y2: Integer): TArray<TPoint>;
const
  DX8: array[0..7] of Integer = (-1, 0, 1, -1, 1, -1, 0, 1);
  DY8: array[0..7] of Integer = (-1, -1, -1, 0, 0, 1, 1, 1);
var
  Prev, Queue: TArray<Integer>;
  QH, QT, K, N, Start, Goal, Cur, Idx, NX, NY: Integer;
begin
  SetLength(Result, 0);
  if (x1 < 0) or (x1 >= GW) or (y1 < 0) or (y1 >= GH) or
     (x2 < 0) or (x2 >= GW) or (y2 < 0) or (y2 >= GH) then Exit;

  Start := y1 * GW + x1;
  Goal  := y2 * GW + x2;

  // Prev : -2 = pas visité, -1 = départ, sinon l'index de la case d'où l'on vient
  SetLength(Prev, NC);
  for Idx := 0 to NC - 1 do Prev[Idx] := -2;
  SetLength(Queue, NC);
  QH := 0; QT := 0;
  Prev[Start] := -1;
  Queue[QT] := Start; Inc(QT);

  while QH < QT do begin
    Cur := Queue[QH]; Inc(QH);
    if Cur = Goal then Break;
    for K := 0 to 7 do begin
      NX := (Cur mod GW) + DX8[K];
      NY := (Cur div GW) + DY8[K];
      if (NX < 0) or (NX >= GW) or (NY < 0) or (NY >= GH) then Continue;
      Idx := NY * GW + NX;
      if (Prev[Idx] <> -2) or (TerrType[Idx] < T_SAND) then Continue;  // pas d'eau
      Prev[Idx] := Cur;
      Queue[QT] := Idx; Inc(QT);
    end;
  end;

  if Prev[Goal] = -2 then Exit;                 // inatteignable → pas de route

  // remontée des "pains d'avoine" Goal → Start, puis écriture à l'endroit
  N := 0; Cur := Goal;
  while Cur <> -1 do begin Inc(N); Cur := Prev[Cur] end;
  SetLength(Result, N);
  Cur := Goal;
  for Idx := N - 1 downto 0 do begin
    Result[Idx].X := Cur mod GW;
    Result[Idx].Y := Cur div GW;
    Cur := Prev[Cur];
  end;
end;

function RouteEntre(VA, VB: TCity): TRoad;
var I: Integer;
begin
  Result := nil;
  for I := 0 to Roads.Count - 1 do
    if ((Roads[I].A = VA) and (Roads[I].B = VB)) or
       ((Roads[I].A = VB) and (Roads[I].B = VA)) then Exit(Roads[I]);
end;

{ ★FIX3 — grille de routes : mise à jour 1×/jour, réponse O(1) }
procedure RebuildRouteGrid;
var I, J: Integer;
   R: TRoad;
begin
  if Length(RouteGrid) <> NC then SetLength(RouteGrid, NC);
  if NC > 0 then FillChar(RouteGrid[0], NC, 0);
  for I := 0 to Roads.Count - 1 do begin
    R := Roads[I];
    for J := 0 to Min(R.Prog, High(R.Chemin)) do
      RouteGrid[R.Chemin[J].Y * GW + R.Chemin[J].X] := 1;
  end;
end;

function SurRoute(X, Y: Single): Boolean;
var CI: Integer;
begin
  CI := CellIdx(X, Y);
  Result := (CI >= 0) and (CI < Length(RouteGrid)) and (RouteGrid[CI] <> 0);
end;

{ ★FIX4 — purge des fantômes AVANT tout, croissance, fondation gardée. }
procedure VeilleRoutes;
var I, K: Integer;
   VA, VB, BestVB: TCity;
   R: TRoad;
   D, BestD: Single;
   Fant: Boolean;
begin
  if EreCourante < 4 then Exit;

  // ★SOIN — purge des routes fantômes : une route saine se termine SUR B.
  // (fait AVANT le plafond de 12 : un fantôme purgé libère une place.)
  for I := Roads.Count - 1 downto 0 do begin
    R := Roads[I];
    if Length(R.Chemin) < 2 then
      Fant := True
    else
      Fant := Sqr(R.Chemin[High(R.Chemin)].X - R.B.X) +
              Sqr(R.Chemin[High(R.Chemin)].Y - R.B.Y) > Sqr(2.0);
    if Fant then begin
      Roads.Delete(I);
      R.Free;    // sûr : les routes ne sont référencées que par Roads et
                 // RouteGrid — qui est reconstruit en fin de procédure.
    end;
  end;

  if Roads.Count >= 12 then Exit;

  // 1) croissance : chaque route existante avance de ROAD_CROISSANCE cases
  for I := 0 to Roads.Count - 1 do begin
    R := Roads[I];
    if R.Prog < High(R.Chemin) then
      R.Prog := Min(High(R.Chemin), R.Prog + ROAD_CROISSANCE);
  end;

  // 2) fondation : chaque ville sans route → vers la ville la plus proche
  for I := 0 to Cities.Count - 1 do begin
    VA := Cities[I];
    BestVB := nil; BestD := 1e9;
    for K := 0 to Cities.Count - 1 do begin
      if K = I then Continue;
      VB := Cities[K];
      D := Sqrt(Sqr(VA.X - VB.X) + Sqr(VA.Y - VB.Y));
      if (D < ROAD_DIST) and (D < BestD) and (RouteEntre(VA, VB) = nil) then begin
        BestD := D; BestVB := VB;
      end;
    end;
    if (BestVB <> nil) and (RouteEntre(VA, BestVB) = nil) then begin
      R := TRoad.Create;
      R.A := VA; R.B := BestVB;
      R.Chemin := CheminRoute(Trunc(VA.X), Trunc(VA.Y),
                              Trunc(BestVB.X), Trunc(BestVB.Y));
      if Length(R.Chemin) < 2 then
        R.Free                              // ★ inatteignable : on renonce,
      else begin                            //   JAMAIS de route fantôme
        R.Prog := 0;
        R.Jour := DayCount;
        Roads.Add(R);
        Toast(Format(L(156), [VA.Nom, BestVB.Nom]));
        ChronAdd(CK_PEOPLE, Format(L(157), [VA.Nom, BestVB.Nom]));
      end;
    end;
  end;
  RebuildRouteGrid;     // ★FIX3 : le calque suit la croissance
end;

{─── point d'entrée unique pour MicroSim.DoStep ───────────────────────────}

procedure VeilleUrbaine(DT: Single);
begin
  if (Huts = nil) or (Creatures = nil) then Exit;
  VilleT := VilleT + DT;
  if VilleT >= CDAY then begin
    VilleT := 0;
    if Huts.Count > 0 then begin
      VeilleVilles;
      ExodeRural;       // ★Exode : la campagne se vide vers les villes
      VeilleCitadin;    // ★Exode : l'annale du basculement (une seule fois)
      DefricherVilles;
      VeilleRoutes;
    end;
  end;
end;

{─── rendu ─────────────────────────────────────────────────────────────────}

procedure DrawRoads(C: TCanvas; OX, OY, S, VX0, VY0, VX1, VY1: Double);
var I, J: Integer;
   R: TRoad;
begin
  if Roads.Count = 0 then Exit;
  // passe 1 : le fond de terre (large, sombre)
  C.Brush.Style := bsClear;
  C.Pen.Style := psSolid;
  C.Pen.Width := Max(2, Trunc(S * 0.8));
  C.Pen.Color := Col(96, 78, 50);
  for I := 0 to Roads.Count - 1 do begin
    R := Roads[I];
    C.MoveTo(Trunc(OX + R.A.X * S), Trunc(OY + R.A.Y * S));
    for J := 1 to Min(R.Prog, High(R.Chemin)) do
      C.LineTo(Trunc(OX + R.Chemin[J].X * S), Trunc(OY + R.Chemin[J].Y * S));
  end;
  // passe 2 : le chemin (plus étroit, ocre clair)
  C.Pen.Width := Max(1, Trunc(S * 0.45));
  C.Pen.Color := Col(186, 158, 108);
  for I := 0 to Roads.Count - 1 do begin
    R := Roads[I];
    C.MoveTo(Trunc(OX + R.A.X * S), Trunc(OY + R.A.Y * S));
    for J := 1 to Min(R.Prog, High(R.Chemin)) do
      C.LineTo(Trunc(OX + R.Chemin[J].X * S), Trunc(OY + R.Chemin[J].Y * S));
  end;
  C.Pen.Width := 1;
  C.Brush.Style := bsSolid;
end;

procedure DrawVilles(C: TCanvas; OX, OY, S, VX0, VY0, VX1, VY1: Double);
var I, K2, NbV, NB2, PX, PY, RR, RR2, HX, HY: Integer;
   V: TCity;
   A, R2: Single;
   HasFeu: Boolean;
   Poly: array[0..2] of TPoint;
   function InV(X, Y, M: Double): Boolean;
   begin
     Result := (X > VX0 - M) and (X < VX1 + M) and (Y > VY0 - M) and (Y < VY1 + M);
   end;
begin
  for I := 0 to Cities.Count - 1 do begin
    V := Cities[I];
    if not InV(V.X, V.Y, 30) then Continue;

    // compte les foyers, cherche le feu
    NbV := 0; HasFeu := False;
    for K2 := 0 to Huts.Count - 1 do
      if Huts[K2].Ville = V then begin
        Inc(NbV);
        if Huts[K2].Fire then HasFeu := True;
      end;
    PX := Trunc(OX + V.X * S);
    PY := Trunc(OY + V.Y * S);

    // l'assiette urbaine
    C.Brush.Style := bsSolid; C.Pen.Style := psClear;
    RR := Trunc(S * (2.6 + V.Niveau * 0.8));
    C.Brush.Color := AlphaColorBlend(Col(168, 158, 138), Col(11, 14, 11), 95);
    C.Ellipse(PX - RR, PY - RR, PX + RR, PY + RR);

    // les remparts + 4 portes
    if V.Niveau >= 3 then begin
      C.Brush.Style := bsClear;
      C.Pen.Style := psSolid;
      C.Pen.Width := Max(2, Trunc(S * 0.45));
      C.Pen.Color := Col(138, 132, 122);
      RR := Trunc(S * (4.6 + V.Niveau * 0.6));
      C.Ellipse(PX - RR, PY - RR, PX + RR, PY + RR);
      C.Pen.Color := Col(176, 170, 158);
      C.Pen.Width := 1;
      C.Ellipse(PX - RR - 2, PY - RR - 2, PX + RR + 2, PY + RR + 2);
      C.Pen.Color := Col(96, 88, 76);
      C.Pen.Width := Max(2, Trunc(S * 0.5));
      C.MoveTo(PX, PY - RR); C.LineTo(PX, PY - RR + Trunc(S * 1.2));
      C.MoveTo(PX, PY + RR); C.LineTo(PX, PY + RR - Trunc(S * 1.2));
      C.MoveTo(PX - RR, PY); C.LineTo(PX - RR + Trunc(S * 1.2), PY);
      C.MoveTo(PX + RR, PY); C.LineTo(PX + RR - Trunc(S * 1.2), PY);
    end;

    // les foyers en couronne (angle d'or)
    C.Brush.Style := bsSolid;
    C.Pen.Style := psSolid; C.Pen.Width := 1; C.Pen.Color := Col(52, 46, 36);
    NB2 := Min(NbV, 12);
    for K2 := 0 to NB2 - 1 do begin
      A := K2 * 2.399963;
      R2 := (1.3 + 0.22 * Sqrt(K2)) * IfThen(V.Niveau >= 3, 1.15, 1.0);
      HX := PX + Trunc(Cos(A) * R2 * S);
      HY := PY + Trunc(Sin(A) * R2 * S);
      RR2 := Max(2, Trunc(S * 0.55));
      if EreCourante >= 6 then begin
        case (V.Jour + K2) mod 4 of
          0: C.Brush.Color := Col(198, 168, 130);
          1: C.Brush.Color := Col(172, 178, 150);
          2: C.Brush.Color := Col(186, 152, 148);
        else C.Brush.Color := Col(158, 170, 182);
        end;
      end else
        C.Brush.Color := Col(150, 146, 138);
      C.Rectangle(HX - RR2, HY - RR2 div 2, HX + RR2, HY + RR2);
      C.Brush.Color := Col(140, 82, 62);
      Poly[0] := Point(HX - RR2 - 1, HY - RR2 div 2);
      Poly[1] := Point(HX + RR2 + 1, HY - RR2 div 2);
      Poly[2] := Point(HX, HY - RR2 - Max(2, RR2 div 2));
      C.Polygon(Poly);
    end;

    // le feu de la ville
    if HasFeu then begin
      C.Brush.Style := bsSolid; C.Pen.Style := psClear;
      RR := Trunc(S * 4.0);
      if FDayLight < 0.5 then
        C.Brush.Color := AlphaColorBlend(Col(255,165,70), Col(11,14,11), 120)
      else
        C.Brush.Color := AlphaColorBlend(Col(255,165,70), Col(11,14,11), 35);
      C.Ellipse(PX - RR, PY - RR, PX + RR, PY + RR);
      RR := Max(2, Trunc(S * 0.5));
      C.Brush.Color := Col(240, 180, 95);
      C.Ellipse(PX - RR, PY - RR * 2, PX + RR, PY + RR);
    end;

    // le monument (cité)
    if V.Niveau >= 4 then begin
      C.Brush.Style := bsSolid;
      C.Pen.Style := psSolid; C.Pen.Width := 1; C.Pen.Color := Col(60, 56, 50);
      C.Brush.Color := Col(140, 136, 128);
      RR2 := Max(3, Trunc(S * 0.9));
      C.Rectangle(PX - RR2, PY - RR2 * 4, PX + RR2, PY - RR2);
      C.Brush.Color := Col(84, 88, 96);
      Poly[0] := Point(PX - RR2 - 1, PY - RR2 * 4);
      Poly[1] := Point(PX + RR2 + 1, PY - RR2 * 4);
      Poly[2] := Point(PX, PY - RR2 * 5);
      C.Polygon(Poly);
    end;

    // le nom
    if FZoom >= 1.8 then begin
      C.Brush.Style := bsClear;
      C.Font.Name := 'Georgia';
      C.Font.Size := Max(9, Trunc(FZoom * 6));
      C.Font.Style := [fsItalic, fsBold];
      C.Font.Color := AlphaColorBlend(Col(232, 226, 206), Col(11, 14, 11), 200);
      C.TextOut(PX - C.TextWidth(V.Nom) div 2,
                PY - Trunc(S * (7 + V.Niveau)) - C.Font.Size - 2, V.Nom);
    end;
  end;
end;

end.

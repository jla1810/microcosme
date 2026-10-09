unit MicroIno;

{ Microcosme — inventions mineures émergentes.
  v16 : NINNO 25 — ère 6 Renaissance (lunette, violon, carte marine).
  Corporations booste l'émergence. Les noms d'objets sont la langue du
  monde : non traduits. }

interface

uses
  System.SysUtils, System.Math,
  MicroTypes, MicroBrain, MicroChrono;

const
  NINNO = 31;
  IN_BROCHETTE = 0;
  IN_TAMBOUR = 1;
  IN_HOTTE = 2;
  IN_PARURE = 3;
  IN_FILET = 4;
  IN_PEAUSS = 5;
  IN_TORCHE = 6;
  IN_FUMEE = 7;
  IN_PIEGE = 8;
  IN_APPENTIS = 9;
  IN_BOUGIE = 10; // ère 2
  IN_CHARR = 11;
  IN_FOUR = 12;
  IN_HORLOGE = 13; // ère 3
  IN_BOSSOLE = 14;
  IN_THEATRE = 15;
  IN_AMPHORE = 16; // ère 4
  IN_SERPE = 17;
  IN_FOSSE = 18;
  IN_ARBALETE = 19; // ère 5
  IN_PARCHEMIN = 20;
  IN_ARMURE = 21;
  IN_LUNETTE = 22; // ère 6
  IN_VIOLON = 23;
  IN_CARMARINE = 24;
  IN_LAMPION = 25;
  IN_RADIO = 26;
  IN_METRO = 27;
  IN_ASPIRINE = 28;
  IN_FRIGO = 29;
  IN_AVION = 30;

  const
  INNOBASE: array [0 .. NINNO - 1] of string = ('brochette', 'tambour', 'hotte',
    'parure', 'filet', 'peausserie', 'torche', 'fumée', 'piège', 'appentis',
    'bougie', 'charrette', 'four', 'horloge', 'boussole', 'théâtre', 'amphore',
    'serpe', 'fosse', 'arbalète', 'parchemin', 'armure', 'lunette', 'violon',
    'carte marine','lampion','radio','métro','aspirine','frigo','avion');

type
  TInnov = record
    Kind: Integer;
    Base: string;
    Mot: string; // ★le mot frappé (remplace Word: Integer)
    Word: Integer;
    Who: string;
    Day: Integer;
  end;

var
  InnoLog: array of TInnov;

function HasInno(C: TCreature; K: Integer): Boolean;
procedure GiveInno(C: TCreature; K: Integer);
procedure ResetInno;
function InnoAllMask: Integer;
procedure TryInventMinor(C: TCreature);
function InnoFull(I: Integer): string;

implementation

uses MicroSim, MicroMain, MicroEre, MicroAudio, MicroLang;

const
  INNO_CHANCE = 0.02;

function HasInno(C: TCreature; K: Integer): Boolean;
begin
  Result := (K >= 0) and (K < NINNO) and ((C.InnoK and (1 shl K)) <> 0);
end;

procedure GiveInno(C: TCreature; K: Integer);
begin
  if (K >= 0) and (K < NINNO) then
    C.InnoK := C.InnoK or (1 shl K);
end;

procedure ResetInno;
begin
  SetLength(InnoLog, 0);
end;

function InnoAllMask: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(InnoLog) do
    Result := Result or (1 shl InnoLog[I].Kind);
end;

function KindKnown(K: Integer): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(InnoLog) do
    if InnoLog[I].Kind = K then
    begin
      Result := True;
      Exit
    end;
end;

function FireNear(X, Y, R: Single): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to Huts.Count - 1 do
    if Huts[I].Fire and (Sqr(Huts[I].X - X) + Sqr(Huts[I].Y - Y) < Sqr(R)) then
    begin
      Result := True;
      Exit
    end;
end;

function HutNear(X, Y, R: Single): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to Huts.Count - 1 do
    if Sqr(Huts[I].X - X) + Sqr(Huts[I].Y - Y) < Sqr(R) then
    begin
      Result := True;
      Exit
    end;
end;

function WaterNear(C: TCreature; R: Integer): Boolean;
var
  DX, DY, K: Integer;
begin
  Result := True;
  for DY := -R to R do
    for DX := -R to R do
    begin
      K := CellIdx(C.X + DX, C.Y + DY);
      if (K >= 0) and (TerrType[K] <= T_SHAL) then
        Exit;
    end;
  Result := False;
end;

function MeanOrn: Single;
var
  I, N: Integer;
begin
  Result := 0;
  N := 0;
  for I := 0 to Creatures.Count - 1 do
    if Creatures[I].Alive and (Creatures[I].Kind = 2) then
    begin
      Result := Result + Creatures[I].Orn;
      Inc(N);
    end;
  if N > 0 then
    Result := Result / N
  else
    Result := 0;
end;

function WildHerbNear(C: TCreature; R, MinN: Integer): Boolean;
var
  N: Integer;
  O: TCreature;
begin
  N := 0;
  CollectNear(C.X, C.Y, R);
  for O in NB do
    if O.Alive and (O.Kind = 0) and (not O.Dom) then
      Inc(N);
  Result := N >= MinN;
end;

function SapienNearCount(C: TCreature; R: Single): Integer;
var
  N: Integer;
  O: TCreature;
begin
  N := 0;
  CollectNear(C.X, C.Y, R);
  for O in NB do
    if O.Alive and (O.Kind = 2) and (O <> C) then
      Inc(N);
  Result := N;
end;

procedure AddInno(C: TCreature; K: Integer);
var
  N: Integer;
  Mot, Mot2: string;
  I, I2: Integer;
begin
  N := Length(InnoLog);
  SetLength(InnoLog, N + 1);
  InnoLog[N].Kind := K;
  InnoLog[N].Base := INNOBASE[K];
  // ★LEXIQUE — un mot en syllabes pour l'invention (frappé localement :
  // MicroSim ne peut pas être dans nos uses — cycle)
  Mot := '';
  for I := 0 to 99 do
  begin
    Mot := SYL[Random(Length(SYL))] + SYL[Random(Length(SYL))];
    if Random < 0.5 then
      Mot := Mot + SYL[Random(Length(SYL))];
    Mot2 := '';
    for I2 := 0 to High(LexiqueDuPeuple) do
      if LexiqueDuPeuple[I2].Mot = Mot then
        Mot2 := 'x';
    if Mot2 = '' then
      Break;
    Mot := '';
  end;
  InnoLog[N].Mot := Mot;
  if Mot <> '' then
  begin
    SetLength(LexiqueDuPeuple, Length(LexiqueDuPeuple) + 1);
    LexiqueDuPeuple[High(LexiqueDuPeuple)].Mot := Mot;
    LexiqueDuPeuple[High(LexiqueDuPeuple)].Sens := INNOBASE[K];
    LexiqueDuPeuple[High(LexiqueDuPeuple)].Qui := C.Name;
    LexiqueDuPeuple[High(LexiqueDuPeuple)].Jour := DayCount;
    ChronAdd(CK_INNO, Format(L(232), [C.Name, Mot, INNOBASE[K]]));
  end;
  GiveInno(C, K);
  Toast(Format(L(118), [C.Name, InnoFull(N)]));
  ChronAdd(CK_INNO, InnoFull(N));
  if (EreCourante >= 3) and (K >= IN_HORLOGE) then
    AudioBell(Round(C.X), Round(C.Y));
end;

procedure TryInventMinor(C: TCreature);
var
  K: Integer;
begin
  if (C.Kind <> 2) or (C.Age <= CHILDHOOD) or (C.Cult < 0.30) then
    Exit;
  if Random >= INNO_CHANCE_V * IfThen(PeopleHas(teCorporations), 1.5, 1.0) then
    Exit;

  // sans feu, seules les inventions "pré-feu" sont possibles
  if not(tFeu in C.Tech) then
  begin
    if (not KindKnown(IN_HOTTE)) and (CellIdx(C.X, C.Y) >= 0) and
      (TerrType[CellIdx(C.X, C.Y)] = T_FOR) then
    begin
      AddInno(C, IN_HOTTE);
      Exit
    end;
    if (not KindKnown(IN_PARURE)) and (MeanOrn > 0.55) then
    begin
      AddInno(C, IN_PARURE);
      Exit
    end;
    if (not KindKnown(IN_TAMBOUR)) and WaterNear(C, TAMBOUR_EAU) then
      for K := 0 to High(C.Mem) do
        if C.Mem[K].K = 0 then
        begin
          AddInno(C, IN_TAMBOUR);
          Exit
        end;
    Exit;
  end;

  if (not KindKnown(IN_BROCHETTE)) and (FDayLight < BROCHETTE_NUIT) and
    (C.Energy < C.MaxE * 0.5) and FireNear(C.X, C.Y, 6) then
  begin
    AddInno(C, IN_BROCHETTE);
    Exit
  end;
  if (not KindKnown(IN_FILET)) and (tPeche in C.Tech) and IsWater(C.X, C.Y) then
  begin
    AddInno(C, IN_FILET);
    Exit
  end;
  if (not KindKnown(IN_PEAUSS)) and (FDayLight < PEAUSS_NUIT) and HutNear(C.X, C.Y, 4)
  then
  begin
    AddInno(C, IN_PEAUSS);
    Exit
  end;
  if (not KindKnown(IN_TORCHE)) and (FDayLight < TORCHE_NUIT) and FHomeSet and
    (Sqr(C.X - FHomeX) + Sqr(C.Y - FHomeY) > 225) then
  begin
    AddInno(C, IN_TORCHE);
    Exit
  end;
  if (not KindKnown(IN_FUMEE)) and (C.SPred <> nil) and FireNear(C.X, C.Y, 6)
  then
  begin
    AddInno(C, IN_FUMEE);
    Exit
  end;
  if (not KindKnown(IN_PIEGE)) and (CellIdx(C.X, C.Y) >= 0) and
    (TerrType[CellIdx(C.X, C.Y)] = T_FOR) and WildHerbNear(C, 8, 4) then
  begin
    AddInno(C, IN_PIEGE);
    Exit
  end;
  if (not KindKnown(IN_APPENTIS)) and (tStock in C.Tech) and (Huts.Count >= 3)
  then
  begin
    AddInno(C, IN_APPENTIS);
    Exit
  end;

  // ── ÈRE 2 ──
  if EreCourante >= 2 then
  begin
    if (not KindKnown(IN_BOUGIE)) and (tEcrit in C.Tech) and (FDayLight < BOUGIE_NUIT)
      and HutNear(C.X, C.Y, 4) then
    begin
      AddInno(C, IN_BOUGIE);
      Exit
    end;
    if (not KindKnown(IN_CHARR)) and (teRoue in C.Tech) and FireNear(C.X, C.Y, 5)
    then
    begin
      AddInno(C, IN_CHARR);
      Exit
    end;
    if (not KindKnown(IN_FOUR)) and (tStock in C.Tech) and FireNear(C.X, C.Y, 5)
    then
    begin
      AddInno(C, IN_FOUR);
      Exit
    end;
  end;

  // ── ÈRE 3 ──
  if EreCourante >= 3 then
  begin
    if (not KindKnown(IN_HORLOGE)) and (teMaths in C.Tech) then
    begin
      AddInno(C, IN_HORLOGE);
      Exit
    end;
    if (not KindKnown(IN_BOSSOLE)) and (teAstronomie in C.Tech) and
      (FDayLight < BOSSOLE_NUIT) and FHomeSet and
      (Sqr(C.X - FHomeX) + Sqr(C.Y - FHomeY) > 225) then
    begin
      AddInno(C, IN_BOSSOLE);
      Exit
    end;
    if (not KindKnown(IN_THEATRE)) and (SapienNearCount(C, 6) >= THEATRE_FOULE) then
    begin
      AddInno(C, IN_THEATRE);
      Exit
    end;
  end;

  // ── ÈRE 4 ──
  if EreCourante >= 4 then
  begin
    if (not KindKnown(IN_AMPHORE)) and (tStock in C.Tech) and (Huts.Count >= 4)
    then
    begin
      AddInno(C, IN_AMPHORE);
      Exit
    end;
    if (not KindKnown(IN_SERPE)) and (tAgri in C.Tech) and
      (CellIdx(C.X, C.Y) >= 0) and (TerrType[CellIdx(C.X, C.Y)] = T_FOR) then
    begin
      AddInno(C, IN_SERPE);
      Exit
    end;
    if (not KindKnown(IN_FOSSE)) and (Huts.Count >= 5) and (C.SPred <> nil) then
    begin
      AddInno(C, IN_FOSSE);
      Exit
    end;
  end;

  // ── ÈRE 5 ──
  if EreCourante >= 5 then
  begin
    if (not KindKnown(IN_ARBALETE)) and (teFer in C.Tech) and
      WildHerbNear(C, 8, 3) then
    begin
      AddInno(C, IN_ARBALETE);
      Exit
    end;
    if (not KindKnown(IN_PARCHEMIN)) and (tEcrit in C.Tech) and
      (FDayLight < PARCHEMIN_NUIT) and HutNear(C.X, C.Y, 4) then
    begin
      AddInno(C, IN_PARCHEMIN);
      Exit
    end;
    if (not KindKnown(IN_ARMURE)) and (teMetal in C.Tech) and (C.SPred <> nil)
      and FireNear(C.X, C.Y, 5) then
    begin
      AddInno(C, IN_ARMURE);
      Exit
    end;
  end;

  // ── ÈRE 6 ──
  if EreCourante >= 6 then
  begin
    if (not KindKnown(IN_LUNETTE)) and (teOptique in C.Tech) and
      (FDayLight < LUNETTE_NUIT) then
    begin
      AddInno(C, IN_LUNETTE);
      Exit
    end;
    if (not KindKnown(IN_VIOLON)) and (SapienNearCount(C, 6) >= VIOLON_FOULE) and
      (FDayLight < VIOLON_NUIT) then
    begin
      AddInno(C, IN_VIOLON);
      Exit
    end;
    if (not KindKnown(IN_CARMARINE)) and (tNav in C.Tech) and (tEcrit in C.Tech)
    then
    begin
      AddInno(C, IN_CARMARINE);
      Exit
    end;
  end;
    // ── ÈRE 7-8 — la modernité (lampion, radio, métro, aspirine, frigo, avion) ──
  if EreCourante >= 7 then begin

    // Lampion : l'électricité rencontre la nuit près des maisons
    // — l'idée : pourquoi brûler de l'huile quand le courant coule ?
    if (not KindKnown(IN_LAMPION)) and (teElectricite in C.Tech) and
       (FDayLight < 0.75) and HutNear(C.X, C.Y, 4) then
      begin AddInno(C, IN_LAMPION); Exit end;

    // Radio : le télégraphe filait les mots sur les fils — et si on
    // les jetait dans l'air ? Naît dans les foules (il faut des oreilles)
    if (not KindKnown(IN_RADIO)) and (teTelegraphe in C.Tech) and
       (teElectricite in C.Tech) and (SapienNearCount(C, 6) >= RADIO_FOULE) then
      begin AddInno(C, IN_RADIO); Exit end;

    // Métro : la ville est trop dense — creuser sous elle
    if (not KindKnown(IN_METRO)) and (teFerroviaire in C.Tech) and
       (C.HomeH <> nil) and (C.HomeH.Ville <> nil) and
       (C.HomeH.Ville.Niveau >= 2) and (Huts.Count >= 20) then
      begin AddInno(C, IN_METRO); Exit end;

    // Aspirine : la médecine moderne au point — soulager à volonté
    if (not KindKnown(IN_ASPIRINE)) and (teMedMod in C.Tech) and
       (teVaccination in C.Tech) and (C.Cult > 0.70) then
      begin AddInno(C, IN_ASPIRINE); Exit end;

    // Frigo : conserver — le grenier qui ne pourrit plus
    // (naît chez qui a connu la faim : un souvenir de nourriture, et le froid)
    if (not KindKnown(IN_FRIGO)) and (teElectricite in C.Tech) and
       (C.HomeH <> nil) and (C.HomeH.Stock > 5) then
      begin AddInno(C, IN_FRIGO); Exit end;

    // Avion : la caravelle était au-dessus des vagues — celle-ci au-dessus de tout
    if (not KindKnown(IN_AVION)) and (tePoudre in C.Tech) and
       (teCaravelles in C.Tech) and (teInformatique in C.Tech) then
      begin AddInno(C, IN_AVION); Exit end;
  end;
end;

function InnoFull(I: Integer): string;
begin
  if (I < 0) or (I > High(InnoLog)) then
    Exit('?');
  if InnoLog[I].Mot <> '' then
    Result := Format('%s «%s» de %s', [InnoLog[I].Base, InnoLog[I].Mot,
      InnoLog[I].Who])
  else
    Result := Format('%s de %s', [InnoLog[I].Base, InnoLog[I].Who]);
end;

end.

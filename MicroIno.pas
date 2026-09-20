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
  NINNO = 25;
  IN_BROCHETTE = 0;
  IN_TAMBOUR   = 1;
  IN_HOTTE     = 2;
  IN_PARURE    = 3;
  IN_FILET     = 4;
  IN_PEAUSS    = 5;
  IN_TORCHE    = 6;
  IN_FUMEE     = 7;
  IN_PIEGE     = 8;
  IN_APPENTIS  = 9;
  IN_BOUGIE    = 10;   // ère 2
  IN_CHARR     = 11;
  IN_FOUR      = 12;
  IN_HORLOGE   = 13;   // ère 3
  IN_BOSSOLE   = 14;
  IN_THEATRE   = 15;
  IN_AMPHORE   = 16;   // ère 4
  IN_SERPE     = 17;
  IN_FOSSE     = 18;
  IN_ARBALETE  = 19;   // ère 5
  IN_PARCHEMIN = 20;
  IN_ARMURE    = 21;
  IN_LUNETTE   = 22;   // ère 6
  IN_VIOLON    = 23;
  IN_CARMARINE = 24;

type
  TInnov = record
    Kind: Integer;
    Base: string;
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

const
  INNOBASE: array[0..NINNO - 1] of string =
    ('brochette','tambour','hotte','parure','filet',
     'peausserie','torche','fumée','piège','appentis',
     'bougie','charrette','four','horloge','boussole','théâtre',
     'amphore','serpe','fosse','arbalète','parchemin','armure',
     'lunette','violon','carte marine');

function HasInno(C: TCreature; K: Integer): Boolean;
begin
  Result := (K >= 0) and (K < NINNO) and ((C.InnoK and (1 shl K)) <> 0);
end;

procedure GiveInno(C: TCreature; K: Integer);
begin
  if (K >= 0) and (K < NINNO) then C.InnoK := C.InnoK or (1 shl K);
end;

procedure ResetInno;
begin
  SetLength(InnoLog, 0);
end;

function InnoAllMask: Integer;
var I: Integer;
begin
  Result := 0;
  for I := 0 to High(InnoLog) do
    Result := Result or (1 shl InnoLog[I].Kind);
end;

function KindKnown(K: Integer): Boolean;
var I: Integer;
begin
  Result := False;
  for I := 0 to High(InnoLog) do
    if InnoLog[I].Kind = K then begin Result := True; Exit end;
end;

function FireNear(X, Y, R: Single): Boolean;
var I: Integer;
begin
  Result := False;
  for I := 0 to Huts.Count - 1 do
    if Huts[I].Fire and (Sqr(Huts[I].X - X) + Sqr(Huts[I].Y - Y) < Sqr(R)) then
      begin Result := True; Exit end;
end;

function HutNear(X, Y, R: Single): Boolean;
var I: Integer;
begin
  Result := False;
  for I := 0 to Huts.Count - 1 do
    if Sqr(Huts[I].X - X) + Sqr(Huts[I].Y - Y) < Sqr(R) then
      begin Result := True; Exit end;
end;

function WaterNear(C: TCreature; R: Integer): Boolean;
var DX, DY, K: Integer;
begin
  Result := True;
  for DY := -R to R do
    for DX := -R to R do begin
      K := CellIdx(C.X + DX, C.Y + DY);
      if (K >= 0) and (TerrType[K] <= T_SHAL) then Exit;
    end;
  Result := False;
end;

function MeanOrn: Single;
var I, N: Integer;
begin
  Result := 0; N := 0;
  for I := 0 to Creatures.Count - 1 do
    if Creatures[I].Alive and (Creatures[I].Kind = 2) then begin
      Result := Result + Creatures[I].Orn; Inc(N);
    end;
  if N > 0 then Result := Result / N else Result := 0;
end;

function WildHerbNear(C: TCreature; R, MinN: Integer): Boolean;
var N: Integer; O: TCreature;
begin
  N := 0;
  CollectNear(C.X, C.Y, R);
  for O in NB do
    if O.Alive and (O.Kind = 0) and (not O.Dom) then Inc(N);
  Result := N >= MinN;
end;

function SapienNearCount(C: TCreature; R: Single): Integer;
var N: Integer; O: TCreature;
begin
  N := 0;
  CollectNear(C.X, C.Y, R);
  for O in NB do
    if O.Alive and (O.Kind = 2) and (O <> C) then Inc(N);
  Result := N;
end;

procedure AddInno(C: TCreature; K: Integer);
var N, W: Integer;
begin
  N := Length(InnoLog);
  SetLength(InnoLog, N + 1);
  InnoLog[N].Kind := K;
  InnoLog[N].Base := INNOBASE[K];
  if (C.Word >= 0) and (C.Word <= 3) then W := C.Word else W := Random(4);
  InnoLog[N].Word := W;
  InnoLog[N].Who := C.Name;
  InnoLog[N].Day := DayCount;
  GiveInno(C, K);
  Toast(Format(L(118), [C.Name, InnoFull(N)]));
  ChronAdd(CK_INNO, InnoFull(N));
  if (EreCourante >= 3) and (K >= IN_HORLOGE) then
    AudioBell(Round(C.X), Round(C.Y));
end;

procedure TryInventMinor(C: TCreature);
var K: Integer;
begin
  if (C.Kind <> 2) or (C.Age <= CHILDHOOD) or (C.Cult < 0.30) then Exit;
  if Random >= INNO_CHANCE * IfThen(PeopleHas(teCorporations), 1.5, 1.0) then Exit;

  // sans feu, seules les inventions "pré-feu" sont possibles
  if not (tFeu in C.Tech) then begin
    if (not KindKnown(IN_HOTTE)) and (CellIdx(C.X, C.Y) >= 0) and
       (TerrType[CellIdx(C.X, C.Y)] = T_FOR) then
      begin AddInno(C, IN_HOTTE); Exit end;
    if (not KindKnown(IN_PARURE)) and (MeanOrn > 0.55) then
      begin AddInno(C, IN_PARURE); Exit end;
    if (not KindKnown(IN_TAMBOUR)) and WaterNear(C, 2) then
      for K := 0 to High(C.Mem) do
        if C.Mem[K].K = 0 then begin AddInno(C, IN_TAMBOUR); Exit end;
    Exit;
  end;

  if (not KindKnown(IN_BROCHETTE)) and (FDayLight < 0.45) and
     (C.Energy < C.MaxE * 0.5) and FireNear(C.X, C.Y, 6) then
    begin AddInno(C, IN_BROCHETTE); Exit end;
  if (not KindKnown(IN_FILET)) and (tPeche in C.Tech) and IsWater(C.X, C.Y) then
    begin AddInno(C, IN_FILET); Exit end;
  if (not KindKnown(IN_PEAUSS)) and (FDayLight < 0.30) and HutNear(C.X, C.Y, 4) then
    begin AddInno(C, IN_PEAUSS); Exit end;
  if (not KindKnown(IN_TORCHE)) and (FDayLight < 0.45) and FHomeSet and
     (Sqr(C.X - FHomeX) + Sqr(C.Y - FHomeY) > 225) then
    begin AddInno(C, IN_TORCHE); Exit end;
  if (not KindKnown(IN_FUMEE)) and (C.SPred <> nil) and FireNear(C.X, C.Y, 6) then
    begin AddInno(C, IN_FUMEE); Exit end;
  if (not KindKnown(IN_PIEGE)) and (CellIdx(C.X, C.Y) >= 0) and
     (TerrType[CellIdx(C.X, C.Y)] = T_FOR) and WildHerbNear(C, 8, 4) then
    begin AddInno(C, IN_PIEGE); Exit end;
  if (not KindKnown(IN_APPENTIS)) and (tStock in C.Tech) and (Huts.Count >= 3) then
    begin AddInno(C, IN_APPENTIS); Exit end;

  // ── ÈRE 2 ──
  if EreCourante >= 2 then begin
    if (not KindKnown(IN_BOUGIE)) and (tEcrit in C.Tech) and
       (FDayLight < 0.35) and HutNear(C.X, C.Y, 4) then
      begin AddInno(C, IN_BOUGIE); Exit end;
    if (not KindKnown(IN_CHARR)) and (teRoue in C.Tech) and FireNear(C.X, C.Y, 5) then
      begin AddInno(C, IN_CHARR); Exit end;
    if (not KindKnown(IN_FOUR)) and (tStock in C.Tech) and FireNear(C.X, C.Y, 5) then
      begin AddInno(C, IN_FOUR); Exit end;
  end;

  // ── ÈRE 3 ──
  if EreCourante >= 3 then begin
    if (not KindKnown(IN_HORLOGE)) and (teMaths in C.Tech) then
      begin AddInno(C, IN_HORLOGE); Exit end;
    if (not KindKnown(IN_BOSSOLE)) and (teAstronomie in C.Tech) and
       (FDayLight < 0.35) and FHomeSet and
       (Sqr(C.X - FHomeX) + Sqr(C.Y - FHomeY) > 225) then
      begin AddInno(C, IN_BOSSOLE); Exit end;
    if (not KindKnown(IN_THEATRE)) and (SapienNearCount(C, 6) >= 5) then
      begin AddInno(C, IN_THEATRE); Exit end;
  end;

  // ── ÈRE 4 ──
  if EreCourante >= 4 then begin
    if (not KindKnown(IN_AMPHORE)) and (tStock in C.Tech) and (Huts.Count >= 4) then
      begin AddInno(C, IN_AMPHORE); Exit end;
    if (not KindKnown(IN_SERPE)) and (tAgri in C.Tech) and (CellIdx(C.X, C.Y) >= 0) and
       (TerrType[CellIdx(C.X, C.Y)] = T_FOR) then
      begin AddInno(C, IN_SERPE); Exit end;
    if (not KindKnown(IN_FOSSE)) and (Huts.Count >= 5) and (C.SPred <> nil) then
      begin AddInno(C, IN_FOSSE); Exit end;
  end;

  // ── ÈRE 5 ──
  if EreCourante >= 5 then begin
    if (not KindKnown(IN_ARBALETE)) and (teFer in C.Tech) and WildHerbNear(C, 8, 3) then
      begin AddInno(C, IN_ARBALETE); Exit end;
    if (not KindKnown(IN_PARCHEMIN)) and (tEcrit in C.Tech) and
       (FDayLight < 0.35) and HutNear(C.X, C.Y, 4) then
      begin AddInno(C, IN_PARCHEMIN); Exit end;
    if (not KindKnown(IN_ARMURE)) and (teMetal in C.Tech) and
       (C.SPred <> nil) and FireNear(C.X, C.Y, 5) then
      begin AddInno(C, IN_ARMURE); Exit end;
  end;

  // ── ÈRE 6 ──
  if EreCourante >= 6 then begin
    if (not KindKnown(IN_LUNETTE)) and (teOptique in C.Tech) and (FDayLight < 0.35) then
      begin AddInno(C, IN_LUNETTE); Exit end;
    if (not KindKnown(IN_VIOLON)) and (SapienNearCount(C, 6) >= 4) and (FDayLight < 0.4) then
      begin AddInno(C, IN_VIOLON); Exit end;
    if (not KindKnown(IN_CARMARINE)) and (tNav in C.Tech) and (tEcrit in C.Tech) then
      begin AddInno(C, IN_CARMARINE); Exit end;
  end;
end;

function InnoFull(I: Integer): string;
begin
  if (I < 0) or (I > High(InnoLog)) then Exit('?');
  if (InnoLog[I].Word >= 0) and (InnoLog[I].Word <= 3) then
    Result := Format('%s %s de %s',
      [InnoLog[I].Base, WORDS[InnoLog[I].Word], InnoLog[I].Who])
  else
    Result := Format('%s de %s', [InnoLog[I].Base, InnoLog[I].Who]);
end;

end.

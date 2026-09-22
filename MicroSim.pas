                      unit MicroSim;

{ Microcosme — créatures, sapiens, boucle DoStep, thread.
  v15.1 : ères 1-6, i18n complet, urbain délégué à MicroVilles,
  ★AUDIT : filets nommés par section dans DoStep (StepPlants/StepFish/
  StepEvo/RebuildGrid/VeilleUrbaine), gardes Morte sur le broutage,
  cooldown des cris (SpeechCD), CId uniques (gNextId). }

interface

uses
  System.SysUtils, System.Classes, System.Math, System.Generics.Collections,
  System.Diagnostics, System.SyncObjs,
  MicroTypes, MicroBrain, MicroConfig, MicroEvo, MicroIno, MicroChrono;

procedure SpawnCreature(Kind: Integer; X, Y: Single;
  Parent, Parent2: TCreature; Gen: Integer);
procedure Kill(C: TCreature; const Cause: string);
procedure DoStep(DT: Single);
procedure GiveTech(C: TCreature; Code: TEcode);

type
  TSimThread = class(TThread)
  protected
    procedure Execute; override;
  end;

implementation

{$OVERFLOWCHECKS OFF}
{$RANGECHECKS OFF}
{$RANGECHECKS ON}   // DIAGNOSTIC TEMPORAIRE — retirer après

uses MicroRender, MicroEre, MicroLang, MicroVilles, MicroAudio;

var
  Heard: array[0..3] of Single;
  FireT: Single = 0;
  gNextId: Integer = 1;        // ★ identifiants uniques des créatures

function NearestHutDist(X, Y: Single): Single;
var I: Integer; D: Single;
begin
  Result := 1e9;
  if Huts = nil then Exit;
  for I := 0 to Huts.Count - 1 do begin
    D := Sqrt(Sqr(Huts[I].X - X) + Sqr(Huts[I].Y - Y));
    if D < Result then Result := D;
  end;
end;

function NearestHut(X, Y, R: Single): THut;
var I: Integer; D: Single;
begin
  Result := nil;
  if Huts = nil then Exit;
  D := Sqr(R);
  for I := 0 to Huts.Count - 1 do
    if Sqr(Huts[I].X - X) + Sqr(Huts[I].Y - Y) < D then
      Result := Huts[I];
end;

function NearWaterRay(C: TCreature; R: Integer): Boolean;
var X0, X1, Y0, Y1, X, Y: Integer;
begin
  Result := False;
  for Y := Max(0, Trunc(C.Y - R)) to Min(GH - 1, Trunc(C.Y + R)) do
    for X := Max(0, Trunc(C.X - R)) to Min(GW - 1, Trunc(C.X + R)) do
      if TerrType[Y * GW + X] <= T_SHAL then begin Result := True; Exit end;
end;

function FindFish(C: TCreature): TFish;
var I: Integer; F: TFish; D: Single;
   InWater: Boolean;
begin
  Result := nil;
  InWater := IsWater(C.X, C.Y);
  for I := 0 to Fishes.Count - 1 do begin
    F := Fishes[I];
    if F.Deep and (not InWater) then Continue;
    D := Sqr(F.X - C.X) + Sqr(F.Y - C.Y);
    if D < Sqr(2.6) then Result := F;
  end;
end;

function DomCount(H: THut): Integer;
var I: Integer;
begin
  Result := 0;
  for I := 0 to Creatures.Count - 1 do
    if Creatures[I].Alive and (Creatures[I].Kind = 0) and
       Creatures[I].Dom and (Creatures[I].HomeH = H) then Inc(Result);
end;

procedure SpawnCreature(Kind: Integer; X, Y: Single;
  Parent, Parent2: TCreature; Gen: Integer);
var C: TCreature; T, I: Integer;
   RSp, RSe, RSz: array[0..1] of Single;
   Src: TCreature;
begin
  for T := 1 to 10 do
    if Walkable(X, Y) then Break
    else begin X := Random(GW); Y := Random(GH) end;
  if not Walkable(X, Y) then Exit;

  C := TCreature.Create;
  C.Kind := Kind; C.X := X; C.Y := Y;
  C.Angle := Random * TAU; C.WAngle := Random * TAU;
  case Kind of
    0: begin RSp[0]:=2.2; RSp[1]:=5.4; RSe[0]:=4; RSe[1]:=9; RSz[0]:=0.6; RSz[1]:=1.5 end;
    1: begin RSp[0]:=3.0; RSp[1]:=6.4; RSe[0]:=5; RSe[1]:=11; RSz[0]:=0.7; RSz[1]:=1.5 end;
  else begin RSp[0]:=2.6; RSp[1]:=5.6; RSe[0]:=6; RSe[1]:=12; RSz[0]:=0.7; RSz[1]:=1.3 end;
  end;
  if Parent <> nil then begin
    if (Parent2 <> nil) and (Random < 0.5) then Src := Parent2 else Src := Parent;
    C.Sp := ClampF(Src.Sp * Exp(RN * 0.15), RSp[0], RSp[1]);
    C.Se := ClampF(Src.Se * Exp(RN * 0.15), RSe[0], RSe[1]);
    C.Sz := ClampF(Src.Sz * Exp(RN * 0.13), RSz[0], RSz[1]);
    if Kind = 2 then begin
      if (Parent2 <> nil) and (Random < 0.5) then Src := Parent2 else Src := Parent;
      C.Orn := ClampF(Src.Orn * Exp(RN * 0.18), 0.03, 1);
      C.Pref := ClampF(Src.Pref + RN * 0.12, 0, 1);
      C.Hue := Frac(Src.Hue + RN * 0.05);
    end else begin
      C.Orn := 0; C.Pref := 0; C.Hue := 0;
    end;
  end else begin
    C.Sp := RSp[0] + Random * (RSp[1] - RSp[0]);
    C.Se := RSe[0] + Random * (RSe[1] - RSe[0]);
    C.Sz := RSz[0] + Random * (RSz[1] - RSz[0]);
    if Kind = 2 then begin
      C.Orn := 0.08 + Random * 0.27;
      C.Pref := 0.10 + Random * 0.50;
      C.Hue := Random;
    end else begin
      C.Orn := 0; C.Pref := 0; C.Hue := 0;
    end;
  end;
  C.HueCol := HueColor(C.Hue);
  case Kind of
    0: begin
         C.Energy := 55 + Random * 20; C.MaxE := 60 + 52 * C.Sz;
         C.MaxAge := 150 + Random * 90; Inc(UidH); C.Name := 'H-' + IntToStr(UidH);
         if Parent <> nil then
           C.Tame := ClampF(Parent.Tame + RN * 0.07, 0.01, 0.95)
         else
           C.Tame := 0.05 + Random * 0.20;
       end;
    1: begin
         C.Energy := 65 + Random * 20; C.MaxE := 80 + 60 * C.Sz;
         C.MaxAge := 230 + Random * 110; Inc(UidP); C.Name := 'P-' + IntToStr(UidP);
         C.Tame := 0;
       end;
  else begin
         C.Energy := 75 + Random * 20; C.MaxE := 95 + 65 * C.Sz;
         C.MaxAge := 260 + Random * 120; Inc(UidS); C.Name := MakeName;
         C.Tame := 0;
       end;
  end;
  C.Age := 0; C.Gen := Gen; C.Alive := True; C.State := L(50);
  C.CId := gNextId; Inc(gNextId);                                     // ★CId uniques
  if Parent <> nil then C.ParentId := Parent.CId else C.ParentId := 0;
  C.ThinkT := Random * 0.3; C.RepCd := 6 + Random * 6;
  C.Born := FSimTime;
  C.Word := -1; C.WordT := 0;
  C.SPred := nil; C.SFood := nil; C.SHerb := nil; C.GuardC := nil;
  C.SPeer := nil;
  C.Mentor := nil; C.MentorT := 0; C.BuildCd := 0;
  C.InnoK := 0;
  if Kind = 2 then begin
    if Parent <> nil then begin
      C.Cult := ClampF(Parent.Cult * (0.88 + Random * 0.10), 0, 0.95);
      if (Parent2 <> nil) and (Random < 0.5) then
        C.Cult := Max(C.Cult, ClampF(Parent2.Cult * (0.88 + Random * 0.10), 0, 0.95));
    end else
      C.Cult := 0.18 + Random * 0.12;
  end else
    C.Cult := 0;
  C.Trust := 0; C.Dom := False; C.HomeH := nil; C.MilkCd := 0;
  C.CatchT := 0;
  SetLength(C.Mem, 0);
  if Kind = 2 then begin
    C.Tech := [];
    C.InventT := 2 + Random * 3;
    if Parent <> nil then
      C.MutRate := ClampF(Parent.MutRate * Exp(RN * 0.10), 0.5, 2.0)
    else
      C.MutRate := 1.0;
    if Parent <> nil then C.InnoK := Parent.InnoK;
    if Parent2 <> nil then C.InnoK := C.InnoK or Parent2.InnoK;
    SetLength(C.Net, NW);
    if Parent <> nil then begin
      for I := 0 to NW - 1 do C.Net[I] := Parent.Net[I];
      MutateNet(C.Net, C.MutRate * CfgMut);
    end else FillInnateNet(C.Net);
    C.Dna := Copy(C.Net, 0, NW);
    SetLength(C.Inp, NIN); SetLength(C.Hid, NHID); SetLength(C.Hid2, NHID2);
    SetLength(C.Oo, NOUT);
    SetLength(C.PrevOo, NOUT);
    for I := 0 to NOUT - 1 do C.PrevOo[I] := 0;
  end;
  if (Kind = 2) and (Parent <> nil) then begin
    if not FirstBornLogged then begin
      ChronAdd(CK_PEOPLE, Format(L(106), [C.Name]));
      FirstBornLogged := True;
    end;
    if C.Gen > GenMark then begin
      GenMark := C.Gen;
      if GenMark mod 5 = 0 then
        ChronAdd(CK_PEOPLE, Format(L(107), [GenMark, C.Name]));
    end;
  end;
  Creatures.Add(C);
  case Kind of 0: Inc(CountH); 1: Inc(CountP); 2: Inc(CountS) end;
end;

procedure Kill(C: TCreature; const Cause: string);
var O: TCreature;
   k: Integer;
begin
  if not C.Alive then Exit;
  C.Alive := False;
  k := Length(DeathLog);
  SetLength(DeathLog, k + 1);
  DeathLog[k].CId := C.CId;
  DeathLog[k].Name := C.Name;
  DeathLog[k].Cause := Cause;
  DeathLog[k].Day := DayCount;
  DeathLog[k].Gen := C.Gen;
  DeathLog[k].ParentId := C.ParentId;
  case C.Kind of 0: Dec(CountH); 1: Dec(CountP); 2: Dec(CountS); 3: Dec(CountD) end;
  if C.Kind = 2 then
    ChronAdd(CK_LIFE, Format(L(98), [C.Name, Cause, Trunc(C.Age)]));
  if (Cause <> L(101)) and (Cause <> L(102)) and
     (Random < 0.85) and Walkable(C.X, C.Y) then
    AddPlant(C.X, C.Y, 0.35);
  for O in Creatures do
    if O.Alive then begin
      if O.SPred = C then O.SPred := nil;
      if O.TargetC = C then O.TargetC := nil;
      if O.Mentor = C then O.Mentor := nil;
      if O.SHerb = C then O.SHerb := nil;
      if O.GuardC = C then O.GuardC := nil;
      if O.Master = C then O.Master := nil;
      if O.SPeer = C then O.SPeer := nil;
    end;
  if FSelected = C then FSelected := nil;
end;

procedure ThinkHerb(C: TCreature);
var O: TCreature; Threat, Peer: TCreature;
   TD, PD, D, PA, S2: Single; CI: Integer;
begin
  C.Fleeing := False;
  if C.Dom and (C.HomeH <> nil) then begin
    Threat := nil; TD := MaxSingle;
    S2 := C.Se * C.Se;
    CollectNear(C.X, C.Y, C.Se);
    for O in NB do
      if O.Alive and (O.Kind = 1) then begin
        D := D2(C.X, C.Y, O.X, O.Y);
        if (D < S2) and (D < TD) then begin TD := D; Threat := O end;
      end;
    if Threat <> nil then begin
      C.Fleeing := True; C.State := L(137); C.TargetP := nil;
      C.FleeA := ArcTan2(C.HomeH.Y - C.Y, C.HomeH.X - C.X);
      Exit;
    end;
    C.TargetP := nil; C.State := L(54);
    if Sqr(C.X - C.HomeH.X) + Sqr(C.Y - C.HomeH.Y) > 100 then
      C.WAngle := ArcTan2(C.HomeH.Y - C.Y, C.HomeH.X - C.X)
    else if C.Energy < C.MaxE * 0.9 then begin
      C.TargetP := FindPlant(C);
      if C.TargetP <> nil then
        C.WAngle := ArcTan2(C.TargetP.Y - C.Y, C.TargetP.X - C.X)
      else C.WAngle := C.WAngle + (Random - 0.5) * 1.2;
    end else
      C.WAngle := C.WAngle + (Random - 0.5) * 0.8;
    Exit;
  end;
  Threat := nil; Peer := nil; TD := MaxSingle; PD := MaxSingle;
  S2 := C.Se * C.Se;
  CollectNear(C.X, C.Y, C.Se);
  for O in NB do begin
    if (not O.Alive) or (O = C) then Continue;
    D := D2(C.X, C.Y, O.X, O.Y);
    if (O.Kind = 1) and (D < S2) and (D < TD) then begin TD := D; Threat := O end
    else if (O.Kind = 0) and (D < PD) then begin PD := D; Peer := O end;
  end;
  if Threat <> nil then begin
    CI := CellIdx(C.X, C.Y);
    if (CI >= 0) and (TerrType[CI] = T_FOR) and (TD > 4.8 * 4.8) then begin
      C.State := L(53); C.TargetP := nil; Exit;
    end;
    C.Fleeing := True; C.State := L(52); C.TargetP := nil;
    C.FleeA := ArcTan2(C.Y - Threat.Y, C.X - Threat.X);
    Exit;
  end;
  if C.Energy < C.MaxE * 0.92 then begin
    C.TargetP := FindPlant(C);
    if C.TargetP <> nil then C.State := L(51) else C.State := L(50);
    if C.TargetP = nil then begin
      if (Peer <> nil) and (PD < 100) then begin
        PA := ArcTan2(Peer.Y - C.Y, Peer.X - C.X);
        C.WAngle := C.WAngle + NormA(PA - C.WAngle) * 0.35;
      end else C.WAngle := C.WAngle + (Random - 0.5) * 2.2;
    end;
  end else begin
    C.TargetP := nil; C.State := L(50);
    if (Peer <> nil) and (PD < 100) then begin
      PA := ArcTan2(Peer.Y - C.Y, Peer.X - C.X);
      C.WAngle := C.WAngle + NormA(PA - C.WAngle) * 0.2;
    end else C.WAngle := C.WAngle + (Random - 0.5) * 1.2;
  end;
end;

function DogNear(X, Y: Single): Boolean;
var I: Integer;
begin
  Result := False;
  for I := 0 to Creatures.Count - 1 do
    if Creatures[I].Alive and (Creatures[I].Kind = 3) and
       (Sqr(Creatures[I].X - X) + Sqr(Creatures[I].Y - Y) < 36) then
      Exit(True);
end;

procedure ThinkPred(C: TCreature);
var O: TCreature; Best: TCreature; BD, D, VR: Single; CI: Integer;
   P: TPlant;
begin
  Best := nil; BD := MaxSingle;
  CollectNear(C.X, C.Y, C.Se);
  for O in NB do begin
    if not O.Alive then Continue;
    if O.Kind = 0 then begin
      CI := CellIdx(O.X, O.Y);
      if (CI >= 0) and (TerrType[CI] = T_FOR) then VR := C.Se * 0.55 else VR := C.Se;
      D := D2(C.X, C.Y, O.X, O.Y);
      if (D < VR * VR) and (D < BD) then begin BD := D; Best := O end;
    end
    else if O.Kind = 2 then begin
      if NearestHutDist(O.X, O.Y) < IfThen(HasInno(O, IN_FOSSE), 6.0, 4.5) then Continue;
      if NearFireHut(O.X, O.Y) then Continue;
      if DogNear(O.X, O.Y) then Continue;
      D := D2(C.X, C.Y, O.X, O.Y) * 6.5;
      if HasInno(O, IN_FUMEE) then D := D * 1.8;
      if (D < C.Se * C.Se * 0.55) and (D < BD) then begin BD := D; Best := O end;
    end;
  end;
  if Best <> nil then begin
    C.State := L(72); C.TargetC := Best; C.TargetP := nil;
    C.WAngle := ArcTan2(Best.Y - C.Y, Best.X - C.X);
  end else if C.Energy < C.MaxE * 0.34 then begin
    P := FindPlant(C);
    C.TargetP := P; C.TargetC := nil;
    if P <> nil then begin
      C.State := L(140); C.WAngle := ArcTan2(P.Y - C.Y, P.X - C.X);
    end else begin
      C.State := L(139); C.WAngle := C.WAngle + (Random - 0.5) * 1.5;
    end;
  end else begin
    C.TargetC := nil; C.TargetP := nil; C.State := L(139);
    C.WAngle := C.WAngle + (Random - 0.5) * 1.5;
  end;
end;

procedure StepCreature(C: TCreature; DT: Single);
var Want, Des, Turn, SP, SM, NX, NY, D, Esc, Eff, Gain, Amt, Crowd, Damp: Single;
   T: TPlant; O: TCreature;
begin
  C.Age := C.Age + DT; C.ThinkT := C.ThinkT - DT;
  C.AtkCd := C.AtkCd - DT; C.RepCd := C.RepCd - DT;
  if C.Flash > 0 then C.Flash := Max(0, C.Flash - DT);
  if C.Kind = 0 then begin
    C.MilkCd := C.MilkCd - DT;
    if C.Dom and ((C.HomeH = nil) or
       (Sqr(C.X - C.HomeH.X) + Sqr(C.Y - C.HomeH.Y) > 2600)) then begin
      C.Dom := False; C.HomeH := nil; C.Trust := 0;
      C.State := L(145);
    end;
  end;
  if C.ThinkT <= 0 then begin
    C.ThinkT := 0.22 + Random * 0.18;
    if C.Kind = 0 then ThinkHerb(C) else ThinkPred(C);
  end;
  if (C.TargetP <> nil) and (PlantGrid[C.TargetP.Cell] <> C.TargetP) then C.TargetP := nil;
  if (C.TargetC <> nil) and (not C.TargetC.Alive) then C.TargetC := nil;

  Want := C.WAngle;
  if C.State = L(53) then Des := 0.07
  else if C.Fleeing then begin Want := C.FleeA; Des := C.Sp * 1.07 end
  else if C.TargetC <> nil then begin
    D := Sqrt(D2(C.X, C.Y, C.TargetC.X, C.TargetC.Y));
    if D > 1.05 then begin
      Want := ArcTan2(C.TargetC.Y - C.Y, C.TargetC.X - C.X); Des := C.Sp * 1.08;
    end else Des := 0.08;
  end else if C.TargetP <> nil then begin
    D := Sqrt(D2(C.X, C.Y, C.TargetP.X, C.TargetP.Y));
    if D > 1.05 then begin
      Want := ArcTan2(C.TargetP.Y - C.Y, C.TargetP.X - C.X); Des := C.Sp * 0.95;
    end else Des := 0.08;
  end else Des := C.Sp * (IfThen((C.Kind = 0) and C.Dom, 0.25, 0.35));

  Turn := 5 * DT; if C.Fleeing then Turn := 9 * DT;
  C.Angle := C.Angle + ClampF(NormA(Want - C.Angle), -Turn, Turn);

  SM := 1;
  if Walkable(C.X, C.Y) and (TerrType[CellIdx(C.X, C.Y)] = T_FOR) then SM := 0.7;
  SP := Des * SM;
  NX := C.X + Cos(C.Angle) * SP * DT; NY := C.Y + Sin(C.Angle) * SP * DT;
  if Walkable(NX, NY) then begin C.X := NX; C.Y := NY end
  else if Walkable(NX, C.Y) then begin C.X := NX; C.Angle := C.Angle + (Random - 0.5) * 1.2 end
  else if Walkable(C.X, NY) then begin C.Y := NY; C.Angle := C.Angle + (Random - 0.5) * 1.2 end
  else C.Angle := C.Angle + 2.4 * DT;
  C.X := ClampF(C.X, 0.01, GW - 0.01); C.Y := ClampF(C.Y, 0.01, GH - 0.01);

  if (C.TargetP <> nil) and (not C.TargetP.Morte) then begin        // ★garde Morte
    T := C.TargetP;
    D := Sqrt(D2(C.X, C.Y, T.X, T.Y));
    if D < 1.05 then begin
      C.BiteT := C.BiteT - DT;
      if C.BiteT <= 0 then begin
        C.BiteT := 0.24;
        Amt := Min(0.18, T.S); T.S := T.S - Amt;
        if C.Kind = 0 then Eff := 1 else Eff := 0.5;
        C.Energy := Min(C.MaxE, C.Energy + Amt * 32 * Eff);
      end;
    end;
  end;
  if (C.TargetP <> nil) and C.TargetP.Morte then C.TargetP := nil;  // ★purge différée
  if (C.TargetC <> nil) and (not C.TargetC.Alive) then C.TargetC := nil;

  if C.Kind = 0 then
    C.Energy := C.Energy - (0.45 + 0.10 * Des + 0.32 * C.Sz) * DT
  else
    C.Energy := C.Energy - (0.48 + 0.12 * Des + 0.50 * C.Sz) * DT;

  if (C.Energy > IfThen(C.Kind = 0, 76, 90)) and (C.Age > 8) and (C.RepCd <= 0) then
    if ((C.Kind = 0) and (CountH < MAXH)) or ((C.Kind = 1) and (CountP < MAXC)) then begin
      Crowd := CrowdCount(C, IfThen(C.Kind = 0, 5, 7));
      if C.Kind = 0 then Damp := 1 / (1 + Crowd * 0.22)
                    else Damp := 1 / (1 + Crowd * 0.45);
      if Random < Damp * DT * IfThen(C.Kind = 0, 0.85, 0.28) *
         IfThen((C.Kind = 0) and C.Dom, 1.5, 1) then begin
        SpawnCreature(C.Kind, C.X + Cos(C.Angle) * 1.3, C.Y + Sin(C.Angle) * 1.3,
                      C, nil, C.Gen + 1);
        if C.Kind = 0 then begin
          Creatures.Last.Energy := 38; C.Energy := C.Energy - 46; C.RepCd := 7;
          if C.Dom then begin
            Creatures.Last.Tame := ClampF(C.Tame + Abs(RN * 0.05) + 0.015, 0.05, 0.97);
            Creatures.Last.Dom := True;
            Creatures.Last.HomeH := C.HomeH;
          end;
        end else begin
          Creatures.Last.Energy := 45; C.Energy := C.Energy - 62; C.RepCd := 17;
        end;
      end else C.RepCd := 2;
    end;

  if C.Alive then begin
    if C.Energy <= 0 then Kill(C, L(99))
    else if C.Age > C.MaxAge then Kill(C, L(100));
  end;
end;

procedure StepDog(C: TCreature; DT: Single);
var Des, SP, SM, NX, NY, TD: Single; O, M: TCreature;
begin
  C.Age := C.Age + DT;
  C.RepCd := C.RepCd - DT;
  if C.Flash > 0 then C.Flash := Max(0, C.Flash - DT);
  if (C.Master <> nil) and (not C.Master.Alive) then C.Master := nil;
  if C.Master = nil then begin
    M := nil; TD := 625;
    CollectNear(C.X, C.Y, 25);
    for O in NB do
      if O.Alive and (O.Kind = 2) and
         (D2(C.X, C.Y, O.X, O.Y) < TD) then begin
        TD := D2(C.X, C.Y, O.X, O.Y);
        M := O;
      end;
    C.Master := M;
  end;
  if C.Master = nil then begin
    C.State := L(146);
    C.WAngle := C.WAngle + (Random - 0.5) * 1.5;
    Des := C.Sp * 0.3;
  end else begin
    TD := D2(C.X, C.Y, C.Master.X, C.Master.Y);
    if TD > 4 then begin
      C.State := L(147);
      C.WAngle := ArcTan2(C.Master.Y - C.Y, C.Master.X - C.X);
      Des := C.Sp * (0.6 + Min(0.55, Sqrt(TD) / 24));
    end else begin
      C.State := L(148);
      C.WAngle := C.WAngle + (Random - 0.5) * 2.0;
      Des := C.Sp * 0.22;
      C.Energy := Min(C.MaxE, C.Energy + 1.1 * DT);
    end;
  end;
  C.Angle := C.Angle + ClampF(NormA(C.WAngle - C.Angle), -7 * DT, 7 * DT);
  SM := 1;
  if Walkable(C.X, C.Y) and (TerrType[CellIdx(C.X, C.Y)] = T_FOR) then SM := 0.75;
  SP := Des * SM;
  NX := C.X + Cos(C.Angle) * SP * DT; NY := C.Y + Sin(C.Angle) * SP * DT;
  if Walkable(NX, NY) then begin C.X := NX; C.Y := NY end
  else C.Angle := C.Angle + 2.4 * DT;
  C.X := ClampF(C.X, 0.01, GW - 0.01); C.Y := ClampF(C.Y, 0.01, GH - 0.01);
  C.Energy := C.Energy - 0.42 * DT;
  if C.Energy <= 0 then Kill(C, L(99))
  else if C.Age > C.MaxAge then Kill(C, L(100));
end;

procedure SenseSapien(C: TCreature);
var I: Integer; FB: TPlant; Peer, Pred, Herb, O: TCreature;
   PD2, QD2, HD2, D, K, SeEff: Single; Rel: Single;
   SrcK, SrcDx, SrcDy: Single;
   MD, MF: Integer; MDD2, MFD2: Single;
   Hunger, Mk: Single;
begin
  for I := 0 to NIN - 1 do C.Inp[I] := 0;
  C.Inp[0] := 1;
  C.Inp[1] := ClampF(C.Energy / (C.MaxE * IfThen(teAnatomie in C.Tech, 1.08, 1.0)), 0, 1);
  C.Inp[2] := FDayLight;
  FB := FindPlant(C);
  if FB <> nil then begin
    Rel := NormA(ArcTan2(FB.Y - C.Y, FB.X - C.X) - C.Angle);
    D := Sqrt(D2(C.X, C.Y, FB.X, FB.Y));
    C.Inp[3] := Cos(Rel); C.Inp[4] := Sin(Rel);
    C.Inp[5] := 1 - D / C.Se;
  end;
  Peer := nil; Pred := nil; Herb := nil;
  PD2 := MaxSingle; QD2 := MaxSingle; HD2 := MaxSingle;
  for I := 0 to 3 do Heard[I] := 0;
  SrcK := 0; SrcDx := 0; SrcDy := 0;
  CollectNear(C.X, C.Y, SIGR);
  SeEff := C.Se * IfThen(teOptique in C.Tech, 1.15, 1.0);
  if (FDayLight < 0.4) and HasInno(C, IN_LUNETTE) then
    SeEff := SeEff * 1.3;
  for O in NB do
    if O.Alive and (O.Kind = 3) and (D2(C.X, C.Y, O.X, O.Y) < 42) then begin
      SeEff := C.Se * 1.8;
      Break;
    end;
  for O in NB do begin
    if (not O.Alive) or (O = C) then Continue;
    D := D2(C.X, C.Y, O.X, O.Y);
    if O.Kind = 2 then begin
      if (D < Sqr(C.Se)) and (D < PD2) then begin PD2 := D; Peer := O end;
      if (O.WordT > 0) and (O.Word >= 0) and (O.Word <= 3) and
         (D < Sqr(SIGR * IfThen(HasInno(O, IN_TAMBOUR), 2.0, 1.0))) then begin
        K := 1 - Sqrt(D) / (SIGR * IfThen(HasInno(O, IN_TAMBOUR), 2.0, 1.0));
        if K > Heard[O.Word] then begin
          Heard[O.Word] := K;
          if K > SrcK then begin
            SrcK := K; SrcDx := O.X - C.X; SrcDy := O.Y - C.Y;
          end;
        end;
      end;
    end
    else if (O.Kind = 1) and (D < Sqr(SeEff)) and (D < QD2) then begin
      QD2 := D; Pred := O;
    end
    else if (O.Kind = 0) and (D < Sqr(C.Se)) and (D < HD2) then begin
      HD2 := D; Herb := O;
    end;
  end;
  if Peer <> nil then begin
    Rel := NormA(ArcTan2(Peer.Y - C.Y, Peer.X - C.X) - C.Angle);
    C.Inp[6] := Cos(Rel); C.Inp[7] := Sin(Rel);
    C.Inp[8] := 1 - Sqrt(PD2) / C.Se;
  end;
  if Pred <> nil then begin
    Rel := NormA(ArcTan2(Pred.Y - C.Y, Pred.X - C.X) - C.Angle);
    C.Inp[9] := Cos(Rel); C.Inp[10] := Sin(Rel);
    C.Inp[11] := 1 - Sqrt(QD2) / C.Se;
  end;
  for I := 0 to 3 do C.Inp[12 + I] := Heard[I];
  if SrcK > 0 then begin
    Rel := NormA(ArcTan2(SrcDy, SrcDx) - C.Angle);
    C.Inp[16] := Cos(Rel) * SrcK;
    C.Inp[17] := Sin(Rel) * SrcK;
  end;
  MD := -1; MF := -1; MDD2 := 1e9; MFD2 := 1e9;
  for I := 0 to High(C.Mem) do begin
    D := Sqr(C.X - C.Mem[I].X) + Sqr(C.Y - C.Mem[I].Y);
    if C.Mem[I].K = 0 then begin
      if D < MDD2 then begin MDD2 := D; MD := I end;
    end else if D < MFD2 then begin MFD2 := D; MF := I end;
  end;
  if MD >= 0 then begin
    Mk := (1 - Sqrt(MDD2) / 40) * (1 - C.Mem[MD].T / MEMLIFE);
    if Mk > 0 then begin
      Rel := NormA(ArcTan2(C.Mem[MD].Y - C.Y, C.Mem[MD].X - C.X) - C.Angle);
      C.Inp[18] := Cos(Rel) * Mk; C.Inp[19] := Sin(Rel) * Mk; C.Inp[20] := Mk;
    end;
  end;
  if MF >= 0 then begin
    Hunger := 1 - C.Energy / C.MaxE;
    Mk := (1 - Sqrt(MFD2) / 40) * (1 - C.Mem[MF].T / MEMLIFE) * Hunger;
    if Mk > 0 then begin
      Rel := NormA(ArcTan2(C.Mem[MF].Y - C.Y, C.Mem[MF].X - C.X) - C.Angle);
      C.Inp[21] := Cos(Rel) * Mk; C.Inp[22] := Sin(Rel) * Mk; C.Inp[23] := Mk;
    end;
  end;
  C.Inp[33] := 1;
  C.SFood := FB; C.SPred := Pred; C.SHerb := Herb; C.SPeer := Peer;
  C.Fleeing := False;
  if (Pred <> nil) and (QD2 < 13) and (not IsWater(C.X, C.Y)) then begin
    C.Fleeing := True;
    C.FleeA := ArcTan2(C.Y - Pred.Y, C.X - Pred.X);
  end;
end;

procedure LogWord(Wr: Integer; C: TCreature);
begin
  Lex[Wr].N := Lex[Wr].N + 1;
  if C.SPred <> nil then Lex[Wr].Pred := Lex[Wr].Pred + 1;
  if C.SFood <> nil then Lex[Wr].Food := Lex[Wr].Food + 1;
end;

procedure TryBuild(C: TCreature);
var H: THut;
   K: Integer;
   R2: Single;
begin
  if (Huts.Count >= IfThen(teCite in C.Tech, HUTCAP * 2, HUTCAP)) or
     (C.Energy < IfThen(teGeometrie in C.Tech, 42, 62)) or (C.BuildCd > 0) then Exit;
  if not Walkable(C.X, C.Y) then Exit;
  if TerrType[CellIdx(C.X, C.Y)] > T_FOR then Exit;
  if PeopleHas(teCite) then begin
    if NearestHutDist(C.X, C.Y) < 2.0 then Exit;
  end else
    if NearestHutDist(C.X, C.Y) < 7 then Exit;
  for K := 0 to Cities.Count - 1 do begin
    R2 := Sqr(C.X - Cities[K].X) + Sqr(C.Y - Cities[K].Y);
    if (R2 < Sqr(50.0)) and (R2 > Sqr(8.0)) then Exit;
  end;
  C.Energy := C.Energy - 26;
  C.BuildCd := 9;
  H := THut.Create;
  H.X := C.X; H.Y := C.Y; H.Fire := False; H.Cult := False; H.Stock := 0;
  H.Ville := nil;
  Huts.Add(H);
end;

function TechDispo(C: TCreature; Idx: Integer): Boolean;
var i, d: Integer;
begin
  Result := False;
  if (Idx < 0) or (Idx >= TECH_COUNT) then Exit;
  with TECHBASE[Idx] do
  begin
    if Era > EreCourante then Exit;
    if TechInfo[Code].Who <> '' then Exit;
    for i := 0 to 1 do begin
      d := Dep[i];
      if d < 0 then Continue;
      if not HasTech(C.Tech, TECHBASE[d].Code) then Exit;
    end;
    case Code of
      tAgri:  if C.Cult < 0.30 then Exit;
      tStock: if C.Cult < 0.34 then Exit;
      tPast:  if C.Cult < 0.38 then Exit;
      tPeche: begin
        if C.Cult < 0.30 then Exit;
        if not NearWaterRay(C, 6) then Exit;
      end;
      tNav:   if not NearWaterRay(C, 5) then Exit;
      tEcrit: if C.Cult < 0.50 then Exit;
    end;
  end;
  Result := True;
end;

function TechProba(Idx: Integer): Single;
begin
  case TECHBASE[Idx].Code of
    tFeu:   Result := CfgFeu;
    tAgri:  Result := CfgAgri;
    tStock: Result := CfgStock;
    tPast:  Result := CfgPast;
    tPeche: Result := CfgPeche;
    tNav:   Result := CfgNav;
    tEcrit: Result := CfgEcrit;
  else
    Result := TECHBASE[Idx].P;
  end;
end;

procedure GiveTech(C: TCreature; Code: TEcode);
var T1, T2: string;
begin
  if HasTech(C.Tech, Code) then Exit;
  Include(C.Tech, Code);
  TechInfo[Code].Who := C.Name;
  TechInfo[Code].Day := DayCount;
  TechLost[Code] := False;
  case Code of
    tFeu:   begin T1 := L(84); T2 := L(91) end;
    tAgri:  begin T1 := L(85); T2 := L(92) end;
    tStock: begin T1 := L(86); T2 := L(93) end;
    tPast:  begin T1 := L(87); T2 := L(94) end;
    tPeche: begin T1 := L(88); T2 := L(95) end;
    tNav:   begin T1 := L(89); T2 := L(96) end;
    tEcrit: begin T1 := L(90); T2 := L(97) end;
  else
    T1 := ''; T2 := '';
  end;
  if T1 <> '' then begin
    Toast(Format(T1, [C.Name]));
    ChronAdd(CK_TECH, Format(T2, [C.Name]));
  end else begin
    Toast(Format(L(118), [C.Name, TechNom(Code)]));
    ChronAdd(CK_TECH, Format(L(118), [C.Name, TechNom(Code)]));
  end;
end;

function TechMult(C: TCreature): Single;
begin
  Result := 1.0;
  if EreCourante >= 2 then
    Result := BiblioMult;
  if teScience in C.Tech then Result := Result * 1.5;
  if teMaths   in C.Tech then Result := Result * 1.25;
  if teUniversites in C.Tech then Result := Result * 1.2;
  if teMethode in C.Tech then Result := Result * 1.3;
end;

procedure TryInvent(C: TCreature);
var i, LastDay: Integer;
    Tente: Boolean;
begin
  if (C.Kind <> 2) or (C.Age <= CHILDHOOD) or (C.Cult < 0.20) then Exit;
  LastDay := -1;
  for i := 0 to TECH_COUNT - 1 do
    if TechInfo[TECHBASE[i].Code].Day > LastDay then
      LastDay := TechInfo[TECHBASE[i].Code].Day;
  if (LastDay > 0) and (DayCount - LastDay < CfgGap) then Exit;
  Tente := False;
  for i := 0 to TECH_COUNT - 1 do
    if TechDispo(C, i) then begin
      Tente := True;
      if Random < TechProba(i) * TechMult(C) then
      begin
        GiveTech(C, TECHBASE[i].Code);
        Exit;
      end;
    end;
  if Tente and (EreCourante >= 2) then
    BiblioFail(DayCount);
end;

function ChooseMate(C: TCreature): TCreature;
var O: TCreature; Best: TCreature; BS, SC: Single;
begin
  Best := nil; BS := -1;
  CollectNear(C.X, C.Y, C.Se);
  for O in NB do begin
    if (not O.Alive) or (O = C) then Continue;
    if (O.Kind <> 2) or (O.Age < CHILDHOOD) then Continue;
    SC := (1 - Abs(O.Orn - C.Pref)) *
          (1 - Sqrt(D2(C.X, C.Y, O.X, O.Y)) / C.Se);
    if SC > BS then begin BS := SC; Best := O end;
  end;
  Result := Best;
end;

procedure StepSapien(C: TCreature; DT: Single);
var Des, SP, SM, NX, NY, Amt, Crowd, Damp, Thrust, Gain, Tgt: Single;
   F: TPlant; Mate: TCreature;
   Bw, O, I, K2: Integer; Bv: Single;
   HHut: THut;
   HasM: Boolean;
   OM: TCreature;
   FF: TFish;
   S: string;
begin
  C.Age := C.Age + DT; C.ThinkT := C.ThinkT - DT;
  C.AtkCd := C.AtkCd - DT; C.RepCd := C.RepCd - DT;
  C.BuildCd := C.BuildCd - DT;
  C.CatchT := C.CatchT - DT;
  if C.SpeechCD > 0 then C.SpeechCD := C.SpeechCD - DT;    // ★cooldown des cris
  if C.Flash > 0 then C.Flash := Max(0, C.Flash - DT);
  C.WordT := C.WordT - DT;
  if C.WordT <= 0 then C.Word := -1;

  for I := High(C.Mem) downto 0 do begin
    C.Mem[I].T := C.Mem[I].T + DT;
    if C.Mem[I].T > MEMLIFE then begin
      if I < High(C.Mem) then
        Move(C.Mem[I + 1], C.Mem[I], (High(C.Mem) - I) * SizeOf(TMemRec));
      SetLength(C.Mem, Length(C.Mem) - 1);
    end;
  end;
  if (C.SPred <> nil) and (C.SPred.Alive) then begin
    HasM := False;
    for I := 0 to High(C.Mem) do
      if (C.Mem[I].K = 0) and (D2(C.Mem[I].X, C.Mem[I].Y, C.SPred.X, C.SPred.Y) < 36) then
        begin HasM := True; Break end;
    if not HasM then begin
      if Length(C.Mem) < MEMMAX then
        SetLength(C.Mem, Length(C.Mem) + 1)
      else begin
        Move(C.Mem[1], C.Mem[0], (MEMMAX - 1) * SizeOf(TMemRec));
        SetLength(C.Mem, MEMMAX - 1);
        SetLength(C.Mem, MEMMAX);
      end;
      C.Mem[High(C.Mem)].X := C.SPred.X;
      C.Mem[High(C.Mem)].Y := C.SPred.Y;
      C.Mem[High(C.Mem)].K := 0;
      C.Mem[High(C.Mem)].T := 0;
    end;
  end;

  // — transmission culturelle + apprentissage autonome —
  if C.Cult <= 0.95 then begin
    C.Cult := Min(0.95, C.Cult + 0.0045 * DT);
    C.MentorT := C.MentorT - DT;
    if C.MentorT <= 0 then begin
      C.MentorT := 0.4;
      C.Mentor := nil;
      CollectNear(C.X, C.Y, 14);
      for OM in NB do
        if OM.Alive and (OM.Kind = 2) and (OM.Age >= CHILDHOOD) and
           (OM.Cult > C.Cult) then
          if (C.Mentor = nil) or
             (D2(C.X, C.Y, OM.X, OM.Y) < D2(C.X, C.Y, C.Mentor.X, C.Mentor.Y)) then
            C.Mentor := OM;
    end;
    if (C.Mentor <> nil) and
       ((not C.Mentor.Alive) or (Creatures.IndexOf(C.Mentor) < 0)) then
      C.Mentor := nil;
    if (C.Mentor <> nil) and (C.Cult < 0.95) then begin
      if NearestHutDist(C.X, C.Y) < 4 then
        Gain := 0.112 * DT
      else
        Gain := 0.070 * DT;
      if teEcole in C.Tech then Gain := Gain * 1.5;
      if teRhetorique in C.Tech then Gain := Gain * 1.2;
      if teHumanites in C.Tech then Gain := Gain * 1.25;
      C.Cult := Min(0.95, C.Cult + Gain);
      for I := 0 to NW - 1 do begin
        Tgt := C.Dna[I] + (C.Mentor.Net[I] - C.Dna[I]) * 0.30;
        C.Net[I] := C.Net[I] + (Tgt - C.Net[I]) * (0.15 * DT);
      end;
      C.Energy := C.Energy - 0.05 * DT;
    end;
    if (C.Mentor <> nil) and (C.Mentor.Alive) then
      C.Tech := C.Tech + C.Mentor.Tech;
  end;

  if C.ThinkT <= 0 then begin
    C.ThinkT := 0.1;
    SenseSapien(C); ThinkNet(C);
    if (C.SPred <> nil) and (not C.SPred.Alive) then C.SPred := nil;
    if (C.SFood <> nil) and (PlantGrid[C.SFood.Cell] <> C.SFood) then C.SFood := nil;
    if C.Oo[2] > 0.55 then TryBuild(C);
    C.InventT := C.InventT - 0.1;
    if C.InventT <= 0 then begin
      C.InventT := 2 + Random * 2;
      TryInvent(C);
      TryInventMinor(C);
    end;
    // — diffusion de proximité —
    CollectNear(C.X, C.Y, 8);
    for OM in NB do
      if OM.Alive and (OM.Kind = 2) and (OM.Age >= CHILDHOOD) and
         (OM.Tech - C.Tech <> []) and
         (Random < CfgDiffu * IfThen(teMonnaie in OM.Tech, 1.5, 1.0)
                        * IfThen(HasInno(OM, IN_THEATRE), 1.25, 1.0)
                        * IfThen(teLegislation in OM.Tech, 1.25, 1.0)
                        * IfThen(HasInno(OM, IN_PARCHEMIN), 1.1, 1.0)
                        * IfThen(teImprimerie in OM.Tech, 1.6, 1.0)
                        * IfThen(teBanque in OM.Tech, 1.25, 1.0)
                        * IfThen(SurRoute(C.X, C.Y) or SurRoute(OM.X, OM.Y), 1.3, 1.0)) then
        C.Tech := C.Tech + OM.Tech;
    for OM in NB do
      if OM.Alive and (OM.Kind = 2) and (Random < 0.04) then
        C.InnoK := C.InnoK or OM.InnoK;
    // — mémoire du peuple —
    if (CfgMemoire >= 0.5) and
       (PeopleHas(teArchives) or
       ((FHomeSet and (Sqr(C.X - FHomeX) + Sqr(C.Y - FHomeY) < 144)) or
       (NearestHutDist(C.X, C.Y) < 6))) then begin
      for I := Ord(Low(TTech)) to Ord(High(TTech)) do
        if (TechInfo[TTech(I)].Who <> '') and (not (TTech(I) in C.Tech)) then
          Include(C.Tech, TTech(I));
      C.InnoK := C.InnoK or InnoAllMask;
    end;
    Bw := -1; Bv := 0.25;
    for O := 5 to 8 do
      if C.Oo[O] > Bv then begin Bv := C.Oo[O]; Bw := O - 5 end;
    if Bw >= 0 then begin
      if C.Word <> Bw then LogWord(Bw, C);
      C.Word := Bw; C.WordT := 1.5;
      if C.SpeechCD <= 0 then begin                          // ★cooldown des cris
        AudioVoiceID(C.CId, Round(C.X), Round(C.Y));
        if HasInno(C, IN_TAMBOUR) then
          AudioSpeak(WORDS[C.Word], Round(C.X), Round(C.Y), True);
        C.SpeechCD := 2 + Random * 3;
      end;
    end;
  end;

  if FDayLight < 0.45 then begin
    HHut := NearestHut(C.X, C.Y, 3.2);
    if (HHut <> nil) and HHut.Fire then begin
      if C.Energy < C.MaxE then
        C.Energy := Min(C.MaxE, C.Energy + 2.4 * DT *
          IfThen(HasInno(C, IN_BROCHETTE), 1.6, 1));
      if (HHut.Stock > 0) and (C.Energy < C.MaxE * 0.6) then begin
        Amt := Min(HHut.Stock, 5 * DT);
        HHut.Stock := HHut.Stock - Amt;
        C.Energy := Min(C.MaxE, C.Energy + Amt * 1.5
          * IfThen(HasInno(C, IN_FOUR), 1.3, 1.0));
      end;
    end;
  end;

  C.GuardC := nil;
  if tPast in C.Tech then begin
    CollectNear(C.X, C.Y, 11);
    for OM in NB do
      if OM.Alive and (OM.Kind = 1) and (OM.TargetC <> nil) and
         (OM.TargetC.Dom) and (C.GuardC = nil) then
        C.GuardC := OM;
    if (C.SHerb <> nil) and C.SHerb.Alive and (not C.SHerb.Dom) and
       (C.SHerb.Age > 6) and (D2(C.X, C.Y, C.SHerb.X, C.SHerb.Y) < 9) then begin
      HHut := NearestHut(C.X, C.Y, 9);
      if C.SHerb.Fleeing then
        C.SHerb.Trust := Max(0, C.SHerb.Trust - DT * 0.25)
      else if (HHut <> nil) and (DomCount(HHut) < 7) then begin
        C.SHerb.Trust := C.SHerb.Trust + DT * (0.10 + 0.28 * C.SHerb.Tame)
           * IfThen(teElevage in C.Tech, 1.5, 1.0);
        if C.SHerb.Trust >= 1 then begin
          C.SHerb.Dom := True; C.SHerb.HomeH := HHut; C.SHerb.Trust := 0;
          Toast(Format(L(109), [C.Name, C.SHerb.Name]));
          ChronAdd(CK_PEOPLE, Format(L(108), [C.Name, C.SHerb.Name]));
        end;
      end;
    end;
    if (C.SHerb <> nil) and C.SHerb.Alive and C.SHerb.Dom and
       (C.SHerb.MilkCd <= 0) and (C.SHerb.Age > 8) and
       (D2(C.X, C.Y, C.SHerb.X, C.SHerb.Y) < 3.6) then begin
      C.SHerb.MilkCd := 9;
      C.Energy := Min(C.MaxE, C.Energy + 13);
    end;
  end;

  // — chien : la domestication fondatrice —
  if (tFeu in C.Tech) and (CountD < MAXDOG) and (C.Age > CHILDHOOD) then begin
    CollectNear(C.X, C.Y, 6);
    for OM in NB do
      if OM.Alive and (OM.Kind = 1) and (OM.Age < 70) and
         (OM.TargetC = nil) and (D2(C.X, C.Y, OM.X, OM.Y) < 36) then begin
        OM.Trust := OM.Trust + DT * 0.055;
        if OM.Trust >= 1 then begin
          OM.Kind := 3;
          OM.Master := C;
          OM.Trust := 0; OM.Tame := 1; OM.Dom := True;
          OM.TargetC := nil; OM.TargetP := nil; OM.Fleeing := False;
          OM.Name := Format(L(149), [C.Name]);
          OM.State := L(147);
          OM.MaxAge := Max(OM.MaxAge, OM.Age + 90 + Random * 60);
          Dec(CountP); Inc(CountD);
          Toast(Format(L(111), [C.Name]));
          ChronAdd(CK_PEOPLE, Format(L(110), [C.Name]));
          Break;
        end;
      end;
  end;

  if C.Fleeing then begin
    C.State := L(52);
    if (FDayLight < 0.45) and HasInno(C, IN_TORCHE) then Des := C.Sp * 1.25
    else Des := C.Sp * 1.08;
    C.Angle := C.Angle + ClampF(NormA(C.FleeA - C.Angle), -8 * DT, 8 * DT);
  end else if (C.GuardC <> nil) and C.GuardC.Alive then begin
    C.State := L(142);
    C.Angle := C.Angle + ClampF(
      NormA(ArcTan2(C.GuardC.Y - C.Y, C.GuardC.X - C.X) - C.Angle), -8 * DT, 8 * DT);
    Des := C.Sp * 1.12;
    if (D2(C.X, C.Y, C.GuardC.X, C.GuardC.Y) < 2.4) and (C.AtkCd <= 0) then begin
      C.AtkCd := 1.2; C.Flash := 0.6;
      Kill(C.GuardC, L(102));
      C.Energy := Min(C.MaxE, C.Energy + 50);
      C.GuardC := nil;
    end;
  end else begin
    if C.Oo[9] > 0.5 then begin
      C.State := L(57);
      C.Energy := C.Energy - (0.30 + 0.20 * Sqr(C.Orn)) * DT;
      if C.Alive then begin
        if C.Energy <= 0 then Kill(C, L(99))
        else if C.Age > C.MaxAge *
           (IfThen(teMedecine in C.Tech, 1.2, 1.0) * IfThen(teHygiene in C.Tech, 1.1, 1.0)
            * IfThen(teMedArabe in C.Tech, 1.1, 1.0)) then
          Kill(C, L(100));
      end;
      Exit;
    end;
    Thrust := (C.Oo[1] + 1) / 2;
    Des := C.Sp * (0.18 + 0.9 * Thrust);
    C.Angle := C.Angle + C.Oo[0] * 4.5 * DT;
    // — priorité à la pêche —
    if (tPeche in C.Tech) and (C.Energy < C.MaxE * 0.8) then begin
      FF := FindFish(C);
      if FF <> nil then begin
        C.State := L(143);
        C.Angle := C.Angle + ClampF(
          NormA(ArcTan2(FF.Y - C.Y, FF.X - C.X) - C.Angle), -6 * DT, 6 * DT);
        Des := C.Sp * 0.8;
        if C.CatchT <= 0 then begin
          if HasInno(C, IN_FILET) then C.CatchT := 0.9
          else C.CatchT := 1.5;
          I := Fishes.IndexOf(FF);
          if I >= 0 then begin
            KillFish(I);
            C.Energy := Min(C.MaxE,
              C.Energy + (15 + 9 * FF.S) * IfThen(HasInno(C, IN_FILET), 1.6, 1));
          end;
        end;
        SM := 1;
        if IsWater(C.X, C.Y) then begin
          SM := 0.5;
          if teVoile in C.Tech then SM := 1.0;
          if teGaleres in C.Tech then SM := 1.4;
          if teHauturiere in C.Tech then SM := 1.7;
          if teCaravelles in C.Tech then SM := 2.2;
        end
        else if Walkable(C.X, C.Y) and (TerrType[CellIdx(C.X, C.Y)] = T_FOR) then SM := 0.7;
        SP := Des * SM;
        NX := C.X + Cos(C.Angle) * SP * DT; NY := C.Y + Sin(C.Angle) * SP * DT;
        if Walkable(NX, NY) or ((tNav in C.Tech) and NavOK(NX, NY)) then
          begin C.X := NX; C.Y := NY end;
        C.X := ClampF(C.X, 0.01, GW - 0.01); C.Y := ClampF(C.Y, 0.01, GH - 0.01);
        if IsWater(C.X, C.Y) then
          C.Energy := C.Energy - (0.48 + 0.11 * Des + 0.34 * C.Sz + 0.20 * Sqr(C.Orn) + 0.30) * DT
        else
          C.Energy := C.Energy - (0.48 + 0.11 * Des + 0.34 * C.Sz + 0.20 * Sqr(C.Orn)) * DT;
        if C.WordT > 0 then C.Energy := C.Energy - 0.08 * DT;
        if C.Alive and (C.Energy <= 0) then Kill(C, L(99));
        Exit;
      end;
    end;
    // — chasse des sauvages —
    if (C.Oo[4] > 0.4) and (C.SHerb <> nil) and C.SHerb.Alive and
       (not C.SHerb.Dom) and (D2(C.X, C.Y, C.SHerb.X, C.SHerb.Y) < 9) then begin
      C.State := L(72);
      C.Angle := C.Angle + ClampF(
        NormA(ArcTan2(C.SHerb.Y - C.Y, C.SHerb.X - C.X) - C.Angle), -7 * DT, 7 * DT);
      Des := C.Sp * 1.05;
      if (D2(C.X, C.Y, C.SHerb.X, C.SHerb.Y) <
          IfThen(HasInno(C, IN_ARBALETE), 2.8,
          IfThen(HasInno(C, IN_PIEGE), 2.2, 1.35))) and (C.AtkCd <= 0) then begin
        C.AtkCd := 1.1; C.Flash := 0.55;
        C.Energy := Min(C.MaxE, C.Energy + (42 + 26 * C.SHerb.Sz)
          * IfThen(teMetal in C.Tech, 1.6, 1.0)
          * IfThen(teFer in C.Tech, 1.4, 1.0)
          * IfThen(tePoudre in C.Tech, 1.3, 1.0));
        Kill(C.SHerb, L(101));
        C.SHerb := nil;
      end
    end else begin
      F := FindPlant(C);
      if (F <> nil) and (not F.Morte) and (F.S > 0.12) and (D2(C.X, C.Y, F.X, F.Y) < 1.2) then begin   // ★garde Morte
        C.State := L(55);
        C.BiteT := C.BiteT - DT;
        if C.BiteT <= 0 then begin
          C.BiteT := 0.22;
          Amt := Min(0.2, F.S);
          if HasInno(C, IN_HOTTE) then Amt := Amt * 1.5;
          if teCharrue in C.Tech then Amt := Amt * 1.5;
          if teAgronomie in C.Tech then Amt := Amt * 1.25;
          if HasInno(C, IN_SERPE) then Amt := Amt * 1.15;
          Amt := Min(Amt, F.S);
          F.S := F.S - Amt;
          C.Energy := Min(C.MaxE, C.Energy + Amt * 32 * 1.9);
          HHut := NearestHut(C.X, C.Y, 5);
          if (HHut <> nil) and HHut.Fire then
            C.Energy := Min(C.MaxE, C.Energy + Amt * 32 * 0.76);
          if tAgri in C.Tech then
            if Random < 0.8 then
              AddPlant(F.X + Random * 4 - 2, F.Y + Random * 4 - 2, 0.12);
          if (tStock in C.Tech) and (HHut <> nil) and HHut.Fire and
             (C.Energy > C.MaxE * 0.85) then
            HHut.Stock := Min(Round(IfThen(teIngenierie in C.Tech, 360, 240)
              * IfThen(HasInno(C, IN_AMPHORE), 1.2, 1.0)),
              HHut.Stock + Amt * IfThen(HasInno(C, IN_APPENTIS), 40, 20)
                * IfThen(HasInno(C, IN_CHARR), 1.5, 1.0));
          HasM := False;
          for I := 0 to High(C.Mem) do
            if (C.Mem[I].K = 1) and (D2(C.Mem[I].X, C.Mem[I].Y, F.X, F.Y) < 36) then
              begin HasM := True; Break end;
          if not HasM then begin
            if Length(C.Mem) < MEMMAX then
              SetLength(C.Mem, Length(C.Mem) + 1)
            else begin
              Move(C.Mem[1], C.Mem[0], (MEMMAX - 1) * SizeOf(TMemRec));
              SetLength(C.Mem, MEMMAX - 1);
              SetLength(C.Mem, MEMMAX);
            end;
            C.Mem[High(C.Mem)].X := F.X;
            C.Mem[High(C.Mem)].Y := F.Y;
            C.Mem[High(C.Mem)].K := 1;
            C.Mem[High(C.Mem)].T := 0;
          end;
        end;
      end else begin
        C.State := L(56);
        if (C.SPeer <> nil) and C.SPeer.Alive and
           (Sqr(C.X - C.SPeer.X) + Sqr(C.Y - C.SPeer.Y) < 100) then begin
          C.Angle := C.Angle + ClampF(
            NormA(ArcTan2(C.SPeer.Y - C.Y, C.SPeer.X - C.X) - C.Angle),
            -2.5 * DT, 2.5 * DT);
        end else if FHomeSet and
           (Sqr(C.X - FHomeX) + Sqr(C.Y - FHomeY) > 100) then begin
          C.Angle := C.Angle + ClampF(
            NormA(ArcTan2(FHomeY - C.Y, FHomeX - C.X) - C.Angle),
            -3.0 * DT, 3.0 * DT);
        end else
          C.WAngle := C.WAngle + (Random - 0.5) *
            IfThen(HasInno(C, IN_BOSSOLE) or HasInno(C, IN_CARMARINE) or
                   (teCartographie in C.Tech), 0.6, 1.2);
      end;
    end;
  end;
  if teRoue in C.Tech then Des := Des * 1.3;
  if teFerrure in C.Tech then Des := Des * 1.1;
  if HasInno(C, IN_HORLOGE) then Des := Des * 1.1;
  if C.BuildCd > 8.8 then C.State := L(144);

  SM := 1;
  if IsWater(C.X, C.Y) then begin
    SM := 0.5;
    if teVoile in C.Tech then SM := 1.0;
    if teGaleres in C.Tech then SM := 1.4;
    if teHauturiere in C.Tech then SM := 1.7;
    if teCaravelles in C.Tech then SM := 2.2;
  end
  else if Walkable(C.X, C.Y) and (TerrType[CellIdx(C.X, C.Y)] = T_FOR) then SM := 0.7;
  if SurRoute(C.X, C.Y) then Des := Des * 1.5;       // ★B2 la route porte le pas
  SP := Des * SM;
  NX := C.X + Cos(C.Angle) * SP * DT; NY := C.Y + Sin(C.Angle) * SP * DT;
  if Walkable(NX, NY) or ((tNav in C.Tech) and NavOK(NX, NY)) then
    begin C.X := NX; C.Y := NY end
  else if Walkable(NX, C.Y) or ((tNav in C.Tech) and NavOK(NX, C.Y)) then
    begin C.X := NX; C.Angle := C.Angle + (Random - 0.5) * 1.2 end
  else if Walkable(C.X, NY) or ((tNav in C.Tech) and NavOK(C.X, NY)) then
    begin C.Y := NY; C.Angle := C.Angle + (Random - 0.5) * 1.2 end
  else C.Angle := C.Angle + 2.4 * DT;
  C.X := ClampF(C.X, 0.01, GW - 0.01); C.Y := ClampF(C.Y, 0.01, GH - 0.01);

  if IsWater(C.X, C.Y) then
    C.Energy := C.Energy - (0.48 + 0.11 * Des + 0.34 * C.Sz + 0.20 * Sqr(C.Orn) + 0.30) * DT
  else
    C.Energy := C.Energy - (0.48 + 0.11 * Des + 0.34 * C.Sz + 0.20 * Sqr(C.Orn)) * DT;
  if C.WordT > 0 then C.Energy := C.Energy - 0.08 * DT;
  if (FDayLight < 0.4) and HasInno(C, IN_PEAUSS) and
     (NearestHutDist(C.X, C.Y) < 4.5) then
    C.Energy := C.Energy + 0.17 * DT;
  if (FDayLight < 0.4) and HasInno(C, IN_BOUGIE) then
    C.Energy := C.Energy + 0.12 * DT;
  if (FDayLight < 0.4) and HasInno(C, IN_VIOLON) then
    C.Energy := C.Energy + 0.10 * DT;

  if (C.Energy > C.MaxE * 0.78) and (C.Age > CHILDHOOD) and
     (C.RepCd <= 0) and (CountS < EreMaxS) and (not IsWater(C.X, C.Y)) then begin
    Mate := ChooseMate(C);
    if Mate <> nil then begin
      Crowd := CrowdCount(C, 6);
      Damp := 1 / (1 + Crowd * 0.3);
      if NearestHutDist(C.X, C.Y) < 4 then Damp := Damp * 1.7;
      if HasInno(C, IN_PARURE) then Damp := Damp * 1.25;
      if Random < DT * 0.7 * ClampF((C.Oo[3] + 1) / 2, 0, 1) * Damp then begin
        SpawnCreature(2, C.X + Cos(C.Angle) * 1.3, C.Y + Sin(C.Angle) * 1.3,
                      C, Mate, C.Gen + 1);
        Creatures.Last.Energy := 50;
        C.Energy := C.Energy - 60; C.RepCd := 9;
        Mate.RepCd := Max(Mate.RepCd, 4);
      end;
    end else
      C.RepCd := 1.5;
  end;
  if C.Alive then begin
    if C.Energy <= 0 then Kill(C, L(99))
    else if C.Age > C.MaxAge *
       (IfThen(teMedecine in C.Tech, 1.2, 1.0) * IfThen(teHygiene in C.Tech, 1.1, 1.0)
        * IfThen(teMedArabe in C.Tech, 1.1, 1.0)) then
      Kill(C, L(100));
  end;
end;

procedure DoStep(DT: Single);
var I, T, K, I2: Integer; C: TCreature;
   TT: TTech; Carriers: Integer;
   Froid, Croiss: Single;
begin
  FSimTime := FSimTime + DT;
  FDayT := FSimTime / CDAY - Floor(FSimTime / CDAY);
  FDayLight := ClampF(0.5 + Sin(FDayT * TAU) * 1.05, 0.05, 1);
  FireT := FireT + DT;
  if FireT >= 0.5 then begin
    FireT := 0;
    for I := 0 to Huts.Count - 1 do begin
      K := 0; T := 0;
      for I2 := 0 to Creatures.Count - 1 do
        if Creatures[I2].Alive and (Creatures[I2].Kind = 2) and
           (Sqr(Creatures[I2].X - Huts[I].X) + Sqr(Creatures[I2].Y - Huts[I].Y) < 49) then begin
          if tFeu in Creatures[I2].Tech then K := 1;
          if tAgri in Creatures[I2].Tech then T := 1;
        end;
      Huts[I].Fire := (K = 1);
      Huts[I].Cult := (T = 1);
    end;
    RebuildFields;
  end;

  // ★VILLES+ROUTES — filet nommé (le crash sera désigné)
  if (Huts.Count > 0) and (Creatures <> nil) then
    try
      VeilleUrbaine(DT);
    except
      on E: Exception do Toast('CRASH Veille: ' + E.Message);
    end;

  Froid := SaisonFroid;
  if PeopleHas(teAstronomie) then Froid := Froid * 0.7;
  Croiss := 1.0;
  if PeopleHas(teIrrig)      then Croiss := Croiss * 1.3;
  if PeopleHas(teAqueduc)    then Croiss := Croiss * 1.2;
  if PeopleHas(teMoulins)    then Croiss := Croiss * 1.15;
  if PeopleHas(teAssolement) then Croiss := Croiss * 1.20;
  try
    StepPlants(DT, (0.25 + 0.75 * FDayLight) * (0.25 + 0.75 * (1 - Froid)) * Croiss);
  except on E: Exception do Toast('CRASH StepPlants: ' + E.Message) end;
  try
    StepFish(DT, (0.25 + 0.75 * FDayLight) * (0.30 + 0.70 * (1 - Froid)));
  except on E: Exception do Toast('CRASH StepFish: ' + E.Message) end;
  try
    StepEvo(DT);
  except on E: Exception do Toast('CRASH StepEvo: ' + E.Message) end;
  try
    RebuildGrid;
  except on E: Exception do Toast('CRASH RebuildGrid: ' + E.Message) end;

  for I := Creatures.Count - 1 downto 0 do begin
    C := Creatures[I];
    if not C.Alive then begin Creatures.Delete(I); C.Free; Continue end;
    try
      if C.Kind = 2 then StepSapien(C, DT)
      else if C.Kind = 3 then StepDog(C, DT)
      else StepCreature(C, DT);
    except
      on E: Exception do begin
        FMsg := Format(L(126), [C.Name, C.State, Trunc(C.Age), E.Message]);
        FMsgT := 8;
        C.SPred := nil; C.SFood := nil; C.Mentor := nil;
        C.TargetC := nil; C.TargetP := nil; C.SHerb := nil; C.GuardC := nil;
        C.SPeer := nil; C.Master := nil;
        C.Fleeing := False;
      end;
    end;
  end;
  SampleT := SampleT + DT;
  if SampleT >= 1 then begin
    SampleT := 0;
    for I := 0 to 3 do begin
      Lex[I].N := Lex[I].N * 0.98;
      Lex[I].Pred := Lex[I].Pred * 0.98;
      Lex[I].Food := Lex[I].Food * 0.98;
    end;
    for TT := Low(TTech) to High(TTech) do begin
      Carriers := 0;
      for I := 0 to Creatures.Count - 1 do
        if Creatures[I].Alive and (Creatures[I].Kind = 2) and (TT in Creatures[I].Tech) then
          Inc(Carriers);
      if TechInfo[TT].Who <> '' then begin
        if (Carriers = 0) and (not TechLost[TT])
           and (not PeopleHas(tePhilosophie)) then begin
          TechLost[TT] := True;
          Toast(Format(L(103), [TechNom(TT)]));
          ChronAdd(CK_TECH, Format(L(104), [TechNom(TT)]));
        end;
        if Carriers > 0 then TechLost[TT] := False;
      end;
    end;
    if CountS > MaxSap then MaxSap := CountS;
    if (MileIdx <= High(CHRONMILE)) and (CountS >= CHRONMILE[MileIdx]) then begin
      ChronAdd(CK_PEOPLE, Format(L(112), [CountS]));
      Inc(MileIdx);
    end;
    if (CountH < 24) or (CountP < 8) or (CountS < 4) then
      for T := 1 to 60 do
        if Walkable(Random(GW), Random(GH)) then begin
          if CountH < 24 then for I := 1 to 2 do
            SpawnCreature(0, Random(GW), Random(GH), nil, nil, 0);
          if CountP < 8  then SpawnCreature(1, Random(GW), Random(GH), nil, nil, 0);
          if (CountS < 4) and (CfgImmig > 0) then begin
            for I := 1 to CfgImmig do
              SpawnCreature(2, FHomeX + Random * 12 - 6,
                               FHomeY + Random * 12 - 6, nil, nil, 0);
            Toast(L(113));
            ChronAdd(CK_PEOPLE, L(114));
          end;
          Break;
        end;
    if (FsN + FdN) < 120 then
      for I := 1 to 2 do
        if Fishes.Count < MAXFS + MAXFD then
          AddFishAt(Random(GW), Random(GH), False);
    if Length(FHist) >= HISTMAX then begin
      Move(FHist[1], FHist[0], (HISTMAX - 1) * SizeOf(THistRec));
      SetLength(FHist, HISTMAX);
      FHist[HISTMAX - 1].P := Plants.Count;
      FHist[HISTMAX - 1].H := CountH;
      FHist[HISTMAX - 1].C := CountP;
      FHist[HISTMAX - 1].S := CountS;
    end else begin
      SetLength(FHist, Length(FHist) + 1);
      FHist[High(FHist)].P := Plants.Count;
      FHist[High(FHist)].H := CountH;
      FHist[High(FHist)].C := CountP;
      FHist[High(FHist)].S := CountS;
    end;
  end;
  if FMsgT > 0 then FMsgT := FMsgT - DT;
end;

procedure TSimThread.Execute;
var FC: TStopwatch; Elapsed, Acc: Double; N: Integer;
begin
  FC := TStopwatch.StartNew;
  while not Terminated do begin
    try
      Elapsed := FC.ElapsedMilliseconds / 1000;
      FC := TStopwatch.StartNew;
      if Elapsed > 0.1 then Elapsed := 0.1;
      if FStarted and FRunning then begin
        Acc := Elapsed * FSpeed; N := 0;
        while (Acc >= STEPDT) and (N < 6) do begin
          FSimCS.Enter;
          try
            DoStep(STEPDT);
          finally
            FSimCS.Leave;
          end;
          Acc := Acc - STEPDT; Inc(N);
        end;
      end;
      Sleep(1);
    except
      on E: Exception do begin
        FMsg := Format(L(127), [E.Message]);
        FMsgT := 6;
        Sleep(200);
      end;
    end;
  end;
end;

end.

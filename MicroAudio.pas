unit MicroAudio;
{==============================================================================
 Microcosme — moteur audio 100% procédural (aucun .wav)
 waveOut + thread dédié + ring-buffers + mixeur additif.
 ★ERE7 : lyre, cloche, fanfares (AudioEre, AudioBell).
 ★DIAG : instrumentation complète du dossier « voix muettes » —
 gDbgBeat (cœur du thread), gDbgTrig (trigs drainés), gDbgCall (entrées
 dans SpawnWord), gDbgPush/gDbgSpeak/gDbgVox, AudioErr (crash du thread),
 garde waveOutWrite. AudioDebug lit tout.
==============================================================================}
interface

procedure AudioInit;
procedure AudioShutdown;
function  AudioReady: Boolean;
procedure AudioSetDayLight(v: Single);
procedure AudioSetWaves(v: Single);
procedure AudioSetFire(v: Single);
procedure AudioSetMasterVolume(v: Single);
procedure AudioSetListener(X, Y: Integer);
procedure AudioSpeak(const AWord: string; X, Y: Integer; Drummed: Boolean = False);
procedure AudioVoiceID(ID: Integer; X, Y: Integer);
procedure AudioDrum(X, Y: Integer);
procedure AudioEre(NEra: Integer);
procedure AudioBell(X, Y: Integer);
function AudioDebug: string;                        // ★DIAG
function Clamp(v, lo, hi: Double): Double; inline;


implementation

{$OVERFLOWCHECKS OFF}
{$RANGECHECKS OFF}

uses
  System.SysUtils, System.Classes, System.SyncObjs, System.Math,
  Winapi.Windows, Winapi.MMSystem;

const
  AUD_SR        = 44100;
  AUD_FRAMES    = 1024;
  AUD_BUFFERS   = 5;
  AUD_MAXVOICES = 24;
  INV_SR        = 1.0 / AUD_SR;

type
  TVoiceKind = (vkDrum, vkVoice, vkChirp, vkCrackle, vkLyre, vkBell);

  TBiquad = record
    b0,b2, a1, a2, x1, x2, y1, y2: Double;
    procedure SetBP(fc, Q: Double); inline;
    function Process(x: Double): Double; inline;
  end;

  TVoice = record
    Active: Boolean;
    Kind: TVoiceKind;
    TStart, Dur: Double;
    GL, GR: Double;
    Phase: Double;
    F0, Fm: Double;
    F1F, F2F: Double;
    Ons, OnsD: Double;
    B1, B2: TBiquad;
    FEnd: Double;
    Amp: array[0..5] of Double;   // amplitudes des 6 harmoniques (modèle voyelle)
    NVib: Double;                 // vitesse de vibrato (propre au locuteur)
    NJit: Double;                 // jitter (instabilité humaine)
  end;
  PVoice = ^TVoice;

  TTrigKind = (tkNone, tkSpeak, tkDrumOne, tkEre, tkBellOne);
  TTrig = record
    Kind: TTrigKind;
    X, Y: Integer;
    Drummed: Boolean;
    AWord: string;
    Num: Integer;
  end;

  TAudioThread = class(TThread)
  protected
    procedure Execute; override;
  end;

var
  gCS: TCriticalSection = nil;
  hWO: HWAVEOUT = 0;
  hEv: THandle = 0;
  gThr: TAudioThread = nil;
  gRun: Boolean = False;

  gFmt: TWAVEFORMATEX;
  gHdr: array[0..AUD_BUFFERS-1] of TWaveHdr;
  gBuf: array[0..AUD_BUFFERS-1] of array[0..AUD_FRAMES*2-1] of SmallInt;

  gDay: Double = 0.5;  gWave: Double = 0;  gFire: Double = 0;  gVol: Double = 0.85;
  gLX: Double = 0;     gLY: Double = 0;

  gT: Double = 0;
  gVoices: array[0..AUD_MAXVOICES-1] of TVoice;
  gSteal: Integer = 0;
  gLastDrum: Double = -10;  gNextChirp: Double = 2;  gNextCrack: Double = 0;
  gWaveLP1: Double = 0;  gWaveLP2: Double = 0;
  gWindLP: Double = 0;   gFireLP: Double = 0;
  gRng: Cardinal = $9E3779B9;
  gA_Day, gA_Wave, gA_Fire, gA_Vol: Double;

  gTrig: array[0..31] of TTrig;
  gTrigR: Integer = 0;  gTrigW: Integer = 0;

  // ★DIAG — l'instrumentation complète
  AudioErr: string = '';    // dernier crash du thread audio
  gDbgBeat: Integer = 0;    // battements du thread (buffers postés)
  gDbgPush: Integer = 0;    // appels AudioSpeak
  gDbgTrig: Integer = 0;    // trigs drainés (tous kinds)
  gDbgCall: Integer = 0;    // entrées effectives dans SpawnWord
  gDbgSpeak: Integer = 0;   // (= gDbgCall en théorie — cohérence)
  gDbgVox: Integer = 0;     // voix vkVoice actives au dernier buffer

  gVoixDepuisDernier: Integer = 0;

const
  PENTA: array[0..4] of Double = (1.0, 1.125, 1.25, 1.5, 1.6667);

function Clamp(v, lo, hi: Double): Double;
begin
  if v < lo then Result := lo
  else if v > hi then Result := hi
  else Result := v;
end;

procedure TBiquad.SetBP(fc, Q: Double);
var w0, cw, al, a0: Double;
begin
  w0 := 2*Pi*Min(fc, AUD_SR*0.45)/AUD_SR;
  cw := Cos(w0);  al := Sin(w0)/(2*Q);  a0 := 1 + al;
  b0 := al/a0;  b2 := -al/a0;
  a1 := -2*cw/a0;  a2 := (1-al)/a0;
  x1 := 0; x2 := 0; y1 := 0; y2 := 0;
end;

function TBiquad.Process(x: Double): Double;
begin
  Result := b0*x - a1*y1 - a2*y2;
  x2 := x1; x1 := x;  y2 := y1; y1 := Result;
end;

function ARand: Double; inline;
begin
  gRng := gRng xor (gRng shl 13);
  gRng := gRng xor (gRng shr 17);
  gRng := gRng xor (gRng shl 5);
  Result := (gRng and $FFFFFF)/Double($FFFFFF) - 0.5;
end;

function WordHash(const s: string): Cardinal;
var i: Integer;
begin
  Result := 2166136261;
  for i := 1 to Length(s) do
    Result := (Result xor Cardinal(Ord(s[i]))) * 16777619;
end;

procedure PlaceAt(X, Y: Integer; out GL, GR: Double);
var dx, dy, d, g, p: Double;
begin
  gCS.Enter;
  dx := X - gLX;  dy := Y - gLY;
  gCS.Leave;
  d := Sqrt(dx*dx + dy*dy);
  g := 320/(320 + d);  if g > 1 then g := 1;
  p := 0.5 + 0.5*Clamp(dx/380, -0.95, 0.95);
  GL := g*Cos(p*Pi/2);  GR := g*Sin(p*Pi/2);
end;

function AllocVoice: PVoice;
var i: Integer;
begin
  Result := nil;
  for i := 0 to AUD_MAXVOICES-1 do
    if not gVoices[i].Active then begin Result := @gVoices[i]; Break; end;
  if Result = nil then begin
    Result := @gVoices[gSteal mod AUD_MAXVOICES];  Inc(gSteal);
  end;
end;

function NewVoice(Kind: TVoiceKind; TStart, Dur, GL, GR: Double): PVoice;
begin
  Result := AllocVoice;
  if Result = nil then Exit;
  FillChar(Result^, SizeOf(TVoice), 0);
  Result.Active := True;  Result.Kind := Kind;
  Result.TStart := TStart;  Result.Dur := Dur;
  Result.GL := GL;  Result.GR := GR;
end;

procedure SpawnDrumOne(X, Y: Integer);
var v: PVoice; GL, GR: Double;
begin
  if gT - gLastDrum < 0.10 then Exit;
  gLastDrum := gT;
  PlaceAt(X, Y, GL, GR);
  v := NewVoice(vkDrum, gT, 0.75, 0.9*GL, 0.9*GR);
  if v <> nil then v.F0 := 88 + ARand*34;
end;

procedure SpawnDrumWord(const AWord: string; X, Y: Integer);
var i, n: Integer; v: PVoice; GL, GR, f0, t0: Double;
begin
  PlaceAt(X, Y, GL, GR);
  n := Min(Length(AWord), 6);
  t0 := 0.02;
  for i := 1 to n do
  begin
    case AWord[i] of
      'α','a','A': f0 := 78;
      'β','b','B': f0 := 108;
      'γ','g','G': f0 := 66;
      'δ','d','D': f0 := 122;
    else f0 := 90;
    end;
    v := NewVoice(vkDrum, gT + t0, 0.7, 0.85*GL, 0.85*GR);
    if v = nil then Break;
    v.F0 := f0 + ARand*10;
    t0 := t0 + 0.16 + ARand*0.04;
  end;
end;

procedure SpawnLyre(f0, T0, Dur, G: Double);
var v: PVoice;
begin
  v := NewVoice(vkLyre, gT + T0, Dur, G, G);
  if v <> nil then v.F0 := f0;
end;

procedure SpawnBellC(f0, T0, Dur, G: Double);
var v: PVoice;
begin
  v := NewVoice(vkBell, gT + T0, Dur, G, G);
  if v <> nil then v.F0 := f0;
end;

procedure SpawnBellOne(X, Y: Integer);
var v: PVoice; GL, GR: Double;
begin
  PlaceAt(X, Y, GL, GR);
  v := NewVoice(vkBell, gT + 0.02, 2.4, 0.30*GL, 0.30*GR);
  if v <> nil then v.F0 := 620 + ARand*40;
end;

procedure SpawnFanfare(NEra: Integer);
var i: Integer;
begin
  case NEra of
    2: begin
      for i := 0 to 5 do
        SpawnLyre(196.0*PENTA[i mod 5]*(1 + (i div 5)*0.5)*(1 + 0.003*(i and 1)),
                  0.05 + i*0.22, 1.8, 0.30);
      SpawnLyre(392.0,      0.05 + 6*0.22, 3.0, 0.22);
      SpawnLyre(196.0*1.25, 0.05 + 6*0.22, 3.0, 0.15);
      SpawnLyre(196.0*1.5,  0.05 + 6*0.22, 3.0, 0.15);
    end;
    3: for i := 0 to 2 do
      SpawnBellC(164.0 - i*26, 0.05 + i*1.2, 4.0, 0.34);
  end;
end;

{ voix v2 — synthèse additive : 6 harmoniques modelées par voyelle,
  enveloppe naturelle, vibrato + jitter propres au locuteur. }
procedure SpawnWord(const AWord: string; X, Y: Integer);
var i, n, k,k2: Integer; h: Cardinal;
    f0, GL, GR, t0, dur: Double;
    v: PVoice;
begin
  Inc(gDbgCall);
  if AWord = '' then Exit;
  gCS.Enter;
  if Sqr(X - gLX) + Sqr(Y - gLY) > Sqr(50) then begin gCS.Leave; Exit end;
  gCS.Leave;
  h := WordHash(AWord);
  PlaceAt(X, Y, GL, GR);
  n := Min(Length(AWord), 6);
  t0 := 0;
  for i := 1 to n do
  begin
    // — modèle d'harmoniques par voyelle (le cœur du timbre) —
    case AWord[i] of
      'α','a','A': begin          // « a » : riche, ouvert
        k := Integer((h shr ((i and 7)*2)) and $F);
        f0 := 140.0*PENTA[k mod 5];
        if (k and 8) <> 0 then f0 := f0*1.335;
        v := NewVoice(vkVoice, gT + t0, 0.22 + ARand*0.05, 0.5*GL, 0.5*GR);
        if v = nil then Break;
        v.Amp[0] := 1.00; v.Amp[1] := 0.72; v.Amp[2] := 0.48;
        v.Amp[3] := 0.22; v.Amp[4] := 0.10; v.Amp[5] := 0.05;
      end;
      'β','b','B': begin          // « o » : rond, sombre
        k := Integer((h shr ((i and 7)*2)) and $F);
        f0 := 118.0*PENTA[k mod 5];
        if (k and 8) <> 0 then f0 := f0*1.335;
        v := NewVoice(vkVoice, gT + t0, 0.24 + ARand*0.05, 0.5*GL, 0.5*GR);
        if v = nil then Break;
        v.Amp[0] := 1.00; v.Amp[1] := 0.55; v.Amp[2] := 0.20;
        v.Amp[3] := 0.07; v.Amp[4] := 0.03; v.Amp[5] := 0.01;
      end;
      'γ','g','G': begin          // « é/i » : clair, front
        k := Integer((h shr ((i and 7)*2)) and $F);
        f0 := 165.0*PENTA[k mod 5];
        if (k and 8) <> 0 then f0 := f0*1.335;
        v := NewVoice(vkVoice, gT + t0, 0.20 + ARand*0.04, 0.46*GL, 0.46*GR);
        if v = nil then Break;
        v.Amp[0] := 0.45; v.Amp[1] := 1.00; v.Amp[2] := 0.85;
        v.Amp[3] := 0.40; v.Amp[4] := 0.18; v.Amp[5] := 0.07;
      end;
      'δ','d','D': begin          // « ou/u » : profond, gorge
        k := Integer((h shr ((i and 7)*2)) and $F);
        f0 := 105.0*PENTA[k mod 5];
        if (k and 8) <> 0 then f0 := f0*1.335;
        v := NewVoice(vkVoice, gT + t0, 0.26 + ARand*0.05, 0.5*GL, 0.5*GR);
        if v = nil then Break;
        v.Amp[0] := 1.00; v.Amp[1] := 0.38; v.Amp[2] := 0.08;
        v.Amp[3] := 0.02; v.Amp[4] := 0.01; v.Amp[5] := 0;
      end;
    else begin                    // défaut : « e » neutre
        k := Integer((h shr ((i and 7)*2)) and $F);
        f0 := 150.0*PENTA[k mod 5];
        v := NewVoice(vkVoice, gT + t0, 0.22, 0.46*GL, 0.46*GR);
        if v = nil then Break;
        v.Amp[0] := 1.00; v.Amp[1] := 0.80; v.Amp[2] := 0.50;
        v.Amp[3] := 0.25; v.Amp[4] := 0.12; v.Amp[5] := 0.05;
      end;
    end;
    // — hauteur de fin : la syllabe « tombe » légèrement —
    v.F0 := f0;
    v.FEnd := f0*0.90;
    // — vibrato + jitter : la signature vivante du locuteur —
    v.NVib := 4.5 + (h mod 20)/10.0;          // 4.5-6.5 Hz selon l'individu/mot
    v.NJit := 0.004 + (h shr 5 mod 100)/20000.0;
    t0 := t0 + 0.19 + ARand*0.06;             // ~5 syllabes/s, posées
  end;
end;
procedure PushTrig(const t: TTrig);
begin
  gCS.Enter;
  try
    if (gTrigW + 1) mod Length(gTrig) <> gTrigR then
    begin
      gTrig[gTrigW] := t;
      gTrigW := (gTrigW + 1) mod Length(gTrig);
    end;
  finally
    gCS.Leave;
  end;
end;

procedure DrainTrigs;
var t: TTrig;
begin
  repeat
    t := Default(TTrig);
    gCS.Enter;
    try
      if gTrigR <> gTrigW then
      begin
        t := gTrig[gTrigR];
        gTrig[gTrigR] := Default(TTrig);
        gTrigR := (gTrigR + 1) mod Length(gTrig);
      end;
    finally
      gCS.Leave;
    end;
    if t.Kind = tkNone then Break;
    Inc(gDbgTrig);                           // ★DIAG tout trig drainé
    case t.Kind of
      tkSpeak:
        if t.Drummed then SpawnDrumWord(t.AWord, t.X, t.Y)
                     else begin
                       SpawnWord(t.AWord, t.X, t.Y);
                       Inc(gDbgSpeak);
                     end;
      tkDrumOne: SpawnDrumOne(t.X, t.Y);
      tkEre:     SpawnFanfare(t.Num);
      tkBellOne: SpawnBellOne(t.X, t.Y);
    end;
  until False;
end;

procedure ScheduleAmbient;
var v: PVoice; r, GL, GR: Double;
begin
  if (gA_Day > 0.35) and (gT >= gNextChirp) then
  begin
    gNextChirp := gT + 1.0 + (ARand + 0.5)*6.0*(1.35 - gA_Day);
    r := ARand + 0.5;
    GL := Cos(r*Pi/2)*0.12;  GR := Sin(r*Pi/2)*0.12;
    v := NewVoice(vkChirp, gT + 0.05 + ARand*0.1, 0.07 + (ARand+0.5)*0.14, GL, GR);
    if v <> nil then
    begin
      v.F0 := 2300 + (ARand + 0.5)*1900;
      v.Fm := 16 + (ARand + 0.5)*34;
    end;
    if (ARand + 0.5) < 0.35 then
    begin
      v := NewVoice(vkChirp, gT + 0.25, 0.06 + (ARand+0.5)*0.1, GR*0.8, GL*0.8);
      if v <> nil then
      begin
        v.F0 := 2300 + (ARand + 0.5)*1900;
        v.Fm := 16 + (ARand + 0.5)*34;
      end;
    end;
  end;
  if (gA_Fire > 0.02) and (gT >= gNextCrack) then
  begin
    gNextCrack := gT + (0.04 + (ARand + 0.5)*0.35)/Max(gA_Fire, 0.05);
    r := ARand + 0.5;
    v := NewVoice(vkCrackle, gT, 0.02 + (ARand+0.5)*0.05,
                  Cos(r*Pi/2)*0.16*gA_Fire, Sin(r*Pi/2)*0.16*gA_Fire);
    if v <> nil then v.B1.SetBP(600 + (ARand + 0.5)*2800, 4.5);
  end;
end;

function S2I(x: Double): SmallInt; inline;
var t: Double;
begin
  t := x*gA_Vol;
  t := t/(1 + Abs(t));
  Result := SmallInt(Round(t*32500));
end;

procedure MixSample(out L, R: Double);
var i,k2: Integer; v: PVoice;
    s, e, f, src, n, et: Double;
begin
  L := 0; R := 0;

  for i := 0 to AUD_MAXVOICES-1 do
  begin
    v := @gVoices[i];
    if not v.Active then Continue;
    if gT < v.TStart then Continue;
    et := gT - v.TStart;
    if et >= v.Dur then begin v.Active := False; Continue; end;
    s := 0;
    case v.Kind of
      vkDrum:
        begin
          e := Exp(-et*6.5);
          f := v.F0*(1 + 0.5*Exp(-et*35));
          v.Phase := v.Phase + 2*Pi*f*INV_SR;
          s := Sin(v.Phase) + 0.45*Sin(v.Phase*1.62 + 0.4)*Exp(-et*11);
          n := ARand*Exp(-et*140);
          s := 1.15*e*s + 0.8*n;
        end;
              vkVoice:  // ★ synthèse additive : 6 harmoniques, enveloppe, vibrato, jitter
        begin
          // enveloppe : attaque 30 ms · tenue ondulée · chute douce
          e := et/0.03; if e > 1 then e := 1;
          e := e * Exp(-2.2*(et/v.Dur));
          if e > 1 then e := 1;
          // fréquence : glissando descendant + vibrato + jitter
          f := (v.F0 + (v.FEnd - v.F0)*(et/v.Dur)) *
               (1 + 0.010*Sin(2*Pi*v.NVib*et)
                  + v.NJit*Sin(2*Pi*7.7*et + 1.3)
                  + v.NJit*0.6*Sin(2*Pi*11.3*et));
          s := 0;
          // — la somme des 6 harmoniques (phases accumulées séparément) —
          src := 0;
          for k2 := 0 to 5 do begin
            v.Phase := v.Phase;   // (Phase sert à l'harmonique 1, voir ci-dessous)
          end;
          // harmonique 1 (fondamentale)
          v.Phase := v.Phase + 2*Pi*f*INV_SR;
          if v.Phase > 2*Pi then v.Phase := v.Phase - 2*Pi;
          s := v.Amp[0]*Sin(v.Phase);
          // harmoniques 2..6 : phases dérivées (2×, 3×, 4×, 5×, 6× la fondamentale)
          if v.Amp[1] > 0 then s := s + v.Amp[1]*Sin(2*v.Phase + 0.5);
          if v.Amp[2] > 0 then s := s + v.Amp[2]*Sin(3*v.Phase + 1.1);
          if v.Amp[3] > 0 then s := s + v.Amp[3]*Sin(4*v.Phase + 0.2);
          if v.Amp[4] > 0 then s := s + v.Amp[4]*Sin(5*v.Phase + 2.0);
          if v.Amp[5] > 0 then s := s + v.Amp[5]*Sin(6*v.Phase + 1.7);
          // micro-souffle glottal (humanise l'attaque)
          n := ARand*0.02*e;
          s := 1.15*(s*e + n);
        end;
      vkChirp:
        begin
          e := et/0.008; if e > 1 then e := 1;
          e := e*Exp(-et*16);
          v.Phase := v.Phase + 2*Pi*v.F0*INV_SR;
          s := Sin(v.Phase + 2.2*Sin(2*Pi*v.Fm*et))*e;
        end;
      vkCrackle:
        s := v.B1.Process(ARand*2)*Exp(-et*70);
      vkLyre:
        begin
          e := Exp(-et*3.2);
          v.Phase := v.Phase + 2*Pi*v.F0*INV_SR;
          src :=    Sin(v.Phase)
                  + 0.62*Exp(-et*5.0)*Sin(2*v.Phase)
                  + 0.40*Exp(-et*9.0)*Sin(2.99*v.Phase)
                  + 0.26*Exp(-et*15.0)*Sin(4.02*v.Phase)
                  + 0.14*Exp(-et*22.0)*Sin(5.04*v.Phase)
                  + 0.08*Exp(-et*30.0)*Sin(6.05*v.Phase);
          n := ARand*Exp(-et*110)*1.4;
          s := 0.9*(src*e + n);
        end;
      vkBell:
        begin
          v.Phase := v.Phase + 2*Pi*v.F0*INV_SR;
          s :=    1.10*Exp(-et*0.9)*Sin(v.Phase)
                + 0.60*Exp(-et*1.4)*Sin(2.00*v.Phase + 0.3)
                + 0.50*Exp(-et*2.0)*Sin(2.40*v.Phase)
                + 0.34*Exp(-et*2.6)*Sin(3.01*v.Phase)
                + 0.20*Exp(-et*3.2)*Sin(4.48*v.Phase)
                + 0.12*Exp(-et*5.0)*Sin(5.93*v.Phase)
                + 0.10*Exp(-et*0.4)*Sin(0.50*v.Phase);
          n := ARand*Exp(-et*90)*0.8;
          s := 0.6*(s + n);
        end;
    end;
    L := L + s*v.GL;  R := R + s*v.GR;
  end;

  n := ARand;
  gWindLP := gWindLP + 0.028*(n - gWindLP);
  s := gWindLP*(1 + 0.4*Sin(2*Pi*0.017*gT) + 0.25*Sin(2*Pi*0.041*gT + 2.0))*0.45;
  L := L + s;  R := R + s;

  if gA_Wave > 0.002 then
  begin
    gWaveLP1 := gWaveLP1 + 0.05*((ARand*1.7) - gWaveLP1);
    gWaveLP2 := gWaveLP2 + 0.045*(gWaveLP1 - gWaveLP2);
    e := 0.5 + 0.5*Sin(2*Pi*0.070*gT);
    e := e*e*(0.65 + 0.35*(0.5 + 0.5*Sin(2*Pi*0.043*gT + 1.7)));
    s := (gWaveLP2*4.0 + (gWaveLP1 - gWaveLP2)*7.0)*e*gA_Wave*0.25;
    L := L + s;  R := R + s;
  end;

  if gA_Day < 0.85 then
  begin
    e := Sqr(1 - gA_Day)*0.055;
    f := Sin(2*Pi*4300*gT);
    src := Sin(2*Pi*23*gT);     src := src*src*src*src;
    n := 0.5 + 0.5*Sin(2*Pi*0.85*gT + 0.6); n := n*n*n;
    s := f*src*n;
    f := Sin(2*Pi*3850*gT + 1.1);
    src := Sin(2*Pi*19.5*gT + 2.1); src := src*src*src*src;
    n := 0.5 + 0.5*Sin(2*Pi*0.63*gT + 3.0); n := n*n*n;
    L := L + (s + 0.7*f*src*n)*e;
    R := R + (0.8*s + f*src*n)*e;
    s := Sin(2*Pi*52*gT + 0.4)*0.30*e;
    L := L + s;  R := R + s;
  end;

  if gA_Fire > 0.01 then
  begin
    gFireLP := gFireLP + 0.012*(ARand - gFireLP);
    s := (gFireLP*2.5 + gFireLP*gFireLP*20)*gA_Fire*0.15;
    L := L + s;  R := R + s;
  end;

  gT := gT + INV_SR;
end;

procedure PostBuffer(idx: Integer);
var p: PSmallInt; i, I2: Integer; L, R: Double;
begin
  Inc(gDbgBeat);                             // ★DIAG le cœur bat
  gCS.Enter;
  gA_Day := gDay;  gA_Wave := gWave;  gA_Fire := gFire;  gA_Vol := gVol;
  gCS.Leave;
  DrainTrigs;
  gVoixDepuisDernier := 0;
  gDbgVox := 0;
  for I2 := 0 to AUD_MAXVOICES-1 do
    if gVoices[I2].Active and (gVoices[I2].Kind = vkVoice) then Inc(gDbgVox);
  ScheduleAmbient;
  p := @gBuf[idx][0];
  for i := 0 to AUD_FRAMES-1 do
  begin
    MixSample(L, R);
    p^ := S2I(L); Inc(p);
    p^ := S2I(R); Inc(p);
  end;
  if hWO <> 0 then
    if waveOutWrite(hWO, @gHdr[idx], SizeOf(TWaveHdr)) <> MMSYSERR_NOERROR then
      AudioErr := 'waveOutWrite a échoué';   // ★DIAG device
end;

procedure TAudioThread.Execute;
var i: Integer;
begin
  Priority := tpHigher;
  try
    for i := 0 to AUD_BUFFERS-1 do PostBuffer(i);
    while (not Terminated) and gRun do
    begin
      WaitForSingleObject(hEv, 150);
      for i := 0 to AUD_BUFFERS-1 do
        if (gHdr[i].dwFlags and WHDR_DONE) <> 0 then
          PostBuffer(i);
    end;
  except
    on E: Exception do
      AudioErr := 'AUDIO CRASH: ' + E.Message;   // ★DIAG le filet
  end;
end;

procedure AudioInit;
var i: Integer;
begin
  if gRun then Exit;
  if gCS = nil then gCS := TCriticalSection.Create;
  gRng := $9E3779B9 or 1;
  hEv := CreateEvent(nil, False, False, nil);
  if hEv = 0 then Exit;
  FillChar(gFmt, SizeOf(gFmt), 0);
  gFmt.wFormatTag := WAVE_FORMAT_PCM;
  gFmt.nChannels := 2;
  gFmt.nSamplesPerSec := AUD_SR;
  gFmt.wBitsPerSample := 16;
  gFmt.nBlockAlign := 4;
  gFmt.nAvgBytesPerSec := AUD_SR*4;
  if waveOutOpen(@hWO, WAVE_MAPPER, @gFmt, DWORD_PTR(hEv), 0, CALLBACK_EVENT)
       <> MMSYSERR_NOERROR then
  begin
    hWO := 0;  CloseHandle(hEv);  hEv := 0;
    Exit;
  end;
  for i := 0 to AUD_BUFFERS-1 do
  begin
    FillChar(gHdr[i], SizeOf(TWaveHdr), 0);
    gHdr[i].lpData := PAnsiChar(@gBuf[i][0]);
    gHdr[i].dwBufferLength := AUD_FRAMES*4;
    waveOutPrepareHeader(hWO, @gHdr[i], SizeOf(TWaveHdr));
  end;
  gRun := True;
  gThr := TAudioThread.Create(False);
end;

procedure AudioShutdown;
var i: Integer;
begin
  gRun := False;
  if gThr <> nil then begin gThr.WaitFor; FreeAndNil(gThr); end;
  if hWO <> 0 then
  begin
    waveOutReset(hWO);
    for i := 0 to AUD_BUFFERS-1 do
      waveOutUnprepareHeader(hWO, @gHdr[i], SizeOf(TWaveHdr));
    waveOutClose(hWO);
    hWO := 0;
  end;
  if hEv <> 0 then begin CloseHandle(hEv); hEv := 0; end;
  FreeAndNil(gCS);
end;

function AudioReady: Boolean;
begin
  Result := gRun and (hWO <> 0);
end;

procedure AudioSetDayLight(v: Single);
begin if gCS = nil then Exit; gCS.Enter; try gDay := Clamp(Double(v), 0.0, 1.0); finally gCS.Leave; end; end;

procedure AudioSetWaves(v: Single);
begin if gCS = nil then Exit; gCS.Enter; try gWave := Clamp(Double(v), 0.0, 1.0); finally gCS.Leave; end; end;

procedure AudioSetFire(v: Single);
begin if gCS = nil then Exit; gCS.Enter; try gFire := Clamp(Double(v), 0.0, 1.0); finally gCS.Leave; end; end;

procedure AudioSetMasterVolume(v: Single);
begin if gCS = nil then Exit; gCS.Enter; try gVol := Clamp(Double(v), 0.0, 1.0); finally gCS.Leave; end; end;

procedure AudioSetListener(X, Y: Integer);
begin if gCS = nil then Exit; gCS.Enter; try gLX := X; gLY := Y; finally gCS.Leave; end; end;

procedure AudioSpeak(const AWord: string; X, Y: Integer; Drummed: Boolean);
var t: TTrig;
begin
  if (gCS = nil) or (AWord = '') then Exit;
  Inc(gDbgPush);                             // ★DIAG
  t := Default(TTrig);
  t.Kind := tkSpeak;  t.X := X;  t.Y := Y;  t.Drummed := Drummed;  t.AWord := AWord;
  PushTrig(t);
end;

procedure AudioVoiceID(ID: Integer; X, Y: Integer);
//const LETTRES = 'abgd';
const LETTRES = 'αβγδ';
var s: string; i, n: Integer;
begin
  s := '';
  n := 3 + (Abs(ID) mod 3);
  for i := 0 to n-1 do
    s := s + LETTRES[(Abs((ID shr i) xor (ID shr (i+3))) mod 4) + 1];
  AudioSpeak(s, X, Y);
end;

procedure AudioDrum(X, Y: Integer);
var t: TTrig;
begin
  if gCS = nil then Exit;
  t := Default(TTrig);
  t.Kind := tkDrumOne;  t.X := X;  t.Y := Y;
  PushTrig(t);
end;

procedure AudioEre(NEra: Integer);
var t: TTrig;
begin
  if gCS = nil then Exit;
  t := Default(TTrig);
  t.Kind := tkEre;  t.Num := NEra;
  PushTrig(t);
end;

procedure AudioBell(X, Y: Integer);
var t: TTrig;
begin
  if gCS = nil then Exit;
  t := Default(TTrig);
  t.Kind := tkBellOne;  t.X := X;  t.Y := Y;
  PushTrig(t);
end;

function AudioDebug: string;
begin
  if gCS = nil then Exit('audio NON initialisé');
  gCS.Enter;
  try
    Result := Format('%sprêt:%s · run:%s · thr:%s · beat:%d · vol:%.2f · push:%d · trigs:%d · call:%d · mots:%d · voix:%d',
      [AudioErr, BoolToStr(AudioReady, True), BoolToStr(gRun, True),
       BoolToStr(gThr <> nil, True), gDbgBeat, gVol,
       gDbgPush, gDbgTrig, gDbgCall, gDbgSpeak, gDbgVox]);
  finally
    gCS.Leave;
  end;
end;

end.

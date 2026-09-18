                                                              unit MicroIO;

{ Microcosme — sauvegarde/chargement v11.
  v11 ★ERE8 : + ère (FEra) et effet bibliothèque (FBiblio), camp
  (FHomeSet/X/Y, omis en v9), journal des inventions (InnoLog) et bits
  d'invention (InnoK) par créature — les critères de passage d'ère
  survivent désormais au chargement. Les techs ères 2-3 sont relues via
  BitsToTech (en v10, seules les 7 techs d'ère 1 étaient restaurées).
  Garde-fou créatures élargi (EreMaxS). Les vieilles saves sont refusées
  par le contrôle de version (voulu : formats incompatibles). }

interface

uses
  System.SysUtils, System.Classes, System.Math, System.Generics.Collections,
  Winapi.Windows,
  MicroTypes, MicroBrain, MicroSim, MicroRender, MicroIno, MicroChrono,
  MicroEre;   // ★ERE8

procedure SaveWorld;
procedure LoadWorld;

implementation

procedure CheckCount(N, MaxN: Integer; const What: string);
begin
  if (N < 0) or (N > MaxN) then
    raise EReadError.CreateFmt('nombre de %s invalide: %d', [What, N]);
end;

function SavePath: string;
begin
  Result := ExtractFilePath(ParamStr(0)) + 'microcosme.sav';
end;

procedure WriteStr(FS: TFileStream; const S: string);
var L: Integer; B: TBytes;
begin
  B := TEncoding.UTF8.GetBytes(S);
  L := Length(B);
  FS.WriteBuffer(L, SizeOf(Integer));
  if L > 0 then FS.WriteBuffer(B[0], L);
end;

function ReadStr(FS: TFileStream): string;
var L: Integer; B: TBytes;
begin
  FS.ReadBuffer(L, SizeOf(Integer));
  if (L < 0) or (L > 10000) then raise Exception.Create('données corrompues');
  SetLength(B, L);
  if L > 0 then FS.ReadBuffer(B[0], L);
  Result := TEncoding.UTF8.GetString(B);
end;

procedure SaveWorld;
var FS: TFileStream; I, N, B: Integer; C: TCreature; P: TPlant;
   Ver: Integer; TmpS: Single; TT: TTech;
begin
  FSimCS.Enter;
  try
    FS := TFileStream.Create(SavePath, fmCreate);
    try
      Ver := SVERSION;
      FS.WriteBuffer(SMAGIC, 4);
      FS.WriteBuffer(Ver, SizeOf(Integer));
      FS.WriteBuffer(SX, SizeOf(Integer));  FS.WriteBuffer(SY, SizeOf(Integer));
      FS.WriteBuffer(FSimTime, SizeOf(Single));
      FS.WriteBuffer(UidH, SizeOf(Integer)); FS.WriteBuffer(UidP, SizeOf(Integer));
      FS.WriteBuffer(UidS, SizeOf(Integer));
      FS.WriteBuffer(FZoom, SizeOf(Single)); FS.WriteBuffer(FCamX, SizeOf(Single));
      FS.WriteBuffer(FCamY, SizeOf(Single));
      FS.WriteBuffer(FEra, SizeOf(Integer));             // ★ERE8 ère
      FS.WriteBuffer(FBiblio, SizeOf(Integer));          // ★ERE8 effet bibliothèque
      B := Ord(FHomeSet);                                // ★ERE8 camp (omis en v9)
      FS.WriteBuffer(B, SizeOf(Integer));
      FS.WriteBuffer(FHomeX, SizeOf(Single));
      FS.WriteBuffer(FHomeY, SizeOf(Single));
      N := Length(FHist);
      FS.WriteBuffer(N, SizeOf(Integer));
      if N > 0 then FS.WriteBuffer(FHist[0], N * SizeOf(THistRec));
      for I := 0 to 3 do begin
        TmpS := Lex[I].N;    FS.WriteBuffer(TmpS, SizeOf(Single));
        TmpS := Lex[I].Pred; FS.WriteBuffer(TmpS, SizeOf(Single));
        TmpS := Lex[I].Food; FS.WriteBuffer(TmpS, SizeOf(Single));
      end;
      for TT := Low(TTech) to High(TTech) do begin       // 32 entrées (3 ères)
        WriteStr(FS, TechInfo[TT].Who);
        N := TechInfo[TT].Day;
        FS.WriteBuffer(N, SizeOf(Integer));
      end;
      N := Length(InnoLog);                              // ★ERE8 journal inventions
      FS.WriteBuffer(N, SizeOf(Integer));
      for I := 0 to N - 1 do begin
        FS.WriteBuffer(InnoLog[I].Kind, SizeOf(Integer));
        FS.WriteBuffer(InnoLog[I].Word, SizeOf(Integer));
        FS.WriteBuffer(InnoLog[I].Day, SizeOf(Integer));
        WriteStr(FS, InnoLog[I].Who);
        WriteStr(FS, InnoLog[I].Base);
      end;
      N := Huts.Count;
      FS.WriteBuffer(N, SizeOf(Integer));
      for I := 0 to N - 1 do begin
        FS.WriteBuffer(Huts[I].X, SizeOf(Single));
        FS.WriteBuffer(Huts[I].Y, SizeOf(Single));
        TmpS := Huts[I].Stock; FS.WriteBuffer(TmpS, SizeOf(Single));
        B := Ord(Huts[I].Cult); FS.WriteBuffer(B, SizeOf(Integer));
      end;
      N := Fishes.Count;
      FS.WriteBuffer(N, SizeOf(Integer));
      for I := 0 to N - 1 do begin
        FS.WriteBuffer(Fishes[I].X, SizeOf(Single));
        FS.WriteBuffer(Fishes[I].Y, SizeOf(Single));
        FS.WriteBuffer(Fishes[I].Angle, SizeOf(Single));
        B := Ord(Fishes[I].Deep); FS.WriteBuffer(B, SizeOf(Integer));
        TmpS := Fishes[I].S; FS.WriteBuffer(TmpS, SizeOf(Single));
      end;
      N := Marks.Count;
      FS.WriteBuffer(N, SizeOf(Integer));
      for I := 0 to N - 1 do begin
        FS.WriteBuffer(Marks[I].X, SizeOf(Single));
        FS.WriteBuffer(Marks[I].Y, SizeOf(Single));
        FS.WriteBuffer(Marks[I].WordI, SizeOf(Integer));
        FS.WriteBuffer(Marks[I].Sense, SizeOf(Integer));
        TmpS := Marks[I].Age; FS.WriteBuffer(TmpS, SizeOf(Single));
      end;
      N := Plants.Count;
      FS.WriteBuffer(N, SizeOf(Integer));
      for P in Plants do begin
        FS.WriteBuffer(P.X, SizeOf(Single)); FS.WriteBuffer(P.Y, SizeOf(Single));
        FS.WriteBuffer(P.S, SizeOf(Single));
      end;
      N := 0;
      for C in Creatures do if C.Alive then Inc(N);
      FS.WriteBuffer(N, SizeOf(Integer));
      for C in Creatures do
        if C.Alive then begin
          FS.WriteBuffer(C.Kind, SizeOf(Integer));
          FS.WriteBuffer(C.X, SizeOf(Single));  FS.WriteBuffer(C.Y, SizeOf(Single));
          FS.WriteBuffer(C.Angle, SizeOf(Single)); FS.WriteBuffer(C.WAngle, SizeOf(Single));
          FS.WriteBuffer(C.Sp, SizeOf(Single)); FS.WriteBuffer(C.Se, SizeOf(Single));
          FS.WriteBuffer(C.Sz, SizeOf(Single));
          FS.WriteBuffer(C.Energy, SizeOf(Single)); FS.WriteBuffer(C.MaxE, SizeOf(Single));
          FS.WriteBuffer(C.Age, SizeOf(Single)); FS.WriteBuffer(C.MaxAge, SizeOf(Single));
          FS.WriteBuffer(C.Gen, SizeOf(Integer));
          FS.WriteBuffer(C.ThinkT, SizeOf(Single));
          FS.WriteBuffer(C.RepCd, SizeOf(Single));
          FS.WriteBuffer(C.Born, SizeOf(Single));
          TmpS := C.Orn;    FS.WriteBuffer(TmpS, SizeOf(Single));
          TmpS := C.Pref;   FS.WriteBuffer(TmpS, SizeOf(Single));
          TmpS := C.Hue;    FS.WriteBuffer(TmpS, SizeOf(Single));
          TmpS := C.Cult;   FS.WriteBuffer(TmpS, SizeOf(Single));
          TmpS := C.Tame;   FS.WriteBuffer(TmpS, SizeOf(Single));
          TmpS := C.Trust;  FS.WriteBuffer(TmpS, SizeOf(Single));
          TmpS := C.MilkCd; FS.WriteBuffer(TmpS, SizeOf(Single));
          TmpS := C.MutRate; FS.WriteBuffer(TmpS, SizeOf(Single));
          B := Ord(C.Dom); FS.WriteBuffer(B, SizeOf(Integer));
          B := 0;
          for TT := Low(TTech) to High(TTech) do
            if TT in C.Tech then B := B or (1 shl Ord(TT));
          FS.WriteBuffer(B, SizeOf(Integer));
          FS.WriteBuffer(C.InnoK, SizeOf(Integer));      // ★ERE8 inventions portées
          if C.HomeH <> nil then N := Huts.IndexOf(C.HomeH) else N := -1;
          FS.WriteBuffer(N, SizeOf(Integer));
          WriteStr(FS, C.Name);
          WriteStr(FS, C.State);
          if C.Kind = 2 then
            for I := 0 to NW - 1 do begin
              TmpS := C.Net[I];
              FS.WriteBuffer(TmpS, SizeOf(Single));
            end;
        end;
    finally
      FS.Free;
    end;
    Toast('monde sauvegardé');
  finally
    FSimCS.Leave;
  end;
end;

procedure LoadWorld;
var FS: TFileStream; I, K, N, B: Integer; C: TCreature;
   H: THut; F: TFish; M: TMark;
   Magic: array[0..3] of AnsiChar; VerI, SXi, SYi: Integer;
   FXs, FYs, FSz, TmpS: Single;
   TT: TTech;
begin
  FSimCS.Enter;
  try
    if not FileExists(SavePath) then begin Toast('aucune sauvegarde trouvée'); Exit end;
    try
      FS := TFileStream.Create(SavePath, fmOpenRead or fmShareDenyWrite);
      try
        FS.ReadBuffer(Magic, 4);
        if not CompareMem(@Magic, @SMAGIC, 4) then begin
          Toast('fichier de sauvegarde invalide'); Exit;
        end;
        FS.ReadBuffer(VerI, SizeOf(Integer));
        if VerI <> SVERSION then begin Toast('version incompatible'); Exit end;
        ClearWorldObjects;
        ResetChron;
        ChronAdd(CK_PEOPLE, 'les annales reprennent avec le monde chargé');
        ResetInno;
        ResetEre;                                        // ★ERE8 (puis relecture dessous)
        FS.ReadBuffer(SXi, SizeOf(Integer)); SX := SXi;
        FS.ReadBuffer(SYi, SizeOf(Integer)); SY := SYi;
        GenTerrain; RenderTerrainBmp;
        FS.ReadBuffer(FSimTime, SizeOf(Single));
        FDayT := Frac(FSimTime / CDAY);
        FDayLight := ClampF(0.5 + Sin(FDayT * TAU) * 1.05, 0.05, 1);
        FS.ReadBuffer(UidH, SizeOf(Integer)); FS.ReadBuffer(UidP, SizeOf(Integer));
        FS.ReadBuffer(UidS, SizeOf(Integer));
        FS.ReadBuffer(FZoom, SizeOf(Single)); FS.ReadBuffer(FCamX, SizeOf(Single));
        FS.ReadBuffer(FCamY, SizeOf(Single));
        ClampCam;
        FS.ReadBuffer(N, SizeOf(Integer)); FEra := N;    // ★ERE8
        FS.ReadBuffer(N, SizeOf(Integer)); FBiblio := N; // ★ERE8
        FS.ReadBuffer(B, SizeOf(Integer)); FHomeSet := (B = 1);   // ★ERE8 camp
        FS.ReadBuffer(FXs, SizeOf(Single)); FHomeX := FXs;
        FS.ReadBuffer(FXs, SizeOf(Single)); FHomeY := FXs;
        FS.ReadBuffer(N, SizeOf(Integer));
        CheckCount(N, HISTMAX, 'points historiques');
        SetLength(FHist, N);
        if N > 0 then FS.ReadBuffer(FHist[0], N * SizeOf(THistRec));
        for I := 0 to 3 do begin
          FS.ReadBuffer(TmpS, SizeOf(Single)); Lex[I].N := TmpS;
          FS.ReadBuffer(TmpS, SizeOf(Single)); Lex[I].Pred := TmpS;
          FS.ReadBuffer(TmpS, SizeOf(Single)); Lex[I].Food := TmpS;
        end;
        for TT := Low(TTech) to High(TTech) do begin
          TechInfo[TT].Who := ReadStr(FS);
          FS.ReadBuffer(N, SizeOf(Integer));
          TechInfo[TT].Day := N;
        end;
        FS.ReadBuffer(N, SizeOf(Integer));               // ★ERE8 journal inventions
        CheckCount(N, 64, 'inventions');
        SetLength(InnoLog, N);
        for I := 0 to N - 1 do begin
          FS.ReadBuffer(InnoLog[I].Kind, SizeOf(Integer));
          FS.ReadBuffer(InnoLog[I].Word, SizeOf(Integer));
          FS.ReadBuffer(InnoLog[I].Day, SizeOf(Integer));
          InnoLog[I].Who := ReadStr(FS);
          InnoLog[I].Base := ReadStr(FS);
        end;
        FS.ReadBuffer(N, SizeOf(Integer));
        CheckCount(N, MAXH, 'huttes');
        for I := 1 to N do begin
          H := THut.Create;
          FS.ReadBuffer(FXs, SizeOf(Single)); H.X := FXs;
          FS.ReadBuffer(FYs, SizeOf(Single)); H.Y := FYs;
          FS.ReadBuffer(TmpS, SizeOf(Single)); H.Stock := TmpS;
          FS.ReadBuffer(B, SizeOf(Integer)); H.Cult := (B = 1);
          H.Fire := False;
          Huts.Add(H);
        end;
        FS.ReadBuffer(N, SizeOf(Integer));
        CheckCount(N, MAXFS + MAXFD, 'poissons');
        for I := 1 to N do begin
          F := TFish.Create;
          FS.ReadBuffer(FXs, SizeOf(Single)); F.X := FXs;
          FS.ReadBuffer(FYs, SizeOf(Single)); F.Y := FYs;
          FS.ReadBuffer(FXs, SizeOf(Single)); F.Angle := FXs;
          FS.ReadBuffer(B, SizeOf(Integer)); F.Deep := (B = 1);
          FS.ReadBuffer(FSz, SizeOf(Single)); F.S := FSz;
          Fishes.Add(F);
          if F.Deep then Inc(FdN) else Inc(FsN);
        end;
        FS.ReadBuffer(N, SizeOf(Integer));
        CheckCount(N, 100000, 'marques');
        for I := 1 to N do begin
          M := TMark.Create;
          FS.ReadBuffer(FXs, SizeOf(Single)); M.X := FXs;
          FS.ReadBuffer(FYs, SizeOf(Single)); M.Y := FYs;
          FS.ReadBuffer(B, SizeOf(Integer)); M.WordI := B;
          FS.ReadBuffer(B, SizeOf(Integer)); M.Sense := B;
          FS.ReadBuffer(TmpS, SizeOf(Single)); M.Age := TmpS;
          Marks.Add(M);
        end;
        FS.ReadBuffer(N, SizeOf(Integer));
        CheckCount(N, MAXP, 'plantes');
        for I := 1 to N do begin
          FS.ReadBuffer(FXs, SizeOf(Single)); FS.ReadBuffer(FYs, SizeOf(Single));
          FS.ReadBuffer(FSz, SizeOf(Single));
          AddPlant(FXs, FYs, FSz);
        end;
        FS.ReadBuffer(N, SizeOf(Integer));
        // ★ERE8 garde-fou élargi : 300 herbivores + 80 prédateurs + EreMaxS + chiens
        CheckCount(N, MAXH + MAXC + EreMaxS + MAXDOG, 'créatures');
        for I := 1 to N do begin
          C := TCreature.Create;
          FS.ReadBuffer(C.Kind, SizeOf(Integer));
          FS.ReadBuffer(C.X, SizeOf(Single));  FS.ReadBuffer(C.Y, SizeOf(Single));
          FS.ReadBuffer(C.Angle, SizeOf(Single)); FS.ReadBuffer(C.WAngle, SizeOf(Single));
          FS.ReadBuffer(C.Sp, SizeOf(Single)); FS.ReadBuffer(C.Se, SizeOf(Single));
          FS.ReadBuffer(C.Sz, SizeOf(Single));
          FS.ReadBuffer(C.Energy, SizeOf(Single)); FS.ReadBuffer(C.MaxE, SizeOf(Single));
          FS.ReadBuffer(C.Age, SizeOf(Single)); FS.ReadBuffer(C.MaxAge, SizeOf(Single));
          FS.ReadBuffer(C.Gen, SizeOf(Integer));
          FS.ReadBuffer(C.ThinkT, SizeOf(Single));
          FS.ReadBuffer(C.RepCd, SizeOf(Single));
          FS.ReadBuffer(C.Born, SizeOf(Single));
          FS.ReadBuffer(TmpS, SizeOf(Single)); C.Orn := TmpS;
          FS.ReadBuffer(TmpS, SizeOf(Single)); C.Pref := TmpS;
          FS.ReadBuffer(TmpS, SizeOf(Single)); C.Hue := TmpS;
          FS.ReadBuffer(TmpS, SizeOf(Single)); C.Cult := TmpS;
          FS.ReadBuffer(TmpS, SizeOf(Single)); C.Tame := TmpS;
          FS.ReadBuffer(TmpS, SizeOf(Single)); C.Trust := TmpS;
          FS.ReadBuffer(TmpS, SizeOf(Single)); C.MilkCd := TmpS;
          FS.ReadBuffer(TmpS, SizeOf(Single)); C.MutRate := TmpS;
          FS.ReadBuffer(B, SizeOf(Integer)); C.Dom := (B = 1);
          FS.ReadBuffer(B, SizeOf(Integer));
          BitsToTech(Cardinal(B), C.Tech);               // ★ERE8 : les 23 techs, toutes ères
          FS.ReadBuffer(B, SizeOf(Integer));
          C.InnoK := B;                                  // ★ERE8 inventions portées
          FS.ReadBuffer(N, SizeOf(Integer));
          if (N >= 0) and (N < Huts.Count) then C.HomeH := Huts[N]
          else C.HomeH := nil;
          C.HueCol := HueColor(C.Hue);
          C.Name := ReadStr(FS);
          C.State := ReadStr(FS);
          C.Alive := True; C.TargetC := nil; C.TargetP := nil;
          C.Fleeing := False; C.FleeA := 0;
          C.BiteT := 0; C.AtkCd := 0; C.Flash := 0;
          C.Word := -1; C.WordT := 0; C.SPred := nil; C.SFood := nil;
          C.SHerb := nil; C.GuardC := nil; C.SPeer := nil;
          C.Mentor := nil; C.MentorT := 0; C.BuildCd := 0;
          C.CatchT := 0;
          SetLength(C.Mem, 0);
          if C.Kind = 2 then begin
            SetLength(C.Net, NW);
            SetLength(C.Dna, NW);
            SetLength(C.Inp, NIN); SetLength(C.Hid, NHID); SetLength(C.Hid2, NHID2);
            SetLength(C.Oo, NOUT);
            SetLength(C.PrevOo, NOUT);
            for K := 0 to NW - 1 do begin
              FS.ReadBuffer(TmpS, SizeOf(Single));
              C.Net[K] := TmpS;
            end;
            C.Dna := Copy(C.Net, 0, NW);
            for K := 0 to NOUT - 1 do C.PrevOo[K] := 0;
            C.InventT := 2 + Random * 3;                 // ★ERE8 (v9 oubliait ce champ)
          end;
          Creatures.Add(C);
          case C.Kind of
            0: Inc(CountH); 1: Inc(CountP); 2: Inc(CountS); 3: Inc(CountD);
          end;
        end;
        FSelected := nil;
        FRunning := False; FStarted := True;
        if FEra > 1 then
          Toast('monde chargé — ' + ERE_NOM[FEra])
        else
          Toast('monde chargé');
      finally
        FS.Free;
      end;
    except
      Toast('chargement impossible — fichier illisible');
    end;
  finally
    FSimCS.Leave;
  end;
end;

end.

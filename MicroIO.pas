unit MicroIO;

{ Microcosme — sauvegarde/chargement v14.
  Masque de techs en 8 octets (TechBits/BitsToTech UInt64) : les 64 bits,
  ères 4-8 incluses, stables définitivement. Ère + bibliothèque + camp +
  journal des inventions + bits d'invention par créature persistés.
  v15 ★A4 : les VILLES persistées (entre les inventions et les huttes) ;
  le rattachement huttes→villes est RECONSTRUIT par proximité au chargement.
  v14 ★i18n : messages via MicroLang (L()).
  SVERSION = 14 (MicroTypes) : les saves antérieures sont refusées. }

interface

uses
  System.SysUtils, System.Classes, System.Math, System.Generics.Collections,
  Winapi.Windows, System.SyncObjs,
  MicroTypes, MicroBrain, MicroSim, MicroRender, MicroIno, MicroChrono,
  MicroEre, MicroLang;

procedure SaveWorld;
procedure LoadWorld;

implementation

procedure CheckCount(N, MaxN: Integer; const What: string);
begin
  if (N < 0) or (N > MaxN) then
    raise EReadError.CreateFmt(L(133), [What, N]);
end;

function SavePath: string;
begin
  Result := ExtractFilePath(ParamStr(0)) + 'microcosme.sav';
end;

procedure WriteStr(FS: TFileStream; const S: string);
var L8: Integer; B: TBytes;
begin
  B := TEncoding.UTF8.GetBytes(S);
  L8 := Length(B);
  FS.WriteBuffer(L8, SizeOf(Integer));
  if L8 > 0 then FS.WriteBuffer(B[0], L8);
end;

function ReadStr(FS: TFileStream): string;
var L8: Integer; B: TBytes;
begin
  FS.ReadBuffer(L8, SizeOf(Integer));
  if (L8 < 0) or (L8 > 10000) then raise Exception.Create(L(134));
  SetLength(B, L8);
  if L8 > 0 then FS.ReadBuffer(B[0], L8);
  Result := TEncoding.UTF8.GetString(B);
end;

procedure SaveWorld;
var FS: TFileStream; I, N, B: Integer; C: TCreature; P: TPlant;
   Ver: Integer; TmpS: Single; TT: TTech; Mask: UInt64;
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
      FS.WriteBuffer(FEra, SizeOf(Integer));
      FS.WriteBuffer(FBiblio, SizeOf(Integer));
      B := Ord(FHomeSet);
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
      for TT := Low(TTech) to High(TTech) do begin       // 64 entrées, format gelé
        WriteStr(FS, TechInfo[TT].Who);
        N := TechInfo[TT].Day;
        FS.WriteBuffer(N, SizeOf(Integer));
      end;
      N := Length(InnoLog);
      FS.WriteBuffer(N, SizeOf(Integer));
      for I := 0 to N - 1 do begin
        FS.WriteBuffer(InnoLog[I].Kind, SizeOf(Integer));
        FS.WriteBuffer(InnoLog[I].Word, SizeOf(Integer));
        FS.WriteBuffer(InnoLog[I].Day, SizeOf(Integer));
        WriteStr(FS, InnoLog[I].Who);
        WriteStr(FS, InnoLog[I].Base);
      end;

      // ★A4 — les villes (entre les inventions et les huttes, ordre gelé)
      N := Cities.Count;
      FS.WriteBuffer(N, SizeOf(Integer));
      for I := 0 to N - 1 do begin
        FS.WriteBuffer(Cities[I].X, SizeOf(Single));
        FS.WriteBuffer(Cities[I].Y, SizeOf(Single));
        B := Cities[I].Niveau; FS.WriteBuffer(B, SizeOf(Integer));
        B := Cities[I].Jour;   FS.WriteBuffer(B, SizeOf(Integer));
        TmpS := Cities[I].Rayon; FS.WriteBuffer(TmpS, SizeOf(Single));
        WriteStr(FS, Cities[I].Nom);
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
          Mask := TechBits(C.Tech);
          FS.WriteBuffer(Mask, SizeOf(Mask));
          FS.WriteBuffer(C.InnoK, SizeOf(Integer));
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
    Toast(L(3));
  finally
    FSimCS.Leave;
  end;
end;

procedure LoadWorld;
var FS: TFileStream; I, K, N, B: Integer; C: TCreature;
   H: THut; F: TFish; M: TMark; V: TCity;
   Magic: array[0..3] of AnsiChar; VerI, SXi, SYi: Integer;
   FXs, FYs, FSz, TmpS: Single;
   TT: TTech; Mask: UInt64;
begin
  FSimCS.Enter;
  try
    if not FileExists(SavePath) then begin Toast(L(132)); Exit end;
    try
      FS := TFileStream.Create(SavePath, fmOpenRead or fmShareDenyWrite);
      try
        FS.ReadBuffer(Magic, 4);
        if not CompareMem(@Magic, @SMAGIC, 4) then begin
          Toast(L(131)); Exit;
        end;
        FS.ReadBuffer(VerI, SizeOf(Integer));
        if VerI <> SVERSION then begin Toast(L(130)); Exit end;
        ClearWorldObjects;
        ResetChron;
        ChronAdd(CK_PEOPLE, L(135));
        ResetInno;
        ResetEre;
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
        FS.ReadBuffer(N, SizeOf(Integer)); FEra := N;
        FS.ReadBuffer(N, SizeOf(Integer)); FBiblio := N;
        FS.ReadBuffer(B, SizeOf(Integer)); FHomeSet := (B = 1);
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

        // — inventions (boucle COMPLÈTE et autonome) —
        FS.ReadBuffer(N, SizeOf(Integer));
        CheckCount(N, 64, 'inventions');
        SetLength(InnoLog, N);
        for I := 0 to N - 1 do begin
          FS.ReadBuffer(InnoLog[I].Kind, SizeOf(Integer));
          FS.ReadBuffer(InnoLog[I].Word, SizeOf(Integer));
          FS.ReadBuffer(InnoLog[I].Day, SizeOf(Integer));
          InnoLog[I].Who := ReadStr(FS);
          InnoLog[I].Base := ReadStr(FS);
        end;

        // — ★A4 les villes (APRÈS les inventions, AVANT les huttes) —
        FS.ReadBuffer(N, SizeOf(Integer));
        CheckCount(N, 16, 'villes');
        for I := 1 to N do begin
          V := TCity.Create;
          FS.ReadBuffer(FXs, SizeOf(Single)); V.X := FXs;
          FS.ReadBuffer(FXs, SizeOf(Single)); V.Y := FXs;
          FS.ReadBuffer(B, SizeOf(Integer)); V.Niveau := B;
          FS.ReadBuffer(B, SizeOf(Integer)); V.Jour := B;
          FS.ReadBuffer(FXs, SizeOf(Single)); V.Rayon := FXs;
          V.Nom := ReadStr(FS);
          Cities.Add(V);
        end;

        // — huttes —
        FS.ReadBuffer(N, SizeOf(Integer));
        CheckCount(N, MAXH, 'huttes');
        for I := 1 to N do begin
          H := THut.Create;
          FS.ReadBuffer(FXs, SizeOf(Single)); H.X := FXs;
          FS.ReadBuffer(FYs, SizeOf(Single)); H.Y := FYs;
          FS.ReadBuffer(TmpS, SizeOf(Single)); H.Stock := TmpS;
          FS.ReadBuffer(B, SizeOf(Integer)); H.Cult := (B = 1);
          H.Fire := False;
          H.Ville := nil;
          Huts.Add(H);
        end;

        // ★A4 — re-rattachement huttes→villes par proximité (les deux
        // listes sont complètes) — remplace la persistance du champ Ville
        for I := 0 to Huts.Count - 1 do
          for K := 0 to Cities.Count - 1 do
            if Sqr(Huts[I].X - Cities[K].X) + Sqr(Huts[I].Y - Cities[K].Y)
               < Sqr(Cities[K].Rayon) then begin
              Huts[I].Ville := Cities[K];
              Break;
            end;

        // — poissons —
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
          FS.ReadBuffer(Mask, SizeOf(Mask));
          BitsToTech(Mask, C.Tech);
          FS.ReadBuffer(B, SizeOf(Integer));
          C.InnoK := B;
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
            C.InventT := 2 + Random * 3;
          end;
          Creatures.Add(C);
          case C.Kind of
            0: Inc(CountH); 1: Inc(CountP); 2: Inc(CountS); 3: Inc(CountD);
          end;
        end;
        FSelected := nil;
        FRunning := False; FStarted := True;
        if FEra > 1 then
          Toast(Format(L(116), [ERE_NOM(FEra)]))
        else
          Toast(L(4));
      finally
        FS.Free;
      end;
    except
      Toast(L(129));
    end;
  finally
    FSimCS.Leave;
  end;
end;

end.

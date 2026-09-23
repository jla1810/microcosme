unit MicroMain;

{ Microcosme — fiche principale, caméra, scroll du carnet, interactions,
  écran de départ. Aide F1 · son F4.
  v15 ★vues : F5 monde plein écran · F6 retour · F7 Observatoire (cerveau
  géant, clic = sapiens suivant) · ★i18n : F8 bascule français/english.
  Triches verrouillées (Ctrl+Shift) : E équiper · B état · P passer ·
  U fonder une ville · V test voix · W diagnostic audio.
  Passage d'ère automatique si CfgEreAuto (F2). }

interface

uses
  System.SysUtils, System.Types, System.Classes, System.Math,
  System.Generics.Collections,
  Winapi.Windows, Winapi.Messages,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.ExtCtrls,
  MicroTypes, MicroBrain, MicroSim, MicroRender, MicroIO, MicroConfig,
  MicroEvo, MicroInfoWin, MicroAudio, MicroHelp, MicroLogo,MicroVilles;

const
  BID_HELP = 207;

type
  TMainForm = class(TForm)
    procedure FormPaint(Sender: TObject);
    procedure FormMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure FormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure FormMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure FormResize(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure TimerTick(Sender: TObject);
    procedure HelpDemo(Act: Integer);
  private
    procedure WMEraseBkgnd(var Msg: TWMEraseBkgnd); message WM_ERASEBKGND;
    procedure VueApply;                            // ★ modes d'écran F5/F6/F7
  protected
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer;
      MousePos: TPoint): Boolean; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  MainForm: TMainForm;

implementation

uses
  System.Diagnostics, System.SyncObjs, MicroBrainWin, MicroGraph3D,
  MicroIno, MicroChrono, MicroEre, MicroLang;

{$OVERFLOWCHECKS OFF}
{$RANGECHECKS OFF}
{$POINTERMATH OFF}

var
  SoundOn: Boolean = True;
  FSaveBounds: TRect;                              // ★ géométrie fenêtrée d'origine
  CHEAT_GATE: TShiftState = [ssCtrl, ssShift];     // ★ serrure de la triche

{--- ★vues : applique le mode 0/1/2 à la fiche ------------------------------}

procedure TMainForm.VueApply;
begin
  case FVue of
    1, 2: begin
      if BorderStyle <> bsNone then begin
        FSaveBounds := BoundsRect;
        BorderStyle := bsNone;
      end;
      BoundsRect := Screen.DesktopRect;
    end;
  else
    if BorderStyle = bsNone then begin
      BorderStyle := bsSizeable;
      BoundsRect := FSaveBounds;
    end;
  end;
  FormResize(Self);
  Invalidate;
end;

{--- boutons démo de l'aide ---------------------------------------------------}

procedure TMainForm.HelpDemo(Act: Integer);
var I: Integer;
begin
  case Act of
    0: for I := 0 to Creatures.Count - 1 do
         if Creatures[I].Alive and (Creatures[I].Kind = 2) then begin
           FSelected := Creatures[I];
           FCamX := Creatures[I].X;  FCamY := Creatures[I].Y;
           ClampCam;
           Break;
         end;
    1: for I := 1 to 12 do
         AddPlant(FCamX + Random * 12 - 6, FCamY + Random * 12 - 6, 0.5);
    2: SpawnCreature(2, FCamX + 1.5, FCamY + 1.5, nil, nil, 0);
    3: FRunning := not FRunning;
  end;
end;

{--- ★F7 observatoire : sélection des sapiens --------------------------------}

procedure AutoPickSapien;                          // le plus cultivé par défaut
var C, Best: TCreature;
begin
  Best := nil;
  for C in Creatures do
    if C.Alive and (C.Kind = 2) then
      if (Best = nil) or (C.Cult > Best.Cult) then Best := C;
  FSelected := Best;
end;

procedure NextSapien;                              // clic = spécimen suivant
var I, Start: Integer;
begin
  if Creatures.Count = 0 then Exit;
  Start := 0;
  if FSelected <> nil then Start := Creatures.IndexOf(FSelected) + 1;
  for I := 0 to Creatures.Count - 1 do
    if Creatures[(Start + I) mod Creatures.Count].Alive and
       (Creatures[(Start + I) mod Creatures.Count].Kind = 2) then begin
      FSelected := Creatures[(Start + I) mod Creatures.Count];
      Exit;
    end;
end;

{--- outils --------------------------------------------------------------------}

function ClampInt(V, A, B: Integer): Integer;
begin
  if V < A then Exit(A);
  if V > B then Exit(B);
  Result := V;
end;

function ScreenToWorld(SXp, SYp: Single): TPointF;
var S: Single;
begin
  S := FScale * FZoom;
  Result.X := FCamX + (SXp - FVP.Left - FVP.Width / 2) / S + 0.5;
  Result.Y := FCamY + (SYp - FVP.Top - FVP.Height / 2) / S + 0.5;
end;

procedure ZoomAt(MX, MY: Integer; F: Single);
var S0, S1, WA, WB: Single;
begin
  S0 := FScale * FZoom;
  WA := FCamX + (MX - FVP.Left - FVP.Width / 2) / S0;
  WB := FCamY + (MY - FVP.Top - FVP.Height / 2) / S0;
  FZoom := ClampF(FZoom * F, 1, 6);
  S1 := FScale * FZoom;
  FCamX := WA - (MX - FVP.Left - FVP.Width / 2) / S1;
  FCamY := WB - (MY - FVP.Top - FVP.Height / 2) / S1;
  ClampCam;
end;

procedure Pick(X, Y: Single);
var C, Best: TCreature; BD, D: Single;
begin
  Best := nil; BD := 2.2 * 2.2;
  for C in Creatures do begin
    if not C.Alive then Continue;
    D := D2(X, Y, C.X, C.Y);
    if D < BD then begin BD := D; Best := C end;
  end;
  FSelected := Best;
end;

procedure NewWorld;
var G, I: Integer; X, Y: Single;
begin
  FSimCS.Enter;
  try
    ClearWorldObjects;
    ResetEvo;
    ResetInno;
    ResetEre;
    SX := Random(4096); SY := Random(4096);
    GenTerrain;
    RenderTerrainBmp;
    SeedFish;
    FSimTime := CDAY * 0.18; SampleT := 0;
    for I := 1 to 1280 do AddPlant(Random(GW), Random(GH), 0.3 + Random * 0.6);
    for G := 1 to 8 do begin
      X := Random(GW); Y := Random(GH);
      for I := 1 to 15 do
        SpawnCreature(0, X + Random * 8 - 4, Y + Random * 8 - 4, nil, nil, 0);
    end;
    for G := 1 to 3 do begin
      X := Random(GW); Y := Random(GH);
      for I := 1 to 3 do
        SpawnCreature(1, X + Random * 6 - 3, Y + Random * 6 - 3, nil, nil, 0);
    end;
    X := GW / 2; Y := GH / 2;
    for I := 1 to 25 do
      if Walkable(X, Y) and (TerrType[CellIdx(X, Y)] >= T_GRASS) then Break
      else begin X := Random(GW); Y := Random(GH) end;
    for I := 1 to 6 do
      SpawnCreature(2, X + Random * 6 - 3, Y + Random * 6 - 3, nil, nil, 0);
    FHomeX := X; FHomeY := Y;
    FHomeSet := True;
    ResetChron;
    ChronAdd(CK_PEOPLE, L(105));
    FZoom := 1; FCamX := (GW - 1) / 2; FCamY := (GH - 1) / 2;
    FRunning := False; FStarted := False;
    Toast(L(2));
  finally
    FSimCS.Leave;
  end;
end;

{--- fiche ---------------------------------------------------------------------}

procedure TMainForm.WMEraseBkgnd(var Msg: TWMEraseBkgnd);
begin
  Msg.Result := 1;
end;

procedure TMainForm.FormMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var I: Integer; WP: TPointF;
begin
  if HelpOn then begin
    HelpMouseDown(X, Y);
    Invalidate;
    Exit;
  end;
  if FVue = 2 then begin
    if Button = mbLeft then begin NextSapien; Invalidate end;
    Exit;
  end;
  if Button = mbRight then begin
    if X >= FPanelW then begin
      FDrag := True; FDragX := X; FDragY := Y; FDragCX := FCamX; FDragCY := FCamY;
    end;
    Exit;
  end;
  if X < FPanelW then begin
    if (X > PANELW - 8) and (FPanelH > ClientHeight) then begin
      if (Y + FPanelScroll) * ClientHeight div FPanelH < FPanelScroll + ClientHeight div 2 then
        FPanelScroll := FPanelScroll - ClientHeight div 3
      else
        FPanelScroll := FPanelScroll + ClientHeight div 3;
      FPanelScroll := ClampInt(FPanelScroll, 0, FPanelH - ClientHeight);
      Invalidate;
      Exit;
    end;
    for I := 0 to High(FBtns) do
      if PtInRect(FBtns[I].R, Point(X, Y)) then begin
        if (FBtns[I].Id >= BID_CFGDEC) and (FBtns[I].Id < BID_CFGDEC + CN) then begin
          ConfigAdjust(FBtns[I].Id - BID_CFGDEC, -1);
          Invalidate; Exit;
        end;
        if (FBtns[I].Id >= BID_CFGINC) and (FBtns[I].Id < BID_CFGINC + CN) then begin
          ConfigAdjust(FBtns[I].Id - BID_CFGINC, 1);
          Invalidate; Exit;
        end;
        case FBtns[I].Id of
          BID_START: begin FStarted := True; FRunning := True end;
          BID_PLAY:  FRunning := not FRunning;
          BID_S1: FSpeed := 1;
          BID_S2: FSpeed := 2;
          BID_S4: FSpeed := 4;
          BID_TI: FTool := TOOL_INSPECT;
          BID_TS: FTool := TOOL_SEED;
          BID_TH: FTool := TOOL_HERB;
          BID_TP: FTool := TOOL_PRED;
          BID_TSA: FTool := TOOL_SAP;
          BID_SAVE: SaveWorld;
          BID_LOAD: LoadWorld;
          BID_NEW: NewWorld;
          BID_BRAIN: OpenBrainWindow;
          BID_INFO: OpenInfoWindow;
          BID_G3D: OpenGraph3DWindow;
          BID_RELIEF: begin SetRelief(not ReliefOn); Invalidate end;
          BID_CHRON: begin FChronShow := not FChronShow; Invalidate end;
          BID_ERE: if PassEre then begin
            ChronAdd(CK_TECH, Format(L(117), [EreCourante, ERE_NOM(EreCourante)]));
            Toast(Format(L(116), [ERE_NOM(EreCourante)]));
            AudioEre(EreCourante);
          end;
          BID_HELP:  HelpToggle;
          BID_CFGSHOW: begin
            FCfgShow := not FCfgShow;
            if FCfgShow then
              FPanelScroll := MaxInt
            else
              FPanelScroll := 0;
            SaveCfg
          end;
          BID_CFGDEF:  begin ResetCfg; SaveCfg; Toast(L(48)) end;
        end;
        Invalidate;
        Exit;
      end;
    Exit;
  end;
  if not FStarted then begin
    FStarted := True; FRunning := True; Invalidate; Exit;
  end;
  WP := ScreenToWorld(X, Y);
  FSimCS.Enter;
  try
    case FTool of
      TOOL_INSPECT: Pick(WP.X, WP.Y);
      TOOL_SEED: AddPlant(WP.X + (Random - 0.5) * 2, WP.Y + (Random - 0.5) * 2,
                          0.25 + Random * 0.35);
      TOOL_HERB: SpawnCreature(0, WP.X, WP.Y, nil, nil, 0);
      TOOL_PRED: SpawnCreature(1, WP.X, WP.Y, nil, nil, 0);
      TOOL_SAP:  SpawnCreature(2, WP.X, WP.Y, nil, nil, 0);
    end;
  finally
    FSimCS.Leave;
  end;
  Invalidate;
end;

procedure TMainForm.FormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  if FDrag then begin
    FCamX := FDragCX - (X - FDragX) / (FScale * FZoom);
    FCamY := FDragCY - (Y - FDragY) / (FScale * FZoom);
    ClampCam;
    Invalidate;
  end;
end;

procedure TMainForm.FormMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  FDrag := False;
end;

function TMainForm.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer;
  MousePos: TPoint): Boolean;
var P: TPoint;
begin
  if HelpOn then begin
    HelpWheel(WheelDelta);
    Result := True;
    Exit;
  end;
  Result := inherited;
  P := ScreenToClient(MousePos);
  if (FVue = 0) and (P.X < FPanelW) then begin
    FPanelScroll := ClampInt(FPanelScroll - WheelDelta, 0, FPanelH - ClientHeight);
    if FPanelScroll < 0 then FPanelScroll := 0;
    Invalidate;
    Result := True;
  end else if (FVue <> 2) and (P.X >= FVP.Left) and FStarted then begin
    ZoomAt(P.X, P.Y, Exp(-WheelDelta * 0.0016));
    Invalidate;
    Result := True;
  end;
end;

procedure TMainForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_F1 then begin
    Key := 0;
    HelpToggle;
    Exit;
  end;
  HelpKeyDown(Key);

  if Key = VK_SPACE then begin
    if not FStarted then FStarted := True
    else FRunning := not FRunning;
    Key := 0; Invalidate;
  end;
  if Key = VK_F2 then begin
    FCfgShow := not FCfgShow;
    if FCfgShow then FPanelScroll := MaxInt else FPanelScroll := 0;
    SaveCfg;
    Invalidate;
    Key := 0;
  end;
  if Key = VK_F3 then begin
    if FSelected <> nil then OpenInfoWindow;
    Key := 0;
  end;
  if Key = VK_F4 then begin
    SoundOn := not SoundOn;
    if SoundOn then AudioSetMasterVolume(0.85)
               else AudioSetMasterVolume(0);
    Key := 0;
  end;

  // ── ★vues F5 / F6 / F7 ──
  if Key = VK_F5 then begin
    Key := 0;
    FVue := IfThen(FVue = 1, 0, 1);
    VueApply;
    Invalidate;
  end;
  if Key = VK_F6 then begin
    Key := 0;
    FVue := 0;
    VueApply;
    Invalidate;
  end;
  if Key = VK_F7 then begin
    Key := 0;
    FVue := IfThen(FVue = 2, 0, 2);
    if FVue = 2 then AutoPickSapien;
    VueApply;
    Invalidate;
  end;

  // ── ★i18n F8 ──
  if Key = VK_F8 then begin
    Key := 0;
    if FLangue = LANG_FR then FLangue := LANG_EN else FLangue := LANG_FR;
    Toast(LangNom);
    Invalidate;
  end;

  // ── ★ERE triche verrouillée : Ctrl+Shift+E · B · P · U · V · W ──
  if FStarted and (Creatures <> nil) and (Shift = CHEAT_GATE) then begin
    if Key = Ord('E') then begin
      Key := 0;
      var C: TCreature;
      var i, k, Seuil, PopMin: Integer;
      FSimCS.Enter;
      try
        for C in Creatures do
          if C.Alive and (C.Kind = 2) then
            for i := 0 to TECH_COUNT - 1 do
              if TECHBASE[i].Era = EreCourante then
                GiveTech(C, TECHBASE[i].Code);
        Seuil := ERE_INV[Min(EreCourante, ERE_MAX - 1)];
        PopMin := ERE_POP[Min(EreCourante, ERE_MAX - 1)];
        for C in Creatures do
          if C.Alive and (C.Kind = 2) then begin
            for k := 0 to Seuil - 1 do
              if not HasInno(C, k) then GiveInno(C, k);
            Break;
          end;
        while CountS < PopMin do
          SpawnCreature(2, FHomeX + Random * 8 - 4, FHomeY + Random * 8 - 4,
                        nil, nil, 0);
        Toast(Format(L(119), [EreCourante, CountS]));
      finally
        FSimCS.Leave;
      end;
      Invalidate;
    end;


        if Key = Ord('C') then begin          // ★Phase C : triche — élire un chef
      Key := 0;
      var V2: TCity;
      var BD, DD: Single;
      if Cities.Count = 0 then
        Toast('il faut une ville d''abord (Ctrl+Shift+U)')
      else begin
        V2 := Cities[0]; BD := 1e9;
        for var K2 := 0 to Cities.Count - 1 do begin
          DD := Sqr(Cities[K2].X - FCamX) + Sqr(Cities[K2].Y - FCamY);
          if DD < BD then begin BD := DD; V2 := Cities[K2] end;
        end;
        if EloireChef(V2) then Invalidate;  // la ville la plus proche de la caméra
      end;
    end;

 if Key = Ord('R') then begin              // ★ triche : route forcée (ou achevée)
  Key := 0;
  var R: TRoad;
  if Cities.Count < 2 then
    Toast('il faut 2 villes d''abord (Ctrl+Shift+U ×2)')
  else begin
    R := RouteEntre(Cities[0], Cities[1]);
    if R = nil then begin
      R := TRoad.Create;
      R.A := Cities[0];
      R.B := Cities[1];
      R.Chemin := CheminRoute(Trunc(R.A.X), Trunc(R.A.Y),
                              Trunc(R.B.X), Trunc(R.B.Y));
      if Length(R.Chemin) < 2 then begin
        R.Free; R := nil;
        Toast(Format('%s — %s : pas de chemin terrestre (îles ?)',
          [Cities[0].Nom, Cities[1].Nom]));
      end else
        Toast(Format('route forcée : %s — %s (%d cellules)',
          [R.A.Nom, R.B.Nom, Length(R.Chemin)]));
    end else
      Toast('route existante : achevée d''un coup');
    if R <> nil then begin
      R.Prog := High(R.Chemin);           // complète d'un coup
      if Roads.IndexOf(R) < 0 then Roads.Add(R);
    end;
  end;
  Invalidate;
end;


    if Key = Ord('B') then begin
      Key := 0;
      var MsgP: string;
      if CanPassEre then MsgP := L(120)
      else if EreCourante >= MaxEraContent then MsgP := L(121)
      else MsgP := L(122);
      Toast(Format('%s | %s | villes %d · routes %d',
        [EreLabel,
         Format(L(32), [CountTechEre(EreCourante),
                        IfThen(EreCourante = 1, 7, 8),
                        CountS, CountInno, InnoTotal]),
         Cities.Count, Roads.Count]));
      Invalidate;
    end;
    if Key = Ord('P') then begin
      Key := 0;
      if PassEre then begin
        ChronAdd(CK_TECH, Format(L(115), [ERE_NOM(EreCourante)]));
        Toast(Format(L(116), [ERE_NOM(EreCourante)]));
        AudioEre(EreCourante);
      end else if EreCourante >= MaxEraContent then
        Toast(L(124))
      else
        Toast(L(123));
      Invalidate;
    end;
    if Key = Ord('U') then begin              // ★ triche : fonder une ville ici
      Key := 0;
      var H: THut;
      var V: TCity;
      var j: Integer;
      var A, R: Single;
      var CX, CY: Single;
      var Nom: string;
      FSimCS.Enter;
      try
        CX := FCamX; CY := FCamY;
        if not Walkable(CX, CY) then
          for j := 1 to 50 do begin
            CX := FCamX + Random * 10 - 5;
            CY := FCamY + Random * 10 - 5;
            if Walkable(CX, CY) then Break;
          end;
        Nom := '';
        for j := 1 to 2 + Random(2) do
          Nom := Nom + SYL[Random(Length(SYL))];
        Nom[1] := UpCase(Nom[1]);
        V := TCity.Create;
        V.Nom := Nom;
        V.Niveau := 2;
        V.Jour := DayCount;
        V.Rayon := 16.0;
        V.X := CX; V.Y := CY;
        for j := 0 to 11 do begin
          H := THut.Create;
          A := j * 2.399963;                  // l'angle d'or
          R := 1.1 + 0.30 * Sqrt(j);          // spirale de Fermat
          H.X := CX + Cos(A) * R;
          H.Y := CY + Sin(A) * R;
          if not Walkable(H.X, H.Y) then begin
            H.X := CX + Cos(A) * (R + 0.6);
            H.Y := CY + Sin(A) * (R + 0.6);
          end;
          H.Fire := False; H.Cult := False; H.Stock := 0;
          H.Ville := V;
          Huts.Add(H);
        end;
        Cities.Add(V);
        Toast('ville fondée (triche) : ' + Nom);
        ChronAdd(CK_PEOPLE, 'ville de test : ' + Nom);
      finally
        FSimCS.Leave;
      end;
      Invalidate;
    end;
    if Key = Ord('V') then begin
      Key := 0;
      AudioSpeak('abgd', Round(FCamX), Round(FCamY), False);
      Toast('test voix envoyé (abgd)');
      Invalidate;
    end;
    if Key = Ord('W') then begin
      Key := 0;
      Toast(AudioDebug);
      Invalidate;
    end;
  end;
  // ── fin triche ──────────────────────────────────────────────────────────────
end;

procedure TMainForm.FormResize(Sender: TObject);
begin
  if FVue = 2 then
    FVP := Rect(ClientWidth, 0, ClientWidth + 8, Max(ClientHeight, 8))
  else if FVue = 1 then
    FVP := Rect(0, 0, Max(ClientWidth, 8), Max(ClientHeight, 8))
  else
    FVP := Rect(PANELW, 0, Max(ClientWidth, PANELW + 8), Max(ClientHeight, 8));
  if FVue = 2 then FPanelW := PANELW
  else FPanelW := PANELW;
  if (FVP.Width > 0) and (FVP.Height > 0) then begin
    FWorld.SetSize(FVP.Width, FVP.Height);
    FScale := Max(FVP.Width / GW, FVP.Height / GH);
    ClampCam;
  end;
  Invalidate;
end;

procedure TMainForm.FormPaint(Sender: TObject);
var BR: TRect;
   SJ, CurH: Integer;
begin
  try
    if (FWorld.Width <> FVP.Width) or (FWorld.Height <> FVP.Height) then
      FormResize(Self);
    AudioSetListener(Trunc(FCamX), Trunc(FCamY));   // ★ l'oreille = la caméra
    FSimCS.Enter;
    try
      if FVue = 2 then begin
        DrawObservatoire(Canvas, ClientWidth, ClientHeight);
      end else begin
        RenderWorld;
        Canvas.Draw(FVP.Left, FVP.Top, FWorld);

        DrawPanel(FPanelBM.Canvas, 0);
        if FPanelBM.Height < FPanelH then FPanelBM.SetSize(FPanelW, FPanelH);
        if FPanelBM.Width <> FPanelW then FPanelBM.SetSize(FPanelW, FPanelH);
        DrawPanel(FPanelBM.Canvas, FPanelBM.Height);

        if FVue = 0 then begin
          FPanelScroll := ClampInt(FPanelScroll, 0, Max(0, FPanelH - ClientHeight));
          Canvas.CopyRect(Rect(0, 0, PANELW, ClientHeight),
                          FPanelBM.Canvas,
                          Rect(0, FPanelScroll, PANELW, FPanelScroll + ClientHeight));
        end;

        if (FVue = 0) and (FPanelH > ClientHeight) then begin
          Canvas.Brush.Style := bsSolid;
          Canvas.Pen.Style := psClear;
          Canvas.Brush.Color := Col(11, 14, 11);
          Canvas.FillRect(Rect(PANELW - 8, 0, PANELW, ClientHeight));
          CurH := ClientHeight * ClientHeight div FPanelH;
          if CurH < 30 then CurH := 30;
          SJ := (ClientHeight - CurH) * FPanelScroll div (FPanelH - ClientHeight);
          Canvas.Brush.Color := Col(80, 86, 72);
          Canvas.FillRect(Rect(PANELW - 6, SJ, PANELW - 2, SJ + CurH));
        end;

        if FMsgT > 0 then begin
          Canvas.Font.Name := 'Segoe UI'; Canvas.Font.Size := 9; Canvas.Font.Style := [];
          Canvas.Brush.Style := bsSolid; Canvas.Brush.Color := Col(17, 21, 15);
          Canvas.Pen.Style := psSolid; Canvas.Pen.Color := Col(38, 43, 33);
          Canvas.Rectangle(FVP.Left + 20, FVP.Bottom - 44,
                           FVP.Left + 20 + Canvas.TextWidth(FMsg) + 20, FVP.Bottom - 18);
          Canvas.Brush.Style := bsClear; Canvas.Font.Color := Col(230, 224, 205);
          Canvas.TextOut(FVP.Left + 30, FVP.Bottom - 39, FMsg);
        end;
      end;
    finally
      FSimCS.Leave;
    end;
    if (not FStarted) and (FVue = 0) then begin
      Canvas.Brush.Style := bsSolid;
      Canvas.Brush.Color := Col(14, 17, 12);
      Canvas.FillRect(FVP);

      DrawLogo(Canvas,
               FVP.Left + (FVP.Width - 300) div 2,
               FVP.Top + FVP.Height div 2 - 240, 300);

      Canvas.Font.Name := 'Georgia'; Canvas.Font.Size := 34;
      Canvas.Font.Style := [fsItalic, fsBold]; Canvas.Font.Color := Col(230, 224, 205);
      Canvas.Brush.Style := bsClear;
      Canvas.TextOut(FVP.Left + (FVP.Width - Canvas.TextWidth('Microcosme')) div 2,
                     FVP.Top + FVP.Height div 2 +140, 'Microcosme');

      BR := Rect(FVP.Left + FVP.Width div 2 - 100, FVP.Top + FVP.Height div 2 + 210,
                 FVP.Left + FVP.Width div 2 + 100, FVP.Top + FVP.Height div 2 + 252);
      AddBtn(BR, L(0), BID_START, True);
      Canvas.Brush.Style := bsSolid; Canvas.Brush.Color := Col(208, 167, 92);
      Canvas.FillRect(BR);
      Canvas.Brush.Style := bsClear; Canvas.Font.Name := 'Segoe UI';
      Canvas.Font.Size := 10; Canvas.Font.Style := [fsBold];
      Canvas.Font.Color := Col(20, 22, 16);
      Canvas.TextOut((BR.Left + BR.Right - Canvas.TextWidth(L(0))) div 2,
                     BR.Top + 13, L(0));

      Canvas.Font.Name := 'Segoe UI'; Canvas.Font.Size := 9; Canvas.Font.Style := [];
      Canvas.Font.Color := Col(100, 105, 88);
      Canvas.TextOut(FVP.Left + (FVP.Width - Canvas.TextWidth(L(1))) div 2,
                     BR.Bottom + 14, L(1));
    end;

    if HelpOn then
      HelpRender(Canvas, ClientWidth, ClientHeight);
  except
    on E: Exception do begin
      FMsg := 'UI: ' + E.Message; FMsgT := 6;
    end;
  end;
end;

procedure TMainForm.TimerTick(Sender: TObject);
begin
  // ★ passage d'ère automatique si le réglage F2 est sur « auto »
  if FRunning and (CfgEreAuto >= 0.5) and CanPassEre then
    if PassEre then begin
      ChronAdd(CK_TECH, Format(L(117), [EreCourante, ERE_NOM(EreCourante)]));
      Toast(Format(L(116), [ERE_NOM(EreCourante)]));
      AudioEre(EreCourante);
    end;
  Invalidate;
end;

constructor TMainForm.Create(AOwner: TComponent);
var I: Integer;
   SDiag: string;
begin
  inherited CreateNew(AOwner);
  Caption := 'Microcosme';
  Width := 1200; Height := 760;
  Position := poScreenCenter;
  Color := Col(11, 14, 11);
  DoubleBuffered := True;
  KeyPreview := True;
  Randomize;
  Loadcfg;
  SDiag := ExtractFilePath(ParamStr(0)) + 'microdiag.txt';
  if FileExists(SDiag) then DeleteFile(PChar(SDiag));
  FSimCS := TCriticalSection.Create;
  Plants := TList<TPlant>.Create;
  Huts := TList<THut>.Create;
  Cities := TList<TCity>.Create;
  Roads := TList<TRoad>.Create;
  Fishes := TList<TFish>.Create;
  Marks := TList<TMark>.Create;
  Creatures := TList<TCreature>.Create;
  NB := TList<TCreature>.Create;
  SetLength(Buckets, CGWC * CGHC);
  for I := 0 to Length(Buckets) - 1 do Buckets[I] := TList<TCreature>.Create;

  FTerrain := TBitmap.Create;
  FTerrain.PixelFormat := pf32bit;
  FThumb := TBitmap.Create;
  FWorld := TBitmap.Create;
  FTintN := TBitmap.Create;
  FTintW := TBitmap.Create;
  FPanelBM := TBitmap.Create;
  FPanelBM.PixelFormat := pf32bit;
  FPanelScroll := 0;
  FPanelH := 0;
  FPanelW := PANELW;
  FVue := 0;

  OnPaint := FormPaint;
  OnMouseDown := FormMouseDown;
  OnMouseMove := FormMouseMove;
  OnMouseUp := FormMouseUp;
  OnResize := FormResize;
  OnKeyDown := FormKeyDown;

  FTimer := TTimer.Create(Self);
  FTimer.Interval := 15;
  FTimer.OnTimer := TimerTick;
  FTimer.Enabled := True;

  NewWorld;
  FormResize(Self);

  FSimThread := TSimThread.Create(False);
  AudioInit;
  HelpDemoProc := HelpDemo;
end;

destructor TMainForm.Destroy;
var i: Integer;
begin
  if FSimThread <> nil then begin
    FSimThread.Terminate;
    FSimThread.WaitFor;
    FreeAndNil(FSimThread);
  end;
  ClearWorldObjects;
  if Cities <> nil then begin
    for i := 0 to Cities.Count - 1 do Cities[i].Free;
    Cities.Clear;
  end;
  if Roads <> nil then begin
    for i := 0 to Roads.Count - 1 do Roads[i].Free;
    Roads.Clear;
  end;
  if FDiag <> nil then FreeAndNil(FDiag);
  FreeAndNil(FSimCS);
  Plants.Free; Huts.Free; Fishes.Free; Marks.Free; Creatures.Free; NB.Free;
  Cities.Free; Roads.Free;
  FTerrain.Free; FThumb.Free; FWorld.Free; FTintN.Free; FTintW.Free;
  FreeAndNil(FPanelBM);
  Savecfg;
  inherited;
end;

end.

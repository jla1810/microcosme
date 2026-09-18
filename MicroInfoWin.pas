unit MicroInfoWin;

{ Microcosme — fenêtre flottante : fiche du spécimen (identité, âge,
  courbe d'énergie, vie et exploits, lignée et causes de décès des
  ancêtres, mémoire spatiale, technologies). }

interface

uses
  System.SysUtils, System.Classes, System.Math, System.Types,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.ExtCtrls,
  MicroTypes, MicroBrain;

procedure OpenInfoWindow;

implementation

uses MicroChrono;

type
  TInfoForm = class(TForm)
    procedure InfoPaint(Sender: TObject);
    procedure InfoTimer(Sender: TObject);
    procedure InfoClose(Sender: TObject; var Action: TCloseAction);
  end;

var
  IW: TInfoForm = nil;
  EnH: array of Single;
  EnSel: TObject = nil;

procedure OpenInfoWindow;
var T: TTimer;
begin
  if IW <> nil then begin IW.BringToFront; Exit end;
  IW := TInfoForm.CreateNew(nil);
  with IW do begin
    Caption := 'Microcosme — fiche';
    Width := 470; Height := 650;
    Position := poScreenCenter;
    Color := Col(17, 21, 15);
    DoubleBuffered := True;
    OnPaint := InfoPaint;
    OnClose := InfoClose;
  end;
  T := TTimer.Create(IW);
  T.Interval := 200;
  T.OnTimer := IW.InfoTimer;
  IW.Show;
end;

procedure TInfoForm.InfoTimer(Sender: TObject);
begin
  Invalidate;
end;

procedure TInfoForm.InfoClose(Sender: TObject; var Action: TCloseAction);
begin
  Action := caFree;
  IW := nil;
end;

procedure TInfoForm.InfoPaint(Sender: TObject);
var
  C: TCanvas;
  W, H, Y, I, N, DI, PX, PY: Integer;
  S, KindS: string;
  Sp: TCreature;
  Clr: TColor;
  ChainId: Integer;
  Found: Boolean;

  procedure Titre(const TT: string);
  begin
    C.Font.Name := 'Segoe UI'; C.Font.Size := 8; C.Font.Style := [];
    C.Font.Color := Col(139, 138, 116);
    C.Brush.Style := bsClear;
    C.TextOut(20, Y, AnsiUpperCase(TT));
    Inc(Y, 18);
  end;

  procedure Bar(X, YY, WW: Integer; Fr: Single; Clr2: TColor);
  begin
    Fr := ClampF(Fr, 0, 1);
    C.Brush.Style := bsSolid; C.Pen.Style := psClear;
    C.Brush.Color := Col(32, 37, 28);
    C.FillRect(Rect(X, YY, X + WW, YY + 8));
    C.Brush.Color := Clr2;
    C.FillRect(Rect(X, YY, X + Trunc(WW * Fr), YY + 8));
  end;

  procedure Ligne(const LL: string; Clr2: TColor);
  begin
    C.Font.Name := 'Segoe UI'; C.Font.Size := 9; C.Font.Style := [];
    C.Brush.Style := bsClear;
    C.Font.Color := Clr2;
    C.TextOut(28, Y, LL);
    Inc(Y, 15);
  end;

begin
  C := Canvas;
  W := ClientWidth; H := ClientHeight;
  FSimCS.Enter;
  try
    if TObject(FSelected) <> EnSel then begin
      EnSel := TObject(FSelected);
      SetLength(EnH, 0);
    end;
    if (FSelected <> nil) and FSelected.Alive then begin
      if Length(EnH) >= 260 then begin
        Move(EnH[1], EnH[0], 259 * SizeOf(Single));
        SetLength(EnH, 259);
      end;
      SetLength(EnH, Length(EnH) + 1);
      EnH[High(EnH)] := FSelected.Energy;
    end;

    C.Brush.Style := bsSolid; C.Pen.Style := psClear;
    C.Brush.Color := Col(17, 21, 15);
    C.FillRect(Rect(0, 0, W, H));

    Sp := FSelected;
    if Sp = nil then begin
      Caption := 'Microcosme — fiche';
      C.Font.Name := 'Segoe UI'; C.Font.Size := 11; C.Font.Style := [];
      C.Brush.Style := bsClear;
      C.Font.Color := Col(139, 138, 116);
      C.TextOut(24, 24, 'Aucun spécimen sélectionné.');
      C.TextOut(24, 46, 'Choisis l''outil « vue », clique un habitant,');
      C.TextOut(24, 64, 'puis rouvre la fiche depuis le carnet.');
      Exit;
    end;
    Caption := 'Microcosme — fiche de ' + Sp.Name;

    Y := 18;
    C.Font.Name := 'Georgia'; C.Font.Size := 17; C.Font.Style := [fsItalic, fsBold];
    C.Font.Color := Sp.HueCol;
    C.Brush.Style := bsClear;
    C.TextOut(20, Y, Sp.Name);
    Inc(Y, 28);
    case Sp.Kind of
      0: KindS := 'herbivore';
      1: KindS := 'prédateur';
    else KindS := 'sapien';
    end;
    S := Format('%s · gén. %d · %s', [KindS, Sp.Gen, Sp.State]);
    if Sp.Kind = 2 then S := S + Format(' · mutations %.2f×', [Sp.MutRate]);
    Ligne(S, Col(139, 138, 116));
    Inc(Y, 6);

    Titre('Âge');
    Ligne(Format('%.0f jours sur une espérance de %.0f', [Sp.Age, Sp.MaxAge]),
          Col(230, 224, 205));
    Bar(20, Y, W - 40, Sp.Age / Sp.MaxAge, Col(157, 187, 107));
    Inc(Y, 20);

    Titre('Énergie (historique en direct)');
    Bar(20, Y, W - 40, Sp.Energy / Sp.MaxE, Col(228, 220, 190));
    Inc(Y, 14);
    C.Brush.Style := bsSolid; C.Pen.Style := psClear;
    C.Brush.Color := Col(11, 14, 11);
    C.FillRect(Rect(20, Y, W - 20, Y + 84));
    C.Pen.Style := psSolid; C.Pen.Width := 1;
    C.Pen.Color := Col(208, 167, 92);
    if Length(EnH) > 1 then
      for I := 0 to High(EnH) do begin
        PX := 20 + Round(I / High(EnH) * (W - 42));
        PY := Y + 82 - Round(ClampF(EnH[I] / Sp.MaxE, 0, 1) * 78);
        if I = 0 then C.MoveTo(PX, PY) else C.LineTo(PX, PY);
      end;
    C.Brush.Style := bsClear;
    C.Font.Name := 'Segoe UI'; C.Font.Size := 8; C.Font.Style := [];
    C.Font.Color := Col(100, 105, 88);
    C.TextOut(W - 76, Y + 2, IntToStr(Trunc(Max(0, Sp.Energy))));
    Inc(Y, 92);

    if Sp.Kind = 2 then begin
      Titre('Vie et exploits');
      if (Sp.Bio = nil) or (Sp.Bio.Count = 0) then
        Ligne('aucun fait marquant pour l''instant', Col(100, 105, 88))
      else
        for I := 0 to Sp.Bio.Count - 1 do
          Ligne(Sp.Bio[I], Col(230, 224, 205));
      Inc(Y, 6);

      Titre('Traits et technologies');
      Ligne(Format('vitesse %.1f · vue %.1f · taille %.2f · plume %d%% · culture %d%%',
        [Sp.Sp, Sp.Se, Sp.Sz, Round(Sp.Orn * 100), Round(Sp.Cult * 100)]),
        Col(230, 224, 205));
      S := '';
      for I := Ord(Low(TTech)) to Ord(High(TTech)) do
        if TTech(I) in Sp.Tech then S := S + TECHNAMES[I] + '  ';
      if S = '' then S := '(aucune)';
      Ligne('technos : ' + S, Col(240, 180, 95));
      Inc(Y, 4);
    end;

    Titre('Lignée — comment les ancêtres sont morts');
    ChainId := Sp.ParentId;
    Found := False;
    N := 0;
    while (ChainId > 0) and (N < 6) do begin
      DI := FindDeath(ChainId);
      if DI < 0 then begin
        Ligne('← ancêtre encore vivant (ou hors mémoire)', Col(100, 105, 88));
        ChainId := 0;
        Found := True;
      end else begin
        if DeathLog[DI].Cause = 'famine' then Clr := Col(230, 160, 80)
        else if DeathLog[DI].Cause = 'vieillesse' then Clr := Col(157, 187, 107)
        else Clr := Col(201, 106, 69);
        Ligne(Format('← %s (gén. %d) — %s, jour %d',
              [DeathLog[DI].Name, DeathLog[DI].Gen,
               DeathLog[DI].Cause, DeathLog[DI].Day]), Clr);
        ChainId := DeathLog[DI].ParentId;
        Found := True;
        Inc(N);
      end;
    end;
    if not Found then
      Ligne('lignée fondatrice (fondateur ou immigrant)', Col(100, 105, 88));
    Inc(Y, 6);

    Titre('Mémoire spatiale');
    if Length(Sp.Mem) = 0 then
      Ligne('aucun souvenir pour l''instant', Col(100, 105, 88))
    else begin
      N := 0;
      for I := High(Sp.Mem) downto 0 do begin
        if N >= 6 then Break;
        if Sp.Mem[I].K = 0 then begin
          S := Format('danger     x%.0f · y%.0f · fraîcheur %d%%',
                [Sp.Mem[I].X, Sp.Mem[I].Y,
                 Max(0, Round(100 * (1 - Sp.Mem[I].T / MEMLIFE)))]);
          Clr := Col(201, 106, 69);
        end else begin
          S := Format('nourriture x%.0f · y%.0f · fraîcheur %d%%',
                [Sp.Mem[I].X, Sp.Mem[I].Y,
                 Max(0, Round(100 * (1 - Sp.Mem[I].T / MEMLIFE)))]);
          Clr := Col(157, 187, 107);
        end;
        Ligne(S, Clr);
        Inc(N);
      end;
    end;

    C.Font.Size := 8;
    C.Font.Color := Col(100, 105, 88);
    C.TextOut(20, H - 24, 'la fiche suit le spécimen sélectionné en temps réel');
  finally
    FSimCS.Leave;
  end;
end;

end.

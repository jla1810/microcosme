                                                                                                                                                                         unit MicroMusWin;

{ Microcosme — le savoir du peuple (F10) : les technologies et les
  inventions, trouvées et à trouver. Instantané copié sous FSimCS.
  Style parchemin de MicroDicWin. }

interface

uses
  System.SysUtils, System.Classes, System.Types, System.Math,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.ExtCtrls,
  MicroTypes;

procedure OuvreMusee;

implementation

uses
  MicroLang,
  MicroIno,
  MicroBrain;

{$OVERFLOWCHECKS OFF}
{$RANGECHECKS OFF}

const
  LD_TITRE = 248;
  DC_TOP = 56;
  LH = 17;
  COL_T = 24;
  COL_I = 372;

type
  TMusTech = record
    Nom, Qui: string;
    Jour: Integer;
  end;
  TMusInno = record
    Base, Mot, Qui: string;
    Jour: Integer;
    Kind: Integer;     // ★l'identifiant de l'invention (pour le classement)
  end;

  TMusForm = class(TForm)
  public
    procedure Peint(Sender: TObject);
    procedure Tic(Sender: TObject);
    procedure Roule(Sender: TObject; Shift: TShiftState; WheelPos: Integer;
      MousePos: TPoint; var Handled: Boolean);
    procedure Touche(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure Ferme(Sender: TObject; var Action: TCloseAction);
  end;

var
  Mus: TMusForm = nil;
  TicM: TTimer = nil;
  ScrlT: Integer = 0;
  TechS: array of TMusTech;
  InnoS: array of TMusInno;

procedure Snapshot;
var
  I, N, T: Integer;
begin
  FSimCS.Enter;
  try
    N := TECH_COUNT;
    SetLength(TechS, N);
    for I := 0 to N - 1 do
    begin
      T := Ord(TECHBASE[I].Code);
      TechS[I].Nom := TECHBASE[I].Nom;
      TechS[I].Qui := TechInfo[TTech(T)].Who;
      TechS[I].Jour := TechInfo[TTech(T)].Day;
    end;
    N := Length(InnoLog);
    SetLength(InnoS, N);
    for I := 0 to N - 1 do
    begin
      InnoS[I].Base := InnoLog[I].Base;
      InnoS[I].Mot := InnoLog[I].Mot;
      InnoS[I].Qui := InnoLog[I].Who;
      InnoS[I].Jour := InnoLog[I].Day;
      InnoS[I].Kind := InnoLog[I].Kind;
    end;
  finally
    FSimCS.Leave;
  end;
end;

procedure TMusForm.Tic(Sender: TObject);
begin
  Snapshot;
  Caption := L(LD_TITRE);
  Invalidate;
end;

procedure TMusForm.Peint(Sender: TObject);
var
  cv: TCanvas;
  I, Y, K, T: Integer;
  S: string;
begin
  cv := Canvas;
  cv.Brush.Style := bsSolid;
  cv.Pen.Style := psClear;
  cv.Brush.Color := Col(226, 219, 197);
  cv.Rectangle(0, 0, ClientWidth, ClientHeight);
  cv.Pen.Style := psSolid;
  cv.Pen.Width := 2;
  cv.Pen.Color := Col(120, 96, 40);
  cv.Brush.Style := bsClear;
  cv.Rectangle(1, 1, ClientWidth - 1, ClientHeight - 1);

  cv.Font.Name := 'Georgia';
  cv.Font.Size := 13;
  cv.Font.Style := [fsBold];
  cv.Font.Color := Col(52, 46, 36);
  cv.TextOut(22, 12, L(LD_TITRE));

  cv.Font.Size := 9;
  cv.Font.Style := [];
  cv.Font.Color := Col(120, 96, 40);
  cv.TextOut(COL_T, DC_TOP - 20, 'TECHNIQUES');
  cv.TextOut(COL_I, DC_TOP - 20, 'INVENTIONS');

  cv.Font.Name := 'Segoe UI';
  cv.Font.Size := 9;

  Y := DC_TOP;
  for I := ScrlT to High(TechS) do
  begin
    if Y > ClientHeight - 24 then
      Break;
    if TechS[I].Qui <> '' then
    begin
      cv.Font.Color := Col(80, 110, 60);
      cv.Font.Style := [fsBold];
      cv.TextOut(COL_T, Y, TechS[I].Nom);
      cv.Font.Style := [];
      cv.Font.Color := Col(120, 96, 40);
      S := TechS[I].Qui + ' · ' + IntToStr(TechS[I].Jour);
      cv.TextOut(COL_T + 200, Y, S);
    end
    else
    begin
      cv.Font.Color := Col(180, 174, 158);
      cv.TextOut(COL_T, Y, TechS[I].Nom + ' — à découvrir');
    end;
    Inc(Y, LH);
  end;

   Y := DC_TOP;
  for I := 0 to NINNO - 1 do
  begin
    if Y > ClientHeight - 24 then
      Break;
    // l'invention est-elle trouvée ? (dans l'instantané)
    K := -1;
    for T := 0 to High(InnoS) do
      if InnoS[T].Kind = I then begin K := T; Break end;
    if K >= 0 then
    begin
      cv.Font.Color := Col(157, 106, 60);
      cv.Font.Style := [fsBold];
      cv.TextOut(COL_I, Y, InnoS[K].Base);
      cv.Font.Style := [];
      cv.Font.Color := Col(52, 46, 36);
      if InnoS[K].Mot <> '' then
        cv.TextOut(COL_I + 140, Y, '«' + InnoS[K].Mot + '»');
      cv.Font.Color := Col(120, 96, 40);
      S := InnoS[K].Qui + ' · ' + IntToStr(InnoS[K].Jour);
      cv.TextOut(COL_I + 280, Y, S);
    end
    else
    begin
      cv.Font.Color := Col(180, 174, 158);
      cv.TextOut(COL_I, Y, INNOBASE[I] + ' — à inventer');
    end;
    Inc(Y, LH);
  end;

  if NINNO = 0 then
  begin
    cv.Font.Color := Col(180, 174, 158);
    cv.Font.Style := [fsItalic];
    cv.TextOut(COL_I, DC_TOP, 'aucune invention encore');
    cv.Font.Style := [];
  end;

  if Length(InnoS) = 0 then
  begin
    cv.Font.Color := Col(180, 174, 158);
    cv.Font.Style := [fsItalic];
    cv.TextOut(COL_I, DC_TOP, 'aucune invention encore');
    cv.Font.Style := [];
  end;

  cv.Font.Name := 'Segoe UI';
  cv.Font.Size := 13;
  cv.Font.Style := [fsBold];
  cv.Font.Color := Col(120, 40, 30);
  cv.TextOut(ClientWidth - 28, 8, '×');
end;

procedure TMusForm.Roule(Sender: TObject; Shift: TShiftState;
  WheelPos: Integer; MousePos: TPoint; var Handled: Boolean);
begin
  if WheelPos > 0 then
    Dec(ScrlT, 3)
  else
    Inc(ScrlT, 3);
  if ScrlT < 0 then
    ScrlT := 0;
  Handled := True;
  Invalidate;
end;

procedure TMusForm.Touche(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = 27 then
    Close;
  if Key = 38 then
    Dec(ScrlT, 3);
  if Key = 40 then
    Inc(ScrlT, 3);
end;

procedure TMusForm.Ferme(Sender: TObject; var Action: TCloseAction);
begin
  Action := caFree;
  Mus := nil;
  TicM := nil;
end;

procedure OuvreMusee;
begin
  if Mus = nil then
  begin
    Mus := TMusForm.CreateNew(Application);
    Mus.BorderStyle := bsSingle;
    Mus.BorderIcons := [biSystemMenu];
    Mus.ClientWidth := 740;
    Mus.ClientHeight := 700;
    Mus.Position := poDesigned;
    Mus.DefaultMonitor := dmMainForm;
    Mus.KeyPreview := True;
    Mus.OnPaint := Mus.Peint;
    Mus.OnMouseWheel := Mus.Roule;
    Mus.OnKeyDown := Mus.Touche;
    Mus.OnClose := Mus.Ferme;
    TicM := TTimer.Create(Mus);
    TicM.Interval := 400;
    TicM.OnTimer := Mus.Tic;
    TicM.Enabled := True;
  end;
  Mus.Caption := L(LD_TITRE);
  Mus.Show;
  Mus.Left := Application.MainForm.Left + 80;
  Mus.Top := Application.MainForm.Top + 40;
  Mus.Invalidate;
end;

end.

unit MicroDicWin;

{ Microcosme — le dictionnaire du peuple (F9).
  100 % code, aucune ressource. Fenêtre non modale : le monde vit dessous.
  Chaque 400 ms, un INSTANTANÉ du lexique est copié sous FSimCS — la
  peinture ne lit jamais le thread sim directement (conv. 12).
  Molette / flèches : le dictionnaire défile. Style : MicroCityWin. }

interface

uses
  System.SysUtils, System.Classes, System.Types, System.Math,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.ExtCtrls,
  MicroTypes;

procedure OuvreDictionnaire;

implementation

uses
  MicroLang,     // L()
  MicroBrain;    // Col

{$OVERFLOWCHECKS OFF}
{$RANGECHECKS OFF}

{ Les numéros L() regroupés ici, comme LC_* dans MicroCityWin. }
const
  LD_TITRE  = 233;
  LD_COMPTE = 234;
  LD_PIED   = 235;
  LD_VIDE   = 236;

  DC_W   = 440;    // largeur client
  DC_H   = 430;    // hauteur client
  DC_TOP = 100;    // y de la première ligne de mots
  DC_LH  = 20;     // hauteur d'une ligne

type
  TDictForm = class(TForm)
  public
    procedure Peint(Sender: TObject);
    procedure Tic(Sender: TObject);
    procedure Roule(Sender: TObject; Shift: TShiftState; WheelPos: Integer;
                    MousePos: TPoint; var Handled: Boolean);
    procedure Touche(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure Ferme(Sender: TObject; var Action: TCloseAction);
  end;

var
  Dic: TDictForm = nil;
  TicD: TTimer = nil;
  ScrlD: Integer = 0;                // décalage de défilement (en lignes)
  Copie: array of TMot;              // l'instantané (copié sous FSimCS)

{ TDictForm }

procedure TDictForm.Tic(Sender: TObject);
var I: Integer;
begin
  FSimCS.Enter;
  try
    SetLength(Copie, Length(LexiqueDuPeuple));
    for I := 0 to High(LexiqueDuPeuple) do
      Copie[I] := LexiqueDuPeuple[I];
  finally
    FSimCS.Leave;
  end;
  Caption := L(LD_TITRE);
  Invalidate;
end;

procedure TDictForm.Peint(Sender: TObject);
var cv: TCanvas;
   I, Y, N, ScrlMax: Integer;
   S : String;
begin
  cv := Canvas;
  N := Length(Copie);

  // le parchemin (plein) — couleurs de la fiche de ville
  cv.Brush.Style := bsSolid; cv.Pen.Style := psClear;
  cv.Brush.Color := Col(226, 219, 197);
  cv.Rectangle(0, 0, ClientWidth, ClientHeight);
  cv.Pen.Style := psSolid; cv.Pen.Width := 2; cv.Pen.Color := Col(120, 96, 40);
  cv.Brush.Style := bsClear;
  cv.Rectangle(1, 1, ClientWidth - 1, ClientHeight - 1);

  // le compteur
  cv.Font.Name := 'Georgia';
  cv.Font.Size := 13; cv.Font.Style := [fsBold];
  cv.Font.Color := Col(52, 46, 36);
  cv.TextOut(22, 14, Format(L(LD_COMPTE), [N]));

  // l'en-tête des colonnes
  cv.Font.Name := 'Segoe UI';
  cv.Font.Size := 9; cv.Font.Style := [];
  cv.Font.Color := Col(120, 96, 40);
  Y := DC_TOP - 22;
  cv.TextOut(22, Y, 'MOT');
  cv.TextOut(150, Y, 'SENS');
  cv.TextOut(300, Y, 'QUI');
  S := 'JOUR'; cv.TextOut(ClientWidth - 24 - cv.TextWidth('JOUR'), Y, 'JOUR');

  // les mots (bornés au bas de page)
  cv.Font.Size := 10;
  ScrlMax := Max(0, (N * DC_LH - (ClientHeight - DC_TOP - 36) + DC_LH - 1) div DC_LH);
  if ScrlD > ScrlMax then ScrlD := ScrlMax;
  if ScrlD < 0 then ScrlD := 0;
  Y := DC_TOP;
  for I := ScrlD to N - 1 do begin
    if Y > ClientHeight - 34 then Break;
    cv.Font.Color := Col(80, 110, 60);                     // le mot, vert langue
    cv.Font.Style := [fsBold];
    cv.TextOut(22, Y, Copie[I].Mot);
    cv.Font.Style := [];
    cv.Font.Color := Col(52, 46, 36);                      // le sens
    cv.TextOut(150, Y, Copie[I].Sens);
    cv.Font.Color := Col(120, 96, 40);                     // l'inventeur
    cv.TextOut(300, Y, Copie[I].Qui);
    cv.Font.Color := Col(150, 130, 90);                    // le jour
    S := IntToStr(Copie[I].Jour);
    cv.TextOut(ClientWidth - 24 - cv.TextWidth(S), Y, S);
    Inc(Y, DC_LH);
  end;

  // vide, ou le pied
  if N = 0 then begin
    cv.Font.Size := 11; cv.Font.Style := [fsItalic];
    cv.Font.Color := Col(120, 96, 40);
    cv.TextOut(22, DC_TOP, L(LD_VIDE));
  end else begin
    cv.Font.Size := 8; cv.Font.Style := [fsItalic];
    cv.Font.Color := Col(150, 130, 90);
    cv.TextOut(22, ClientHeight - 22, L(LD_PIED));
  end;

  // la croix de fermeture
  cv.Font.Name := 'Segoe UI';
  cv.Font.Size := 13; cv.Font.Style := [fsBold];
  cv.Font.Color := Col(120, 40, 30);
  cv.TextOut(ClientWidth - 28, 8, '×');
end;

procedure TDictForm.Roule(Sender: TObject; Shift: TShiftState;
  WheelPos: Integer; MousePos: TPoint; var Handled: Boolean);
begin
  if WheelPos > 0 then Dec(ScrlD, 3) else Inc(ScrlD, 3);
  Handled := True;
  Invalidate;
end;

procedure TDictForm.Touche(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = 27 then Close;                    // Échap
  if Key = 38 then Dec(ScrlD, 3);            // flèche haut
  if Key = 40 then Inc(ScrlD, 3);            // flèche bas
end;

procedure TDictForm.Ferme(Sender: TObject; var Action: TCloseAction);
begin
  Action := caFree;
  Dic := nil;
  TicD := nil;
end;

procedure OuvreDictionnaire;
begin
  if Dic = nil then
  begin
    Dic := TDictForm.CreateNew(Application);
    Dic.DefaultMonitor := dmMainForm;
    Dic.BorderStyle := bsSingle;
    Dic.BorderIcons := [biSystemMenu];
    Dic.ClientWidth := DC_W;
    Dic.ClientHeight := DC_H;
    Dic.Position := poDesigned;
    if Application.MainForm <> nil then
    begin
      Dic.Left := Application.MainForm.Left + 96;
      Dic.Top := Application.MainForm.Top + 96;
    end;
    Dic.KeyPreview := True;
    Dic.OnPaint := Dic.Peint;
    Dic.OnMouseWheel := Dic.Roule;
    Dic.OnKeyDown := Dic.Touche;
    Dic.OnClose := Dic.Ferme;
    TicD := TTimer.Create(Dic);
    TicD.Interval := 400;
    TicD.OnTimer := Dic.Tic;
    TicD.Enabled := True;
  end;
  Dic.Caption := L(LD_TITRE);
  Dic.Show;
  Dic.Invalidate;
end;

end.

unit MicrocityWin;

{ Microcosme — la fiche d'une ville (clic sur une ville).
  100 % code, aucune ressource. Fenêtre non modale : le monde vit dessous
  et la fiche se rafraîchit toute seule. Si la ville vient à disparaître
  de Cities, la fiche se ferme seule (défensif). }

interface

uses
  System.SysUtils, System.Classes, System.Types, System.Math,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.ExtCtrls,
  MicroTypes;

procedure OuvreFicheVille(V: TCity);                 // ouvre (ou met à jour)
function  VilleSousLeMonde(WX, WY: Double): TCity;   // ville au point MONDE, nil sinon

implementation

uses
  MicroLang,    // L()
  MicroBrain;   // Col, DayCount

{$OVERFLOWCHECKS OFF}
{$RANGECHECKS OFF}

{ Les numéros L() sont regroupés ICI : si un jour tu dois décaler
  (chaînes déjà posées en 164-167), tu changes 11 nombres, rien d'autre. }
const
  LC_BOURG  = 164;
  LC_VILLE  = 165;
  LC_CITE   = 166;
  LC_TITRE  = 167;
  LC_RANG   = 168;
  LC_FONTE  = 169;
  LC_FOYERS = 170;
  LC_HAB    = 171;
  LC_ROUTES = 172;
  LC_CHEF   = 173;
  LC_AUCUN  = 174;

  FC_W = 320;   // largeur client
  FC_H = 250;   // hauteur client

type
  TFicheVille = class(TForm)
  public
    V: TCity;                                   // la ville montrée (validée au tic)
    procedure Peint(Sender: TObject);
    procedure Tic(Sender: TObject);
    procedure Clic(Sender: TObject; Button: TMouseButton;
                   Shift: TShiftState; X, Y: Integer);
    procedure Touche(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure Ferme(Sender: TObject; var Action: TCloseAction);
  end;

var
  Fiche: TFicheVille = nil;
  TicF: TTimer = nil;

function VilleSousLeMonde(WX, WY: Double): TCity;
var I: Integer;
begin
  Result := nil;
  for I := 0 to Cities.Count - 1 do
    if Sqr(WX - Cities[I].X) + Sqr(WY - Cities[I].Y) <= Sqr(Cities[I].Rayon) then
      Exit(Cities[I]);
end;

{ TFicheVille }

procedure TFicheVille.Peint(Sender: TObject);
var cv: TCanvas;
   I, NbFoy, NbHab, NbRout, Y: Integer;
   C: TCreature;
   S: string;
begin
  if V = nil then Exit;
  cv := Canvas;
  try
    NbFoy := 0;
    for I := 0 to Huts.Count - 1 do
      if Huts[I].Ville = V then Inc(NbFoy);

    // ★ les habitants appartiennent à la ville PAR LEUR FOYER, pas par
    // leur position : un Sapien aux champs reste citadin, un promeneur
    // de passage ne le devient pas (cohérent avec l'ExodeRural).
    NbHab := 0;
    for I := 0 to Creatures.Count - 1 do
    begin
      C := Creatures[I];
      if C.Alive and (C.Kind = 2) and (C.HomeH <> nil) and
         (C.HomeH.Ville = V) then Inc(NbHab);
    end;
    for I := 0 to Roads.Count - 1 do
      if (Roads[I].A = V) or (Roads[I].B = V) then Inc(NbRout);

    // le parchemin (plein)
    cv.Brush.Style := bsSolid; cv.Pen.Style := psClear;
    cv.Brush.Color := Col(226, 219, 197);
    cv.Rectangle(0, 0, ClientWidth, ClientHeight);
    cv.Pen.Style := psSolid; cv.Pen.Width := 2; cv.Pen.Color := Col(120, 96, 40);
    cv.Brush.Style := bsClear;
    cv.Rectangle(1, 1, ClientWidth - 1, ClientHeight - 1);

    // la mini-couronne
    cv.Brush.Style := bsSolid; cv.Pen.Style := psSolid;
    cv.Pen.Width := 1; cv.Pen.Color := Col(120, 96, 40);
    cv.Brush.Color := Col(208, 167, 92);
    cv.Polygon([Point(20, 34), Point(20, 16), Point(27, 24), Point(34, 12),
                Point(41, 24), Point(48, 16), Point(48, 34)]);
    cv.Brush.Color := Col(186, 78, 60);
    cv.Ellipse(31, 24, 37, 30);

    // ★ APRÈS la couronne : plus aucune forme pleine, et le texte
    // doit avoir un fond TRANSPARENT (TextOut peint le Brush courant
    // derrière chaque lettre — s'il reste bsSolid, pavés de couleur)
    cv.Brush.Style := bsClear;

    // le titre
    cv.Font.Name := 'Georgia';
    cv.Font.Size := 14; cv.Font.Style := [fsBold];
    cv.Font.Color := Col(52, 46, 36);
    cv.TextOut(58, 14, V.Nom);

    // les caractéristiques
    Y := 64;
    cv.Font.Size := 11; cv.Font.Style := [];
    if V.Niveau >= 4 then S := L(LC_CITE)
    else if V.Niveau >= 3 then S := L(LC_VILLE)
    else S := L(LC_BOURG);
    cv.TextOut(22, Y, Format(L(LC_RANG), [S]));                          Inc(Y, 27);
    cv.TextOut(22, Y, Format(L(LC_FONTE), [Max(0, DayCount - V.Jour)])); Inc(Y, 27);
    cv.TextOut(22, Y, Format(L(LC_FOYERS), [NbFoy]));                    Inc(Y, 27);
    cv.TextOut(22, Y, Format(L(LC_HAB), [NbHab]));                       Inc(Y, 27);
    cv.TextOut(22, Y, Format(L(LC_ROUTES), [NbRout]));                   Inc(Y, 27);
    if V.ChefCId <> 0 then S := Format(L(LC_CHEF), [V.ChefNom])
    else S := Format(L(LC_CHEF), [L(LC_AUCUN)]);
    cv.Font.Color := Col(150, 110, 30);
    cv.TextOut(22, Y, S);

    // la croix de fermeture
    cv.Font.Color := Col(120, 40, 30);
    cv.Font.Size := 13; cv.Font.Style := [fsBold];
    cv.TextOut(ClientWidth - 28, 8, '×');
  except
    // le monde a bougé sous nos pieds : on redessinera au prochain tic
  end;
end;
procedure TFicheVille.Tic(Sender: TObject);
begin
  if (V = nil) or (Cities.IndexOf(V) < 0) then
  begin
    Close;                                    // la ville n'est plus : fiche fermée
    Exit;
  end;
  Caption := Format(L(LC_TITRE), [V.Nom]);
  Invalidate;
end;

procedure TFicheVille.Clic(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if PtInRect(Rect(ClientWidth - 36, 4, ClientWidth - 6, 32), Point(X, Y)) then
    Close;
end;

procedure TFicheVille.Touche(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = 27 then Close;                     // Échap
end;

procedure TFicheVille.Ferme(Sender: TObject; var Action: TCloseAction);
begin
  Action := caFree;
  Fiche := nil;
  TicF := nil;                                 // le Tic appartient à la fiche : il meurt avec
end;

procedure OuvreFicheVille(V: TCity);
begin
  if V = nil then Exit;
  if Fiche = nil then
  begin
    Fiche := TFicheVille.CreateNew(Application);
    Fiche.BorderStyle := bsSingle;
    Fiche.BorderIcons := [biSystemMenu];
    Fiche.ClientWidth := FC_W;
    Fiche.ClientHeight := FC_H;
    Fiche.Position := poDesigned;
    if Application.MainForm <> nil then
    begin
      Fiche.Left := Application.MainForm.Left + 64;
      Fiche.Top := Application.MainForm.Top + 64;
    end;
    Fiche.KeyPreview := True;
    Fiche.OnPaint := Fiche.Peint;
    Fiche.OnMouseDown := Fiche.Clic;
    Fiche.OnKeyDown := Fiche.Touche;
    Fiche.OnClose := Fiche.Ferme;
    TicF := TTimer.Create(Fiche);
    TicF.Interval := 400;
    TicF.OnTimer := Fiche.Tic;
    TicF.Enabled := True;
  end;
  Fiche.V := V;
  Fiche.Caption := Format(L(LC_TITRE), [V.Nom]);
  Fiche.Show;
  Fiche.Invalidate;
end;

end.

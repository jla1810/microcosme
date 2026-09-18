unit MicroEre;

{ Microcosme — moteur d'ères v3 (chantier 1b : généralisé à 8 ères).
  - ERE_NOM / seuils pop / seuils inventions / pool d'inventions : tableaux 1..8 ;
  - CanPassEre GÉNÉRIQUE (boucle) + verrou MaxEraContent : impossible de
    dépasser la plus haute ère présente dans TECHBASE → ajouter une ère
    future = ajouter ses AddTech, ZÉRO code ici ;
  - EreMaxS : ×1,5 jusqu'à l'ère 5, ×1,35 ensuite, plafond POP_CAP 450 ;
  - effet bibliothèque inchangé (BiblioFail/BiblioMult, reset par ère). }

interface

uses
  System.SysUtils, System.Math, System.Generics.Collections, MicroTypes;

const
  ERE_MAX = 8;

  ERE_NOM: array[1..ERE_MAX] of string =
    ('Néolithique', 'Âge du bronze', 'Âge du fer', 'Antiquité',
     'Moyen Âge', 'Renaissance', 'Révolution industrielle', 'Ère moderne');

  // seuils pour QUITTER l'ère N (transitions 1→2 ... 7→8)
  ERE_POP: array[1..ERE_MAX-1] of Integer = (10, 16, 22, 30, 40, 52, 66);
  ERE_INV: array[1..ERE_MAX-1] of Integer = (6, 9, 12, 15, 18, 21, 24);

  // taille CUMULÉE du pool d'inventions par ère (bits 0..30 = 31 max, InnoK OK)
  INNO_ERE: array[1..ERE_MAX] of Integer = (10, 13, 16, 19, 22, 25, 28, 31);

  POP_CAP     = 450;    // plafond sapiens absolu (rendu/performances)
  BIBLIO_STEP = 0.10;
  BIBLIO_MAX  = 30;     // ×4 max — à remonter (ex. 50 = ×6) si les ères 4+ vont trop lentement

function EreCourante: Integer;
function EreLabel: string;
function MaxEraContent: Integer;                  // plus haute ère pourvue en techs
function EreMaxS: Integer;
function InnoTotal: Integer;
function CountTechEre(Era: Integer): Integer;
function CountInno: Integer;
function PeopleHas(Code: TEcode): Boolean;
procedure BiblioFail(Day: Integer);
function BiblioMult: Single;
function CanPassEre: Boolean;
function PassEre: Boolean;                        // True = passage effectué
procedure ResetEre;

var
  FEra: Integer = 1;
  FBiblio: Integer = 0;
  FBiblioDay: Integer = -1;

implementation

function EreCourante: Integer;
begin
  Result := FEra;
end;

function EreLabel: string;
begin
  if (FEra >= 1) and (FEra <= ERE_MAX) then
    Result := Format('Ère %d · %s', [FEra, ERE_NOM[FEra]])
  else
    Result := 'Ère ' + IntToStr(FEra);
end;

{ La plus haute ère ayant au moins une tech dans TECHBASE.
  Le passage d'ère est verrouillé au-delà → contenu = clé. }
function MaxEraContent: Integer;
var
  I: Integer;
begin
  Result := 1;
  for I := 0 to TECH_COUNT - 1 do
    if TECHBASE[I].Era > Result then
      Result := TECHBASE[I].Era;
end;

function EreMaxS: Integer;
var
  E: Integer;
  M: Single;
begin
  M := MAXS;
  for E := 2 to Max(FEra, 1) do
    if E <= 5 then M := M * 1.5 else M := M * 1.35;
  Result := Min(Round(M), POP_CAP);
end;

function InnoTotal: Integer;
begin
  if (FEra >= 1) and (FEra <= ERE_MAX) then
    Result := INNO_ERE[FEra]
  else
    Result := 31;
end;

function CountTechEre(Era: Integer): Integer;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to TECH_COUNT - 1 do
    if (TECHBASE[i].Era = Era)
       and (TechInfo[TECHBASE[i].Code].Day > 0)
       and (not TechLost[TECHBASE[i].Code]) then
      Inc(Result);
end;

function CountInno: Integer;
var
  M, k: Integer;
  C: TCreature;
begin
  M := 0;
  if Creatures <> nil then
    for C in Creatures do
      if C.Alive and (C.Kind = 2) then
        M := M or C.InnoK;
  Result := 0;
  for k := 0 to InnoTotal - 1 do
    if (M and (1 shl k)) <> 0 then
      Inc(Result);
end;

function PeopleHas(Code: TEcode): Boolean;
begin
  Result := (TechInfo[Code].Who <> '') and (not TechLost[Code]);
end;

procedure BiblioFail(Day: Integer);
begin
  if Day <> FBiblioDay then begin
    FBiblioDay := Day;
    Inc(FBiblio);
  end;
end;

function BiblioMult: Single;
begin
  Result := 1 + BIBLIO_STEP * Min(FBiblio, BIBLIO_MAX);
end;

{ Générique : toutes les techs de l'ère courante + pop + inventions.
  Verrou de contenu : au-delà de MaxEraContent, jamais vrai. }
function CanPassEre: Boolean;
var
  Era, Need, I: Integer;
begin
  Result := False;
  Era := FEra;
  if (Era < 1) or (Era >= ERE_MAX) then Exit;   // ère 8 = sommet
  if Era >= MaxEraContent then Exit;            // l'ère suivante n'existe pas encore
  Need := 0;
  for I := 0 to TECH_COUNT - 1 do
    if TECHBASE[I].Era = Era then Inc(Need);
  if CountTechEre(Era) < Need then Exit;
  if CountS < ERE_POP[Era] then Exit;
  if CountInno < ERE_INV[Era] then Exit;
  Result := True;
end;

function PassEre: Boolean;
begin
  Result := False;
  if (FEra < 1) or (FEra >= ERE_MAX) then Exit;
  if not CanPassEre then Exit;
  Inc(FEra);
  FBiblio := 0;
  FBiblioDay := -1;
  Result := True;
end;

procedure ResetEre;
begin
  FEra := 1;
  FBiblio := 0;
  FBiblioDay := -1;
end;

end.

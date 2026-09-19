unit MicroEre;

{ Microcosme — moteur d'ères v3 : 8 ères, seuils en tableaux,
  verrou de contenu (MaxEraContent), effet bibliothèque, EreMaxS.
  v14 ★i18n : ERE_NOM_FR / ERE_NOM_EN — EreLabel suit FLangue (MicroLang). }

interface

uses
  System.SysUtils, System.Math, System.Generics.Collections, MicroTypes,
  MicroLang;

const
  ERE_MAX = 8;

  ERE_NOM_FR: array[1..ERE_MAX] of string =
    ('Néolithique', 'Âge du bronze', 'Âge du fer', 'Antiquité',
     'Moyen Âge', 'Renaissance', 'Révolution industrielle', 'Ère moderne');

  ERE_NOM_EN: array[1..ERE_MAX] of string =
    ('Neolithic', 'Bronze Age', 'Iron Age', 'Antiquity',
     'Middle Ages', 'Renaissance', 'Industrial Revolution', 'Modern Era');

  ERE_POP: array[1..ERE_MAX-1] of Integer = (10, 16, 22, 30, 40, 52, 66);
  ERE_INV: array[1..ERE_MAX-1] of Integer = (6, 9, 12, 15, 18, 21, 24);

  INNO_ERE: array[1..ERE_MAX] of Integer = (10, 13, 16, 19, 22, 25, 28, 31);

  POP_CAP     = 450;
  BIBLIO_STEP = 0.10;
  BIBLIO_MAX  = 30;

// ERE_NOM : compatibilité — renvoie le nom dans la langue courante
function ERE_NOM(Era: Integer): string;

function EreCourante: Integer;
function EreLabel: string;
function MaxEraContent: Integer;
function EreMaxS: Integer;
function InnoTotal: Integer;
function CountTechEre(Era: Integer): Integer;
function CountInno: Integer;
function PeopleHas(Code: TEcode): Boolean;
procedure BiblioFail(Day: Integer);
function BiblioMult: Single;
function CanPassEre: Boolean;
function PassEre: Boolean;
procedure ResetEre;

var
  FEra: Integer = 1;
  FBiblio: Integer = 0;
  FBiblioDay: Integer = -1;

implementation

function ERE_NOM(Era: Integer): string;
begin
  if (Era < 1) or (Era > ERE_MAX) then Exit('?');
  if FLangue = LANG_EN then Result := ERE_NOM_EN[Era]
  else Result := ERE_NOM_FR[Era];
end;

function EreCourante: Integer;
begin
  Result := FEra;
end;

function EreLabel: string;
begin
  if (FEra >= 1) and (FEra <= ERE_MAX) then
    if FLangue = LANG_EN then
      Result := Format('Era %d · %s', [FEra, ERE_NOM_EN[FEra]])
    else
      Result := Format('Ère %d · %s', [FEra, ERE_NOM_FR[FEra]])
  else
    Result := 'Era ' + IntToStr(FEra);
end;

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

function CanPassEre: Boolean;
var
  Era, Need, I: Integer;
begin
  Result := False;
  Era := FEra;
  if (Era < 1) or (Era >= ERE_MAX) then Exit;
  if Era >= MaxEraContent then Exit;
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

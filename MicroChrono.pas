unit MicroChrono;

{ Microcosme — annales du peuple : la simulation écrit sa propre
  chronique (découvertes, inventions, naissances, morts, foule). }

interface

uses
  System.SysUtils,
  MicroTypes, MicroBrain;

const
  CK_TECH = 0;    { technologies majeures }
  CK_INNO = 1;    { inventions mineures }
  CK_LIFE = 2;    { naissances et morts }
  CK_PEOPLE = 3;  { le peuple : foule, immigrants, apprivoisements }

  CHRONMILE: array[0..8] of Integer = (8, 12, 16, 20, 26, 32, 40, 50, 60);

type
  TChronRec = record
    Day: Integer;
    Kind: Integer;
    Text: string;
  end;

var
  Chronicle: array of TChronRec;
  FChronShow: Boolean = True;
  MileIdx: Integer = 0;
  FirstBornLogged: Boolean = False;
  GenMark: Integer = 0;
  MaxSap: Integer = 0;


 type
  TDeathRec = record
    CId: Integer;
    Name: string;
    Cause: string;
    Day: Integer;
    Gen: Integer;
    ParentId: Integer;
  end;

var
  DeathLog: array of TDeathRec;

function FindDeath(AId: Integer): Integer;

procedure ChronAdd(Kind: Integer; const Text: string);
procedure ResetChron;

implementation

function FindDeath(AId: Integer): Integer;
var I: Integer;
begin
  Result := -1;
  for I := High(DeathLog) downto 0 do
    if DeathLog[I].CId = AId then begin Result := I; Exit end;
end;

procedure ResetChron;
begin
  SetLength(Chronicle, 0);
  MileIdx := 0;
  FirstBornLogged := False;
  GenMark := 0;
  MaxSap := 0;
end;

procedure ChronAdd(Kind: Integer; const Text: string);
var N: Integer;
begin
  N := Length(Chronicle);
  if N >= 500 then begin
    Move(Chronicle[100], Chronicle[0], (N - 100) * SizeOf(TChronRec));
    SetLength(Chronicle, N - 100);
    N := Length(Chronicle);
  end;
  SetLength(Chronicle, N + 1);
  Chronicle[N].Day := DayCount;
  Chronicle[N].Kind := Kind;
  Chronicle[N].Text := Text;
end;




end.

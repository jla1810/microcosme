unit MicroBrainWin;

{ Microcosme — fenêtre flottante : grand cerveau du spécimen sélectionné. }

interface

uses
  System.SysUtils, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.ExtCtrls,
  MicroTypes, MicroBrain, MicroRender;

procedure OpenBrainWindow;

implementation

type
  TBrainForm = class(TForm)
    procedure BrainPaint(Sender: TObject);
    procedure BrainTimer(Sender: TObject);
    procedure BrainClose(Sender: TObject; var Action: TCloseAction);
  end;

var
  BW: TBrainForm = nil;

procedure OpenBrainWindow;
var T: TTimer;
begin
  if BW <> nil then begin
    BW.BringToFront;
    Exit;
  end;
  BW := TBrainForm.CreateNew(nil);
  with BW do begin
    Caption := 'Microcosme — cerveau';
    Width := 720; Height := 560;
    Position := poScreenCenter;
    Color := Col(17, 21, 15);
    DoubleBuffered := True;
    OnPaint := BrainPaint;
    OnClose := BrainClose;
  end;
  T := TTimer.Create(BW);
  T.Interval := 150;
  T.OnTimer := BW.BrainTimer;
  BW.Show;
end;

procedure TBrainForm.BrainTimer(Sender: TObject);
begin
  Invalidate;
end;

procedure TBrainForm.BrainClose(Sender: TObject; var Action: TCloseAction);
begin
  Action := caFree;
  BW := nil;
end;

procedure TBrainForm.BrainPaint(Sender: TObject);
begin
  FSimCS.Enter;
  try
    if FSelected <> nil then
      Caption := 'Microcosme — cerveau de ' + FSelected.Name
    else
      Caption := 'Microcosme — cerveau';
    DrawBrainBig(Canvas, ClientWidth, ClientHeight);
  finally
    FSimCS.Leave;
  end;
end;

end.

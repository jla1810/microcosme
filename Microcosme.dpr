program Microcosme;

uses
  Vcl.Forms,
  MicroTypes in 'MicroTypes.pas',
  MicroBrain in 'MicroBrain.pas',
  MicroRender in 'MicroRender.pas',
  MicroIO in 'MicroIO.pas',
  MicroMain in 'MicroMain.pas',
  MicroConfig in 'MicroConfig.pas',
  MicroEvo in 'MicroEvo.pas',
  MicroBrainWin in 'MicroBrainWin.pas',
  MicroGraph3D in 'MicroGraph3D.pas',
  MicroIno in 'MicroIno.pas',
  MicroChrono in 'MicroChrono.pas',
  MicroAudio in 'MicroAudio.pas',
  MicroRenderPro in 'MicroRenderPro.pas',
  MicroHelp in 'MicroHelp.pas',
  Micrologo in 'Micrologo.pas',
  MicroEre in 'MicroEre.pas',
  MicroLang in 'MicroLang.pas',
  MicroSim in 'MicroSim.pas',
  MicroVilles in 'MicroVilles.pas',
  MicrocityWin in 'MicrocityWin.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'Microcosme v ';
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.

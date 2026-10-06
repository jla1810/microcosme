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
  MicrocityWin in 'MicrocityWin.pas',
  MicroInfoWin in 'MicroInfoWin.pas',
  MicroDicWin in 'MicroDicWin.pas';

{$R *.res}

const

  DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2 = -4;   // valeur officielle Win32

begin
  Application.Initialize;
  // ★multi-écrans : suivre le DPI par écran (plus de fenêtres étirées)
 // SetProcessDpiAwarenessContext(Pointer(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2));
  Application.MainFormOnTaskbar := True;
  Application.Title := 'Microcosme v 0.18beta';
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.

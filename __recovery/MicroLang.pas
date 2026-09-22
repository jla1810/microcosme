unit MicroLang;

{ Microcosme — bilinguisme FR/EN. L(id) selon FLangue (0=FR, 1=EN).
  Tableaux PARALLÈLES, ordre GELÉ : ajouter = ajouter EN FIN des deux.
  Langue du monde (cris, noms, objets) non traduite. }

interface

uses
  System.SysUtils;

const
  LANG_FR = 0;
  LANG_EN = 1;

function L(id: Integer): string;
function LangNom: string;

var
  FLangue: Integer = LANG_FR;

implementation

const
  FR: array[0..159] of string = (
    'Observer le monde',            // 0
    'l''île s''éveille…',           // 1
    'nouveau monde',                // 2
    'monde sauvegardé',             // 3
    'monde chargé',                 // 4
    'CARNET D''OBSERVATION · DELPHI', // 5
    'Populations',                  // 6
    'Technologies',                 // 7
    'Dynamique',                    // 8
    'Évolution',                    // 9
    'Lexique émergent',             // 10
    'Inventions du peuple',         // 11
    'Spécimen',                     // 12
    'Commandes',                    // 13
    'Réglages',                     // 14
    'Annales du peuple',            // 15
    'l''histoire n''a pas encore d''objets…',        // 16
    'l''histoire du peuple n''a pas encore commencé…', // 17
    'entrée :',                     // 18
    'fiche',                        // 19
    'flore',                        // 20
    'herbivores',                   // 21
    'prédateurs',                   // 22
    'sapiens',                      // 23
    'poissons',                     // 24
    'spirale de Fisher — plume %d%%',                // 25
    'spirale de Fisher — plume —',                   // 26
    'culture — savoir moyen %d%%',                   // 27
    'culture — savoir moyen —',                      // 28
    'marins — %d navigateurs · %d en mer',           // 29
    'inconnue',                     // 30
    'PERDUE',                       // 31
    'technologies %d/%d · peuple %d · inventions %d/%d', // 32
    ' entré dans l''ère suivante',  // 33
    'entrer dans l''ère suivante',  // 34
    'vue',                          // 35
    'sem',                          // 36
    'her',                          // 37
    'pré',                          // 38
    'sap',                          // 39
    'Sauver',                       // 40
    'Charger',                      // 41
    'Nouveau monde',                // 42
    'aide (F1)',                    // 43
    'réglages',                     // 44
    'annales',                      // 45
    'relief',                       // 46
    'tout par défaut',              // 47
    'réglages par défaut',          // 48
    'Cerveau',                      // 49
    'rôde',                         // 50
    'broute',                       // 51
    'en fuite',                     // 52
    'caché',                        // 53
    'paît',                         // 54
    'récolte',                      // 55
    'explore',                      // 56
    'repos',                        // 57
    'cliquez un spécimen · l''océan est navigable',  // 58
    'cliquez/glissez pour semer',   // 59
    'cri d''alarme ?',              // 60
    'nourriture ?',                 // 61
    'signal social ?',              // 62
    'entend',                       // 63
    'vitesse',                      // 64
    'perception',                   // 65
    'taille',                       // 66
    'savoir',                       // 67
    'cliquez pour relâcher un herbivore',  // 68
    'cliquez pour relâcher un prédateur',  // 69
    'cliquez pour éveiller un sapien',     // 70
    'techn. : ',                    // 71
    'chasse',                       // 72
    'Aucun sapien sélectionné.',    // 73
    'Ferme cette fenêtre, clique un sapiens avec l''outil « vue »,',  // 74
    'puis rouvre le cerveau depuis le carnet.',      // 75
    'vert = excitation · rouge = inhibition · pointillés = voie directe · 34 → 9 → 9 → 10',  // 76
    'clic : sapiens suivant · F7 : revenir',         // 77
    'énergie',                      // 78
    'aucune technologie',           // 79
    'n''entend rien',               // 80
    'aucun spécimen',               // 81
    'sapiens %d/%d · herbivores %d · prédateurs %d · poissons %d · flore %d',  // 82
    'par ',                         // 83
    '%s a découvert le feu',        // 84
    '%s a inventé l''agriculture',  // 85
    '%s a inventé les réserves',    // 86
    '%s a découvert le pastoralisme', // 87
    '%s a inventé la pêche',        // 88
    '%s a construit la première pirogue', // 89
    '%s a inventé l''écriture',     // 90
    '%s découvre le feu',           // 91
    '%s invente l''agriculture',    // 92
    '%s invente les réserves',      // 93
    '%s découvre le pastoralisme',  // 94
    '%s invente la pêche',          // 95
    '%s construit la première pirogue', // 96
    '%s invente l''écriture',       // 97
    '%s disparaît — %s, à %d jours',  // 98
    'famine',                       // 99
    'vieillesse',                   // 100
    'dévoré',                       // 101
    'abattu',                       // 102
    'la connaissance de %s s''est perdue',  // 103
    'la connaissance de %s se perd',  // 104
    'le peuple s''établit au camp', // 105
    'le premier enfant du peuple naît : %s',  // 106
    'la génération %d voit le jour — %s',     // 107
    '%s apprivoise %s',             // 108
    '%s a apprivoisé %s',           // 109
    '%s apprivoise un loup : le chien naît',  // 110
    '%s a apprivoisé un loup — le premier chien est né',  // 111
    'le peuple compte %d sapiens',  // 112
    'des immigrants ont rejoint l''île',  // 113
    'des immigrants rejoignent le camp',  // 114
    'une nouvelle ère s''ouvre : %s',  // 115
    'nouvelle ère : %s',            // 116
    'le peuple entre dans l''ère %d — %s',  // 117
    '%s invente %s',                // 118
    'cheat : ère %d équipée · pop %d',  // 119
    ' — PASSAGE PRÊT (bouton doré)',  // 120
    ' — sommet de contenu livré',   // 121
    ' — incomplet',                 // 122
    'passage refusé — Ctrl+Shift+B pour voir ce qui manque',  // 123
    'sommet de contenu livré — les ères futures attendent leur contenu',  // 124
    'ère atteinte — sommet de contenu livré',  // 125
    'SIM %s (%s · âge %d): %s',     // 126
    'SIM: %s',                      // 127
    'UI: %s',                       // 128
    'chargement impossible — fichier illisible',  // 129
    'version incompatible',         // 130
    'fichier de sauvegarde invalide',  // 131
    'aucune sauvegarde trouvée',    // 132
    'nombre de %s invalide: %d',    // 133
    'données corrompues',           // 134
    'les annales reprennent avec le monde chargé',  // 135
    'français',                     // 136
    'vers berger',                  // 137
    'chasse (prédateur)',           // 138
    'traque',                       // 139
    'famine (traque)',              // 140
    'raté',                         // 141
    'défend',                       // 142
    'pêche',                        // 143
    'construit',                    // 144
    'retourné sauvage',             // 145
    'errance',                      // 146
    'suit',                         // 147
    'flâne',                        // 148
    'chien de %s',                  // 149
    '%s grandit — dix foyers s''assemblent : c''est un bourg',  // 150 fondation (toast court)
    'le bourg de %s naît — %d foyers, jour %d',  // 151 fondation (annale)
    '%s devient une ville — %d foyers vivent derrière ses remparts',  // 152
    '%s est désormais une ville (%d foyers)',     // 153
    '%s est proclamée cité — %d foyers sous son monument',  // 154
    'la cité de %s rayonne — %d foyers',          // 155
    ' ',                                        //156
    ' ',                                        //157
    '%d familles rejoignent les villes',   // 158 — 1 arg (%d)
    'le peuple devient citadin'            // 159 — 0 arg

  );

  EN: array[0..159] of string = (
    'Observe the world',            // 0
    'the island awakens…',          // 1
    'new world',                    // 2
    'world saved',                  // 3
    'world loaded',                 // 4
    'OBSERVATION NOTEBOOK · DELPHI', // 5
    'Populations',                  // 6
    'Technologies',                 // 7
    'Dynamics',                     // 8
    'Evolution',                    // 9
    'Emerging lexicon',             // 10
    'People''s inventions',         // 11
    'Specimen',                     // 12
    'Commands',                     // 13
    'Settings',                     // 14
    'People''s annals',             // 15
    'history has no objects yet…',  // 16
    'the people''s history has not begun…', // 17
    'entry:',                       // 18
    'sheet',                        // 19
    'flora',                        // 20
    'herbivores',                   // 21
    'predators',                    // 22
    'sapiens',                      // 23
    'fish',                         // 24
    'Fisher spiral — feather %d%%', // 25
    'Fisher spiral — feather —',    // 26
    'culture — average knowledge %d%%', // 27
    'culture — average knowledge —',    // 28
    'sailors — %d navigators · %d at sea', // 29
    'unknown',                      // 30
    'LOST',                         // 31
    'technologies %d/%d · people %d · inventions %d/%d', // 32
    ' entered the next era',        // 33
    'enter the next era',           // 34
    'view',                         // 35
    'seed',                         // 36
    'herb',                         // 37
    'pred',                         // 38
    'sap',                          // 39
    'Save',                         // 40
    'Load',                         // 41
    'New world',                    // 42
    'help (F1)',                    // 43
    'settings',                     // 44
    'annals',                       // 45
    'relief',                       // 46
    'restore defaults',             // 47
    'default settings',             // 48
    'Brain',                        // 49
    'roams',                        // 50
    'grazing',                      // 51
    'fleeing',                      // 52
    'hidden',                       // 53
    'grazing (herd)',               // 54
    'harvesting',                   // 55
    'exploring',                    // 56
    'resting',                      // 57
    'click a specimen · the ocean is navigable', // 58
    'click/drag to sow seeds',      // 59
    'alarm call?',                  // 60
    'food?',                        // 61
    'social signal?',               // 62
    'hears',                        // 63
    'speed',                        // 64
    'perception',                   // 65
    'size',                         // 66
    'knowledge',                    // 67
    'click to release a herbivore', // 68
    'click to release a predator',  // 69
    'click to wake a sapien',       // 70
    'techs: ',                      // 71
    'hunting',                      // 72
    'No sapien selected.',          // 73
    'Close this window, click a sapien with the "view" tool,',  // 74
    'then reopen the brain from the notebook.',     // 75
    'green = excitation · red = inhibition · dashed = direct path · 34 → 9 → 9 → 10',  // 76
    'click: next sapiens · F7: back',               // 77
    'energy',                       // 78
    'no technologies yet',          // 79
    'hears nothing',                // 80
    'no specimen',                  // 81
    'sapiens %d/%d · herbivores %d · predators %d · fish %d · flora %d',  // 82
    'by ',                          // 83
    '%s discovered fire',           // 84
    '%s invented agriculture',      // 85
    '%s invented stores',           // 86
    '%s discovered herding',        // 87
    '%s invented fishing',          // 88
    '%s built the first canoe',     // 89
    '%s invented writing',          // 90
    '%s discovers fire',            // 91
    '%s invents agriculture',       // 92
    '%s invents stores',            // 93
    '%s discovers herding',         // 94
    '%s invents fishing',           // 95
    '%s builds the first canoe',    // 96
    '%s invents writing',           // 97
    '%s passes away — %s, aged %d days',  // 98
    'starvation',                   // 99
    'old age',                      // 100
    'devoured',                     // 101
    'slain',                        // 102
    'the knowledge of %s has been lost',  // 103
    'the knowledge of %s is lost',  // 104
    'the people settles at the camp', // 105
    'the people''s first child is born: %s',  // 106
    'generation %d is born — %s',   // 107
    '%s tames %s',                  // 108
    '%s has tamed %s',              // 109
    '%s tames a wolf: the dog is born',  // 110
    '%s has tamed a wolf — the first dog is born',  // 111
    'the people counts %d sapiens', // 112
    'immigrants have joined the island',  // 113
    'immigrants reach the camp',    // 114
    'a new era opens: %s',          // 115
    'new era: %s',                  // 116
    'the people enters era %d — %s',  // 117
    '%s invents %s',                // 118
    'cheat: era %d equipped · pop %d',  // 119
    ' — READY (golden button)',     // 120
    ' — content summit reached',    // 121
    ' — incomplete',                // 122
    'denied — Ctrl+Shift+B to see what''s missing',  // 123
    'content summit reached — future eras await their content',  // 124
    'era reached — content summit delivered',  // 125
    'SIM %s (%s · age %d): %s',     // 126
    'SIM: %s',                      // 127
    'UI: %s',                       // 128
    'load failed — unreadable file',  // 129
    'incompatible version',         // 130
    'invalid save file',            // 131
    'no save file found',           // 132
    'invalid number of %s: %d',     // 133
    'corrupted data',               // 134
    'the annals resume with the loaded world',  // 135
    'english',                      // 136
    'towards shepherd',             // 137
    'hunting (predator)',           // 138
    'stalking',                     // 139
    'starving (stalking)',          // 140
    'missed',                       // 141
    'defending',                    // 142
    'fishing',                      // 143
    'building',                     // 144
    'turned feral',                 // 145
    'wandering',                    // 146
    'following',                    // 147
    'loafing',                      // 148
    '%s''s dog',                     // 149
    '%s grows — ten hearths gather: a town is born',  // 150
    'the town of %s is born — %d hearths, day %d',    // 151
    '%s becomes a city — %d hearths live behind its walls',  // 152
    '%s is now a city (%d hearths)',                  // 153
    '%s is proclaimed a city-state — %d hearths under its monument',  // 154
    'the city-state of %s shines — %d hearths',       // 155
     ' ',                                        //156
    ' ',                                        //157
    '%d families move to the cities',      // 158 — 1 arg (%d)
    'the people turn urban'                // 159 — 0 arg

  );

function L(id: Integer): string;
begin
  if (id < 0) then Exit('');
  case FLangue of
    LANG_EN: if id <= High(EN) then Exit(EN[id]);
  else
    if id <= High(FR) then Exit(FR[id]);
  end;
  Result := '?';
end;

function LangNom: string;
begin
  if FLangue = LANG_EN then Result := 'english' else Result := 'français';
end;

end.

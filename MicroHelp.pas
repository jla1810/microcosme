unit MicroHelp;

{ Microcosme — mode d'emploi intégré (F1).
  Overlay par-dessus le monde : sommaire cliquable, pages courtes,
  boutons « démo » qui agissent sur la vraie simulation.
  ▼ Pour modifier/ajouter des pages : tout est dans HelpBuild (plus bas). }

interface

uses
  System.SysUtils, System.Math, System.Types, System.Classes,
  Winapi.Windows, Vcl.Graphics;

const
  BID_HELP = 207;   // pour un bouton « aide » dans le carnet

procedure HelpToggle;
procedure HelpShow(AOn: Boolean);
function  HelpOn: Boolean;
procedure HelpRender(C: TCanvas; W, H: Integer);
function  HelpMouseDown(X, Y: Integer): Boolean;  // True = clic consommé
procedure HelpWheel(Delta: Integer);
procedure HelpKeyDown(Key: Word);                 // flèches / Échap si ouverte
function HelpBtnCount: Integer;


type
  THelpDemoProc = procedure(Act: Integer) of object;
var
  HelpDemoProc: THelpDemoProc = nil;  // MicroMain l'assigne (boutons démo)

implementation

uses MicroBrain;   // Col, ClampF

type
  THelpLine = record
    Txt: string;
    K: Byte;       // 0 normal · 1 section · 2 astuce · 3 vert · 4 rouge · 5 gris · 6 lien
    Act: Integer;  // pour K=6 : page cible
  end;
  THelpDemo = record Cap: string; Act: Integer; end;
  THelpPage = record
    Title: string;
    L: array of THelpLine;
    D: array of THelpDemo;
  end;
  THBtn = record R: TRect; Id: Integer; end;

var
  Pages: array of THelpPage;
  Cur: Integer = 0;
  FOn: Boolean = False;
  CurP: Integer = 0;
  HBtns: array of THBtn;

{--- constructeurs de pages (usage interne) -------------------------------}

function HelpBtnCount: Integer;
begin
  Result := Length(HBtns);
end;


procedure P(const Title: string);
begin
  SetLength(Pages, Length(Pages) + 1);
  Pages[High(Pages)].Title := Title;
  Pages[High(Pages)].L := nil;
  Pages[High(Pages)].D := nil;
  CurP := High(Pages);
end;

procedure LT(const Txt: string; K: Byte = 0; Act: Integer = 0);
var N: Integer;
begin
  N := Length(Pages[CurP].L);
  SetLength(Pages[CurP].L, N + 1);
  Pages[CurP].L[N].Txt := Txt;
  Pages[CurP].L[N].K := K;
  Pages[CurP].L[N].Act := Act;
end;

procedure DB(const Cap: string; Act: Integer);
var N: Integer;
begin
  N := Length(Pages[CurP].D);
  SetLength(Pages[CurP].D, N + 1);
  Pages[CurP].D[N].Cap := Cap;
  Pages[CurP].D[N].Act := Act;
end;

{============================================================================
 ▼▼▼  LE CONTENU — modifiez librement  ▼▼▼
   P('titre')            : nouvelle page
   LT('texte')           : ligne normale
   LT('texte', 1)        : sous-titre doré     LT('texte', 2) : astuce ◆
   LT('texte', 3)        : vert                LT('texte', 4) : rouge
   LT('texte', 5)        : gris                LT('titre', 6, nPage) : lien
   DB('libellé', n)      : bouton démo -> HelpDemoProc(n) dans MicroMain
============================================================================}
procedure HelpBuild;
begin
  SetLength(Pages, 0);

  // ============================================================ 0. SOMMAIRE
  P('Sommaire');
  LT('cliquez un chapitre · F1 ouvre/ferme · Échap ferme · flèches et molette tournent', 5);
  LT('Comprendre le jeu', 1);
  LT('L''esprit du jeu', 6, 1);
  LT('Prise en main', 6, 2);
  LT('Les raccourcis clavier', 6, 13);
  LT('La vie', 1);
  LT('Le monde : relief, saisons, océan', 6, 4);
  LT('Les bêtes : herbivores, prédateurs, poissons', 6, 5);
  LT('Les sapiens : corps et esprit', 6, 6);
  LT('La culture et son héritage', 6, 7);   LT('Les ères de l''humanité', 6, 19);
  LT('Les technologies des ères 2 et 3', 6, 20);
  LT('Les technologies, une à une', 6, 14);
  LT('Les inventions mineures', 6, 9);
  LT('Le langage et les cris', 6, 8);
  LT('Le réseau neuronal', 1);
  LT('Anatomie du réseau neuronal', 6, 17);
  LT('Comment il apprend', 6, 18);
  LT('Observer', 1);
  LT('Le carnet d''observation', 6, 11);
  LT('Lire le cerveau d''un sapiens', 6, 15);
  LT('Les sons du monde', 6, 10);
  LT('Jouer et expérimenter', 1);
  LT('Les outils', 6, 3);
  LT('Expériences et défis', 6, 12);
  LT('Questions fréquentes', 6, 16);
  LT('les pages « essayer » agissent sur la vraie simulation.', 2);

  // ============================================================ 1. ESPRIT
  P('L''esprit du jeu');
  LT('Microcosme est une boîte de vie. On n''y gagne rien, on ne perd rien :');
  LT('on installe un monde, on l''arrose d''un peu de hasard, et on regarde.');
  LT('');
  LT('Ce qui pousse tout seul', 1);
  LT('· la sélection naturelle : les plus rapides ou plus perspicaces échappent');
  LT('  aux loups, se reproduisent, transmettent leurs traits — vitesse, vue,');
  LT('  taille, plume ;');
  LT('· la culture : un enfant né sait presque rien, mais il choisit un mentor');
  LT('  et son esprit glisse vers le sien. Le savoir est un héritage vivant ;');
  LT('· le langage : les sapiens émettent des cris (α β γ δ) dont le sens');
  LT('  n''est fixé par personne. Le lexique du carnet devine : alarme ? nourriture ?');
  LT('· les inventions : une brochette, un tambour, un filet naissent des');
  LT('  circonstances — un feu, une nuit, une rivière — pas d''un plan.');
  LT('');
  LT('Votre rôle', 1);
  LT('Dieu ne fait rien ici, ou presque : vous semez, vous relâchez, vous regardez.');
  LT('la meilleure action est souvent aucune. Revenez demain, lisez les annales.', 2);
  LT('Laissez tourner une nuit à 4x : au matin, des générations sont passées.', 3);

  // ============================================================ 2. PRISE EN MAIN
  P('Prise en main');
  LT('L''écran', 1);
  LT('· à droite : le carnet — populations, technologies, lexique, annales, commandes ;');
  LT('· au centre : le monde. Clic droit maintenu = déplacer la vue ;');
  LT('· molette = zoomer sur un point précis (de ×1 à ×6).');
  LT('');
  LT('Le temps', 1);
  LT('II / > : pause et lecture · 1x 2x 4x : vitesse du temps.');
  LT('Espace : pause rapide. Un jour dure ~2 minutes à 1x.');
  LT('La barre dorée en haut du carnet montre l''heure du jour.');
  LT('4x pour voir des générations, 1x pour assister à une naissance.', 2);
  LT('');
  LT('Le premier geste conseillé', 1);
  LT('1. appuyez sur « Observer le monde » ;');
  LT('2. zoomez sur le camp au centre (molette) ;');
  LT('3. sélectionnez un sapiens avec l''outil « vue » — sa fiche s''ouvre ;');
  LT('4. cliquez « cerveau » dans le carnet : le réseau en direct.');
  DB('pause / lecture', 3);
  DB('me montrer un sapiens', 0);

  // ============================================================ 3. OUTILS
  P('Les outils');
  LT('Cinq outils, en bas du carnet :');
  LT('');
  LT('vue', 1);
  LT('Cliquez une créature : elle devient le spécimen. Sa fiche (F3) montre');
  LT('traits, énergie, technologies, ce qu''elle entend, et son réseau neuronal.');
  LT('Le grand cercle gris autour d''elle = sa distance de perception.');
  LT('');
  LT('sem', 1);
  LT('Cliquez ou glissez : des plantes poussent. Utile pour sauver une espèce,');
  LT('ou créer un grenier naturel et observer l''effet sur la natalité.');
  DB('semer 12 plantes ici', 1);
  LT('');
  LT('her — relâcher un herbivore', 1);
  LT('Préférez les abords de forêt : ils s''y cachent des loups.');
  LT('');
  LT('pré — relâcher un prédateur', 1);
  LT('Le grand régulateur. Sans lui : surpâturage puis famine générale.');
  LT('Avec trop de lui : plus d''herbivores, et les sapiens à leur tour chassés.', 4);
  LT('Les sapiens près d''un feu ou d''un chien le repoussent.', 3);
  LT('');
  LT('sap — éveiller un sapiens', 1);
  LT('Il naît adulte, sans savoir, rejoint le camp et cherche un mentor.');
  LT('Posez-en 2-3 près d''un groupe : la culture se transmettra mieux.');
  DB('éveiller un sapiens ici', 2);

  // ============================================================ 4. LE MONDE
  P('Le monde : relief, saisons, océan');
  LT('Le relief', 1);
  LT('L''île est générée par bruit fractal : côtes découpées, plaine, forêts');
  LT('(où l''on se cache et où l''on construit), roches, neiges en altitude.');
  LT('Le bouton « relief » du carnet accentue l''ombrage du terrain.');
  LT('Trois îlots volcaniques entourent l''île — leurs eaux sont poissonneuses.');
  LT('');
  LT('Les saisons', 1);
  LT('Une année = 24 jours, quatre saisons de 6 jours :');
  LT('· printemps : la flore repart ;');
  LT('· été : tout pousse (flore ×1.0) — la période des naissances ;');
  LT('· automne : la croissance ralentit ;');
  LT('· hiver : flore ×0.25, teinte bleutée — la famine guette les faibles.', 4);
  LT('Regardez les courbes du carnet : les populations respirent au rythme des saisons.', 2);
  LT('');
  LT('L''océan', 1);
  LT('Il est mortel à la nage — un sapiens qui s''y aventure s''épuise vite.');
  LT('Avec la pêche puis la navigation (pirogue), il devient un garde-manger.');
  LT('Les poissons clairs nagent près des côtes ; les sombres, au large,');
  LT('ne sont accessibles qu''aux marins munis du filet.');

  // ============================================================ 5. LES BÊTES
  P('Les bêtes');
  LT('Herbivores', 1);
  LT('Ils broutent, fuient à la vue d''un loup, se figent dans la forêt si');
  LT('celle-ci est assez loin du danger (état « caché »).');
  LT('Domestiqués (anneau doré) : ils paissent autour de leur hutte,');
  LT('les sapiens les traient (le petit pictogramme blanc = lait disponible).');
  LT('Ils redeviennent sauvages si on les abandonne trop loin du camp.');
  LT('');
  LT('Prédateurs', 1);
  LT('Ils traquent la proie la plus proche VISIBLE ; la forêt réduit la vue.');
  LT('Ils chassent les sapiens aussi — sauf près d''un feu, d''un chien,');
  LT('ou si la fumée (invention) brouille leur flair.');
  LT('Yeux rouges quand la chasse est lancée.', 2);
  LT('');
  LT('Poissons', 1);
  LT('Les clairs vivent sur les hauts-fonds ; les sombres, plus gros, au large.');
  LT('Les populations se reconstituent seules si on pêche raisonnablement —');
  LT('un vrai stock. Trop pêcher le vide pour des saisons.', 4);
  LT('');
  LT('Le chien', 1);
  LT('Un jeune loup peut être apprivoisé près d''un feu (technologie feu requise).');
  LT('Il suit son maître, le nourrit de son flair (vue ×1.8), repousse les loups.');
  LT('Le trait doré du chien au sapiens = le lien de maître.');

  // ============================================================ 6. LES SAPIENS
  P('Les sapiens : corps et esprit');
  LT('Le corps', 1);
  LT('· énergie : récolte, chasse, pêche, lait, réserves des huttes la nuit ;');
  LT('· la marche coûte ; nager coûte cher ; parler un peu ; penser beaucoup ;');
  LT('· en dessous de zéro : famine. Au-delà de l''âge maximal : vieillesse.');
  LT('· la nuit près d''un feu : récupération — et brochette encore mieux.');
  LT('');
  LT('L''esprit', 1);
  LT('Un réseau 34 entrées → 9 → 9 → 10 sorties, hérité et mutable :');
  LT('· entrées : besoins, directions (nourriture, pair, prédateur), les 4 cris');
  LT('  entendus, la mémoire des dangers et des lieux à nourriture,');
  LT('  les échos de ses propres sorties précédentes (récurrences) ;');
  LT('· sorties : tourner, avancer, bâtir, se reproduire, chasser,');
  LT('  crier α β γ δ, se reposer.');
  LT('Personne ne programme rien : la mutation et le mentorat façonnent tout.', 3);
  LT('');
  LT('La mémoire', 1);
  LT('Chaque danger vu est noté (croix rouge sur la carte mentale), chaque');
  LT('bonne récolte aussi (cercle vert). Ils s''estompent en ~70 secondes.');
  LT('Sélectionnez un sapiens pour VOIR sa carte mentale sur le terrain.');

  // ============================================================ 7. CULTURE
  P('La culture et son héritage');
  LT('Le savoir, une jauge de 0 à 95 %', 1);
  LT('Elle monte lentement avec l''âge, plus vite auprès d''un mentor,');
  LT('nettement plus vite encore près d''une hutte (le feu, l''école du camp).');
  LT('');
  LT('Le mentorat', 1);
  LT('L''enfant choisit le plus savant des voisins. Son réseau glisse vers');
  LT('celui du mentor — mais jamais au-delà de 30 % de la distance génétique :');
  LT('l''ADN n''est jamais écrasé, seulement guidé.');
  LT('Le trait doré pointillé = un enfant suit son mentor.');
  LT('');
  LT('La diffusion', 1);
  LT('Les adultes proches s''imitent : ce qu''un voisin sait, l''autre l''apprend.');
  LT('Au camp (ou près d''une hutte), la « mémoire du peuple » redonne tout');
  LT('ce qui fut inventé — une bibliothèque vivante, réglable dans « réglages ».');
  LT('');
  LT('La perte', 1);
  LT('Un savoir sans porteur meurt (« PERDUE » dans le carnet).');
  LT('Une épidémie, une guerre, une migration… et des siècles s''effacent.', 4);
  LT('Vérifiez la colonne Technologies : les barres sont les % de porteurs.', 2);

  // ============================================================ 8. LANGAGE
  P('Le langage et les cris');
  LT('Les cris', 1);
  LT('Quatre sorties du cerveau : α β γ δ. Quand l''une gagne, le sapiens');
  LT('crie — la bulle colorée s''affiche au-dessus de lui, et le mot SONNE');
  LT('(chaque son est synthétisé en direct, chaque mot a sa signature).');
  LT('');
  LT('Le sens n''est pas programmé', 1);
  LT('Le carnet compte, pour chaque mot, le contexte d''émission :');
  LT('· émis surtout avec un prédateur en vue → « cri d''alarme ? » ;');
  LT('· émis près de nourriture → « nourriture ? » ;');
  LT('· émis pour rien de spécial → « signal social ? ».');
  LT('Ce sont des HYPOTHÈSES de lecture, pas des étiquettes vraies.', 2);
  LT('');
  LT('La contagion', 1);
  LT('Entendre un mot façonne le lexique de l''auditeur : les mots se');
  LT('propagent de proche en proche, avec variations à chaque bouche.');
  LT('Avec le tambour (invention), un cri porte deux fois plus loin —');
  LT('et se joue à la peau tendue plutôt qu''à la gorge.', 3);
  LT('');
  LT('Comment le lire au cerveau', 1);
  LT('Les entrées α..δ s''allument quand il ENTEND ; les sorties quand il PARLE.');
  LT('Regardez une conversation : boucle entrée→sortie chez deux voisins.', 2);

  // ============================================================ 9. INVENTIONS
  P('Les inventions mineures');
  LT('Elles naissent des circonstances — jamais d''un plan :');
  LT('');
  LT('avant le feu', 1);
  LT('· hotte — née en forêt : récolte +50 % ;');
  LT('· parure — née d''une esthétique commune (plume > 55 %) : séduction +25 % ;');
  LT('· tambour — né près de l''eau avec souvenir de danger : les cris portent 2×.');
  LT('');
  LT('avec le feu', 1);
  LT('· brochette — la nuit, affamé, près du feu : repos ×1.6 plus nourrissant ;');
  LT('· filet — pêcheur dans l''eau : captures rapides, +60 % ;');
  LT('· peausserie — nuit + hutte : la nuit pèse moins ;');
  LT('· torche — nuit + loin du camp : fuite +25 % ;');
  LT('· fumée — prédateur vu + feu : les loups vous voient mal ;');
  LT('· piège — forêt + gibier : frappe à distance ;');
  LT('· appentis — réserves + 3 huttes : stockage ×2.');
  LT('');
  LT('Leur nom est une phrase', 1);
  LT('Chaque invention prend un mot du langage émergent et le nom de son');
  LT('inventeur : « tambour β de Grok ». Elles se transmettent comme les');
  LT('technologies — et se perdent aussi.', 4);
  LT('Elles sont listées dans le carnet, avec l''auteur et le jour.', 2);
  LT('Les ères apportent six inventions de plus — voir la page ères.', 6, 20);

  // ============================================================ 10. SONS
  P('Les sons du monde');
  LT('Tout est synthétisé en direct — aucun fichier son.');
  LT('');
  LT('Les voix', 1);
  LT('Chaque cri α β γ δ a sa sonorité (voyelles différentes), chaque sapiens');
  LT('sa hauteur de voix, chaque mot sa petite mélodie pentatonique —');
  LT('le même mot retentit toujours pareil : on apprend à le reconnaître.');
  LT('Un porteur de tambour « parle » en frappant sa peau tendue.');
  LT('');
  LT('L''ambiance', 1);
  LT('· jour : oiseaux çà et là ;');
  LT('· nuit : grillons et un drone grave ;');
  LT('· côte : la houle — approchez la caméra du rivage ;');
  LT('· camp la nuit : le crépitement du feu.');
  LT('');
  LT('Commandes', 1);
  LT('F4 ou le bouton ♪ : couper / remettre.');
  LT('Pas assez fort ? Réglez le volume Windows — le moteur suit.');

  // ============================================================ 11. CARNET
  P('Le carnet d''observation');
  LT('De haut en bas :');
  LT('');
  LT('· date, heure, saison, année — et la barre dorée du jour ;');
  LT('· populations : flore, herbivores, prédateurs, sapiens, poissons ;');
  LT('· spirale de Fisher : la plume moyenne (l''esthétique du peuple) ;');
  LT('· culture : le savoir moyen ;');
  LT('· marins : navigateurs et pirogues en mer ;');
  LT('· technologies : qui sait quoi, depuis quand, ou « PERDUE » ;');
  LT('· dynamique : les courbes croisées des populations ;');
  LT('· évolution : vitesse, vue, taille, plume, culture, mutations —');
  LT('  les traits MOYENS qui dérivent de génération en génération ;');
  LT('· lexique émergent : le sens deviné de chaque mot ;');
  LT('· inventions du peuple : les 12 dernières ;');
  LT('· spécimen : la fiche de la créature sélectionnée, avec son cerveau ;');
  LT('· commandes, réglages, annales, et la mini-carte.');
  LT('Le carnet défile : molette ou clic sur sa barre grise à droite.', 2);

  // ============================================================ 12. EXPÉRIENCES
  P('Expériences et défis');
  LT('Voici ce pour quoi Microcosme est vraiment fait :');
  LT('');
  LT('Expérience 1 — la sélection en direct', 1);
  LT('Relâchez 6 prédateurs. Regardez la courbe « vitesse » des herbivores :');
  LT('en quelques générations, les survivants sont plus rapides.', 3);
  LT('');
  LT('Expérience 2 — la culture sans école', 1);
  LT('Isolez 2 sapiens à l''est, 6 à l''ouest. Qui découvre le feu le premier ?');
  LT('Le groupe le plus dense — la densité fait les savants.', 3);
  LT('');
  LT('Expérience 3 — l''effondrement', 1);
  LT('Supprimez tout prédateur et nourrissez à foison. La population');
  LT('explose, la forêt recule, puis l''hiver arrive…', 4);
  LT('');
  LT('Expérience 4 — la chaîne du feu', 1);
  LT('Notez le jour de la découverte du feu. Puis « Nouveau monde » :');
  LT('le feu reviendra-t-il au même jour ? Jamais tout à fait.', 3);
  LT('');
  LT('Expérience 5 — le mot perdu', 1);
  LT('Quand un mot atteint « cri d''alarme ? », éliminez (famine) tous les');
  LT('locuteurs. Le mot survit-il ailleurs ? Réapparaît-il plus tard ?', 3);
  LT('');
  LT('comparez plusieurs mondes : c''est là que le jeu devient science.', 2);

  // ============================================================ 13. RACCOURCIS
  P('Les raccourcis clavier');
  LT('F1', 1);
  LT('aide : ouvre / ferme ce manuel. Échap ferme aussi. Flèches : pages.');
  LT('');
  LT('Espace', 1);
  LT('pause / lecture. Premier appui : démarre le monde.');
  LT('');
  LT('F2', 1);
  LT('réglages : ouvre/ferme les molettes de rythme du monde');
  LT('(feu, agriculture, immigration, mémoire du peuple…).');
  LT('');
  LT('F3', 1);
  LT('fiche : ouvre la fenêtre détaillée du spécimen sélectionné.');
  LT('');
  LT('F4', 1);
  LT('son : coupe / remet tout l''audio.');
  LT('');
  LT('Souris', 1);
  LT('· clic gauche : action de l''outil courant ;');
  LT('· clic droit maintenu : déplacer la vue ;');
  LT('· molette : zoom (monde) ou défilement (carnet).');

  // ============================================================ 14. TECHNOLOGIES
  P('Les technologies, une à une');
  LT('feu', 1);
  LT('La première. Sans lui, presque rien d''autre n''arrive. Chasse les');
  LT('prédateurs, réchauffe la nuit, permet brochette, torche, fumée, piège…');
  LT('Chance de découverte par sapiens cultivé (molette « réglages »).');
  LT('');
  LT('agriculture', 1);
  LT('Après le feu. En récoltant, le sapiens replante : des champs naissent');
  LT('autour du camp (cercle pointillé vert des huttes cultivées).');
  LT('');
  LT('réserves', 1);
  LT('Le surplus de récolte part dans la hutte (anneau doré = niveau du stock).');
  LT('La nuit ou en famine, on puise dedans. L''appentis double le stockage.');
  LT('');
  LT('pastoralisme', 1);
  LT('Apprivoiser les herbivores sauvages (jauge de confiance invisible),');
  LT('les parquer près d''une hutte, les traire. Le chien vient avec le feu.');
  LT('');
  LT('pêche', 1);
  LT('Au bord de l''eau, le sapiens attrape les poissons côtiers.');
  LT('Le filet (invention) accélère beaucoup et ouvre les poissons profonds.');
  LT('');
  LT('navigation', 1);
  LT('La pirogue : l''océan n''est plus une muraille. Les marins vont vers');
  LT('les îlots — et parfois n''en reviennent pas.', 4);
  LT('');
  LT('écriture', 1);
  LT('La dernière. Les tablettes (petites croix blanches près des huttes)');
  LT('apparaissent — et l''histoire devient plus longue que les mémoires.', 3);

  // ============================================================ 15. LIRE LE CERVEAU
  P('Lire le cerveau d''un sapiens');
  LT('Sélectionnez un sapiens (outil « vue »), cliquez le grand schéma');
  LT('« Cerveau » dans le carnet — ou la fenêtre dédiée pour tout voir.');
  LT('');
  LT('Ce qu''on voit', 1);
  LT('· colonnes de gauche à droite : 34 entrées, 9 neurones, 9 neurones,');
  LT('  10 sorties ;');
  LT('· un lien vert = excitation, rouge = inhibition ; plus il est vif,');
  LT('  plus le signal passe fort EN CE MOMENT ;');
  LT('· les pointillés = la voie directe (réflexes sans passer par les couches) ;');
  LT('· les étiquettes s''allument quand le signal est actif :');
  LT('  « préd.x » quand un loup est vu, « r.β » pour l''écho du cri entendu…');
  LT('');
  LT('Ce qu''il faut chercher', 1);
  LT('· les réflexes : prédateur → fuite (préd.* → tourner/vitesse) ;');
  LT('· la boucle du langage : α..δ entendus → α..δ émis ;');
  LT('· la mémoire : m.dan.* allumé = il « pense » à un danger connu.');
  LT('Comparez un vieux sapiens et un enfant : la densité parle.', 3);

  // ============================================================ 16. FAQ
  P('Questions fréquentes');
  LT('Pourquoi mes sapiens meurent de famine alors qu''il y a des plantes ?', 1);
  LT('Vérifiez l''heure : la nuit, personne ne récolte — et l''hiver divise');
  LT('la flore par 4. Les réserves et le feu existent pour ça. Patience.', 3);
  LT('');
  LT('Pourquoi les prédateurs disparaissent ?', 1);
  LT('S''il n''y a plus d''herbivores à portée, ils meurent. Le système se');
  LT('régule : relâchez-en peu, et laissez les herbivores revenir.', 2);
  LT('');
  LT('Le feu n''arrive jamais !', 1);
  LT('Il faut des sapiens adultes, cultivés (savoir > 20 %), et de la chance.');
  LT('Accélérez le temps. Ou ouvrez « réglages » (F2) et montez la molette feu.', 2);
  LT('');
  LT('Un sapiens est tout seul au milieu de nulle part', 1);
  LT('Il rentre au camp d''instinct (« explore » + attraction du camp).');
  LT('S''il est bloqué par l''eau sans navigation, il tournera en rond. Désolé.', 5);
  LT('');
  LT('Les mots changent d''un monde à l''autre ?', 1);
  LT('Oui : le lexique est généré à la naissance de chaque esprit. Deux');
  LT('mondes, deux langues. Comme chez nous.', 3);
  LT('');
  LT('Comment sauvegarder une histoire ?', 1);
  LT('Sauver / Charger dans le carnet : le monde, les esprits, le lexique,');
  LT('les annales — tout repartira où vous l''avez laissé.');

  // ============================================================ 17. ANATOMIE DU RÉSEAU
  P('Anatomie du réseau neuronal');
  LT('Chaque sapiens porte son propre cerveau : environ 600 nombres flottants');
  LT('en réalité — son ADN mental. Le voici, couche par couche.');
  LT('');
  LT('Vue d''ensemble : 34 → 9 → 9 → 10', 1);
  LT('· 34 entrées : ce que le corps sent du monde, à chaque « pensée » ;');
  LT('· 9 neurones cachés, puis 9 autres : le traitement ;');
  LT('· 10 sorties : les actions possibles.');
  LT('');
  LT('Les 34 entrées, dans l''ordre', 1);
  LT('0 biais · 1 énergie (0=faim, 1=replet) · 2 lumière du jour', 5);
  LT('3-5 nourriture : direction X, Y, proximité', 5);
  LT('6-8 pair le plus proche : X, Y, proximité', 5);
  LT('9-11 prédateur le plus proche : X, Y, proximité', 5);
  LT('12-15 les quatre cris entendus : α, β, γ, δ (force du signal)', 5);
  LT('16-17 direction d''où vient le cri le plus fort', 5);
  LT('18-20 mémoire de danger la plus proche : X, Y, force', 5);
  LT('21-23 mémoire de nourriture : X, Y, force (pondérée par la faim !)', 5);
  LT('24-32 les NEUF échos : ce que le réseau a décidé à la pensée précédente', 5);
  LT('33 biais constant = 1', 5);
  LT('Les directions sont relatives à l''orientation du corps :');
  LT('« devant moi à gauche », pas « au nord-ouest de l''île ».', 2);
  LT('');
  LT('Les 10 sorties', 1);
  LT('0 tourner (gauche/droite) · 1 avancer (vitesse du corps)', 5);
  LT('2 BÂTIR une hutte · 3 se reproduire · 4 chasser', 5);
  LT('5-8 crier α, β, γ, δ · 9 se reposer', 5);
  LT('La sortie la plus active gagne et devient l''action du moment.');
  LT('');
  LT('Comment ça calcule', 1);
  LT('Chaque neurone caché fait une somme pondérée de ses entrées, puis');
  LT('écrase le résultat entre -1 et +1 (tangente hyperbolique).');
  LT('Les couches suivantes refont pareil. C''est tout — et ça suffit :');
  LT('chaque connexion porte un poids (sa force) qui fait TOUT le caractère.');
  LT('');
  LT('Les trois voies', 1);
  LT('· voie lente : entrées → 9 → 9 → sorties (la réflexion) ;');
  LT('· voie directe (pointillés à l''écran) : entrées → sorties (les réflexes) ;');
  LT('· récurrences : les sorties d''hier nourrissent les entrées d''aujourd''hui.');
  LT('C''est la récurrence qui donne des comportements sostenus :');
  LT('un sapiens qui fuit CONTINUE de fuir, un crieur continue de crier.', 3);
  LT('');
  LT('Où le voir tourner', 1);
  LT('Sélectionne un sapiens, ouvre « cerveau » : chaque lien s''allume selon');
  LT('sa force ACTUELLE. Les poids ne changent pas en direct — voir la page');
  LT('suivante pour ce qui les façonne.', 2);

  // ============================================================ 18. APPRENTISSAGE
  P('Comment il apprend');
  LT('Personne n''enseigne rien au réseau. Trois forces le façonnent :');
  LT('');
  LT('1. L''héritage', 1);
  LT('À la naissance, l''enfant copie le réseau d''un parent — le plus souvent');
  LT('la mère — PUIS la mutation passe :');
  LT('· ~13 % des poids bougent un peu (+/- 0,3 en moyenne) ;');
  LT('· ~2 % sautent franchement ailleurs (mutation sauvage) ;');
  LT('· la VOIX (poids α β γ δ) mute 2 fois plus : c''est voulu, le langage');
  LT('  doit varier plus vite que le corps — c''est lui qui évolue le plus vite.');
  LT('· chaque lignée a son taux de mutation, hérité et lui-même mutable :');
  LT('  familles « innovantes » et « conservatrices » coexistent.');
  LT('');
  LT('2. Le mentorat (la culture)', 1);
  LT('L''enfant choisit le plus savant des voisins comme mentor. Son réseau');
  LT('glisse doucement vers celui du mentor — MAIS seulement sur 30 % de la');
  LT('distance génétique au maximum :');
  LT('l''ADN n''est jamais écrasé, il est GUIDÉ. Un enfant de parents médiocres');
  LT('peut devenir grand ; il ne deviendra jamais son mentor tout entier.');
  LT('');
  LT('3. La sélection (le juge de paix)', 1);
  LT('Ceux qui savent trouver à manger, éviter les loups, ne pas se noyer…');
  LT('vivent plus longtemps et se reproduisent plus. Leurs poids se diffusent.');
  LT('C''est la sélection naturelle, sans autre jugement que la survie.');
  LT('');
  LT('Ce qui N''EXISTE PAS (et qu''on croit souvent voir)', 1);
  LT('· pas de rétroaction d''erreur : le réseau ne « sait » pas quand il se trompe ;');
  LT('· pas de mémoire entre générations autre que les gènes et la culture ;');
  LT('· pas de but : personne ne vise « mieux ». L''émergence fait le reste.', 3);
  LT('');
  LT('Résultat observable', 1);
  LT('Après 30-40 générations, regarde le carnet : les courbes de vitesse et');
  LT('de vue montent si les prédateurs pressent, la culture grimpe en');
  LT('dents de scie (une invention perdue, réapprise au camp), les mots');
  LT('apparaissent et disparaissent. L''histoire s''écrit toute seule.', 2);
    // ============================================================ 19. ÈRES
  P('Les ères de l''humanité');
  LT('Trois âges', 1);
  LT('· ère 1 — Néolithique : feu, agriculture, réserves, pastoralisme,');
  LT('  pêche, navigation, écriture. Le monde que vous connaissez déjà ;');
  LT('· ère 2 — Âge du bronze : la terre se laboure, le métal mord,');
  LT('  la voile se dresse, les idées s''échangent de main en main ;');
  LT('· ère 3 — Âge du fer : l''outillage parfait, l''eau conduite, la');
  LT('  philosophie — et pour la première fois, un savoir qui ne meurt plus.');
  LT('');
  LT('Rien ne se perd au passage', 1);
  LT('Les technologies et inventions de l''ère précédente restent actives.');
  LT('On n''abandonne jamais le feu. On construit dessus.', 3);
  LT('');
  LT('Comment on passe', 1);
  LT('Le passage n''est jamais automatique : quand toutes les technologies');
  LT('de l''ère sont découvertes, que le peuple compte assez d''adultes');
  LT('et assez d''inventions, un bouton doré « entrer dans l''ère suivante »');
  LT('apparaît en tête des commandes du carnet — et attend votre main.');
  LT('Le carnet affiche votre progression sous le badge d''ère :', 5);
  LT('technologies 5/7 · peuple 12 · inventions 4/10.', 5);
  LT('Ne traversez pas en pleine famine ni à la veille de l''hiver.', 4);
  LT('');
  LT('Ce qui change', 1);
  LT('· les découvertes s''accélèrent : chaque jour de recherche ratée');
  LT('  nourrit la suivante (l''effet bibliothèque) — puis Science et');
  LT('  Mathématiques l''amplifient encore ;');
  LT('· le peuple peut croître : le plafond des sapiens monte d''un tiers');
  LT('  à chaque ère (64 → 96 → 144) ;');
  LT('· le village se transforme : les huttes rondes deviennent des maisons');
  LT('  de pierre au toit de tuile ; au fer, la pierre se taille plus claire,');
  LT('  et la maison au feu porte un fanion doré.');
  LT('Chaque passage est consigné dans les annales.', 2);

  // ============================================================ 20. TECHS DES ÈRES
  P('Les technologies des ères 2 et 3');
  LT('Âge du bronze', 1);
  LT('· charrue — la récolte rapporte moitié plus à chaque cueillette ;');
  LT('· roue — chacun marche un tiers plus vite, en toutes besognes ;');
  LT('· irrigation — la terre porte un tiers de végétation de plus ;');
  LT('· métallurgie — la chasse rapporte bien plus à chaque frappe ;');
  LT('· voile — en mer, la pirogue va aussi vite qu''on marche à terre ;');
  LT('· monnaie — les idées circulent : la diffusion entre voisins s''emballe ;');
  LT('· archives — la mémoire du peuple se lit partout sur l''île,');
  LT('  plus seulement au camp ;');
  LT('· science — chaque découverte rend les suivantes plus probables.');
  LT('');
  LT('Âge du fer', 1);
  LT('· fer — le métal parfait encore la chasse (il se cumule au bronze) ;');
  LT('· aqueduc — avec l''irrigation, la terre nourrit encore davantage ;');
  LT('· ingénierie — les réserves des huttes gagnent la moitié ;');
  LT('· philosophie — le savoir ne se perd JAMAIS plus, même si tous');
  LT('  les porteurs disparaissent ;');
  LT('· médecine — la vieillesse recule d''un cinquième ;');
  LT('· mathématiques — les découvertes s''accélèrent encore ;');
  LT('· astronomie — les hivers perdent un tiers de leur mordant ;');
  LT('· école — le mentorat transmet moitié plus de savoir.');
  LT('');
  LT('Les inventions des nouveaux âges', 1);
  LT('· bougie — née de l''écriture, la nuit près d''une hutte : la nuit');
  LT('  ne pèse plus, même loin des feux ;');
  LT('· charrette — la roue devenue fardeau : les réserves se remplissent');
  LT('  moitié plus vite ;');
  LT('· four — le repas pris aux réserves nourrit un tiers de plus ;');
  LT('· horloge — les mathématiques mesurent le temps : la marche s''affine ;');
  LT('· boussole — s''orienter aux étoiles, la nuit loin du camp :');
  LT('  l''exploration erre deux fois moins ;');
  LT('· théâtre — quand un public se forme, la diffusion s''enflamme.', 3);
  LT('Dans le carnet, chaque ère ouverte a son sous-titre doré ;', 2);
  LT('les technologies des ères à venir restent secrètes.', 2);

end;

{--- service ----------------------------------------------------------------}

procedure HelpShow(AOn: Boolean);
begin
  if AOn and (Length(Pages) = 0) then HelpBuild;
  FOn := AOn;
  if FOn then Cur := 0;
end;

procedure HelpToggle;
begin
  HelpShow(not FOn);
end;

function HelpOn: Boolean;
begin
  Result := FOn;
end;

function DrawWrapped(C: TCanvas; const S: string; X, Y, MaxW: Integer;
  Clr: TColor): Integer;
var P0, Px: Integer; Wd, Ln: string;

  procedure FlushLn;
  begin
    if Ln <> '' then begin
      C.Font.Color := Clr;
      C.TextOut(X, Y, Ln);
      Inc(Y, 14);
      Ln := '';
    end;
  end;

begin
  C.Brush.Style := bsClear;
  Ln := '';  P0 := 1;
  while P0 <= Length(S) do begin
    Px := P0;
    while (Px <= Length(S)) and (S[Px] <> ' ') do Inc(Px);
    Wd := Copy(S, P0, Px - P0);
    if Ln = '' then Ln := Wd
    else if C.TextWidth(Ln + ' ' + Wd) <= MaxW then Ln := Ln + ' ' + Wd
    else begin FlushLn; Ln := Wd; end;
    P0 := Px + 1;
  end;
  FlushLn;
  Result := Y;
end;

{--- rendu ------------------------------------------------------------------}

procedure HelpRender(C: TCanvas; W, H: Integer);
const MARG = 24;
var PW, PH, X0, Y0, Y, I, BX, BW: Integer;

  procedure BtnBox(R: TRect; const Cap: string; Id: Integer; Hot: Boolean);
  begin
    SetLength(HBtns, Length(HBtns) + 1);
    HBtns[High(HBtns)].R := R;
    HBtns[High(HBtns)].Id := Id;
    C.Brush.Style := bsSolid;
    if Hot then C.Brush.Color := Col(30, 36, 26)
           else C.Brush.Color := Col(22, 27, 19);
    C.Pen.Style := psSolid; C.Pen.Width := 1; C.Pen.Color := Col(48, 54, 42);
    C.Rectangle(R);
    C.Brush.Style := bsClear;
    if Hot then C.Font.Color := Col(230, 224, 205)
           else C.Font.Color := Col(170, 168, 148);
    C.TextOut(R.Left + 8, (R.Top + R.Bottom - C.TextHeight(Cap)) div 2, Cap);
  end;

begin
  if not FOn then Exit;
  if Length(Pages) = 0 then HelpBuild;
  HBtns := nil;
  PW := Min(720, W - 36);  PH := Min(560, H - 36);
  X0 := (W - PW) div 2;  Y0 := (H - PH) div 2;

  C.Font.Name := 'Segoe UI'; C.Font.Size := 9; C.Font.Style := [];

  // ombre + panneau
  C.Brush.Style := bsSolid;  C.Pen.Style := psClear;
  C.Brush.Color := Col(6, 8, 6);
  C.FillRect(Rect(X0 + 5, Y0 + 6, X0 + PW + 5, Y0 + PH + 6));
  C.Brush.Color := Col(19, 23, 16);
  C.FillRect(Rect(X0, Y0, X0 + PW, Y0 + PH));
  C.Pen.Style := psSolid;  C.Pen.Color := Col(54, 60, 46);  C.Pen.Width := 1;
  C.Brush.Style := bsClear;
  C.Rectangle(X0, Y0, X0 + PW, Y0 + PH);

  // bandeau
  C.Brush.Style := bsSolid;  C.Pen.Style := psClear;
  C.Brush.Color := Col(25, 30, 21);
  C.FillRect(Rect(X0 + 1, Y0 + 1, X0 + PW - 1, Y0 + 36));
  C.Font.Name := 'Georgia';  C.Font.Size := 13;  C.Font.Style := [fsBold, fsItalic];
  C.Brush.Style := bsClear;
  C.Font.Color := Col(232, 226, 206);
  C.TextOut(X0 + 16, Y0 + 8, Pages[Cur].Title);
  C.Font.Name := 'Segoe UI';  C.Font.Size := 8;  C.Font.Style := [];
  C.Font.Color := Col(120, 126, 106);
  C.TextOut(X0 + PW - 90, Y0 + 12, Format('%d / %d', [Cur + 1, Length(Pages)]));

  // contenu
  Y := Y0 + 48;
  C.Font.Name := 'Segoe UI';  C.Font.Size := 9;  C.Font.Style := [];
  for I := 0 to High(Pages[Cur].L) do begin
    with Pages[Cur].L[I] do begin
      case K of
        1: begin
             Inc(Y, 5);
             C.Font.Style := [fsBold];
             Y := DrawWrapped(C, Txt, X0 + MARG, Y, PW - 2*MARG, Col(208, 167, 92));
             C.Font.Style := [];
             Inc(Y, 2);
           end;
        2: begin
             C.Font.Style := [fsItalic];
             Y := DrawWrapped(C, '◆ ' + Txt, X0 + MARG, Y, PW - 2*MARG, Col(240, 180, 95));
             C.Font.Style := [];
           end;
        6: begin
             BtnBox(Rect(X0 + MARG, Y, X0 + PW - MARG, Y + 24), '▸ ' + Txt, Act, True);
             Inc(Y, 28);
           end;
      else begin
             case K of
               3: Y := DrawWrapped(C, Txt, X0 + MARG, Y, PW - 2*MARG, Col(157, 187, 107));
               4: Y := DrawWrapped(C, Txt, X0 + MARG, Y, PW - 2*MARG, Col(206, 116, 79));
               5: Y := DrawWrapped(C, Txt, X0 + MARG, Y, PW - 2*MARG, Col(139, 138, 116));
             else
               Y := DrawWrapped(C, Txt, X0 + MARG, Y, PW - 2*MARG, Col(222, 216, 196));
             end;
             Inc(Y, 2);
           end;
      end;
    end;
    if Y > Y0 + PH - 92 then begin
      C.Font.Color := Col(120, 126, 106);
      C.Brush.Style := bsClear;
      C.TextOut(X0 + MARG, Y, '…');
      Break;
    end;
  end;

  // boutons démo
  if (Length(Pages[Cur].D) > 0) and Assigned(HelpDemoProc) then begin
    Y := Y0 + PH - 86;
    BX := X0 + MARG;
    for I := 0 to High(Pages[Cur].D) do begin
      BW := C.TextWidth(Pages[Cur].D[I].Cap) + 20;
      if BX + BW > X0 + PW - MARG then begin BX := X0 + MARG; Inc(Y, 28) end;
      BtnBox(Rect(BX, Y, BX + BW, Y + 24),
             'essayer : ' + Pages[Cur].D[I].Cap, 1000 + Pages[Cur].D[I].Act, True);
      BX := BX + BW + 8;
    end;
  end;

  // navigation
  Y := Y0 + PH - 46;
  C.Pen.Style := psSolid;  C.Pen.Color := Col(48, 54, 42);  C.Pen.Width := 1;
  C.MoveTo(X0 + MARG, Y - 8);  C.LineTo(X0 + PW - MARG, Y - 8);
  BtnBox(Rect(X0 + MARG, Y, X0 + MARG + 34, Y + 26), '◀', -1, True);
  BtnBox(Rect(X0 + MARG + 40, Y, X0 + MARG + 74, Y + 26), '▶', -2, True);
  BtnBox(Rect(X0 + PW - MARG - 156, Y, X0 + PW - MARG - 76, Y + 26), 'sommaire', -3, True);
  BtnBox(Rect(X0 + PW - MARG - 70, Y, X0 + PW - MARG, Y + 26), 'fermer', -4, True);
end;

{--- interactions ------------------------------------------------------------}

function HelpMouseDown(X, Y: Integer): Boolean;
var I: Integer;
begin
  Result := False;
  if not FOn then Exit;
  Result := True;                     // l'aide ouverte consomme le clic
  for I := High(HBtns) downto 0 do
    if PtInRect(HBtns[I].R, Point(X, Y)) then begin
      case HBtns[I].Id of
        -1: if Cur > 0 then Dec(Cur);
        -2: if Cur < High(Pages) then Inc(Cur);
        -3: Cur := 0;
        -4: FOn := False;
      else
        if (HBtns[I].Id >= 0) and (HBtns[I].Id < 1000) then Cur := HBtns[I].Id
        else if Assigned(HelpDemoProc) then
          HelpDemoProc(HBtns[I].Id - 1000);
      end;
      Exit;
    end;
end;

procedure HelpWheel(Delta: Integer);
begin
  if not FOn then Exit;
  if Delta < 0 then begin if Cur < High(Pages) then Inc(Cur) end
  else begin if Cur > 0 then Dec(Cur) end;
end;

procedure HelpKeyDown(Key: Word);
begin
  if not FOn then Exit;
  case Key of
    VK_ESCAPE: FOn := False;
    VK_NEXT, VK_DOWN, VK_RIGHT: if Cur < High(Pages) then Inc(Cur);
    VK_PRIOR, VK_UP, VK_LEFT:   if Cur > 0 then Dec(Cur);
    VK_HOME: Cur := 0;
    VK_END:  Cur := High(Pages);
  end;
end;

end.

unit MicroHelp;

{ Microcosme — mode d'emploi intégré (F1), bilingue FR/EN (vague 4 i18n).
  Overlay par-dessus le monde : sommaire cliquable, pages courtes,
  boutons « démo » qui agissent sur la vraie simulation.
  Deux HelpBuild (FR/EN) construisent les 21 pages DANS LE MÊME ORDRE :
  les indices des liens (K=6, nPage) restent valides dans les deux langues.
  La langue est lue au moment de la construction ; F8 rebâtit à chaud.
  ▼ Pour modifier/ajouter des pages : HelpBuildFR et HelpBuildEN (plus bas) —
    AJOUTER UNE PAGE = l'ajouter EN DERNIER dans les DEUX procédures. }

interface

uses
  System.SysUtils, System.Math, System.Types, System.Classes,
  Winapi.Windows, Vcl.Graphics;

const
  BID_HELP = 207;

procedure HelpToggle;
procedure HelpShow(AOn: Boolean);
function  HelpOn: Boolean;
procedure HelpRender(C: TCanvas; W, H: Integer);
function  HelpMouseDown(X, Y: Integer): Boolean;
procedure HelpWheel(Delta: Integer);
procedure HelpKeyDown(Key: Word);
function HelpBtnCount: Integer;

type
  THelpDemoProc = procedure(Act: Integer) of object;
var
  HelpDemoProc: THelpDemoProc = nil;

implementation

uses MicroBrain, MicroLang;   // Col, ClampF · FLangue/LANG_*

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
  FLangueBuild: Integer = -1;    // langue avec laquelle les pages ont été bâties
  crl: Integer = 0;             // ★ défilement de la page courante (pixels)
  LastCur: Integer = -1;         // ★ détection de changement de page (reset du scroll)
  CurMaxScrl: Integer = 0;       // ★ débordement mesuré au dernier rendu (pour la molette)
  Scrl : Integer =0;

{--- constructeurs de pages --------------------------------------------------}

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
  LE CONTENU — HelpBuildFR et HelpBuildEN : MÊME ORDRE, MÊME NOMBRE DE PAGES.
============================================================================}

 procedure HelpBuildFR;
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
  LT('Les bêtes : vaches, moutons, loups, ours', 6, 5);
  LT('Les sapiens : corps et esprit', 6, 6);
  LT('La culture et son héritage', 6, 7);
  LT('Villes, campagnes et routes', 6, 21);
  LT('Les ères de l''humanité', 6, 19);
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
  LT('· les villes : dix huttes deviennent un bourg nommé, le bourg gagne ses');
  LT('  remparts, la cité son monument — et la campagne se vide peu à peu ;');
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
  LT('vache — relâcher une vache', 1);
  LT('Préférez les abords de forêt : elles s''y cachent des loups et des ours.');
  LT('');
  LT('loup — relâcher un loup', 1);
  LT('Le grand régulateur. Sans lui : surpâturage puis famine générale.');
  LT('Avec trop de lui : plus de bétail, et les sapiens à leur tour chassés.', 4);
  LT('Les sapiens près d''un feu ou d''un chien le repoussent.', 3);
  LT('Les moutons et les ours ne se relâchent pas : ils viennent au monde');
  LT('d''eux-mêmes — moutons en troupeaux, ours très rares.', 5);
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
  P('Les bêtes : vaches, moutons, loups, ours');
  LT('Les vaches', 1);
  LT('Elles broutent, fuient à la vue d''un loup OU d''un ours, se figent dans');
  LT('la forêt si celle-ci est assez loin du danger (état « caché »).');
  LT('Domestiquées (anneau doré) : elles paissent autour de leur hutte,');
  LT('et les sapiens les traient — seules les vaches donnent du lait');
  LT('(le petit pictogramme blanc = lait disponible).');
  LT('Elles redeviennent sauvages si on les abandonne trop loin du camp.');
  LT('');
  LT('Les moutons', 1);
  LT('Petits, à la toison claire, ils vivent en troupeaux. Plus dociles que');
  LT('les vaches — la confiance vient deux fois plus vite — et prolifiques :');
  LT('un troupeau bien nourri grossit vite. Mais maigres : pas de lait,');
  LT('peu de viande. La proie de prédilection des loups.', 2);
  LT('');
  LT('Les loups', 1);
  LT('Ils traquent la proie la plus proche VISIBLE — vaches, moutons, et les');
  LT('sapiens aussi — sauf près d''un feu, d''un chien, ou si la fumée');
  LT('(invention) brouille leur flair. La forêt réduit leur vue.');
  LT('Yeux rouges quand la chasse est lancée.', 2);
  LT('Un jeune loup peut être apprivoisé près du feu : il devient chien.', 3);
  LT('');
  LT('Les ours', 1);
  LT('Bruns, massifs, rares — on en compte une poignée sur toute l''île.');
  LT('Omnivores : ils broutent volontiers, mais un troupeau à portée est');
  LT('irrésistible — vaches comme moutons, domestiqués compris.', 4);
  LT('Ils ne touchent JAMAIS les sapiens ni les chiens.');
  LT('Indomptables : aucun anneau doré pour eux, jamais.', 4);
  LT('');
  LT('Le berger', 1);
  LT('Un sapiens qui connaît le pastoralisme défend son bétail : le loup ou');
  LT('l''ours qui s''attaque à une bête domestiquée est abattu — et mangé.', 3);
  LT('');
  LT('Poissons', 1);
  LT('Les clairs vivent sur les hauts-fonds ; les sombres, plus gros, au large.');
  LT('Les populations se reconstituent seules si on pêche raisonnablement —');
  LT('un vrai stock. Trop pêcher le vide pour des saisons.', 4);
  LT('');
  LT('Le chien', 1);
  LT('Un jeune loup apprivoisé près d''un feu (technologie feu requise).');
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
  LT('Les ères apportent d''autres inventions de plus — voir la page des');
  LT('technologies des ères.', 6, 20);

  // ============================================================ 10. SONS
  P('Les sons du monde');
  LT('Tout est synthétisé en direct — aucun fichier son.');
  LT('');
  LT('Les voix', 1);
  LT('Chaque cri α β γ δ a sa sonorité (voyelles différentes), chaque sapiens');
  LT('sa hauteur de voix, chaque mot sa petite mélodie pentatonique —');
  LT('le même mot retentit toujours pareil : on apprend à le reconnaître.');
  LT('Un porteur de tambour « parle » en frappant sa peau tendue.');
  LT('Au passage d''ère, une fanfare : la lyre au bronze, les cloches au fer.');
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
  LT('· badge d''ère : où en est le peuple, avec sa progression ;');
  LT('· populations : flore, vaches, loups, sapiens, poissons, moutons, ours ;');
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
  LT('Relâchez 6 loups. Regardez la courbe « vitesse » des vaches :');
  LT('en quelques générations, les survivantes sont plus rapides.', 3);
  LT('');
  LT('Expérience 2 — la culture sans école', 1);
  LT('Isolez 2 sapiens à l''est, 6 à l''ouest. Qui découvre le feu le premier ?');
  LT('Le groupe le plus dense — la densité fait les savants.', 3);
  LT('');
  LT('Expérience 3 — l''effondrement', 1);
  LT('Supprimez tout loup et nourrissez à foison. La population');
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
  LT('Expérience 6 — la naissance d''une ville', 1);
  LT('Laissez le peuple bâtir. Quand dix huttes s''assemblent, un bourg');
  LT('prend un nom. Regardez-le gagner ses remparts, puis son monument.', 3);
  LT('');
  LT('Expérience 7 — l''exode', 1);
  LT('Passez à l''ère du bronze et comptez les huttes isolées : familles');
  LT('après familles, la campagne se vide dans les villes.', 3);
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
  LT('F5', 1);
  LT('monde plein écran, sans bordure (F5 à nouveau : revenir).');
  LT('');
  LT('F6', 1);
  LT('revenir à la fenêtre normale, depuis n''importe quel mode.');
  LT('');
  LT('F7', 1);
  LT('l''Observatoire : le réseau neuronal du spécimen en géant, la fiche');
  LT('à gauche, technologies et annales à droite. Clic = sapiens suivant.');
  LT('');
  LT('F8', 1);
  LT('français / english : bascule toute l''interface — et ce manuel.');
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
  LT('Apprivoiser les vaches et moutons sauvages (jauge de confiance invisible),');
  LT('les parquer près d''une hutte, traire les vaches. Les moutons se laissent');
  LT('faire deux fois plus vite ; le chien vient avec le feu.');
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
  LT('« Cerveau » dans le carnet — ou appuyez F7 : l''Observatoire.');
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
  LT('Pourquoi les loups disparaissent ?', 1);
  LT('S''il n''y a plus de proies à portée, ils meurent. Le système se');
  LT('régule : relâchez-en peu, et laissez le bétail revenir.', 2);
  LT('');
  LT('Un ours dévore mon troupeau !', 1);
  LT('C''est sa nature : il ne touche jamais les sapiens, mais le bétail');
  LT('l''attire. Un berger l''abattra — ou éloignez les parcs des forêts.', 3);
  LT('');
  LT('Tant de huttes isolées, et rien ne bouge ?', 1);
  LT('Dès l''ère du bronze, l''exode les emmène vers les villes — les trop');
  LT('lointaines restent des hameaux de frontière. Voir la page villes.', 6, 21);
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
  LT('de vue montent si les loups pressent, la culture grimpe en');
  LT('dents de scie (une invention perdue, réapprise au camp), les mots');
  LT('apparaissent et disparaissent. L''histoire s''écrit toute seule.', 2);

  // ============================================================ 19. ÈRES
  P('Les ères de l''humanité');
  LT('Six âges, du premier feu aux façades peintes', 1);
  LT('· ère 1 — Néolithique : feu, agriculture, réserves, pastoralisme,');
  LT('  pêche, navigation, écriture. Le monde des débuts ;');
  LT('· ère 2 — Âge du bronze : la terre se laboure, le métal mord,');
  LT('  la voile se dresse, les idées s''échangent de main en main ;');
  LT('· ère 3 — Âge du fer : l''outillage parfait, l''eau conduite, la');
  LT('  philosophie — un savoir qui ne meurt plus ;');
  LT('· ère 4 — Antiquité : la cité, la géométrie, les lois, la colonne');
  LT('  de marbre sur la place du feu — et les premières routes ;');
  LT('· ère 5 — Moyen Âge : moulins, universités, corporations, le donjon ;');
  LT('· ère 6 — Renaissance : l''imprimerie multiplie les mots, les façades');
  LT('  se peignent, la méthode observe et recommence.');
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
  LT('  nourrit la suivante (l''effet bibliothèque) — puis Science,');
  LT('  Mathématiques, Universités et Méthode l''amplifient encore ;');
  LT('· le peuple peut croître : le plafond des sapiens monte à chaque ère ;');
  LT('· le village se transforme : huttes rondes → maisons de pierre →');
  LT('  façades peintes ; la maison au feu porte le monument de son âge ;');
  LT('· la campagne se vide : l''exode vers les villes s''emballe ère après');
  LT('  ère, et dès l''Antiquité les villes se relient de routes.');
  LT('Chaque passage est consigné dans les annales.', 2);

  // ============================================================ 20. TECHS DES ÈRES
  P('Les technologies des ères suivantes');
  LT('Âge du bronze', 1);
  LT('· charrue — la récolte rapporte moitié plus ;');
  LT('· roue — chacun marche un tiers plus vite ;');
  LT('· irrigation — la terre porte un tiers de végétation de plus ;');
  LT('· métallurgie — la chasse rapporte bien plus à chaque frappe ;');
  LT('· voile — en mer, la pirogue va aussi vite qu''on marche à terre ;');
  LT('· monnaie — la diffusion entre voisins s''emballe ;');
  LT('· archives — la mémoire du peuple se lit partout sur l''île ;');
  LT('· science — chaque découverte rend les suivantes plus probables.');
  LT('');
  LT('Âge du fer', 1);
  LT('· fer — le métal parfait encore la chasse ;');
  LT('· aqueduc — la terre nourrit encore davantage ;');
  LT('· ingénierie — les réserves des huttes gagnent la moitié ;');
  LT('· philosophie — le savoir ne se perd JAMAIS plus ;');
  LT('· médecine — la vieillesse recule d''un cinquième ;');
  LT('· mathématiques — les découvertes s''accélèrent encore ;');
  LT('· astronomie — les hivers perdent un tiers de leur mordant ;');
  LT('· école — le mentorat transmet moitié plus de savoir.');
  LT('');
  LT('Antiquité', 1);
  LT('· cité — deux fois plus de huttes peuvent s''assembler ;');
  LT('· géométrie — bâtir coûte moins d''efforts ;');
  LT('· législation — la diffusion gagne un quart ;');
  LT('· rhétorique — le mentorat transmet un cinquième de plus ;');
  LT('· galères — la mer devient plus vite que la marche ;');
  LT('· agronomie — la récolte gagne encore un quart ;');
  LT('· hygiène — la vieillesse recule d''un dixième ;');
  LT('· cartographie — l''exploration ne divage plus.');
  LT('');
  LT('Moyen Âge', 1);
  LT('· moulins et assolement — la terre porte un tiers de plus ;');
  LT('· ferrure — des pas sûrs, un dixième plus vifs ;');
  LT('· universités — les découvertes gagnent un cinquième ;');
  LT('· corporations — les inventions arrivent moitié plus vite ;');
  LT('· élevage sélectif — l''apprivoisement va moitié plus vite ;');
  LT('· médecine arabe — la vieillesse recule encore d''un dixième ;');
  LT('· navigation hauturière — la mer, un dixième de plus encore.');
  LT('');
  LT('Renaissance', 1);
  LT('· imprimerie — la diffusion s''emballe (×1.6) ;');
  LT('· optique — le regard porte un cinquième plus loin ;');
  LT('· anatomie — le corps tient un vingtième d''énergie de plus ;');
  LT('· caravelles — la mer est maîtrisée (×2.2) ;');
  LT('· poudre — la chasse gagne encore un tiers ;');
  LT('· banque — les idées circulent encore plus ;');
  LT('· méthode — les découvertes gagnent un tiers ;');
  LT('· humanités — le mentorat gagne un quart.');
  LT('');
  LT('Les inventions des nouveaux âges', 1);
  LT('· bougie, charrette, four (bronze) — la nuit allégée, les réserves');
  LT('  remplies moitié plus vite, le repas plus nourrissant ;');
  LT('· horloge, boussole, théâtre (fer) — la marche affine, l''errance');
  LT('  divisée par deux, la diffusion enflammée par le public ;');
  LT('· amphore, serpe, fosse (Antiquité) — greniers plus vastes, récolte');
  LT('  affinée, loups tenus à distance ;');
  LT('· arbalète, parchemin, armure (Moyen Âge) — chasse au loin, idées');
  LT('  qui circulent, crocs qui glissent ;');
  LT('· lunette, violon, carte marine (Renaissance) — voir dans le noir,');
  LT('  la musique qui apaise, l''exploration guidée.', 2);

  // ============================================================ 21. VILLES (nouveau)
  P('Villes, campagnes et routes');
  LT('La naissance d''un bourg', 1);
  LT('Quand dix huttes isolées s''assemblent à peu de distance, elles');
  LT('deviennent un bourg : il reçoit un nom — syllabes de nulle part,');
  LT('une langue à lui — et les huttes se replacent en spirale autour');
  LT('du feu de la ville.');
  LT('');
  LT('Les niveaux', 1);
  LT('· 10 foyers : le bourg ;');
  LT('· 18 foyers : la ville — les remparts montent, percés de quatre portes ;');
  LT('· 28 foyers : la cité — et son monument face au feu.');
  LT('Le nom s''affiche au zoom ; à la Renaissance, les façades se peignent.', 2);
  LT('');
  LT('L''espace du sauvage', 1);
  LT('On ne bâtit pas entre 8 et 50 cases d''une ville : ce cordon, c''est');
  LT('la chasse, la forêt, le gibier. Mais près des murailles (moins de');
  LT('20 cases), dès le bronze, la maison qui naît est CITADINE — c''est');
  LT('la banlieue, et la ville grossit par sa périphérie.', 3);
  LT('');
  LT('La clairière', 1);
  LT('La ville défriche : ni arbre ni buisson dans son enceinte.');
  LT('L''empreinte écologique des cités se lit à la carte.', 2);
  LT('');
  LT('L''exode', 1);
  LT('Dès l''ère 2 — et de plus en plus à chaque ère — les familles isolées');
  LT('quittent les bois pour la ville la plus proche (dans un rayon');
  LT('raisonnable ; les trop lointaines restent des hameaux).');
  LT('Le jour où plus d''un foyer sur deux est urbain, les annales écrivent :');
  LT('« le peuple devient citadin ».', 2);
  LT('');
  LT('Les routes', 1);
  LT('À l''Antiquité, les villes proches (moins de 200 cases) se relient.');
  LT('Les routes poussent d''elles-mêmes, trois cases par jour, contournant');
  LT('l''eau. Sur la route, on marche moitié plus vite — et les idées y');
  LT('circulent mieux.', 3);
  LT('Un anneau de routes reliant plusieurs villes : le signe d''un monde', 2);
  LT('qui se tient.', 2);
end;
  procedure HelpBuildEN;
begin
  SetLength(Pages, 0);

  // ============================================================ 0. SOMMAIRE
  P('Table of contents');
  LT('click a chapter · F1 opens/closes · Échap closes · arrows and wheel turn', 5);
  LT('Understanding the game', 1);
  LT('The spirit of the game', 6, 1);
  LT('Getting started', 6, 2);
  LT('Keyboard shortcuts', 6, 13);
  LT('Life', 1);
  LT('The world: relief, seasons, ocean', 6, 4);
  LT('The beasts: cows, sheep, wolves, bears', 6, 5);
  LT('The sapiens: body and mind', 6, 6);
  LT('Culture and its inheritance', 6, 7);
  LT('Cities, countryside and roads', 6, 21);
  LT('The eras of humankind', 6, 19);
  LT('Era 2 and 3 technologies', 6, 20);
  LT('Technologies, one by one', 6, 14);
  LT('Minor inventions', 6, 9);
  LT('Language and calls', 6, 8);
  LT('The neural network', 1);
  LT('Anatomy of the neural network', 6, 17);
  LT('How it learns', 6, 18);
  LT('Observing', 1);
  LT('The observation notebook', 6, 11);
  LT('Reading a sapien''s brain', 6, 15);
  LT('The sounds of the world', 6, 10);
  LT('Playing and experimenting', 1);
  LT('The tools', 6, 3);
  LT('Experiments and challenges', 6, 12);
  LT('Frequently asked questions', 6, 16);
  LT('the "try" pages act on the real simulation.', 2);

  // ============================================================ 1. ESPRIT
  P('The spirit of the game');
  LT('Microcosme is a box of life. You win nothing, you lose nothing:');
  LT('you install a world, water it with a little chance, and watch.');
  LT('');
  LT('What grows by itself', 1);
  LT('· natural selection: the faster or sharper ones escape the wolves,');
  LT('  breed, pass on their traits — speed, sight,');
  LT('  size, feather;');
  LT('· culture: a newborn knows almost nothing, but picks a mentor');
  LT('  and its mind glides toward theirs. Knowledge is a living heritage;');
  LT('· language: sapiens emit calls (α β γ δ) whose meaning');
  LT('  is fixed by no one. The notebook''s lexicon guesses: alarm? food?');
  LT('· cities: ten huts become a named town, the town raises walls,');
  LT('  the city its monument — and the countryside slowly empties;');
  LT('· inventions: a skewer, a drum, a net are born of circumstances —');
  LT('  a fire, a night, a river — not of a plan.');
  LT('');
  LT('Your role', 1);
  LT('God does nothing here, or almost: you sow, you release, you watch.');
  LT('the best action is often none. Come back tomorrow, read the annals.', 2);
  LT('Let it run one night at 4x: by morning, generations have passed.', 3);

  // ============================================================ 2. PRISE EN MAIN
  P('Getting started');
  LT('The screen', 1);
  LT('· on the right: the notebook — populations, technologies, lexicon,');
  LT('  annals, commands;');
  LT('· in the middle: the world. Hold right-click = pan the view;');
  LT('· wheel = zoom on a precise point (from ×1 to ×6).');
  LT('');
  LT('Time', 1);
  LT('II / > : pause and play · 1x 2x 4x: time speed.');
  LT('Space: quick pause. A day lasts ~2 minutes at 1x.');
  LT('The golden bar atop the notebook shows the time of day.');
  LT('4x to see generations, 1x to attend a birth.', 2);
  LT('');
  LT('The recommended first gesture', 1);
  LT('1. press "Observe the world";');
  LT('2. zoom on the camp in the middle (wheel);');
  LT('3. select a sapien with the "view" tool — its sheet opens;');
  LT('4. click "brain" in the notebook: the network, live.');
  DB('pause / play', 3);
  DB('show me a sapien', 0);

  // ============================================================ 3. OUTILS
  P('The tools');
  LT('Five tools, at the bottom of the notebook:');
  LT('');
  LT('view', 1);
  LT('Click a creature: it becomes the specimen. Its sheet (F3) shows');
  LT('traits, energy, technologies, what it hears, and its neural network.');
  LT('The big grey circle around it = its perception range.');
  LT('');
  LT('seed', 1);
  LT('Click or drag: plants grow. Useful to save a species,');
  LT('or build a natural granary and watch the birth rate.');
  DB('sow 12 plants here', 1);
  LT('');
  LT('cow — release a cow', 1);
  LT('Prefer forest edges: they hide from wolves and bears there.');
  LT('');
  LT('wolf — release a wolf', 1);
  LT('The great regulator. Without it: overgrazing then general famine.');
  LT('With too many: no more livestock — and sapiens hunted in turn.', 4);
  LT('Sapiens near a fire or a dog repel it.', 3);
  LT('Sheep and bears cannot be released: they come into the world');
  LT('by themselves — sheep in flocks, bears very rare.', 5);
  LT('');
  LT('sap — wake a sapien', 1);
  LT('It is born adult, knowing nothing, joins the camp, seeks a mentor.');
  LT('Place 2-3 near a group: culture will spread better.');
  DB('wake a sapien here', 2);

  // ============================================================ 4. LE MONDE
  P('The world: relief, seasons, ocean');
  LT('Relief', 1);
  LT('The island is generated by fractal noise: carved coasts, plain, forests');
  LT('(where one hides and builds), rocks, high-altitude snow.');
  LT('The "relief" button in the notebook deepens terrain shading.');
  LT('Three volcanic islets surround the island — their waters are full of fish.');
  LT('');
  LT('Seasons', 1);
  LT('One year = 24 days, four seasons of 6 days:');
  LT('· spring: flora returns;');
  LT('· summer: everything grows (flora ×1.0) — the season of births;');
  LT('· autumn: growth slows;');
  LT('· winter: flora ×0.25, bluish tint — famine stalks the weak.', 4);
  LT('Watch the notebook curves: populations breathe with the seasons.', 2);
  LT('');
  LT('The ocean', 1);
  LT('It is deadly to swim — a sapien venturing in tires fast.');
  LT('With fishing then navigation (canoe), it becomes a pantry.');
  LT('Light fish swim near the coast; dark ones, offshore,');
  LT('are reachable only by sailors with the net.');

  // ============================================================ 5. LES BÊTES
  P('The beasts: cows, sheep, wolves, bears');
  LT('Cows', 1);
  LT('They graze, flee at the sight of a wolf OR a bear, freeze in the');
  LT('forest if it is far enough from danger ("hidden" state).');
  LT('Domesticated (golden ring): they graze around their hut,');
  LT('and sapiens milk them — only cows give milk');
  LT('(the small white mark = milk available).');
  LT('They turn feral again if abandoned too far from camp.');
  LT('');
  LT('Sheep', 1);
  LT('Small, light-fleeced, they live in flocks. Tamer than cows — trust');
  LT('comes twice as fast — and prolific: a well-fed flock grows fast.');
  LT('But lean: no milk, little meat. The wolves'' favourite prey.', 2);
  LT('');
  LT('Wolves', 1);
  LT('They stalk the nearest VISIBLE prey — cows, sheep, and sapiens');
  LT('too — except near a fire, a dog, or if smoke (an invention) blurs');
  LT('their scent. The forest shortens their sight.');
  LT('Red eyes when the hunt is on.', 2);
  LT('A young wolf can be tamed near a fire: it becomes a dog.', 3);
  LT('');
  LT('Bears', 1);
  LT('Brown, massive, rare — a handful live on the whole island.');
  LT('Omnivores: they gladly graze, but a herd in reach is');
  LT('irresistible — cows and sheep alike, domesticated included.', 4);
  LT('They NEVER touch sapiens or dogs.');
  LT('Untameable: no golden ring for them, ever.', 4);
  LT('');
  LT('The herdsman', 1);
  LT('A sapien who knows pastoralism defends his livestock: the wolf or');
  LT('bear attacking a domesticated beast is slain — and eaten.', 3);
  LT('');
  LT('Fish', 1);
  LT('Light ones live on the shallows; dark, bigger ones, offshore.');
  LT('Populations rebuild alone if you fish reasonably —');
  LT('a true stock. Overfish it and it empties for seasons.', 4);
  LT('');
  LT('The dog', 1);
  LT('A young wolf tamed near a fire (fire technology required).');
  LT('It follows its master, feeds him with its nose (sight ×1.8), repels wolves.');
  LT('The golden line from dog to sapien = the master''s bond.');

  // ============================================================ 6. LES SAPIENS
  P('The sapiens: body and mind');
  LT('The body', 1);
  LT('· energy: harvest, hunt, fishing, milk, hut stores at night;');
  LT('· walking costs; swimming costs a lot; talking a little; thinking much;');
  LT('· below zero: starvation. Beyond max age: old age.');
  LT('· at night near a fire: recovery — a skewer makes it better.');
  LT('');
  LT('The mind', 1);
  LT('A network of 34 inputs → 9 → 9 → 10 outputs, inherited and mutable:');
  LT('· inputs: needs, directions (food, peer, predator), the 4 calls');
  LT('  heard, memory of dangers and food spots,');
  LT('  echoes of its own previous outputs (recurrences);');
  LT('· outputs: turn, advance, build, breed, hunt,');
  LT('  call α β γ δ, rest.');
  LT('No one programs anything: mutation and mentorship shape it all.', 3);
  LT('');
  LT('Memory', 1);
  LT('Every danger seen is noted (red cross on the mental map), every');
  LT('good harvest too (green circle). They fade in ~70 seconds.');
  LT('Select a sapien to SEE its mental map on the ground.');

  // ============================================================ 7. CULTURE
  P('Culture and its inheritance');
  LT('Knowledge, a gauge from 0 to 95 %', 1);
  LT('It rises slowly with age, faster near a mentor,');
  LT('clearly faster still near a hut (fire, the camp''s school).');
  LT('');
  LT('Mentorship', 1);
  LT('The child picks the wisest of neighbors. Its network glides toward');
  LT('the mentor''s — but never beyond 30 % of the genetic distance:');
  LT('DNA is never overwritten, only guided.');
  LT('The dashed golden line = a child following its mentor.');
  LT('');
  LT('Diffusion', 1);
  LT('Nearby adults imitate each other: what a neighbor knows, the other learns.');
  LT('At camp (or near a hut), the "people''s memory" gives back everything');
  LT('ever invented — a living library, tunable in "settings".');
  LT('');
  LT('Loss', 1);
  LT('Knowledge without a carrier dies ("LOST" in the notebook).');
  LT('An epidemic, a war, a migration… and centuries fade away.', 4);
  LT('Check the Technologies column: bars are % of carriers.', 2);

  // ============================================================ 8. LANGAGE
  P('Language and calls');
  LT('The calls', 1);
  LT('Four brain outputs: α β γ δ. When one wins, the sapien');
  LT('calls — the colored bubble shows above it, and the word SOUNDS');
  LT('(each sound is synthesized live, each word has its signature).');
  LT('');
  LT('Meaning is not programmed', 1);
  LT('The notebook counts, for each word, the context of emission:');
  LT('· emitted mostly with a predator in sight → "alarm call?";');
  LT('· emitted near food → "food?";');
  LT('· emitted for nothing special → "social signal?".');
  LT('These are READING HYPOTHESES, not true labels.', 2);
  LT('');
  LT('Contagion', 1);
  LT('Hearing a word shapes the listener''s lexicon: words spread');
  LT('from mouth to mouth, with variations at each tongue.');
  LT('With the drum (invention), a call carries twice as far —');
  LT('and is played on a stretched skin rather than a throat.', 3);
  LT('');
  LT('Reading it in the brain', 1);
  LT('The α..δ inputs light up when it HEARS; outputs when it SPEAKS.');
  LT('Watch a conversation: an input→output loop across two neighbors.', 2);

  // ============================================================ 9. INVENTIONS
  P('Minor inventions');
  LT('They are born of circumstances — never of a plan:');
  LT('');
  LT('before fire', 1);
  LT('· basket — born in the forest: harvest +50 %;');
  LT('· ornament — born of shared aesthetics (feather > 55 %): charm +25 %;');
  LT('· drum — born by the water with a memory of danger: calls carry 2×.');
  LT('');
  LT('with fire', 1);
  LT('· skewer — at night, hungry, near fire: rest ×1.6 more nourishing;');
  LT('· net — fisher in the water: fast catches, +60 %;');
  LT('· leatherwork — night + hut: night weighs less;');
  LT('· torch — night + far from camp: flight +25 %;');
  LT('· smoke — predator seen + fire: wolves smell you badly;');
  LT('· trap — forest + game: strike from afar;');
  LT('· lean-to — stores + 3 huts: storage ×2.');
  LT('');
  LT('Their name is a sentence', 1);
  LT('Each invention takes a word from the emergent language and its');
  LT('inventor''s name: "drum β of Grok". They spread like technologies —');
  LT('and are lost as well.', 4);
  LT('They are listed in the notebook, with author and day.', 2);
  LT('The eras bring more inventions — see the era technologies page.', 6, 20);

  // ============================================================ 10. SONS
  P('The sounds of the world');
  LT('Everything is synthesized live — no sound file.');
  LT('');
  LT('Voices', 1);
  LT('Each call α β γ δ has its timbre (different vowels), each sapien');
  LT('its voice pitch, each word its small pentatonic melody —');
  LT('the same word always sounds the same: you learn to recognize it.');
  LT('A drum carrier "speaks" by striking a stretched skin.');
  LT('At each era passage, a fanfare: the lyre in the Bronze Age, bells in Iron.');
  LT('');
  LT('Ambience', 1);
  LT('· day: birds here and there;');
  LT('· night: crickets and a deep drone;');
  LT('· coast: the swell — bring the camera near the shore;');
  LT('· camp at night: the crackle of fire.');
  LT('');
  LT('Commands', 1);
  LT('F4 or the ♪ button: mute / unmute.');
  LT('Too quiet? Set the Windows volume — the engine follows.');

  // ============================================================ 11. CARNET
  P('The observation notebook');
  LT('From top to bottom:');
  LT('');
  LT('· date, time, season, year — and the golden bar of the day;');
  LT('· era badge: where the people stands, with its progress;');
  LT('· populations: flora, cows, wolves, sapiens, fish, sheep, bears;');
  LT('· Fisher spiral: the average feather (the people''s aesthetics);');
  LT('· culture: average knowledge;');
  LT('· sailors: navigators and canoes at sea;');
  LT('· technologies: who knows what, since when, or "LOST";');
  LT('· dynamics: the crossed curves of populations;');
  LT('· evolution: speed, sight, size, feather, culture, mutations —');
  LT('  the AVERAGE traits drifting from generation to generation;');
  LT('· emerging lexicon: the guessed meaning of each word;');
  LT('· people''s inventions: the last 12;');
  LT('· specimen: the sheet of the selected creature, with its brain;');
  LT('· commands, settings, annals, and the mini-map.');
  LT('The notebook scrolls: wheel or click its grey bar on the right.', 2);

  // ============================================================ 12. EXPÉRIENCES
  P('Experiments and challenges');
  LT('This is what Microcosme is truly made for:');
  LT('');
  LT('Experiment 1 — selection live', 1);
  LT('Release 6 wolves. Watch the cows'' "speed" curve:');
  LT('within a few generations, survivors are faster.', 3);
  LT('');
  LT('Experiment 2 — culture without school', 1);
  LT('Isolate 2 sapiens to the east, 6 to the west. Who discovers fire first?');
  LT('The denser group — density makes scholars.', 3);
  LT('');
  LT('Experiment 3 — the collapse', 1);
  LT('Remove every wolf and feed abundantly. The population');
  LT('explodes, the forest recedes, then winter comes…', 4);
  LT('');
  LT('Experiment 4 — the fire chain', 1);
  LT('Note the day fire is discovered. Then "New world":');
  LT('will fire come back on the same day? Never quite.', 3);
  LT('');
  LT('Experiment 5 — the lost word', 1);
  LT('When a word reaches "alarm call?", remove (starvation) every');
  LT('speaker. Does the word survive elsewhere? Does it come back later?', 3);
  LT('');
  LT('Experiment 6 — the birth of a town', 1);
  LT('Let the people build. When ten huts gather, a town takes');
  LT('a name. Watch it win its walls, then its monument.', 3);
  LT('');
  LT('Experiment 7 — the exodus', 1);
  LT('Go to the Bronze Age and count the scattered huts: family');
  LT('after family, the countryside empties into the cities.', 3);
  LT('');
  LT('compare several worlds: that is where the game becomes science.', 2);

  // ============================================================ 13. RACCOURCIS
  P('Keyboard shortcuts');
  LT('F1', 1);
  LT('help: opens / closes this manual. Échap closes too. Arrows: pages.');
  LT('');
  LT('Space', 1);
  LT('pause / play. First press: starts the world.');
  LT('');
  LT('F2', 1);
  LT('settings: opens/closes the world''s pace dials');
  LT('(fire, agriculture, immigration, people''s memory…).');
  LT('');
  LT('F3', 1);
  LT('sheet: opens the detailed window of the selected specimen.');
  LT('');
  LT('F4', 1);
  LT('sound: mutes / restores all audio.');
  LT('');
  LT('F5', 1);
  LT('borderless fullscreen world (F5 again: return).');
  LT('');
  LT('F6', 1);
  LT('return to the normal window, from any mode.');
  LT('');
  LT('F7', 1);
  LT('the Observatory: the specimen''s neural network giant, its sheet');
  LT('on the left, technologies and annals on the right. Click = next sapien.');
  LT('');
  LT('F8', 1);
  LT('français / english: switches the whole interface — and this manual.');
  LT('');
  LT('Mouse', 1);
  LT('· left click: current tool''s action;');
  LT('· right-click hold: pan the view;');
  LT('· wheel: zoom (world) or scroll (notebook).');

  // ============================================================ 14. TECHNOLOGIES
  P('Technologies, one by one');
  LT('fire', 1);
  LT('The first one. Without it, almost nothing else happens. It repels');
  LT('predators, warms the night, allows skewer, torch, smoke, trap…');
  LT('Chance of discovery by a cultivated sapien ("settings" dial).');
  LT('');
  LT('agriculture', 1);
  LT('After fire. While harvesting, the sapien replants: fields grow');
  LT('around the camp (green dotted circle of cultivated huts).');
  LT('');
  LT('stores', 1);
  LT('Harvest surplus goes into the hut (golden ring = stock level).');
  LT('At night or in famine, one draws from it. The lean-to doubles storage.');
  LT('');
  LT('pastoralism', 1);
  LT('Tame wild cows and sheep (an invisible trust gauge), pen them near');
  LT('a hut, milk the cows. Sheep let themselves be taken twice as fast;');
  LT('the dog comes with fire.');
  LT('');
  LT('fishing', 1);
  LT('By the water, the sapien catches coastal fish.');
  LT('The net (invention) speeds it a lot and opens deep fish.');
  LT('');
  LT('navigation', 1);
  LT('The canoe: the ocean is no longer a wall. Sailors go toward');
  LT('the islets — and sometimes never come back.', 4);
  LT('');
  LT('writing', 1);
  LT('The last one. Tablets (small white crosses near huts) appear —');
  LT('and history becomes longer than memories.', 3);

  // ============================================================ 15. LIRE LE CERVEAU
  P('Reading a sapien''s brain');
  LT('Select a sapien ("view" tool), click the big "Brain" chart');
  LT('in the notebook — or press F7: the Observatory.');
  LT('');
  LT('What you see', 1);
  LT('· columns from left to right: 34 inputs, 9 neurons, 9 neurons,');
  LT('  10 outputs;');
  LT('· a green link = excitation, red = inhibition; the livelier it is,');
  LT('  the stronger the signal flows RIGHT NOW;');
  LT('· the dashed lines = the direct path (reflexes bypassing the layers);');
  LT('· labels light up when the signal is active:');
  LT('  "pred.x" when a wolf is seen, "r.β" for the echo of a call heard…');
  LT('');
  LT('What to look for', 1);
  LT('· reflexes: predator → flight (pred.* → turn/speed);');
  LT('· the language loop: α..δ heard → α..δ spoken;');
  LT('· memory: m.dan.* lit = it is "thinking" of a known danger.');
  LT('Compare an old sapien and a child: density speaks.', 3);

  // ============================================================ 16. FAQ
  P('Frequently asked questions');
  LT('Why do my sapiens starve while there are plants?', 1);
  LT('Check the time: at night, nobody harvests — and winter divides');
  LT('flora by 4. Stores and fire exist for that. Patience.', 3);
  LT('');
  LT('Why do the wolves disappear?', 1);
  LT('If there is no prey in reach, they die. The system regulates');
  LT('itself: release few, and let the livestock come back.', 2);
  LT('');
  LT('A bear is devouring my flock!', 1);
  LT('It is its nature: it never touches sapiens, but livestock draws it.');
  LT('A herdsman will slay it — or move the pens away from forests.', 3);
  LT('');
  LT('So many scattered huts, and nothing moves?', 1);
  LT('From the Bronze Age on, the exodus takes them to the cities — the');
  LT('too-distant ones remain frontier hamlets. See the cities page.', 6, 21);
  LT('');
  LT('Fire never comes!', 1);
  LT('It takes adult, cultivated sapiens (knowledge > 20 %), and luck.');
  LT('Speed up time. Or open "settings" (F2) and raise the fire dial.', 2);
  LT('');
  LT('A sapien is all alone in the middle of nowhere', 1);
  LT('It returns to camp by instinct ("explore" + camp attraction).');
  LT('If blocked by water without navigation, it will circle. Sorry.', 5);
  LT('');
  LT('Do words change from one world to another?', 1);
  LT('Yes: the lexicon is generated at the birth of every mind. Two');
  LT('worlds, two tongues. Like us.', 3);
  LT('');
  LT('How to save a story?', 1);
  LT('Save / Load in the notebook: the world, the minds, the lexicon,');
  LT('the annals — everything will resume where you left it.');

  // ============================================================ 17. ANATOMIE DU RÉSEAU
  P('Anatomy of the neural network');
  LT('Each sapiens carries its own brain: about 600 floating numbers in');
  LT('truth — its mental DNA. Here it is, layer by layer.');
  LT('');
  LT('Overview: 34 → 9 → 9 → 10', 1);
  LT('· 34 inputs: what the body feels of the world, at each "thought";');
  LT('· 9 hidden neurons, then 9 more: the processing;');
  LT('· 10 outputs: the possible actions.');
  LT('');
  LT('The 34 inputs, in order', 1);
  LT('0 bias · 1 energy (0=starving, 1=full) · 2 daylight', 5);
  LT('3-5 food: direction X, Y, closeness', 5);
  LT('6-8 nearest peer: X, Y, closeness', 5);
  LT('9-11 nearest predator: X, Y, closeness', 5);
  LT('12-15 the four calls heard: α, β, γ, δ (signal strength)', 5);
  LT('16-17 direction the loudest call comes from', 5);
  LT('18-20 nearest danger memory: X, Y, strength', 5);
  LT('21-23 food memory: X, Y, strength (weighted by hunger!)', 5);
  LT('24-32 the NINE echoes: what the network decided the previous thought', 5);
  LT('33 constant bias = 1', 5);
  LT('Directions are relative to the body''s heading:');
  LT('"ahead of me, to the left", not "north-west of the island".', 2);
  LT('');
  LT('The 10 outputs', 1);
  LT('0 turn (left/right) · 1 advance (body speed)', 5);
  LT('2 BUILD a hut · 3 breed · 4 hunt', 5);
  LT('5-8 call α, β, γ, δ · 9 rest', 5);
  LT('The most active output wins and becomes the current action.');
  LT('');
  LT('How it computes', 1);
  LT('Each hidden neuron takes a weighted sum of its inputs, then');
  LT('crushes the result between -1 and +1 (hyperbolic tangent).');
  LT('The next layers do the same. That is all — and it suffices:');
  LT('each connection carries a weight (its strength) that makes ALL the character.');
  LT('');
  LT('The three paths', 1);
  LT('· slow path: inputs → 9 → 9 → outputs (the reflection);');
  LT('· direct path (dashed on screen): inputs → outputs (the reflexes);');
  LT('· recurrences: yesterday''s outputs feed today''s inputs.');
  LT('Recurrence is what gives sustained behaviours:');
  LT('a fleeing sapien KEEPS fleeing, a caller keeps calling.', 3);
  LT('');
  LT('Where to see it run', 1);
  LT('Select a sapien, open "brain": each link lights up by its CURRENT');
  LT('strength. Weights do not change live — see the next page for what');
  LT('shapes them.', 2);

  // ============================================================ 18. APPRENTISSAGE
  P('How it learns');
  LT('Nobody teaches the network anything. Three forces shape it:');
  LT('');
  LT('1. Inheritance', 1);
  LT('At birth, the child copies a parent''s network — most often the');
  LT('mother''s — THEN the mutation passes:');
  LT('· ~13 % of the weights move a little (+/- 0.3 on average);');
  LT('· ~2 % jump boldly elsewhere (wild mutation);');
  LT('· the VOICE (α β γ δ weights) mutates twice as much: it is meant so,');
  LT('  language must vary faster than the body — it evolves the fastest.');
  LT('· each lineage has its own mutation rate, inherited and itself mutable:');
  LT('  "innovative" and "conservative" families coexist.');
  LT('');
  LT('2. Mentorship (culture)', 1);
  LT('The child picks the wisest of neighbors as mentor. Its network glides');
  LT('slowly toward the mentor''s — BUT only over 30 % of the genetic');
  LT('distance at most:');
  LT('DNA is never overwritten, it is GUIDED. A child of mediocre parents');
  LT('may grow great; it will never become its mentor entire.');
  LT('');
  LT('3. Selection (the judge)', 1);
  LT('Those who know how to find food, avoid wolves, not drown…');
  LT('live longer and breed more. Their weights spread.');
  LT('It is natural selection, with no other judgement than survival.');
  LT('');
  LT('What does NOT exist (yet is often believed seen)', 1);
  LT('· no error feedback: the network does not "know" when it is wrong;');
  LT('· no memory across generations other than genes and culture;');
  LT('· no goal: nobody aims at "better". Emergence does the rest.', 3);
  LT('');
  LT('Observable result', 1);
  LT('After 30-40 generations, look at the notebook: the speed and sight');
  LT('curves rise if wolves press hard, culture climbs in sawteeth (an');
  LT('invention lost, relearned at camp), words appear and vanish.');
  LT('History writes itself.', 2);

  // ============================================================ 19. ÈRES
  P('The eras of humankind');
  LT('Six ages, from first fire to painted façades', 1);
  LT('· era 1 — Neolithic: fire, agriculture, stores, pastoralism,');
  LT('  fishing, navigation, writing. The world of beginnings;');
  LT('· era 2 — Bronze Age: the earth is ploughed, metal bites,');
  LT('  the sail rises, ideas pass from hand to hand;');
  LT('· era 3 — Iron Age: perfected tools, conducted water,');
  LT('  philosophy — knowledge that no longer dies;');
  LT('· era 4 — Antiquity: the city, geometry, laws, the marble column');
  LT('  on the fire''s square — and the first roads;');
  LT('· era 5 — Middle Ages: mills, universities, guilds, the keep;');
  LT('· era 6 — Renaissance: printing multiplies words, façades');
  LT('  get painted, the method observes and starts again.');
  LT('');
  LT('Nothing is lost on the way', 1);
  LT('Technologies and inventions of the previous era stay active.');
  LT('One never abandons fire. One builds upon it.', 3);
  LT('');
  LT('How one passes', 1);
  LT('The passage is never automatic: when all the era''s technologies');
  LT('are discovered, when the people counts enough adults');
  LT('and enough inventions, a golden button "enter the next era"');
  LT('appears atop the notebook''s commands — and waits for your hand.');
  LT('The notebook shows your progress under the era badge:', 5);
  LT('technologies 5/7 · people 12 · inventions 4/10.', 5);
  LT('Do not cross in mid-famine nor on the eve of winter.', 4);
  LT('');
  LT('What changes', 1);
  LT('· discoveries speed up: every day of failed research feeds the next');
  LT('  (the library effect) — then Science, Mathematics, Universities');
  LT('  and Method amplify it further;');
  LT('· the people may grow: the sapiens ceiling rises at each era;');
  LT('· the village transforms: round huts → stone houses →');
  LT('  painted façades; the house with fire bears its age''s monument;');
  LT('· the countryside empties: the exodus to cities swells era after');
  LT('  era, and from Antiquity on, cities link themselves with roads.');
  LT('Each passage is recorded in the annals.', 2);

  // ============================================================ 20. TECHS DES ÈRES
  P('Era technologies');
  LT('Bronze Age', 1);
  LT('· plough — harvest yields half again as much;');
  LT('· wheel — everyone walks a third faster;');
  LT('· irrigation — the land carries a third more vegetation;');
  LT('· metallurgy — hunting yields much more at each strike;');
  LT('· sail — at sea, the canoe goes as fast as one walks on land;');
  LT('· coin — diffusion between neighbors races;');
  LT('· archives — the people''s memory reads everywhere on the island;');
  LT('· science — each discovery makes the next more likely.');
  LT('');
  LT('Iron Age', 1);
  LT('· iron — metal perfects the hunt further;');
  LT('· aqueduct — the land feeds even more;');
  LT('· engineering — hut stores gain half;');
  LT('· philosophy — knowledge NEVER gets lost again;');
  LT('· medicine — old age recedes by a fifth;');
  LT('· mathematics — discoveries speed up again;');
  LT('· astronomy — winters lose a third of their bite;');
  LT('· school — mentorship transmits half again as much.');
  LT('');
  LT('Antiquity', 1);
  LT('· city-state — twice as many huts may gather;');
  LT('· geometry — building costs less effort;');
  LT('· legislation — diffusion gains a quarter;');
  LT('· rhetoric — mentorship transmits a fifth more;');
  LT('· galleys — the sea becomes faster than walking;');
  LT('· agronomy — harvest gains another quarter;');
  LT('· hygiene — old age recedes by a tenth;');
  LT('· cartography — exploration no longer wanders.');
  LT('');
  LT('Middle Ages', 1);
  LT('· mills and rotation — the land carries a third more;');
  LT('· shoeing — sure steps, a tenth livelier;');
  LT('· universities — discoveries gain a fifth;');
  LT('· guilds — inventions come half again as fast;');
  LT('· selective breeding — taming goes half again as fast;');
  LT('· arabic medicine — old age recedes another tenth;');
  LT('· deep-sea navigation — the sea, a tenth more still.');
  LT('');
  LT('Renaissance', 1);
  LT('· printing — diffusion races (×1.6);');
  LT('· optics — sight carries a fifth farther;');
  LT('· anatomy — the body holds a twentieth more energy;');
  LT('· caravels — the sea is mastered (×2.2);');
  LT('· powder — hunting gains another third;');
  LT('· banking — ideas circulate even more;');
  LT('· method — discoveries gain a third;');
  LT('· humanities — mentorship gains a quarter.');
  LT('');
  LT('The new ages'' inventions', 1);
  LT('· candle, cart, oven (Bronze) — the night lightened, stores');
  LT('  filled half again as fast, the meal more nourishing;');
  LT('· clock, compass, theatre (Iron) — walking refined, wandering');
  LT('  halved, diffusion inflamed by the audience;');
  LT('· amphora, billhook, pit (Antiquity) — vaster granaries, finer');
  LT('  harvest, wolves kept at distance;');
  LT('· crossbow, parchment, armour (Middle Ages) — hunting afar, ideas');
  LT('  circulating, fangs sliding off;');
  LT('· spyglass, violin, portolan chart (Renaissance) — seeing in the');
  LT('  dark, soothing music, guided exploration.', 2);

  // ============================================================ 21. VILLES (nouveau)
  P('Cities, countryside and roads');
  LT('The birth of a town', 1);
  LT('When ten scattered huts gather close enough, they become a town:');
  LT('it receives a name — syllables from nowhere, a tongue of its own —');
  LT('and the huts rearrange in a spiral around the town''s fire.');
  LT('');
  LT('The levels', 1);
  LT('· 10 hearths: the town;');
  LT('· 18 hearths: the city — walls rise, pierced with four gates;');
  LT('· 28 hearths: the metropolis — and its monument facing the fire.');
  LT('The name shows at zoom; in the Renaissance, façades get painted.', 2);
  LT('');
  LT('The wild''s space', 1);
  LT('One does not build between 8 and 50 cells of a city: that cord is');
  LT('hunting, forest, game. But near the walls (under 20 cells), from');
  LT('the Bronze Age on, the house born there is a TOWNSMAN''S — that is');
  LT('the suburb, and the city grows by its fringe.', 3);
  LT('');
  LT('The clearing', 1);
  LT('The city clears: neither tree nor bush within its bounds.');
  LT('The cities'' ecological footprint reads on the map.', 2);
  LT('');
  LT('The exodus', 1);
  LT('From era 2 on — and more and more each era — scattered families');
  LT('leave the woods for the nearest city (within a reasonable radius;');
  LT('the too-far remain hamlets).');
  LT('The day more than one hearth in two is urban, the annals write:');
  LT('"the people turn urban".', 2);
  LT('');
  LT('The roads', 1);
  LT('In Antiquity, nearby cities (under 200 cells) link together.');
  LT('Roads grow by themselves, three cells a day, skirting the water.');
  LT('On the road, one walks half again as fast — and ideas circulate');
  LT('better there.', 3);
  LT('A ring of roads linking several cities: the sign of a world', 2);
  LT('that holds together.', 2);
end;


procedure HelpBuild;
begin
  if FLangue = LANG_EN then HelpBuildEN
  else HelpBuildFR;
  FLangueBuild := FLangue;
  Cur := 0;
end;


{--- service ----------------------------------------------------------------}

procedure HelpShow(AOn: Boolean);
begin
  if AOn and ((Length(Pages) = 0) or (FLangueBuild <> FLangue)) then
    HelpBuild;                     // première ouverture OU changement de langue (F8)
  FOn := AOn;
  if FOn then begin
    if Cur >= Length(Pages) then Cur := 0;
  end;
end;

procedure HelpToggle;
begin
  HelpShow(not FOn);
end;

function HelpOn: Boolean;
begin
  Result := FOn;
end;

{ ★ retourne la HAUTEUR dessinée (au lieu du Y suivant) — sert au scroll }
function DrawWrapped(C: TCanvas; const S: string; X, Y, MaxW: Integer;
  Clr: TColor): Integer;
var P0, Px, Y0: Integer; Wd, Ln: string;

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
  Ln := '';  P0 := 1;  Y0 := Y;
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
  Result := Y - Y0;              // la hauteur (0 pour une ligne vide)
end;
{--- rendu ------------------------------------------------------------------}

procedure HelpRender(C: TCanvas; W, H: Integer);
const MARG = 24;
var PW, PH, X0, Y0, I, BX, BW: Integer;
   CTop, CBot, YL, YS, DS, ContH, MaxScrl, VH, VY: Integer;
   SommaireLbl, FermerLbl, EssayerLbl: string;

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
  if (Length(Pages) = 0) or (FLangueBuild <> FLangue) then HelpBuild;
  HBtns := nil;
  if Cur <> LastCur then begin Scrl := 0; LastCur := Cur end;   // ★ nouvelle page : haut

  if FLangue = LANG_EN then begin
    SommaireLbl := 'contents';  FermerLbl := 'close';  EssayerLbl := 'try: ';
  end else begin
    SommaireLbl := 'sommaire';  FermerLbl := 'fermer'; EssayerLbl := 'essayer : ';
  end;

  PW := Min(720, W - 36);  PH := Min(560, H - 36);
  X0 := (W - PW) div 2;  Y0 := (H - PH) div 2;
  CTop := Y0 + 48;             // haut de la zone de contenu
  CBot := Y0 + PH - 92;        // bas (au-dessus des boutons démo / nav, fixes)

  C.Font.Name := 'Segoe UI'; C.Font.Size := 9; C.Font.Style := [];

  // ombre + panneau + bandeau (inchangés)
  C.Brush.Style := bsSolid;  C.Pen.Style := psClear;
  C.Brush.Color := Col(6, 8, 6);
  C.FillRect(Rect(X0 + 5, Y0 + 6, X0 + PW + 5, Y0 + PH + 6));
  C.Brush.Color := Col(19, 23, 16);
  C.FillRect(Rect(X0, Y0, X0 + PW, Y0 + PH));
  C.Pen.Style := psSolid;  C.Pen.Color := Col(54, 60, 46);  C.Pen.Width := 1;
  C.Brush.Style := bsClear;
  C.Rectangle(X0, Y0, X0 + PW, Y0 + PH);
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

  // ★ le contenu DÉFILE : clip sur la zone, curseur logique YL, dessin à YL - Scrl
  DS := SaveDC(C.Handle);
  IntersectClipRect(C.Handle, X0 + 2, CTop - 4, X0 + PW - 2, Y0 + PH - 50);

  YL := CTop ;
  C.Font.Name := 'Segoe UI';  C.Font.Size := 9;  C.Font.Style := [];
  for I := 0 to High(Pages[Cur].L) do begin
    YS := YL - Scrl;
    with Pages[Cur].L[I] do begin
      case K of
        1: begin
             Inc(YL, 5);
             C.Font.Style := [fsBold];
             YS := DrawWrapped(C, Txt, X0 + MARG, YL - Scrl, PW - 2*MARG, Col(208, 167, 92));
             YL := YL + YS + 2;
             C.Font.Style := [];
           end;
        2: begin
             C.Font.Style := [fsItalic];
             YS := DrawWrapped(C, '◆ ' + Txt, X0 + MARG, YL - Scrl, PW - 2*MARG, Col(240, 180, 95));
             YL := YL + YS + 2;
             C.Font.Style := [];
           end;
        6: begin
             // lien : dessiné et cliquable seulement s'il est dans la zone
             if (YS + 24 > CTop - 4) and (YS < Y0 + PH - 50) then
               BtnBox(Rect(X0 + MARG, YS, X0 + PW - MARG, YS + 24), '▸ ' + Txt, Act, True);
             Inc(YL, 28);
           end;
      else begin
             case K of
               3: YS := DrawWrapped(C, Txt, X0 + MARG, YL - Scrl, PW - 2*MARG, Col(157, 187, 107));
               4: YS := DrawWrapped(C, Txt, X0 + MARG, YL - Scrl, PW - 2*MARG, Col(206, 116, 79));
               5: YS := DrawWrapped(C, Txt, X0 + MARG, YL - Scrl, PW - 2*MARG, Col(139, 138, 116));
             else
               YS := DrawWrapped(C, Txt, X0 + MARG, YL - Scrl, PW - 2*MARG, Col(222, 216, 196));
             end;
             YL := YL + YS + 2;
           end;
      end;
    end;
  end;
  RestoreDC(C.Handle, DS);

  // ★ mesure du débordement (pour la molette + l'ascenseur) — actif dès ce frame+1
  ContH := Max(1, YL - CTop);
  MaxScrl := Max(0, ContH - (CBot - CTop));
  if Scrl > MaxScrl then Scrl := MaxScrl;
  CurMaxScrl := MaxScrl;

  // ★ mini-ascenseur à droite
  if MaxScrl > 0 then begin
    C.Brush.Style := bsSolid; C.Pen.Style := psClear;
    C.Brush.Color := Col(32, 37, 28);
    C.FillRect(Rect(X0 + PW - 7, CTop, X0 + PW - 4, CBot));
    VH := Max(28, MulDiv(CBot - CTop, CBot - CTop, ContH));
    VY := CTop + MulDiv(CBot - CTop - VH, Scrl, MaxScrl);
    C.Brush.Color := Col(96, 102, 86);
    C.FillRect(Rect(X0 + PW - 7, VY, X0 + PW - 4, VY + VH));
  end;

  // boutons démo (fixes, inchangés)
  if (Length(Pages[Cur].D) > 0) and Assigned(HelpDemoProc) then begin
    YL := Y0 + PH - 86;
    BX := X0 + MARG;
    for I := 0 to High(Pages[Cur].D) do begin
      BW := C.TextWidth(EssayerLbl + Pages[Cur].D[I].Cap) + 20;
      if BX + BW > X0 + PW - MARG then begin BX := X0 + MARG; Inc(YL, 28) end;
      BtnBox(Rect(BX, YL, BX + BW, YL + 24),
             EssayerLbl + Pages[Cur].D[I].Cap, 1000 + Pages[Cur].D[I].Act, True);
      BX := BX + BW + 8;
    end;
  end;

  // navigation (inchangée)
  YL := Y0 + PH - 46;
  C.Pen.Style := psSolid;  C.Pen.Color := Col(48, 54, 42);  C.Pen.Width := 1;
  C.MoveTo(X0 + MARG, YL - 8);  C.LineTo(X0 + PW - MARG, YL - 8);
  BtnBox(Rect(X0 + MARG, YL, X0 + MARG + 34, YL + 26), '◀', -1, True);
  BtnBox(Rect(X0 + MARG + 40, YL, X0 + MARG + 74, YL + 26), '▶', -2, True);
  BtnBox(Rect(X0 + PW - MARG - 156, YL, X0 + PW - MARG - 76, YL + 26), SommaireLbl, -3, True);
  BtnBox(Rect(X0 + PW - MARG - 70, YL, X0 + PW - MARG, YL + 26), FermerLbl, -4, True);
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
  if Delta < 0 then begin
    if Scrl < CurMaxScrl then Scrl := Min(CurMaxScrl, Scrl + 56)
    else if Cur < High(Pages) then Inc(Cur);      // bas atteint : page suivante
  end else begin
    if Scrl > 0 then Scrl := Max(0, Scrl - 56)
    else if Cur > 0 then Dec(Cur);                // haut atteint : page précédente
  end;
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

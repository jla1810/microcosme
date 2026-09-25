1. README.md (remplacer en entier)

🇬🇧 English
🌍 Microcosme

Une simulation de monde vivant en Delphi — 100 % code, zéro ressource externe.

Aucun fichier image. Aucun fichier son. Aucune bibliothèque. Une île, du bruitfractal, un peu de hasard — et des créatures qui se débrouillent pour le reste.

Delphi 12 · Windows · VCL
✨ Ce qui émerge tout seul

L'évolution. La sélection naturelle agit sur la vitesse, la vue, la taille.Les prédateurs pressent, les lignées de proies s'affûtent. Chaque lignée portesa couleur — et son propre taux de mutation, hérité et lui-même mutable :des familles « innovantes » et « conservatrices » coexistent, et la surviearbitre.

Les esprits. Chaque sapiens porte son propre réseau neuronal — 34 sens,dix décisions, ~850 poids synaptiques, trois chemins dans le même réseau :la réflexion, le réflexe, les échos. Rétropropagation ? Non : l'héritage, lementorat et la sélection façonnent tout.→ Le réseau neuronal de Microcosme

La culture. Chaque enfant choisit un mentor : son esprit glisse vers lesien, sans jamais franchir 30 % de la distance génétique. L'ADN est guidé,jamais écrasé. Les techniques se transmettent de bouche à oreille — la monnaie,l'école et l'imprimerie les font circuler plus vite — et le savoir peut seperdre.

Le langage. Quatre cris (α β γ δ) dont le sens n'est fixé par personne.Le carnet observe les coïncidences et devine : cri d'alarme ? de nourriture ?La voix mute deux fois plus vite que le corps : le langage doit pouvoir varier.

Les inventions. Une brochette naît d'une nuit de faim près du feu, untambour d'un souvenir de danger au bord de l'eau. 25 inventions, chacune nomméepar le lexique émergent.

Les villes. Un amas de huttes devient un bourg nommé : place, remparts àquatre portes, monument. La forêt recule autour d'elles, des routes poussentde bourg en bourg — et se recalculent quand la ville dérive. Puis la campagnese vide : l'exode rural verse les foyers dans les villes, ère après ère —« le peuple devient citadin », écrit un jour le carnet.

Le chef. Quand un bourg se constitue, il se donne un chef : celui qui sait —techniques, inventions, culture, sagesse des anciens. Règne à vie ; à sa mort,une cloche sonne et le carnet écrit qui succède. Sous son règne, ses sujetsapprennent plus vite — lui plus vite encore.

Le son. Tout est synthétisé en direct (waveOut + un fil) : les voix àformants qui portent les cris, les tambours, les grillons, la houle, le vent,la fanfare de lyre à chaque portail d'ère — et la cloche du sacre.
🏛️ Les ères
Ère	Ce qu'elle apporte
Néolithique	le feu → l'écriture ; huttes rondes, le premier camp
Âge du bronze	charrue, voile, science ; maisons de pierre
Âge du fer	philosophie, médecine ; le savoir qui ne meurt plus
Antiquité	la Cité ; places pavées, colonnes de marbre, routes
Moyen Âge	universités, moulins ; remparts et donjons
Renaissance	l'imprimerie ; façades peintes

Les ères 7 (Industrielle) et 8 (Moderne) sont déjà inscrites dans leprogramme — elles viendront.

Le passage d'ère n'est jamais automatique : quand toutes les techniques del'âge sont trouvées, quand le peuple est assez nombreux et inventif, unbouton doré apparaît dans le carnet — et attend votre main.
👁️ Voir à travers leurs yeux

Une fenêtre 3D écrite à la main — un raycaster, comme les premiers jeux, enpur Pascal : sol granulé, brume de distance, murailles de pierre appareillée,toits de chaume, feu qui vacille la nuit. Un bouton du carnet l'ouvre ;trois modes (clic droit) :

    les étoiles — chaque habitant est un point dans l'espace vitesse × vue ×taille : l'évolution se lit d'un regard ;
    les populations — les quatre courbes de l'histoire en relief ;
    les yeux d'un sapiens — vous voyez ce qu'il voit, depuis sa tête : laforêt, la route ocre qui serpente, la muraille qui surgit de la brume.

Et dans ce monde vu de l'intérieur, ESPACE incarne le sapiens suivi :flèches ou ZQSD pour marcher, ESPACE à nouveau rend le corps à son esprit.Les métiers se lisent d'un coup d'œil — le bâton du berger, la lance duchasseur, la canne du pêcheur — et le chef porte le diadème et l'étendard.
🏙️ L'Observatoire

    un clic sur une ville (outil loupe) ouvre sa fiche : rang, fondation,foyers, habitants, routes, et le nom de son chef ;
    F7 : le cerveau du spécimen en géant, chaque lien allumé par son signaldu moment — un clic passe d'esprit en esprit ;
    le carnet : les annales du peuple, les courbes, le lexique qui se devine.

⌨️ Commandes
Touche	Action
F1	le manuel intégré (22 pages illustrées, FR/EN)
F2	le rythme du monde
F3	la fiche du spécimen
F4	le son
F5	le monde plein écran
F7	l'Observatoire — l'esprit choisi, en direct
F8	français / english
Espace	pause

Souris : clic gauche = l'outil choisi (loupe, graine, herbivore, prédateur,sapiens) ; clic droit glissé = déplacer la caméra ; molette = zoom.

Triches (Ctrl+Shift, pour les curieux) : E équiper une ère · B l'état dumonde · P passer l'ère · U fonder une ville · R forcer une route ·C sacrer un chef · V tester la voix · W diagnostic audio · M couperla voix.
🧠 Les esprits

    Ce n'est pas un modèle entraîné — c'est une espèce vivante.

Chaque sapiens naît avec ses poids et meurt à peu près avec eux. Rien n'estcorrigé, jamais : ceux qui trouvent à manger, esquivent les loups et évitentde se noyer vivent plus longtemps et se reproduisent davantage — leurs poidsse diffusent. La leçon s'apprend entre les générations, pas dans une vie.

→ Le réseau neuronal de Microcosme — le chapitre complet
🔨 Compiler

    Delphi 12 (Community Edition convient) avec VCL ;
    ouvrir le projet, Construire — tout est dans ce dépôt ;
    lancer. Observer le monde.

📸 Aperçu
	
La ville au crépuscule	Les yeux d'un sapiens
L'Observatoire	La fiche d'une ville
📜 Licence

(à choisir — voir fichier LICENSE)

Microcosme est une boîte de vie contemplative : on n'y gagne rien, on n'y perdrien. On sème, on regarde — et l'histoire s'écrit toute seule.
2. README_EN.md (nouveau fichier)

Français 🇫🇷
🌍 Microcosme

A living-world simulation in Delphi — 100 % code, zero external resources.

No image files. No sound files. No libraries. An island, fractal noise, alittle chance — and creatures who figure out the rest by themselves.

Delphi 12 · Windows · VCL
✨ What emerges on its own

Evolution. Natural selection acts on speed, sight, size. Predators press,the prey lineage sharpens. Every lineage carries its own color — and its ownmutation rate, inherited and itself mutable: "innovative" and "conservative"families coexist, and survival arbitrates.

Minds. Every sapien carries its own neural network — 34 senses, tendecisions, ~850 synaptic weights, three paths in one network: reflection,reflex, echoes. No backpropagation: inheritance, mentorship and selectionshape everything.→ The neural network of Microcosme (in French —English version coming)

Culture. Each child picks a mentor; its mind glides toward theirs, butnever beyond 30 % of the genetic distance. DNA is guided, never overwritten.Techniques travel mouth to mouth — money, school and the printing press speedthem up — and knowledge can be lost.

Language. Four calls (α β γ δ) whose meaning is fixed by no one. Thenotebook watches the coincidences and guesses: alarm call? food? The voicemutates twice as fast as the body: language must be free to drift.

Inventions. A skewer is born of a hungry night by the fire, a drum of amemory of danger by the water. 25 inventions, each named by the emergentlexicon.

Cities. A dense cluster of huts becomes a named town: a square, walls withfour gates, a monument. The forest recedes around them; roads slowly grow fromtown to town — and re-route when a town drifts. Then the countryside empties:the rural exode pours households into the towns, era after era — "the peoplebecomes citadin", the notebook writes one day.

The chief. When a town stands, it elects a chief: the one who knows —techniques, inventions, culture, the wisdom of elders. Reign for life; attheir death a bell tolls and the notebook writes who succeeds. Under a chief,subjects learn faster — the chief faster still.

Sound. Everything is synthesized live (waveOut + one thread): formantvoices carrying the calls, drums, crickets, swell, wind, the lyre fanfare ateach era's gate — and the bell of the coronation.
🏛️ The eras
Era	What it brings
Neolithic	fire → writing; round huts, the first camp
Bronze Age	plough, sail, science; stone houses
Iron Age	philosophy, medicine; knowledge that no longer dies
Antiquity	the City; paved squares, marble columns, roads
Middle Ages	universities, mills; walls and keeps
Renaissance	the printing press; painted facades

Eras 7 (Industrial) and 8 (Modern) are already written into the program —they are coming.

Passing an era is never automatic. When every technology of the age is found,when the people is numerous and inventive enough, a golden button appears inthe notebook — and waits for your hand.
👁️ See through their eyes

A hand-written 3D window — a raycaster, like the first games, in pure Pascal:grained ground, distance fog, stone walls, thatch, fire flickering at night.A notebook button opens it; three modes (right click):

    the stars — every inhabitant is a point in speed × sight × size space:evolution at a glance;
    the populations — the four curves of history in relief;
    a sapien's eyes — you see what HE sees, from his head: the forest, theochre road winding ahead, the walls rising out of the mist.

And in this first-person world, SPACE incarnates the followed sapien:arrows or ZQSD to walk, SPACE again hands the body back to its mind. Tradesread at a glance — the shepherd's staff, the hunter's spear, the fisher'srod — and the chief wears the diadem and the banner.
🏙️ The Observatory

    one click on a town (lens tool) opens its record: rank, founding,households, inhabitants, roads, and its chief's name;
    F7: the specimen's brain rendered giant, every link lit by its currentsignal — click to step from mind to mind;
    the notebook: the people's annals, the curves, the guessed lexicon.

⌨️ Controls
Key	Action
F1	the built-in manual (22 illustrated pages, FR/EN)
F2	world pace
F3	specimen sheet
F4	sound
F5	borderless fullscreen world
F7	the Observatory — the selected mind, live
F8	français / english
Space	pause

Mouse: left click = the chosen tool (lens, seed, herbivore, predator, sapien);right-drag = move the camera; wheel = zoom.

Cheats (Ctrl+Shift, for the curious): E equip an era · B world state ·P pass an era · U found a town · R force a road · C crown a chief ·V voice test · W audio diagnostics · M mute voice.
🧠 The minds

    Not a trained model — a living species.

Every sapien is born with its weights and mostly dies with them. Nothing isever corrected: those who find food, dodge wolves and avoid drowning livelonger and breed more — their weights spread. The lesson is learned acrossgenerations, not within one life.

→ The neural network of Microcosme — the full chapter(in French — English version coming)
🔨 Build

    Delphi 12 (Community Edition works) with VCL;
    open the project, Build — everything is in this repository;
    run. Observe the world.

📸 Gallery
	
The town at dusk	A sapien's eyes
The Observatory	A town record
📜 License

(to choose — see LICENSE file)

Microcosme is a contemplative box of life: you win nothing, you lose nothing.You sow, you release, you watch — and history writes itself.
3. docs/NEURAL_NETWORK.md (remplacer en entier)
Le réseau neuronal de Microcosme

    Ce n'est pas un modèle entraîné — c'est une espèce vivante.

Chaque sapiens de Microcosme porte son propre réseau neuronal : 845 poidsflottants, hérités, mutés, sélectionnés par la seule survie. Pas derétropropagation, pas de récompense, pas d'objectif — l'héritage, le mentoratet la sélection façonnent tout.

L'Observatoire (F7) : le réseau, en direct — chaque lien allumé par lesignal du moment.
1. Un cerveau par créature

Il n'y a pas UN réseau dans Microcosme — il y en a autant que de sapiens.La faune, elle, évolue sur ses traits seuls (vitesse, vue, taille), sansréseau. Chaque sapiens porte :

    son génome mental (Dna) : les 845 poids reçus à la naissance ;
    son réseau vivant (Net) : les mêmes poids, dérivés par la culture(§7) — jamais au-delà de ce que l'ADN permet ;
    sa mémoire (Mem) : jusqu'à six souvenirs de danger et de nourriture ;
    ses échos (PrevOo) : ses neuf décisions précédentes, réinjectées enentrées.

Le réseau pense toutes les 0,1 seconde de monde : il sent (SenseSapien),il décide (ThinkNet), le corps exécute. Indissociable : le réseau agit entemps réel, et le monde répond — ses décisions décident de sa survie.
2. L'architecture : trois chemins dans un même génome

Les 845 poids sont stockés à plat dans un tableau :
Bloc	Taille	Rôle
entrées → cachée	34 × 9 = 306	la réflexion
biais de la cachée	9	
cachée → sorties	9 × 10 = 90	la réflexion, sortie
voie directe	34 × 10 = 340	les réflexes (entrées → sorties, sans détour)
biais de sortie	10	
réservé	9 × 9 + 9 = 90	une seconde couche de 9 neurones, posée pour une extension

La passe avant (ThinkNet) calcule :

    le chemin lent : 34 entrées → 9 neurones (tanh) → 10 sorties (tanh) ;
    la voie directe : les entrées alimentent aussi les sorties directement —les réflexes ne passent pas par la réflexion ;
    les échos : les neuf premières sorties de la pensée précédente reviennenten entrées (24-32). C'est ce qui donne la persistance du comportement : unsapiens qui fuit continue de fuir, un crieur continue de crier.

Toutes les unités sont des tanh : les signaux vivent dans [-1, +1].
3. Les 34 sens
Entrées	Sens
0	biais constant = 1
1	l'énergie (0 = la faim, 1 = repu)
2	la lumière du jour
3–5	la nourriture la plus proche : direction X, Y, proximité
6–8	le congénère le plus proche : direction X, Y, proximité
9–11	le prédateur le plus proche : direction X, Y, proximité
12–15	les quatre cris entendus : α, β, γ, δ (force du signal)
16–17	la direction du cri le plus fort
18–20	le souvenir de danger le plus pressant : direction, force
21–23	le souvenir de nourriture (pondéré par la faim)
24–32	les neuf échos — ce que le réseau a décidé la pensée d'avant
33	biais = 1

Les directions sont relatives au corps : « devant à ma gauche », pas« au nord-ouest de l'île ».

La vue n'est pas un don uniforme. Sa portée (Se, 6 à 12 cases à lanaissance, mutée) est multipliée :

    × 1,15 avec l'Optique ;
    × 1,3 la nuit avec les lunettes (invention) ;
    × 1,8 dès qu'un chien rôde à moins de six cases — la domesticationfondatrice est aussi une extension des sens.

L'ouïe porte à 14 cases, × 2 avec le tambour.
4. Les dix décisions

Chaque sortie est lue contre son propre seuil — tourner et avancers'appliquent en continu, les autres sont des portes :
Sortie	Décision	Lecture
0	tourner	proportionnel, jusqu'à ±4,5 rad/s
1	avancer	poussée de 18 % à 108 % de la vitesse propre
2	construire	> 0,55 — une hutte, si le monde s'y prête
3	se reproduire	module la probabilité (à condition d'avoir l'énergie, d'être adulte)
4	chasser	> 0,4 et une proie sauvage en vue
5–8	crier α β γ δ	le plus actif (> 0,25) devient le cri du jour
9	se reposer	> 0,5 — le corps veille toujours (faim, vieillesse)
5. Le réflexe qui n'est pas du réseau

Quand un prédateur entre à moins de 3,6 cases, le corps ne demande pas sonavis au réseau : il fuit, direction opposée. Le réseau voit quand même leprédateur (entrées 9-11) et l'écrit en mémoire — mais la fuite elle-même estcâblée. La peur a précédé le cortex.
6. Hérédité et mutation

À la naissance (SpawnCreature) :

    le corps : chaque trait (vitesse, vue, taille, parure, teinte) vientd'un des deux parents au hasard, puis dérive d'un facteur exponentiel doux(× e^±0,15 environ), borné par les bornes de l'espèce ;
    le cerveau : copie intégrale du réseau d'UN parent, puis mutation(MutateNet) — environ 13 % des poids dérivent légèrement, ~2 % sautentcarrément ailleurs ; et les poids de la voix (les sorties 5-8) mutentdeux fois plus — par dessein : le langage doit pouvoir varier plus viteque le corps ;
    le taux de mutation lui-même est un gène : hérité (× e^±0,10), borné[0,5 ; 2,0] — des lignées « innovantes » et « conservatrices » coexistent,et la sélection arbitre ;
    les inventions (bits) : le OU des bits des deux parents ;
    la culture : ~90 % du meilleur parent (une décote d'au plus 12 %) —le savoir se transmet partiellement, jamais intégralement ;
    les fondateurs (sans parent) : un réseau inné tiré par le programme(FillInnateNet), une culture de départ de 0,18 à 0,30.

7. Le mentorat : la culture qui guide l'ADN

L'enfant choisit le voisin le plus « cultivé » (culture supérieure à lasienne, dans 14 cases) — et le re-choisit toutes les 0,4 s. Son réseauglisse vers celui du mentor, mais jamais au-delà de 30 % de la distancegénétique. Le code réel, tel qu'il tourne :

// — transmission culturelle + apprentissage autonome —if (C.Mentor <> nil) and (C.Cult < 0.95) then begin  ...  C.Cult := Min(0.95, C.Cult + Gain);  // le réseau dérive vers le mentor SANS effacer l'ADN :  // au plus 30 % de la distance génétique peut être comblée  for I := 0 to NW - 1 do begin    Tgt := C.Dna[I] + (C.Mentor.Net[I] - C.Dna[I]) * 0.30;    C.Net[I] := C.Net[I] + (Tgt - C.Net[I]) * (0.15 * DT);  end;  ...end;

Le rythme du savoir : 0,070 par seconde de monde (0,112 près d'une hutte),× 1,5 avec l'École, × 1,2 avec la Rhétorique, × 1,25 avec les Humanités —et cela coûte 0,05/s d'énergie : apprendre, ça nourrit moins. Plafond : 0,95.

Pendant l'apprentissage, les techniques du mentor coulent aussi — et ladiffusion entre voisins (§8) les répand bien au-delà.

C'est un étage lamarckien posé sur une transmission darwinienne : ce qui estappris dans une vie ne passe pas aux enfants — mais cela change qui survit,donc quels gènes se diffusent. L'effet Baldwin, en direct.
8. La diffusion : les idées circulent

Toutes les 0,1 s, chaque sapiens regarde ses voisins (dans 8 cases) : avecune probabilité de base (curseur de configuration) multipliée par

    × 1,6 si l'autre a l'Imprimerie — l'encre multiplie les mots ;
    × 1,5 la Monnaie — l'argent prête et voyage ;
    × 1,3 si l'un des deux marche sur une route ;
    × 1,25 la Banque, la Législation, le Théâtre ; × 1,1 le Parchemin ;

…les techniques manquantes sont copiées. Les bits d'invention passent avec4 % de chance par voisin. Une invention née chez un sapiens peut ainsiconquérir le peuple — ou mourir avec lui.
9. La mémoire : personnelle et collective

Personnelle — jusqu'à six souvenirs, qui vieillissent en ~70 secondes demonde (environ un jour et trois quarts) :

    le danger : écrit dès qu'un prédateur est repéré sans souvenircorrespondant ;
    la nourriture : écrite en mangeant.

Leur force = proximité (1 − d/40) × fraîcheur (1 − âge/vie), pondérée par lafaim pour la nourriture. Elles alimentent les entrées 18-23 : le passé procheguide le pas présent.

Collective — avec les Archives (ou près du foyer d'origine), chaquenouveau-né reçoit d'emblée tout ce que le peuple sait, et tous les bitsd'invention : la mort ne tue plus le savoir. C'est la promesse de l'ère dufer — tenue par le code.
10. Le langage émergent

Quatre cris — α, β, γ, δ — portés à 14 cases (× 2 avec le tambour). Quiparle est entendu (entrées 12-15), avec la direction du cri le plus fort(entrées 16-17).

Personne ne fixe leur sens. Le carnet observe les coïncidences — un cri,puis un prédateur ? une trouvaille de nourriture ? — et devine unlexique. La voix de chaque sapiens est synthétisée en direct ; avecl'invention du tambour, le cri devient percussion.

Et puisque les poids de la voix mutent deux fois plus vite que le reste(§6), le langage se transforme plus vite que les corps qui le portent.
11. Comment l'observer

    F7 — l'Observatoire : le réseau du spécimen en géant, chaque lienallumé par son signal du moment ; un clic passe d'esprit en esprit ;
    F3 — la fiche : vitesse, vue, taille, génération, culture, inventions ;
    les courbes du carnet : après 30-40 générations, elles racontent — lavitesse et la vue montent si les prédateurs pressent, la culture scie(une invention perdue, réapprise au camp), les mots apparaissent etdisparaissent ;
    en 3D : la couleur d'un sapiens est sa lignée ; le bâton du berger, lalance du chasseur, la canne du pêcheur et le diadème du chef se lisentd'un coup d'œil.

12. La place du projet

Microcosme appartient à la famille de la neuroévolution — voir NEAT(Stanley & Miikkulainen) et la célèbre expérience MarI/O. Ce qui ledistingue :

    les réseaux vivent dans un monde persistant (saisons, prédateurs,famines, la mémoire d'un peuple), pas dans une tâche éphémère ;
    l'étage culturel (mentorat borné par la distance génétique) fait pontentre Lamarck et Darwin ;
    un langage émergent dont la voix mute plus vite que le corps, et dontle sens n'est fixé par personne — le carnet ne fait que le deviner.

Les curseurs de configuration (mutation, diffusion, mémoire) en font unpetit laboratoire d'évolution : on sème, on relâche, on regarde — etl'histoire s'écrit toute seule.

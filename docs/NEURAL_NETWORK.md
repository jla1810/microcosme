# Le réseau neuronal de Microcosme — neuroévolution en Pascal

> Ce n'est pas un modèle entraîné — c'est une espèce vivante. Un document
> pratique sur la **neuroévolution** : réseaux de neurones + algorithme
> génétique, sans rétropropagation, en Pascal/Delphi.

Chaque sapiens de Microcosme porte son propre réseau neuronal : **2 030 poids**
flottants, hérités, mutés, sélectionnés par la seule survie. Pas de
rétropropagation, pas de récompense, pas d'objectif — l'héritage, le mentorat
et la sélection façonnent tout.

L'Observatoire (F7) : le réseau, en direct — chaque lien allumé par le signal
du moment. Un **clic** bascule entre le graphe des poids et le **mode esprit**.

## 1. Un cerveau par créature

Il n'y a pas UN réseau dans Microcosme — il y en a autant que de sapiens.
La faune, elle, évolue sur ses traits seuls (vitesse, vue, taille), sans
réseau. Chaque sapiens porte :

- son **génome mental** (`Dna`) : les 2 030 poids reçus à la naissance ;
- son **réseau vivant** (`Net`) : les mêmes poids, dérivés par la culture (§7)
  — jamais au-delà de ce que l'ADN permet ;
- sa **mémoire** (`Mem`) : jusqu'à six souvenirs de danger et de nourriture ;
- ses **échos** (`PrevOo`) : ses neuf décisions précédentes, réinjectées en
  entrées.

Le réseau pense toutes les 0,1 seconde de monde : il sent (`SenseSapien`), il
décide (`ThinkNet`), le corps exécute. Indissociable : le réseau agit en temps
réel, et le monde répond — ses décisions décident de sa survie.

## 2. L'architecture : trois chemins dans un même génome

Les 2 030 poids sont stockés à plat dans un tableau (`Net`), avec une carte
symbolique — changer les dimensions recalcule tous les index :

| Bloc | Taille | Rôle |
|---|---|---|
| entrées → H1 | 34 × 24 = 816 | la réflexion, premier étage : les traits |
| biais de H1 | 24 | |
| H1 → H2 | 24 × 24 = 576 | la réflexion, second étage : les situations |
| biais de H2 | 24 | |
| H2 → sorties | 24 × 10 = 240 | la réflexion, sortie |
| voie directe | 34 × 10 = 340 | les réflexes (entrées → sorties, sans détour) |
| biais de sortie | 10 | |
| **Total (NW)** | | **2 030** |

La passe avant (`ThinkNet`) calcule :

- **le chemin lent** : 34 entrées → 24 neurones (tanh) → 24 neurones (tanh)
  → 10 sorties (tanh). Le premier étage fabrique des *traits* (des
  conjonctions simples), le second fabrique des *situations* (des conjonctions
  de traits) — le moment de jugement entre voir et agir ;
- **la voie directe** : les entrées alimentent aussi les sorties directement —
  les réflexes ne passent pas par la réflexion ;
- **les échos** : les neuf premières sorties de la pensée précédente reviennent
  en entrées (24-32). C'est ce qui donne la persistance du comportement : un
  sapiens qui fuit continue de fuir, un crieur continue de crier.

Toutes les unités sont des tanh : les signaux vivent dans [-1, +1].

> **Historique — les deux big bangs.** La seconde couche fut *posée dès
> l'origine mais bypassée* pendant toute la première vie du projet (845
> poids) : le chemin lent court-circuitait H2, qui mutait dans le vide, et le
> biais de H1 était lu au mauvais endroit. Le premier big bang l'activa et
> élargit les étages à 16 (1 342 poids). Le second — le palier actuel — les
> porta à 24 (2 030 poids). Chaque big bang rend les mondes sauvegardés
> antérieurs incompatibles (refus propre par numéro de version).

## 3. Les 34 sens

| Entrées | Sens |
|---|---|
| 0 | biais constant = 1 |
| 1 | l'énergie (0 = la faim, 1 = repu) |
| 2 | la lumière du jour |
| 3–5 | la nourriture la plus proche : direction X, Y, proximité |
| 6–8 | le congénère le plus proche : direction X, Y, proximité |
| 9–11 | le prédateur le plus proche : direction X, Y, proximité |
| 12–15 | les quatre cris entendus : α, β, γ, δ (force du signal) |
| 16–17 | la direction du cri le plus fort |
| 18–20 | le souvenir de danger le plus pressant : direction, force |
| 21–23 | le souvenir de nourriture (pondéré par la faim) |
| 24–32 | les neuf échos — ce que le réseau a décidé la pensée d'avant |
| 33 | biais = 1 |

Les directions sont relatives au corps : « devant à ma gauche », pas « au
nord-ouest de l'île ».

La vue n'est pas un don uniforme. Sa portée (`Se`, mutée à chaque naissance)
est multipliée :

- × 1,15 avec l'Optique ;
- × 1,3 la nuit avec les lunettes (invention) ;
- × 1,8 dès qu'un chien rôde à moins de six cases — la domestication
  fondatrice est aussi une extension des sens.

L'ouïe porte à 14 cases, × 2 avec le tambour.

## 4. Les dix décisions

| Sortie | Décision | Lecture |
|---|---|---|
| 0 | tourner | proportionnel, jusqu'à ±4,5 rad/s |
| 1 | avancer | poussée de 18 % à 108 % de la vitesse propre |
| 2 | construire | > 0,55 — une hutte, si le monde s'y prête |
| 3 | se reproduire | module la probabilité (énergie et âge requis) |
| 4 | chasser | > 0,4 et une proie sauvage en vue |
| 5–8 | crier α β γ δ | le plus actif (> 0,25) devient le cri du jour |
| 9 | se reposer | > 0,5 — le corps veille toujours (faim, vieillesse) |

## 5. Le réflexe qui n'est pas du réseau

Quand un prédateur entre à moins de 3,6 cases, le corps ne demande pas son
avis au réseau : il fuit, direction opposée. Le réseau voit quand même le
prédateur (entrées 9-11) et l'écrit en mémoire — mais la fuite elle-même est
câblée. La peur a précédé le cortex.

## 6. Hérédité et mutation

À la naissance (`SpawnCreature`) :

- **le corps** : chaque trait (vitesse, vue, taille, parure, teinte) vient
  d'un des deux parents au hasard, puis dérive d'un facteur exponentiel doux
  (× e^±0,15 environ), borné par les bornes de l'espèce ;
- **le cerveau** : copie intégrale du réseau d'UN parent, puis mutation
  (`MutateNet`) — environ 13 % des poids dérivent légèrement, ~2 % sautent
  carrément ailleurs ; et les poids de la voix (les sorties 5-8) mutent deux
  fois plus — par dessein : le langage doit pouvoir varier plus vite que le
  corps. La boucle porte sur tout le Net : depuis le premier big bang, la
  couche 2 est mutée et sélectionnée comme le reste ;
- **le taux de mutation lui-même est un gène** : hérité (× e^±0,10), borné
  [0,5 ; 2,0] — des lignées « innovantes » et « conservatrices » coexistent,
  et la sélection arbitre ;
- **les inventions** (bits) : le OU des bits des deux parents ;
- **la culture** : ~90 % du meilleur parent (une décote d'au plus 12 %) —
  le savoir se transmet partiellement, jamais intégralement ;
- **les fondateurs** (sans parent) : un réseau inné tiré par le programme
  (`FillInnateNet`) — bruit faible partout, réflexes écrits dans la voie
  directe, et **couche 2 transparente** : H2 recopie H1 au premier jour
  (diagonale à 1.0, biais nul). Les fondateurs se comportent comme s'il
  n'y avait qu'un étage ; l'évolution sculpte ensuite la couche neuve sans
  choc démographique. Culture de départ : 0,18 à 0,30.

## 7. Le mentorat : la culture qui guide l'ADN

L'enfant choisit le voisin le plus « cultivé » (culture supérieure à la
sienne, dans 14 cases) — et le re-choisit toutes les 0,4 secondes. Son réseau
glisse ensuite vers celui du mentor, **mais jamais au-delà de 30 % de la
distance génétique** : pour chaque poids, le mentor ne peut l'entraîner qu'à
travers les trois dixièmes du chemin qui sépare l'élève de son propre ADN —
la culture tire, l'hérédité ancre.

Le mécanisme, décrit pas à pas : chaque poids de l'élève calcule d'abord sa
cible (son ADN plus 30 % de la distance vers le poids du mentor), puis glisse
vers cette cible à un rythme de 15 % par seconde de monde. L'ADN lui-même
n'est jamais écrit : il reste la signature immuable de la naissance, le
point de retour.

Le rythme du savoir : 0,070 par seconde de monde (0,112 près d'une hutte),
× 1,5 avec l'École, × 1,2 avec la Rhétorique, × 1,25 avec les Humanités —
et cela coûte 0,05 par seconde d'énergie : apprendre, ça nourrit moins.
Plafond : 0,95.

Pendant l'apprentissage, les techniques du mentor coulent aussi — et la
diffusion entre voisins (§8) les répand bien au-delà.

C'est un étage lamarckien posé sur une transmission darwinienne : ce qui est
appris dans une vie ne passe pas aux enfants — mais cela change qui survit,
donc quels gènes se diffusent. L'effet Baldwin, en direct.

## 8. La diffusion : les idées circulent

Toutes les 0,1 s, chaque sapiens regarde ses voisins (dans 8 cases) : avec
une probabilité de base (curseur de configuration) multipliée par

- × 1,6 si l'autre a l'Imprimerie — l'encre multiplie les mots ;
- × 1,5 la Monnaie — l'argent prête et voyage ;
- × 1,3 si l'un des deux marche sur une route ;
- × 1,25 la Banque, la Législation, le Théâtre ; × 1,1 le Parchemin ;

…les techniques manquantes sont copiées. Les bits d'invention passent avec
4 % de chance par voisin. Une invention née chez un sapiens peut ainsi
conquérir le peuple — ou mourir avec lui.

## 9. La mémoire : personnelle et collective

**Personnelle** — jusqu'à six souvenirs, qui vieillissent en ~70 secondes de
monde (environ un jour et trois quarts) :

- le danger : écrit dès qu'un prédateur est repéré sans souvenir correspondant ;
- la nourriture : écrite en mangeant.

Leur force = proximité (1 − d/40) × fraîcheur (1 − âge/vie), pondérée par la
faim pour la nourriture. Elles alimentent les entrées 18-23 : le passé proche
guide le pas présent.

**Collective** — avec les Archives (ou près du foyer d'origine), chaque
nouveau-né reçoit d'emblée tout ce que le peuple sait, et tous les bits
d'invention : la mort ne tue plus le savoir. C'est la promesse de l'ère du
fer — tenue par le code.

## 10. Le langage émergent

Quatre cris — α, β, γ, δ — portés à 14 cases (× 2 avec le tambour). Qui parle
est entendu (entrées 12-15), avec la direction du cri le plus fort
(entrées 16-17).

Personne ne fixe leur sens. Le carnet observe les coïncidences — un cri, puis
un prédateur ? une trouvaille de nourriture ? — et devine un **lexique**. La
voix de chaque sapiens est synthétisée en direct ; avec l'invention du
tambour, le cri devient percussion.

Et depuis le **dictionnaire vivant** : chaque découverte — technologie ou
invention — frappe un **mot nouveau** assemblé en syllabes (jamais
réutilisées), prononcé à voix haute par son inventeur (synthèse à formants :
consonnes neutres, voyelles chantées, le tambour qui percute le motif),
archivé avec son sens, son auteur et son jour — consultable en F9. Les mots
ne se traduisent pas : la langue du monde est une.

## 11. Comment l'observer

- **F7 — l'Observatoire**, deux lectures au clic :
  - le **graphe** : les trois colonnes (24, 24) et la sortie (10), chaque lien
    allumé par son signal du moment — vert excite, rouge inhibe, l'opacité
    dit la force, les pointillés sont la voie directe ;
  - le **mode esprit** : le journal de bord — ce qu'il perçoit en clair
    (énergie, nourriture, prédateur, congénère, mots entendus, souvenirs),
    son **humeur interne** (24 barres : la couche 2, vivante mais sans nom —
    on ne mentira pas sur ce qu'elle « signifie »), ce qu'il **veut** (les
    décisions triées), et pour sa décision la plus forte les **trois
    contributions les plus lourdes** (poids × activation, voie directe ou
    interne n°k) : du pourquoi mesurable, pas de la poésie ;
- **F9** : le dictionnaire du peuple — chaque mot, son sens, son auteur, son jour ;
- **F3 — la fiche** : vitesse, vue, taille, génération, culture, inventions ;
- **les courbes du carnet** : après 30-40 générations, elles racontent — la
  vitesse et la vue montent si les prédateurs pressent, la culture scie (une
  invention perdue, réapprise au camp), les mots apparaissent et disparaissent ;
- **en 3D** : la couleur d'un sapiens est sa lignée ; le bâton du berger, la
  lance du chasseur, la canne du pêcheur et le diadème du chef se lisent
  d'un coup d'œil.

## 12. La place du projet

Microcosme appartient à la famille de la **neuroévolution** — voir NEAT
(Stanley & Miikkulainen) et la célèbre expérience MarI/O. Ce qui le distingue :

- les réseaux vivent dans un monde persistant (saisons, prédateurs, famines,
  la mémoire d'un peuple), pas dans une tâche éphémère ;
- l'étage culturel (mentorat borné par la distance génétique) fait pont entre
  Lamarck et Darwin ;
- un langage émergent dont la voix mute plus vite que le corps, dont les mots
  s'archivent avec leur histoire — le carnet ne fait que deviner leur sens.

**Les limites honnêtes** : l'apprentissage est lent (mutation + sélection, pas
de gradient) ; à 2 030 poids, le monde approche le seuil de bruit de sélection
(~2 500) — le prochain palier ne se fera pas sans renforcer le signal
(population plus grande, plasticité vivante) ; pour un cerveau plus gros :
élargir avant de creuser, et d'abord enrichir les capteurs — chaque nouveau
canal sensoriel vaut mieux qu'un étage.

---

*Historique du document : v1 — 845 poids, couche 2 allouée mais bypassée.
v2 — 1 342 poids (étages à 16), couche 2 active en série, biais H1 corrigé,
couche 2 transparente à la naissance, mode esprit. v3 — 2 030 poids (étages
à 24), dictionnaire vivant, mots chantés à leur naissance. Mondes antérieurs
incompatibles.*
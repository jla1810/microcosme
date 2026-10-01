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
sienne, dans 14 cases) — et le re-choisit toutes les 0,4 s. Son réseau glisse
vers celui du mentor, mais jamais au-delà de 30 % de la distance génétique.
Le code réel, tel qu'il tourne :

```pascal
// — transmission culturelle + apprentissage autonome —
if (C.Mentor <> nil) and (C.Cult < 0.95) then begin
  ...
  C.Cult := Min(0.95, C.Cult + Gain);
  // le réseau dérive vers le mentor SANS effacer l'ADN :
  // au plus 30 % de la distance génétique peut être comblée
  for I := 0 to NW - 1 do begin
    Tgt := C.Dna[I] + (C.Mentor.Net[I] - C.Dna[I]) * 0.30;
    C.Net[I] := C.Net[I] + (Tgt - C.Net[I]) * (0.15 * DT);
  end;
  ...
end;
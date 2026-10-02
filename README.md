<div align="center">

# 🌍 Microcosme

**Une simulation de monde vivant en Delphi — 100 % code, zéro ressource externe.**

*Aucun fichier image. Aucun fichier son. Aucune bibliothèque. Une île, du bruit fractal,
un peu de hasard — et des créatures qui se débrouillent pour le reste.*

![Delphi](https://img.shields.io/badge/Delphi-12-CC2835?logo=delphi&logoColor=white)
![Windows](https://img.shields.io/badge/Windows-VCL-0078D4?logo=windows11&logoColor=white)
![Dependencies](https://img.shields.io/badge/dépendances-0-3E9B4F)
![Langue](https://img.shields.io/badge/FR-EN-8B7355)

[🇬🇧 English](README_EN.md) · [🧠 Le réseau neuronal](docs/NEURAL_NETWORK.md) · [📖 Le décodeur des symboles](docs/SYMBOLES.md)

</div>

---

## 🌱 Le premier jour

Cinq clans de sapiens — vingt-cinq esprits neufs, le premier au centre de l'île —, des troupeaux
de vaches et de moutons, des loups en meute, trois ours solitaires. Le feu n'est pas inventé,
l'écriture pas rêvée. **Tout le reste leur appartient.**

## ✨ Ce qui émerge tout seul

> *Ce n'est pas un modèle entraîné — c'est une espèce vivante.*

| | |
|---|---|
| **🧬 L'évolution** | La sélection agit sur la vitesse, la vue, la taille. Chaque lignée porte sa couleur — et son propre taux de mutation, hérité et lui-même mutable : des familles « innovantes » et « conservatrices » coexistent, la survie arbitre. |
| **🧠 Les esprits** | Chaque sapiens porte son propre réseau neuronal — 34 sens, dix décisions, **2 030 poids**, trois chemins : la réflexion (deux étages — le second fabrique des *situations*), le réflexe, les échos. Pas de rétropropagation : l'héritage, le mentorat et la sélection façonnent tout. Microcosme relève de la **neuroévolution** — la famille de *NEAT* et de la célèbre expérience *MarI/O* : des réseaux de neurones façonnés par un **algorithme génétique**. |
| **🗣️ Le langage** | Quatre cris (α β γ δ) dont **le sens n'est fixé par personne** — le carnet devine : cri d'alarme ? de nourriture ? Et chaque découverte frappe un **mot nouveau en syllabes**, prononcé à voix haute : le peuple écrit son dictionnaire. |
| **🏛️ La culture** | Chaque enfant choisit un mentor : son esprit glisse vers le sien, sans jamais franchir 30 % de la distance génétique. L'ADN est guidé, jamais écrasé — l'effet Baldwin, en direct. |
| **💡 Les inventions** | Une brochette naît d'une nuit de faim près du feu, un tambour d'un souvenir de danger au bord de l'eau. Chacune nommée par le lexique émergent. |
| **🏘️ Les villes** | Un amas de huttes devient un bourg nommé : place, remparts à quatre portes, monument. Des routes serpentent de bourg en bourg. Puis la campagne se vide — « le peuple devient citadin », écrit un jour le carnet. |
| **👑 Le chef** | Quand un bourg se constitue, il se donne un chef : celui qui sait. Règne à vie ; à sa mort, une cloche sonne et le carnet écrit qui succède. |
| **🎵 Le son** | Tout est synthétisé en direct (waveOut + un fil) : les voix à formants, les tambours, les grillons, la houle, le vent, la fanfare de lyre à chaque portail d'ère — et la cloche du sacre. |

## 🏛️ Les ères

| Ère | Ce qu'elle apporte |
|---|---|
| Néolithique | le feu → l'écriture ; huttes rondes, le premier camp |
| Âge du bronze | charrue, voile, science ; maisons de pierre |
| Âge du fer | philosophie, médecine ; le savoir qui ne meurt plus |
| Antiquité | la Cité ; places pavées, colonnes de marbre, routes |
| Moyen Âge | universités, moulins ; remparts et donjons |
| Renaissance | l'imprimerie ; façades peintes |
| Ère industrielle | la vapeur, les usines ; les cheminées fumantes à l'horizon |
| Ère moderne | l'électricité ; la nuit n'est plus tout à fait la nuit |
| **Les Trois Cités** | *écrite dans le programme — l'avenir du peuple* |

Le passage d'ère n'est jamais automatique : quand toutes les techniques de l'âge sont trouvées,
quand le peuple est assez nombreux et inventif, un **bouton doré** apparaît dans le carnet — et attend votre main.

## 👁️ Voir à travers leurs yeux

Une fenêtre 3D écrite à la main — un **raycaster**, comme les premiers jeux, en pur Pascal :
sol granulé, brume de distance, murailles de pierre appareillée, toits de chaume, feu qui
vacille la nuit, fumées d'usines à l'ère industrielle. Trois modes (clic droit) :

1. **Les étoiles** — chaque habitant est un point dans l'espace vitesse × vue × taille : l'évolution se lit d'un regard ;
2. **Les populations** — les courbes de l'histoire en relief ;
3. **Les yeux d'un sapiens** — vous voyez ce qu'il voit, depuis sa tête : la forêt, la route ocre qui serpente, la muraille qui surgit de la brume.

Et dans ce monde vu de l'intérieur, **ESPACE incarne** le sapiens suivi : flèches ou ZQSD pour
marcher, ESPACE à nouveau rend le corps à son esprit. Les métiers se lisent d'un coup d'œil —
le bâton du berger, la lance du chasseur, la canne du pêcheur — et le chef porte le diadème et l'étendard.

## 🏙️ L'Observatoire

- 🏘️ **Clic sur une ville** (outil loupe) : sa fiche — rang, fondation, foyers, habitants, routes, le nom de son chef ;
- 🧠 **F7** : le cerveau du spécimen en géant — un clic bascule entre le **graphe des poids** et le **mode esprit** : ce qu'il perçoit, son humeur interne (la couche 2, en barres vivantes), ce qu'il veut, et les trois raisons les plus lourdes de sa décision ;
- 📖 **F9** : le **dictionnaire du peuple** — chaque mot frappé, daté, signé ;
- 📜 **Le carnet** : les annales, les courbes, le lexique qui se devine.

## ⌨️ Commandes

| Touche | Action |
|:---:|---|
| **F1** | le manuel intégré (23 pages illustrées, FR/EN) |
| **F2** | le rythme du monde — réglages en direct, dont la table de mixage audio |
| **F3** | la fiche du spécimen |
| **F4** | le son : tout / muet |
| **F5** | le monde plein écran |
| **F7** | l'Observatoire — l'esprit choisi, en direct |
| **F8** | français / english |
| **F9** | le dictionnaire du peuple |
| **Espace** | pause |

*Souris : clic gauche = l'outil choisi (loupe, graine, herbivore, prédateur, sapiens) ·
clic droit glissé = déplacer la caméra · molette = zoom.*

<details>
<summary>🔑 Triches (Ctrl+Shift, pour les curieux)</summary>

**E** équiper une ère · **B** l'état du monde · **P** passer l'ère · **U** fonder une ville ·
**R** forcer une route · **C** sacrer un chef · **V** tester la voix · **W** diagnostic audio ·
**M** couper la voix

</details>

## 🔨 Compiler

1. [Delphi 12](https://www.embarcadero.com/products/delphi) (Community Edition convient) avec VCL ;
2. ouvrir le projet, **Construire** — tout est dans ce dépôt ;
3. lancer. Observer le monde.

## 📸 Aperçu

| | |
|:---:|:---:|
| *La ville au crépuscule* | *Les yeux d'un sapiens* |
| *L'Observatoire* | *La fiche d'une ville* |

## 📜 Licence

*(à choisir — voir fichier LICENSE)*

---

<div align="center">

*Microcosme est une boîte de vie contemplative : on n'y gagne rien, on n'y perd rien.
On sème, on regarde — et l'histoire s'écrit toute seule.*

</div>

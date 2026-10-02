Le document

Crée docs/GUERRE.md dans le dossier du projet (avec le Bloc-notes ou n'importe quel éditeur) et colle tout le bloc ci-dessous :
LA GUERRE — note de design (congelée)

    Statut : design acté, RIEN n'est implémenté. Étape 1 prête à coder dèsles tranchages (§2) faits et les colles (§6) reçues.En ouverture de séance guerre : relire §2, §6, §9. Rien d'autre.

1. Principe (acté)

Émergent, JAMAIS de bouton. Trois conditions se cumulent pour déclencherle pillage : la faim + l'armement (métal, PeopleHas) + un camp étrangerà grenier plein. La guerre naît du monde ou ne naît pas.
2. Quatre tranchages EN OUVERTURE de séance

(recos du pilote — décision du créateur EN ATTENTE, jamais formelle)

    Morts de sapiens par sapiens ? — reco OUI (le prix du réalisme ;inerte en étape 1 de toute façon, ne mord qu'à l'étape 2).
    Tribus seulement ou villes aussi ? — reco LES DEUX, échelonnés :l'étape 1 cible hameaux uniquement (Ville = nil des deux côtés),donc les villes sont de facto protégées sans une ligne de code.
    Degré de violence ? — reco pillage d'abord, ZÉRO mort en étape 1 ;la victime ne reçoit qu'une trace mémoire (K=2).
    Curseur réglages ? — reco OUI : WAR_P:Single=1.0 (0 = jamais,3 = forcé pour tests), indice 37, CNALL 37→38, section INI « Monde »,onglet « Le monde » ou « Villes & routes » à décider sur place.

3. Freins de design (actés)

    exige abondance relative OU famine aiguë (jamais la misère sèche) ;
    feux protecteurs, comme les loups (déléguer leur test — conv. 4) ;
    fuite possible → réfugiés vers les villes (lien avec l'ère 9) ;
    se battre coûte cher : rentable seulement contre greniers pleins ;
    villes ère 4+ : remparts = gros malus d'attaque (inexpugnables).

4. Ancrages de code VÉRIFIÉS (lire le vrai code, jamais ce résumé)
4.1 Porteurs de données (MicroTypes)

    THut = class : X, Y: Single ; Fire, Cult: Boolean ; Stock: Single ;Ville: TCity (nil = isolée). PAS de champ Tribu (à ajouter).
    TCreature : champs utiles — Kind (2 = sapien), Energy/MaxE, Age/MaxAge,TargetC/TargetP, GuardC, AtkCd: Single, HomeH: THut, Mem: TArray,Cult, Tech: TTechs, InnoK, Piloted, CId/ParentId.PAS de Tribu ni TargetH (à ajouter). PAS de champ « Stock » individuel :le grenier vit dans la hutte.
    TMemRec = record X, Y: Single ; K: Integer (0 danger, 1 nourriture ;la guerre ajoutera 2 « ennemi vu ici ») ; T: Single.Purge AUTONOME : T += DT, expire à MEMLIFE=70, plafond MEMMAX=6.→ K=2 ne demande AUCUN changement au record ni à la purge.
    L'unité Graph3D a déjà un Bruit(IX,IY) hash déterministe — le pillagen'en a pas besoin, mais toute randomisation spatiale s'en inspirera.

4.2 Sites d'insertion

    NewWorld : vit dans MicroMain (PAS MicroSim ! — piège corrigé enséance). Les 5 clans fondateurs EXISTENT (25 sapiens, clan 1 au centre→ FHomeX/FHomeY, les autres au hasard). Re-taggage tribu à poser dansce bloc : Tribu := G-1 (0..4).
    Filet d'immigration (MicroSim, grep CfgImmig) : si CountS < 4 etCfgImmig > 0 → immigrants en FHomeX±6/FHomeY±6 + Toast L(113) +ChronAdd CK_PEOPLE L(114). Tribu des immigrants : à trancher(reco : -1, sans clan ; ou tribu du hameau le plus proche).
    SpawnCreature (MicroSim) : init commune vers « C.HomeH := nil » →poser C.Tribu := -1 (et C.TargetH := nil à l'étape 1) ;héritage dans le bloc Kind=2 Parent<>nil, à côté de« C.InnoK := Parent.InnoK » → C.Tribu := Parent.Tribu (parent seul,pas de mélange Parent2).
    TryBuild (MicroSim) : TROIS créations de hutte — (a) banlieue citadineère 2+, rayon 8-20 : H.Ville := Cities[K] (né citadin) → Tribu := -1 ;(b) greffe hameau spirale d'or : H.Ville := nil → Tribu := C.Tribu ;(c) pionnier à > HAMEAU_DIST : H.Ville := nil → Tribu := C.Tribu.Style de la maison : payer (énergie/BuildCd) au DERNIER moment.
    StepSapien : le bloc « garde du hameau » (GuardC=nil + Age>CHILDHOOD +NearestHutDist<9 … + ChronAdd L175) est le voisin d'accueil du blocraid — même niveau de priorité.

4.3 Invariants Kill (lue en séance, à retrouver par grep « procedure Kill »)

    Kill(C, Cause: string) : Alive := False — le corps RESTE dansCreatures, JAMAIS de Free → tout test de créature exige .Alive.
    DeathLog : CId, Name, Cause, Day, Gen, ParentId (fiche lignée).
    Cause est une CHAÎNE DÉJÀ TRADUITE (Kill compare à L(101) famine,L(102) vieillesse) → la guerre ajoutera sa cause via un NOUVEL id L(),et toute classification de cause compare à L(), jamais en dur.
    Plante (« fleur ») sur le mort à 35 % sauf famine/vieillesse.
    Nettoyage automatique des pointeurs : SPred, TargetC, Mentor, SHerb,GuardC, Master, SPeer → AJOUTER TargetH dans cette liste à l'étape 2(et dès l'étape 1 si un pillard peut mourir en route).
    Compteurs Kind 0..5 décrémentés (fix CountO/CountM posé en séance).

4.4 Pièges connus

    State est une STRING TRADUITE (C.State := L(50)) : ne JAMAIS testerState = '...' en dur — cohabiter par mécanismes (targets nil,GuardC nil), étiqueter par L().
    Conv. 20 : tout nouvel id L() se pose dans LES DEUX tableaux AVANT decompiler (absent = AV silencieuse du thread sim).
    Conv. 21 : WAR_P et tout réglage vivent dans l'INTERFACE de MicroTypes,et on vérifie sa position relative à implementation après collage.
    Conv. 12 : le raid lit Huts/Homes dans le thread sim — naturel, ne pasy toucher depuis les fenêtres sans FSimCS.
    Conv. 5/9 : collages cochés numérotés, un seul exemplaire par bloc.

5. Ce qui a changé depuis le premier design

    Les 5 clans fondateurs existent (avant : monde neuf sans sapiens, lefilet déposait 6 immigrants tardifs — voir §4.2).
    Kill décompte ours/moutons (avant : populations fantômes du panneau).
    NewWorld localisé : MicroMain, pas MicroSim.

6. Colles encore manquantes (demander AVANT de coder — conv. 13)

    La mécanique Stock en action (n°1 en importance) : la ligne quiincrémente (CollectNear ?) et celle(s) qui décrémentent (repas ?).→ cale FAMINE et GRENIER_PLEIN sur l'échelle RÉELLE, pas au pif.
    StepCreature, partie chasse/combat du loup : portée, rôle exactd'AtkCd, dégâts, appel Kill. L'étape 2 RETOURNE ce code (conv. 4 :même mécanique que le berger, retournée — jamais copiée).
    Le frein feu des loups : la ligne où un prédateur renonce près d'unfoyer → délégué tel quel au pillard.
    ChronAdd : signature + liste complète des CK_* (CK_LIFE, CK_PEOPLEvus) → choisir la catégorie, ou créer CK_WAR si le style le permet.
    Où HomeH est assigné au sapien adulte (procédure + conditions).
    Existe-t-il un retrait de Huts quelque part ? → répond si la gardeHuts.IndexOf(TargetH) >= 0 est gratuite ou vitale (elle est poséedans tous les cas).
    Noms exacts des techs métal dans TEcode (bronze/fer) → PeopleHas(?).
    Les 10 premières lignes d'implementation de MicroSim ET MicroTypes.
    Un réglage MicroConfig en exemplaire complet (EXODE_7 : Defaults,CfgGet, CfgSet, MinMax, Name, Text, SaveCfg, LoadCfg + la ligne decréation [-][+] de l'onglet) → cloner en WAR_P indice 37.

7. Plan étape 1 — pillage non-létal (une séance)
7.1 Modifications par unité

    MicroTypes (interface, conv. 21) : TCreature.Tribu: Integer (-1 défaut),THut.Tribu: Integer, TCreature.TargetH: THut, WAR_P: Single = 1.0.
    MicroLang : L176 « %s a pillé un grenier rival » / « %s plundered arival granary » (+ L177 si une seconde annale s'impose) — LES DEUXtableaux AVANT de compiler.
    MicroMain/NewWorld : Tribu := G-1 dans le bloc des 5 clans.
    MicroSim : SpawnCreature (init + héritage), TryBuild (3 sites),StepSapien (bloc raid à côté du garde du hameau).
    MicroConfig : indice 37, MinMax 0..3, défaut 1, section « Monde ».
    Constantes de calibrage (seuils famine/grenier, RAID_DIST) en constLOCALES de MicroSim cette étape — promenées en var MicroTypes seulementsi l'observation les condamne.
    ZÉRO appel à Kill() cette étape. Q1 (morts) ne mord qu'à l'étape 2.

7.2 Conditions du raid (l'ordre compte — toutes obligatoires)

Tribu >= 0, et HomeH <> nil, et HomeH.Ville = nil (le pillard esthameaudeux) ; famine : Energy bas ET HomeH.Stock bas (seuils §6.1) ;PeopleHas(métal) ; cible existante : autre Tribu, Ville = nil,Stock « plein » (seuil §6.1), à portée RAID_DIST ; frein feux (§6.3) ;tirage Random < DT * WAR_P. Cible mémorisée dans TargetH, gardeHuts.IndexOf(TargetH) >= 0 chaque tic.
7.3 À l'arrivée sur la cible

Transfert HomeH.Stock += pris / TargetH.Stock -= pris ; annale UNE fois(ChronAdd, L176) ; TMemRec K=2 « ennemi vu ici » chez la victime présente(écriture seule cette étape — lecture/ralliement = étape 2) ;TargetH := nil, retour au foyer.
7.4 Protocole d'observation

Monde neuf → triche E (ère 3-4 + pop). WAR_P à 3 pour la démo, 1.0 pourobserver ~10 générations. Vérifier : pas de pillage sans différentiel degreniers ; pas de spam d'annales ; les 5 clans intacts à la génération 0 ;héritage Tribu correct (fiche/généalogie). Ne pas toucher MicroHelp cetteétape — la page « guerre » naîtra à l'étape 2 avec le combat réel.
8. Étapes suivantes (esquisse, NON engagée)

    Étape 2 : combat retourné (GuardC/AtkCd/Kill retournés — même code quele berger) ; Q1 mord ici ; ralliement par cri (le lexique du carnetdevinera « cri de guerre ? ») + LECTURE de K=2 ; représailles notéesaux annales (spirale de représailles).
    Étape 3 : villes — remparts ère 4+ inexpugnables ; réfugiés → villes(lien ère 9).
    Curseur WAR_P visible F2 (§2.4).

9. Numérotation L() — conflit résolu

Le design ère 9 réservait L176 (« V. n'est plus ») mais RIEN n'est poséaprès L175. Décision : la guerre prend L176 (+177 si besoin) ; l'ère 9glissera — append-only le permet, ses ids n'existent pas encore.Rappel ère 9 : son préalable technique TTechs 64→71 reste ouvert
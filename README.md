# Kevencre · la dernière goutte d'encre

Un jeu de plateforme 2D original, peint à l'aquarelle, fait avec **Godot 4.3**.
Tranche jouable : 3 chapitres + le combat contre le Délaveur, environ 15 minutes.

Le monde a perdu ses couleurs : le Délaveur, un géant de térébenthine grise, les a toutes bues.
Tu joues **Sépia**, la dernière goutte d'encre. Partout où elle passe, la couleur revient un peu autour d'elle ;
chaque chevalet touché, chaque Tache repeinte rend durablement ses couleurs au paysage.

## Lancer le jeu
1. Ouvre Godot 4.3 (ou plus récent en 4.x).
2. « Importer » → choisis le fichier `project.godot` de ce dossier.
3. Appuie sur **F5** (ou le bouton ▶ en haut à droite).

La première ouverture prend quelques secondes (Godot importe les peintures et les sons).
Sur Mac, en ligne de commande : `godot --path <ce dossier>`

## Commandes
| Action | Clavier | Manette |
|---|---|---|
| Courir | ← → ou A / D (Q / D en AZERTY) | croix / stick |
| Sauter (maintenir = plus haut) | Espace, C ou K | A |
| Rebondir contre un mur | sauter en touchant un mur | A |
| **Trait d'encre** (8 directions) | X, J ou Maj + direction | X ou RB |
| Passer les dialogues | Espace ou Entrée | A |
| Pause | Échap ou P | Select |

## La capacité signature : le Trait d'encre
Au chapitre 1, le Vieux Pinceau donne à Sépia son dernier geste. Sépia fend l'air d'un coup de pinceau,
et **son trajet reste peint dans l'air pendant près de 2 secondes** :
- un trait horizontal ou en diagonale devient une **plateforme** sur laquelle on se pose et d'où l'on ressaute ;
- un trait vers le haut ou vers le bas devient un **mur** contre lequel on peut rebondir ;
- traverser une Tache, un Corbac ou une goutte grise avec le trait les **repeint** (et recharge le trait).

Le trait se recharge en touchant le vrai sol (pas ton propre trait !), sur les fleurs-ressorts et avec les gouttes rouges.
Chaque trait prend une couleur différente : outremer, vermillon, ocre, viridian, pourpre.

## Les chapitres
1. **Les Prés Délavés** : courir, sauter, rebondir sur les murs, l'autel du Vieux Pinceau, les premiers grands vides, le papier qui se déchire.
2. **La Forêt d'Aquarelle** : fleurs-ressorts, sous-bois aux ronces, la grande cascade à remonter, Corbacs et Crachins.
3. **Les Falaises d'Ocre** : une ascension verticale jusqu'à l'atelier.
4. **Le Délaveur** : un combat en 3 phases (coups de poing, pluie grise, vagues, puis l'atelier inondé). Quand il frappe le sol, son cœur s'ouvre : frappe-le d'un Trait d'encre ou d'un saut.

Le menu « Chapitres » de l'écran titre permet d'aller directement à n'importe quel chapitre.

## Secrets
Cinq **pigments légendaires** sont cachés (2 dans les prés, 2 dans la forêt, 1 dans les falaises), souvent derrière un faux mur qui s'efface quand on passe à travers.
Chacun donne **+1 goutte de vie** et raconte un petit souvenir. Avec les cinq, la fin est différente.
On compte aussi les gouttes d'encre ramassées, le temps et les chutes.

## Organisation du projet
- `scripts/` : le jeu (Player = Sépia, Stroke = Trait d'encre, Level, Boss, Hud, Title…), `scripts/ent/` : objets et ennemis.
- `levels/` : les 3 niveaux sous forme de grilles de caractères (générées par `tools/build_levels.py`).
- `art/` : toutes les peintures (terrain, fonds en parallaxe, écran titre, fins), générées par `tools/paint.py` à partir des niveaux.
- `audio/` : 6 musiques et 28 bruitages synthétisés par `tools/audio_synth.py`.
- `shaders/couleur.gdshader` : l'effet « monde délavé / couleur qui revient ».
- `tools/AutoTest.gd` : test qui joue le jeu tout seul et prend des captures (`godot --path . -- --shots=/chemin`) ; `tools/Metrics.gd` mesure les sauts (`-- --metrics`).

Pour modifier un niveau : édite `tools/build_levels.py`, puis relance `python3 tools/build_levels.py` et `python3 tools/paint.py`.

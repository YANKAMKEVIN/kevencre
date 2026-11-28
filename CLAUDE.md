# Kevencre

Jeu de plateforme 2D peint à l'aquarelle, **Godot 4.3**, GDScript. Kevin décide du game design ; ne pas changer le gameplay ni les niveaux sans son accord (sauf bug avéré, décrit dans le commit).

## Règles

1. Une tâche n'est finie que si `GODOT=… tools/test.sh` est vert (import, tailles, scripts, tests, parcours) ; avant une fusion, la CI GitHub doit être verte (dont le robot `tools/ci.sh`).
2. **Aucun script de plus de 400 lignes** (`tools/check_sizes.sh`, bloquant en CI) : on découpe en modules (`scripts/level/`, `scripts/player/`).
3. Logique pure séparée des nœuds quand c'est possible (`SaveData`, `LevelGrid`), testée dans `tests/unit/`.
4. Sauvegarde : toute évolution du format incrémente `SaveData.VERSION` et ajoute une étape dans `SaveData.MIGRATIONS`, avec un test. Jamais d'écrasement d'une sauvegarde plus récente.
5. Pas d'allocation inutile dans `_process` / `_physics_process` (tableaux réutilisés, voir `Level._update_color`, `PlayerLook`).
6. Un changement de physique de Sépia (`Player.gd`) doit garder le modèle `tests/parcours/MoveSim.gd` fidèle : le volet « modèle contre moteur » de `--parcours` échoue sinon.
7. Modifier un niveau : `tools/build_levels.py` puis `tools/paint.py` ; `--parcours` dit si le chapitre reste faisable.
8. Commits petits, en français. Ne jamais désactiver un test pour obtenir du vert.

## Commandes

```bash
tools/install_godot.sh                     # Godot 4.3 vérifié dans .godot-bin/
GODOT=… tools/test.sh [import|sizes|check|unit|parcours]
godot --headless --path . --fixed-fps 60 -- --unit --tests=save,boss
godot --headless --path . --fixed-fps 60 -- --parcours --niveau=2 --verbose
GODOT=… tools/ci.sh                        # robot, partie complète (xvfb)
```

## Tests

`tests/Runner.gd` lance chaque méthode `test_*` des fichiers `tests/unit/test_*.gd` et `tests/integration/test_*.gd` (base : `tests/TestCase.gd`, avec `make_level(grille)` pour construire un petit chapitre et `player.auto_input` pour piloter Sépia). Chaque test part d'une partie neuve et d'une sauvegarde de test isolée.

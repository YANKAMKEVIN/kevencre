extends Node
## Tests unitaires de la logique pure (sauvegarde).
## Lancement : godot --headless --path . -- --unit   (code de sortie 1 si un test échoue)

var fails := 0
var count := 0

func check(cond: bool, what: String) -> void:
	count += 1
	print(("OK    " if cond else "ECHEC ") + what)
	if not cond:
		fails += 1

func _ready() -> void:
	_test_format()
	_test_migration()
	_test_rejets()
	_test_fichier()
	print("RESULTAT : %d test(s), %d échec(s)" % [count, fails])
	get_tree().quit(1 if fails > 0 else 0)

func _partie() -> Dictionary:
	return SaveData.make(2, true, {"1:40:12": 0, "1:88:5": 1}, 12, {"1:3:4": true, "2:7:7": true}, 3, 312.5,
		{1: Vector2(4200, 1056), 2: Vector2(960.5, 480)}, {1: [[Vector2(100, 200), 180.0]]})

func _test_format() -> void:
	var d := _partie()
	check(d["version"] == SaveData.VERSION, "la sauvegarde porte la version courante")
	check(SaveData.is_valid(d), "une partie normale est valide")
	var back := SaveData.parse(SaveData.to_text(d))
	check(back == d, "aller-retour JSON sans perte (types compris)")
	check(SaveData.checkpoints_of(back)[2] == Vector2(960.5, 480), "chevalet relu en Vector2, au demi-pixel près")
	check(SaveData.restored_of(back)[1][0][0] == Vector2(100, 200) and SaveData.restored_of(back)[1][0][1] == 180.0, "couleur rendue au paysage relue")

func _test_migration() -> void:
	var futur := _partie(); futur["version"] = SaveData.VERSION + 1
	check(SaveData.parse(SaveData.to_text(futur)).is_empty(), "une sauvegarde d'une version plus récente est refusée")
	var sans := _partie(); sans.erase("version")
	check(SaveData.parse(SaveData.to_text(sans)).is_empty(), "un fichier sans version est refusé")

func _test_rejets() -> void:
	check(SaveData.parse("").is_empty(), "fichier vide refusé")
	check(SaveData.parse("{abîmé").is_empty(), "JSON cassé refusé")
	var d := _partie(); d["level"] = 9
	check(not SaveData.is_valid(d), "niveau inconnu refusé")
	d = _partie(); d["pigments"]["x"] = 7
	check(not SaveData.is_valid(d), "pigment inconnu refusé")
	d = _partie(); d["checkpoint"]["1"] = [1]
	check(not SaveData.is_valid(d), "position de chevalet abîmée refusée")
	d = _partie(); d["deaths"] = -1
	check(not SaveData.is_valid(d), "compteur négatif refusé")

func _test_fichier() -> void:
	var old_path := Game.save_path
	Game.save_path = "user://test_sauvegarde.json"
	DirAccess.remove_absolute(Game.save_path)
	check(Game.load_game() == 0, "pas de fichier : rien à reprendre")
	Game.new_game()
	Game.level = 3; Game.has_brush = true; Game.pigments = {"2:5:5": 3}; Game.deaths = 4; Game.time = 99.0
	Game.checkpoint = {3: Vector2(500, 600)}
	check(Game.save_game(), "écriture de la sauvegarde")
	check(not FileAccess.file_exists(Game.save_path + ".tmp"), "pas de fichier temporaire laissé derrière")
	Game.new_game()
	check(Game.load_game() == 3, "reprise au bon chapitre")
	check(Game.has_brush and Game.pigments.get("2:5:5") == 3 and Game.deaths == 4, "pinceau, pigments et chutes restaurés")
	check(Game.checkpoint.get(3) == Vector2(500, 600), "reprise au dernier chevalet")
	check(Game.max_hp() == 6, "le pigment donne toujours sa goutte de vie après rechargement")
	var f := FileAccess.open(Game.save_path, FileAccess.WRITE); f.store_string("{abîmé"); f.close()
	check(Game.load_game() == 0, "fichier abîmé : pas de plantage, rien à reprendre")
	DirAccess.remove_absolute(Game.save_path)
	Game.save_path = old_path
	Game.new_game()

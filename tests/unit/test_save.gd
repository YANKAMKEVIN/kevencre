extends "res://tests/TestCase.gd"
## Sauvegarde : format versionné, migrations, rejets, fichier absent ou abîmé, copie de secours.


func _partie() -> Dictionary:
	return SaveData.make(2, true, {"1:40:12": 0, "1:88:5": 1}, 12, {"1:3:4": true, "2:7:7": true}, 3, 312.5,
		{1: Vector2(4200, 1056), 2: Vector2(960.5, 480)}, {1: [[Vector2(100, 200), 180.0]]})


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func test_format() -> void:
	var d := _partie()
	check(d["version"] == SaveData.VERSION, "la sauvegarde porte la version courante")
	check(SaveData.is_valid(d), "une partie normale est valide")
	var back := SaveData.parse(SaveData.to_text(d))
	check(back == d, "aller-retour JSON sans perte (types compris)")
	check(SaveData.checkpoints_of(back)[2] == Vector2(960.5, 480), "chevalet relu en Vector2, au demi-pixel près")
	check(SaveData.restored_of(back)[1][0][0] == Vector2(100, 200) and SaveData.restored_of(back)[1][0][1] == 180.0, "couleur rendue au paysage relue")


func test_versions_refusees() -> void:
	var futur := _partie(); futur["version"] = SaveData.VERSION + 1
	check(SaveData.parse(SaveData.to_text(futur)).is_empty(), "une sauvegarde d'une version plus récente est refusée")
	var sans := _partie(); sans.erase("version")
	check(SaveData.parse(SaveData.to_text(sans)).is_empty(), "un fichier sans version est refusé")
	var zero := _partie(); zero["version"] = 0
	check(SaveData.parse(SaveData.to_text(zero)).is_empty(), "version 0 refusée")
	var texte := _partie(); texte["version"] = "1"
	check(SaveData.parse(SaveData.to_text(texte)).is_empty(), "version écrite en texte refusée")
	var demi := _partie(); demi["version"] = 1.5
	check(SaveData.migrate(demi).is_empty(), "version non entière refusée")


func test_migration_en_chaine() -> void:
	var calls: Array = []
	var v1_to_v2 := func(d: Dictionary) -> Dictionary:
		calls.append(1)
		var o := d.duplicate(true); o["chutes"] = o["deaths"]; return o
	var v2_to_v3 := func(d: Dictionary) -> Dictionary:
		calls.append(2)
		var o := d.duplicate(true); o.erase("deaths"); return o
	var old := _partie(); old["version"] = 1
	var out := SaveData.migrate_with(old, {1: v1_to_v2, 2: v2_to_v3}, 3)
	eq(out.get("version"), 3, "une sauvegarde v1 passe par toutes les étapes jusqu'à v3")
	eq(calls, [1, 2], "les étapes sont appliquées dans l'ordre, une seule fois")
	check(out.get("chutes") == 3 and not out.has("deaths"), "les données sont transformées par les étapes")
	check(old.has("deaths") and old["version"] == 1, "la sauvegarde d'origine n'est pas modifiée")
	var v2 := _partie(); v2["version"] = 2
	calls.clear()
	SaveData.migrate_with(v2, {1: v1_to_v2, 2: v2_to_v3}, 3)
	eq(calls, [2], "une sauvegarde v2 ne repasse pas par l'étape v1")
	check(SaveData.migrate_with(old, {2: v2_to_v3}, 3).is_empty(), "une étape manquante : sauvegarde refusée, pas de plantage")
	var broken := func(_d: Dictionary) -> Dictionary: return {}
	check(SaveData.migrate_with(old, {1: broken}, 2).is_empty(), "une étape qui échoue : sauvegarde refusée")
	var by_name := SaveData.migrate_with(old, {1: "checkpoints_of"}, 2)
	eq(by_name.get("version"), 2, "une étape peut être une fonction statique de SaveData, donnée par son nom")


func test_migration_courante() -> void:
	for v in range(1, SaveData.VERSION):
		check(SaveData.MIGRATIONS.has(v), "il existe une étape de migration depuis la version %d" % v)
	var d := _partie()
	var text := SaveData.to_text(d)
	check(SaveData.parse(text) == d, "une sauvegarde à la version courante se relit à l'identique")
	var j: Dictionary = JSON.parse_string(text)
	eq(typeof(SaveData.migrate(j)["level"]), TYPE_INT, "les nombres relus en flottants redeviennent entiers")


func test_rejets() -> void:
	check(SaveData.parse("").is_empty(), "fichier vide refusé")
	check(SaveData.parse("{abîmé").is_empty(), "JSON cassé refusé")
	check(SaveData.parse("[1, 2, 3]").is_empty(), "JSON qui n'est pas un objet refusé")
	check(SaveData.parse("null").is_empty(), "JSON null refusé")
	check(SaveData.parse(" ".repeat(SaveData.MAX_BYTES + 1)).is_empty(), "fichier démesuré refusé")
	var d := _partie(); d["level"] = 9
	check(not SaveData.is_valid(d), "niveau inconnu refusé")
	d = _partie(); d["level"] = "2"
	check(not SaveData.is_valid(d), "niveau écrit en texte refusé")
	d = _partie(); d["pigments"]["x"] = 7
	check(not SaveData.is_valid(d), "pigment inconnu refusé")
	d = _partie()
	for i in 6:
		d["pigments"]["k%d" % i] = 0
	check(not SaveData.is_valid(d), "plus de 5 pigments refusé")
	d = _partie(); d["checkpoint"]["1"] = [1]
	check(not SaveData.is_valid(d), "position de chevalet abîmée refusée")
	d = _partie(); d["checkpoint"]["7"] = [1, 2]
	check(not SaveData.is_valid(d), "chevalet d'un niveau inconnu refusé")
	d = _partie(); d["restored"]["1"] = [[1, 2]]
	check(not SaveData.is_valid(d), "couleur rendue abîmée refusée")
	d = _partie(); d["deaths"] = -1
	check(not SaveData.is_valid(d), "compteur négatif refusé")
	d = _partie(); d["has_brush"] = 1
	check(not SaveData.is_valid(d), "pinceau qui n'est pas un booléen refusé")
	d = _partie(); d.erase("time")
	check(not SaveData.is_valid(d), "temps manquant refusé")


func test_fichier() -> void:
	check(Game.load_game() == 0, "pas de fichier : rien à reprendre")
	check(Game.read_save().is_empty(), "pas de fichier : Continuer n'apparaît pas")
	Game.level = 3; Game.has_brush = true; Game.pigments = {"2:5:5": 3}; Game.deaths = 4; Game.time = 99.0
	Game.checkpoint = {3: Vector2(500, 600)}
	check(Game.save_game(), "écriture de la sauvegarde")
	check(not FileAccess.file_exists(Game.save_path + ".tmp"), "pas de fichier temporaire laissé derrière")
	Game.new_game()
	check(Game.load_game() == 3, "reprise au bon chapitre")
	check(Game.has_brush and Game.pigments.get("2:5:5") == 3 and Game.deaths == 4, "pinceau, pigments et chutes restaurés")
	check(Game.checkpoint.get(3) == Vector2(500, 600), "reprise au dernier chevalet")
	check(Game.max_hp() == 6, "le pigment donne toujours sa goutte de vie après rechargement")


func test_fichier_abime_sans_copie() -> void:
	_write(Game.save_path, "{abîmé")
	check(Game.load_game() == 0, "fichier abîmé sans copie : pas de plantage, rien à reprendre")
	Game.level = 2
	check(Game.save_game(), "on peut de nouveau sauvegarder par-dessus un fichier abîmé")
	check(not FileAccess.file_exists(Game.backup_path()), "un fichier abîmé n'est jamais gardé comme copie de secours")
	check(Game.load_game() == 2, "la nouvelle sauvegarde se relit")


func test_copie_de_secours() -> void:
	Game.level = 2; Game.deaths = 1
	Game.save_game()
	check(not FileAccess.file_exists(Game.backup_path()), "première sauvegarde : pas encore de copie")
	Game.level = 3; Game.deaths = 5
	Game.save_game()
	var bak := SaveData.parse(FileAccess.get_file_as_string(Game.backup_path()))
	eq(bak.get("level"), 2, "la sauvegarde précédente est gardée en copie de secours")
	_write(Game.save_path, "{\"version\": 1, \"level\": ")   # écriture interrompue
	Game.new_game()
	eq(Game.load_game(), 2, "fichier principal abîmé : reprise depuis la copie de secours")
	eq(Game.deaths, 1, "les compteurs viennent de la copie")
	DirAccess.remove_absolute(Game.save_path)
	Game.new_game()
	eq(Game.load_game(), 2, "fichier principal supprimé : reprise depuis la copie")
	_write(Game.backup_path(), "pas du JSON")
	check(Game.load_game() == 0, "les deux fichiers abîmés : rien à reprendre, pas de plantage")


func test_dossier_inaccessible() -> void:
	Game.save_path = "user://dossier_qui_n_existe_pas/sous/sauvegarde.json"
	check(not Game.save_game(), "dossier inaccessible : l'écriture échoue proprement")
	check(Game.load_game() == 0, "dossier inaccessible : rien à reprendre")


func test_sauvegarde_invalide_jamais_ecrite() -> void:
	Game.level = 12
	check(not Game.save_game(), "une partie incohérente n'est pas écrite")
	check(not FileAccess.file_exists(Game.save_path), "aucun fichier créé")

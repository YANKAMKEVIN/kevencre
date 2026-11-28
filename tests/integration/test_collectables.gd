extends "res://tests/TestCase.gd"
## Gouttes d'encre, pigments légendaires, chevalets, sortie, faux murs et ennemis.


func _row(chars: Dictionary) -> Array:
	return box(30, 16, 12, chars)


func test_goutte() -> void:
	var l := await make_level(_row({Vector2i(10, 11): "*", Vector2i(4, 12): "S"}), 1)
	var p: CharacterBody2D = l.player
	await place(l, 6, 12)
	eq(Game.drops, 0, "aucune goutte au départ")
	p.global_position = foot(10, 11)
	await phys(3)
	eq(Game.drops, 1, "toucher une goutte la ramasse")
	check(Game.drops_level.has("1:10:11"), "la goutte est notée comme ramassée (niveau:x:y)")
	await phys(3)
	eq(Game.drops, 1, "une goutte ne se ramasse qu'une fois")
	l.queue_free()
	await phys(2)
	var l2 := await make_level(_row({Vector2i(10, 11): "*", Vector2i(4, 12): "S"}), 1)
	var left: Array = l2.world.get_children().filter(func(n: Node) -> bool:
		return n.get_script() != null and n.get_script().resource_path.ends_with("Drop.gd"))
	eq(left.size(), 0, "au retour dans le chapitre, la goutte ramassée n'est plus là")


func test_pigment() -> void:
	var l := await make_level(_row({Vector2i(12, 11): "P", Vector2i(4, 12): "S"}), 2)
	var p: CharacterBody2D = l.player
	await place(l, 6, 12)
	p.hp = 2
	eq(Game.max_hp(), 5, "5 gouttes de vie sans pigment")
	p.global_position = foot(12, 11)
	await phys(3)
	eq(Game.pigment_count(), 1, "le pigment est ramassé")
	eq(Game.pigments.get("2:12:11"), 2, "premier pigment du chapitre 2 : l'Ocre (index 2)")
	eq(Game.max_hp(), 6, "+1 goutte de vie")
	eq(p.hp, 6, "le pigment remplit la vie")
	check(l.waves.size() > 0, "la couleur revient autour du pigment")
	check(Game.restored.has(2), "la couleur rendue est gardée pour la sauvegarde")


func test_chevalet() -> void:
	var l := await make_level(_row({Vector2i(14, 12): "C", Vector2i(4, 12): "S"}), 1, false)
	var p: CharacterBody2D = l.player
	check(Game.load_game() == 1, "le début de chapitre est sauvegardé")
	Game.has_brush = false
	await place(l, 8, 12)
	p.hp = 1
	p.global_position = foot(14, 12)
	await phys(3)
	var cp: Vector2 = Game.checkpoint.get(1, Vector2.ZERO)
	check(cp.distance_to(foot(14, 12)) < 1.0, "toucher le chevalet enregistre la reprise")
	eq(p.hp, Game.max_hp(), "le chevalet soigne")
	var saved := Game.read_save()
	check(not saved.is_empty() and SaveData.checkpoints_of(saved).get(1, Vector2.ZERO).distance_to(cp) < 1.0, "le chevalet écrit la sauvegarde")
	# mort : retour au chevalet, pas au départ
	await place(l, 22, 12)
	p.invuln = 0.0
	p.hp = 1
	p.hurt(p.global_position + Vector2(10, 0))
	check(await until(func() -> bool: return not p.dead, 600), "Sépia revient après sa chute")
	check(p.global_position.distance_to(cp) < 4.0, "retour au dernier chevalet touché")
	# rechargement : on repart du chevalet, déjà peint
	l.queue_free()
	await phys(2)
	Game.new_game()
	eq(Game.load_game(), 1, "la sauvegarde se recharge")
	var l2 := await make_level(_row({Vector2i(14, 12): "C", Vector2i(4, 12): "S"}), 1, true)
	check(l2.player.global_position.distance_to(cp) < 24.0, "au rechargement, Sépia repart du chevalet")
	check(l2.checkpoints[0].active, "le chevalet est déjà peint au rechargement")


func test_chevalet_en_rejeu() -> void:
	var l := await make_level(_row({Vector2i(14, 12): "C", Vector2i(4, 12): "S"}), 1, true)
	var p: CharacterBody2D = l.player
	await place(l, 8, 12)
	p.global_position = foot(14, 12)
	await phys(3)
	check(Game.checkpoint.has(1), "en rejeu (menu Chapitres), le chevalet sert de reprise")
	check(not FileAccess.file_exists(Game.save_path), "mais n'écrase pas la sauvegarde")


func test_sortie() -> void:
	var l := await make_level(_row({Vector2i(20, 12): "G", Vector2i(4, 12): "S"}), 1)
	var p: CharacterBody2D = l.player
	await place(l, 8, 12)
	check(not l.finished, "chapitre en cours")
	Game.checkpoint[1] = foot(8, 12)
	p.global_position = foot(20, 12)
	await phys(3)
	check(l.finished, "toucher le cadre termine le chapitre")
	check(p.frozen, "Sépia ne bouge plus pendant la victoire")
	l.queue_free()   # avant le passage au chapitre suivant


func test_faux_mur() -> void:
	var extra := {}
	for y in range(9, 13):
		extra[Vector2i(16, y)] = "X"
	var l := await make_level(_row(extra), 1)
	var p: CharacterBody2D = l.player
	await place(l, 12, 12)
	p.auto_input["x"] = 1.0
	await phys(90)
	check(p.global_position.x > 17 * TS, "on traverse un faux mur")
	var fw: Node = null
	for n in l.world.get_children():
		if n.get_script() != null and n.get_script().resource_path.ends_with("FakeWall.gd"):
			fw = n
	check(fw != null and fw.found, "le faux mur se révèle quand on passe dedans")


func test_tache_repeinte_en_sautant_dessus() -> void:
	var l := await make_level(_row({Vector2i(14, 12): "E"}), 1)
	var p: CharacterBody2D = l.player
	await place(l, 6, 12)
	var tache: Node = null
	for n in l.world.get_children():
		if n.get_script() != null and n.get_script().resource_path.ends_with("Tache.gd"):
			tache = n
	check(tache != null, "la Tache est posée")
	var hp: int = p.hp
	p.global_position = tache.global_position + Vector2(0, -90)
	p.velocity = Vector2(0, 300)
	await phys(30)
	check(not is_instance_valid(tache) or not tache.alive, "sauter sur une Tache la repeint")
	eq(p.hp, hp, "sans se blesser")


func test_tache_blesse_de_cote() -> void:
	var l := await make_level(_row({Vector2i(14, 12): "E"}), 1)
	var p: CharacterBody2D = l.player
	await place(l, 6, 12)
	var tache: Node = null
	for n in l.world.get_children():
		if n.get_script() != null and n.get_script().resource_path.ends_with("Tache.gd"):
			tache = n
	var hp: int = p.hp
	p.invuln = 0.0
	p.global_position = Vector2(tache.global_position.x, foot(0, 12).y)
	await phys(3)
	eq(p.hp, hp - 1, "toucher une Tache de côté blesse")
	check(p.invuln > 0.0, "puis une courte invulnérabilité")
	var hp2: int = p.hp
	await phys(3)
	eq(p.hp, hp2, "pas de second coup pendant l'invulnérabilité")

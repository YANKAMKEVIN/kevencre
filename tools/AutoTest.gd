extends Node
## Outil de test : joue le jeu tout seul (téléportations + combat du boss) et prend des captures.
## godot --path . -- --shots=/dossier

var out := "/tmp/kevencre_shots"
var main: Variant = null
var log_lines: Array = []
var auto_dialogue := true
var _tick := 0.0
var fails := 0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			out = a.substr(8)
	DirAccess.make_dir_recursive_absolute(out)
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.pause_on_focus_loss = false
	main = get_parent()
	await get_tree().process_frame
	await run()
	print("RESULTAT : %d échec(s)" % fails)
	print("TEST FINI")
	get_tree().quit(1 if fails > 0 else 0)  # code de sortie lu par la CI

func w(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout

func shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return   # pas d'image sans écran : le robot joue quand même toute la partie
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/" + name + ".png")
	print("SHOT ", name)

func check(cond: bool, what: String) -> void:
	print(("OK    " if cond else "ECHEC ") + what)
	if not cond:
		fails += 1

func press(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	await get_tree().process_frame
	await get_tree().process_frame
	var e2 := InputEventAction.new()
	e2.action = action
	e2.pressed = false
	Input.parse_input_event(e2)
	await get_tree().process_frame

func _process(delta: float) -> void:
	_tick += delta
	if _tick < 0.2:
		return
	_tick = 0.0
	var c: Variant = main.current
	if auto_dialogue and c and "hud" in c and c.hud and c.hud.dlg_active:
		press("jump")

func lvl() -> Variant:
	return main.current

func tp(tx: float, ty: float) -> void:
	var l: Variant = lvl()
	l.player.global_position = Vector2((tx + 0.5) * 48, (ty + 1) * 48)
	l.player.velocity = Vector2.ZERO
	l.cam.global_position = l.player.global_position
	l.cam.reset_smoothing()

func find_char(ch: String) -> Array:
	var res: Array = []
	var l: Variant = lvl()
	for y in l.H:
		for x in l.W:
			if l.grid[y][x] == ch:
				res.append(Vector2i(x, y))
	return res

func until(cond: Callable, timeout := 20.0) -> bool:
	var tt := 0.0
	while tt < timeout:
		if cond.call():
			return true
		await w(0.1)
		tt += 0.1
	return false

func run() -> void:
	# ---------------- écran titre et conte
	main.goto("title")
	await w(1.5)
	await shot("00_titre")
	Game.new_game()
	main.goto("intro")
	await w(1.4)
	await shot("01_conte")
	# on appuie jusqu'à quitter le conte (une pression pendant le délai anti-rebond est ignorée)
	for i in 10:
		if lvl() != null and "num" in lvl():
			break
		await press("jump")
		await w(0.7)
	await until(func(): return lvl() != null and "num" in lvl(), 5.0)
	await w(1.2)
	check(lvl() != null and "num" in lvl() and lvl().num == 1, "le conte mène au chapitre 1")
	await shot("10_chapitre1")
	var l: Variant = lvl()
	# ---------------- un vrai bout de course : courir et sauter le premier trou
	var p: Variant = l.player
	p.auto_input = {"x": 1.0, "y": 0.0, "jump": false, "dash": false}
	var t0 := 0.0
	var jumped := false
	while t0 < 4.0:
		await get_tree().physics_frame
		t0 += 1.0 / 120.0
		if p.is_on_floor() and (p.is_on_wall() or (not jumped and p.global_position.x > 24.0 * 48)):
			p.auto_input["jump_p"] = true
			p.auto_input["jump"] = true
			if p.global_position.x > 24.0 * 48:
				jumped = true
		elif p.velocity.y > 0:
			p.auto_input["jump"] = false
		if p.global_position.x > 30 * 48:
			break
	p.auto_input["jump"] = false
	await w(0.3)
	await until(func(): return not p.frozen and not l.hazard_lock, 3.0)
	check(p.global_position.x > 28 * 48 and not p.dead and p.global_position.y < 23 * 48, "Sépia court et saute le premier trou (x=%.1f)" % (p.global_position.x / 48.0))
	await shot("11_premier_saut")
	p.auto_input = {}
	# ---------------- repeindre une Tache en lui sautant dessus
	var taches := get_tree().get_nodes_in_group("_none")
	var enemy: Variant = null
	for n in l.world.get_children():
		if n.get_script() and n.get_script().resource_path.ends_with("Tache.gd"):
			enemy = n
			break
	if enemy:
		# un panneau peut ouvrir un dialogue (arbre en pause) : on attend qu'il soit fermé, puis on retente
		for essai in 4:
			await until(func(): return not (l.hud and l.hud.dlg_active), 5.0)
			if not is_instance_valid(enemy):
				break
			p.global_position = enemy.global_position + Vector2(0, -120)
			p.velocity = Vector2(0, 200)
			await w(0.8)
			if not is_instance_valid(enemy):
				break
		check(not is_instance_valid(enemy), "sauter sur une Tache la repeint")
		await shot("12_tache_repeinte")
	# ---------------- secret 1 (pigment dans le pilier)
	var pigs := find_char("P")
	check(pigs.size() == 2, "chapitre 1 : 2 pigments cachés")
	tp(pigs[0].x, pigs[0].y)
	await w(0.6)
	check(Game.pigment_count() == 1, "ramasser un pigment (+1 vie : %d)" % Game.max_hp())
	await shot("13_pigment")
	await w(1.0)
	# ---------------- l'autel du Vieux Pinceau
	var k: Vector2i = find_char("K")[0]
	tp(k.x - 1, k.y)
	await w(2.2)
	await shot("14_vieux_pinceau")
	await until(func(): return Game.has_brush, 30.0)
	check(Game.has_brush, "l'autel donne le Trait d'encre")
	await w(1.0)
	# ---------------- démonstration du Trait d'encre
	tp(108, 17)
	await w(0.5)
	p.auto_input = {"x": 1.0, "y": 0.0, "jump": false, "dash": false}
	await until(func(): return p.global_position.x > 112.3 * 48, 3.0)
	p.auto_input["jump_p"] = true
	p.auto_input["jump"] = true
	await w(0.3)
	p.auto_input["dash_p"] = true
	await w(0.2)
	await shot("15_trait_encre")
	await w(0.5)
	check(p.global_position.x > 118 * 48, "le Trait d'encre fait franchir le grand vide (x=%.1f)" % (p.global_position.x / 48.0))
	await shot("16_sur_le_trait")
	p.auto_input = {}
	await w(1.0)
	# ---------------- chevalet et mort / reprise
	var cps := find_char("C")
	tp(cps[1].x, cps[1].y)
	await w(1.0)
	await shot("17_chevalet")
	check(Game.checkpoint.has(1), "le chevalet enregistre la reprise")
	p.hp = 1
	tp(144, 19)
	await w(3.0)
	check(not p.dead and p.global_position.distance_to(Game.checkpoint[1]) < 200, "après une chute dans les ronces, Sépia revient au chevalet")
	# ---------------- second pigment et sortie
	tp(pigs[1].x, pigs[1].y)
	await w(0.6)
	check(Game.pigment_count() == 2, "second pigment du chapitre 1")
	var g: Vector2i = find_char("G")[0]
	tp(g.x, g.y)
	await w(1.5)
	await shot("18_fin_chapitre1")
	var old_id1: int = l.get_instance_id()
	await until(func(): return lvl() != null and lvl().get_instance_id() != old_id1 and lvl() != null and "num" in lvl() and lvl().num == 2, 10.0)
	check(lvl().num == 2, "la sortie mène au chapitre 2")
	# ---------------- chapitre 2
	await w(2.0)
	l = lvl()
	p = l.player
	await shot("20_chapitre2")
	for v in [Vector2i(14, 26), Vector2i(80, 27), Vector2i(108, 25), Vector2i(155, 20), Vector2i(200, 13)]:
		tp(v.x, v.y)
		await w(1.0)
	tp(155, 20)
	await w(0.2)
	p.velocity.y = 300
	await w(0.5)
	await shot("21_fleur_ressort")
	tp(108, 25)
	await w(0.6)
	await shot("22_cascade")
	pigs = find_char("P")
	for pg in pigs:
		tp(pg.x, pg.y)
		await w(0.7)
	check(Game.pigment_count() == 4, "chapitre 2 : pigments ramassés (%d / 5)" % Game.pigment_count())
	await shot("23_pigment_foret")
	g = find_char("G")[0]
	tp(g.x, g.y)
	var old_id2: int = l.get_instance_id()
	await until(func(): return lvl() != null and lvl().get_instance_id() != old_id2 and lvl() != null and "num" in lvl() and lvl().num == 3, 10.0)
	check(lvl().num == 3, "la sortie mène au chapitre 3")
	# ---------------- chapitre 3
	await w(2.0)
	l = lvl()
	p = l.player
	await shot("30_chapitre3")
	tp(30, 37)
	await w(1.2)
	await shot("31_falaises")
	pigs = find_char("P")
	for pg in pigs:
		tp(pg.x, pg.y)
		await w(0.7)
	check(Game.pigment_count() == 5, "les 5 pigments légendaires")
	tp(20, 19)
	await w(1.2)
	await shot("32_falaises_haut")
	g = find_char("G")[0]
	tp(g.x, g.y)
	var old_id3: int = l.get_instance_id()
	await until(func(): return lvl() != null and lvl().get_instance_id() != old_id3 and lvl() != null and "num" in lvl() and lvl().num == 4, 10.0)
	check(lvl().num == 4, "la sortie mène au Délaveur")
	# ---------------- boss
	await w(2.0)
	await shot("40_delaveur")
	l = lvl()
	p = l.player
	await until(func(): return l.intro_done, 30.0)
	var boss: Variant = l.boss
	# Temps de jeu (images physiques), pas l'horloge murale : avec --fixed-fps 60 une machine
	# chargée joue la même partie, plus lentement.
	var frames := 0
	var shots_done := {}
	var hits_taken := 0
	p.hurt_signal.connect(func(): hits_taken += 1)
	while is_instance_valid(boss) and not boss.dead and frames < 240 * Engine.physics_ticks_per_second:
		await get_tree().physics_frame
		frames += 1
		if p.dead or p.frozen:
			continue
		p.invuln = 99.0     # le robot ne teste pas l'esquive
		if boss.exposed and boss.core_cool <= 0.0 and p.dashing <= 0.0:
			var core: Vector2 = boss.core_pos()
			p.global_position = core + Vector2(0, 150)
			p.velocity = Vector2.ZERO
			p.can_dash = true
			p.auto_input = {"x": 0.0, "y": -1.0, "dash_p": true}
			await get_tree().physics_frame
			await get_tree().physics_frame
			p.auto_input = {}
		elif not boss.exposed:
			if p.global_position.distance_to(Vector2(7 * 48, 13 * 48)) > 60:
				p.global_position = Vector2(7 * 48, 13 * 48)
				p.velocity = Vector2.ZERO
		var ph: int = boss.phase
		if not shots_done.has("p%d" % ph):
			shots_done["p%d" % ph] = true
			await shot("4%d_phase%d" % [ph, ph])
		if boss.flood > 0.8 and not shots_done.has("flood"):
			shots_done["flood"] = true
			await shot("44_inondation")
		if boss.waves.size() > 0 and not shots_done.has("wave"):
			shots_done["wave"] = true
			await shot("45_vague")
		if boss.markers.size() > 0 and not shots_done.has("rain"):
			shots_done["rain"] = true
			await shot("46_pluie")
		if boss.exposed and not shots_done.has("open"):
			shots_done["open"] = true
			await shot("47_coeur_ouvert")
	var dur := float(frames) / Engine.physics_ticks_per_second
	check(is_instance_valid(boss) and boss.dead, "le Délaveur est vaincu (en %.0f s, %d coups encaissés par le robot)" % [dur, hits_taken])
	p.invuln = 0
	await w(3.5)
	await shot("48_victoire")
	var old_id4: int = l.get_instance_id()
	await until(func(): return lvl() != null and lvl().get_instance_id() != old_id4 and lvl() != null and not ("num" in lvl()), 60.0)
	await w(1.5)
	await shot("50_fin")
	check(Game.pigment_count() == 5, "fin avec les 5 pigments")
	print("Temps de jeu simulé : ", Game.format_time(Game.time), "  gouttes : ", Game.drops)

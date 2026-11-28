extends "res://tests/TestCase.gd"
## Physique de Sépia sur de petites grilles : saut, coyote time, saut mémorisé, murs,
## plafonds, plateformes traversables, rebond mural, Trait d'encre, chutes.

const Player := preload("res://scripts/Player.gd")
const HZ := 120   # images physiques par seconde (project.godot)


func _rise_of(l: Node2D, hold_frames: int) -> float:
	var p: CharacterBody2D = l.player
	var y0 := p.global_position.y
	tap(l, "jump", true)
	var top := y0
	for i in 110:
		if i == hold_frames:
			p.auto_input["jump"] = false
		await phys(1)
		top = minf(top, p.global_position.y)
	p.auto_input["jump"] = false
	await until(func() -> bool: return p.is_on_floor(), 240)
	return (y0 - top) / TS


func test_hauteur_de_saut() -> void:
	var l := await make_level(box(20, 16, 12))
	await place(l, 8, 12)
	var full := await _rise_of(l, 999)
	var v := Player.JUMP_V
	near(full, 3.6, 0.3, "saut maintenu : environ 3,6 cases")
	check(full < v * v / (2.0 * Player.GRAV) / TS + 0.6, "le saut ne dépasse pas la hauteur balistique (+ planer au sommet)")
	var short := await _rise_of(l, 3)
	check(short < 1.6 and short > 0.5, "saut tapé : petit saut (%.2f case)" % short)
	check(short < full * 0.5, "relâcher tôt coupe le saut")


## Corniche : un bloc de sol de x=2 à x=10 dont le dessus est la ligne 8, sol bas à la ligne 12.
func _ledge() -> Array:
	var extra := {}
	for x in range(2, 11):
		for y in range(9, 13):
			extra[Vector2i(x, y)] = "#"
	return box(30, 16, 12, extra)


## Court vers la droite depuis la corniche ; appuie sur saut `late` images après avoir quitté le sol.
## Renvoie la vitesse verticale juste après l'appui.
func _ledge_jump(l: Node2D, late: int) -> float:
	var p: CharacterBody2D = l.player
	await place(l, 8, 8)
	p.auto_input["x"] = 1.0
	await until(func() -> bool: return not p.is_on_floor(), 240)
	await phys(late)
	tap(l, "jump", true)
	await phys(2)
	var vy := p.velocity.y
	p.auto_input = {"x": 0.0, "y": 0.0, "jump": false, "dash": false}
	await until(func() -> bool: return p.is_on_floor(), 300)
	return vy


func test_coyote_time() -> void:
	var l := await make_level(_ledge())
	var within := int(Player.COYOTE * HZ) - 4
	var vy := await _ledge_jump(l, within)
	check(vy < -Player.JUMP_V * 0.8, "saut accepté %d images après avoir quitté le bord (coyote %.2f s)" % [within, Player.COYOTE])
	var late := int(Player.COYOTE * HZ) + 10
	vy = await _ledge_jump(l, late)
	check(vy > 0.0, "saut refusé %d images après le bord : Sépia continue de tomber" % late)


## Lâche Sépia de haut ; renvoie l'image d'atterrissage (comptée depuis le lâcher).
func _drop_and_press(l: Node2D, press_at: int) -> Dictionary:
	var p: CharacterBody2D = l.player
	await place(l, 8, 12)
	p.global_position = foot(8, 6)
	p.velocity = Vector2.ZERO
	var landed := -1
	var jumped_after := -1
	for i in 200:
		if i == press_at:
			tap(l, "jump", true)
		await phys(1)
		if landed < 0 and p.is_on_floor():
			landed = i
		if landed >= 0 and jumped_after < 0 and p.velocity.y < -Player.JUMP_V * 0.8:
			jumped_after = i - landed
		if landed >= 0 and i > landed + 30:
			break
	p.auto_input["jump"] = false
	await until(func() -> bool: return p.is_on_floor(), 300)
	return {"landed": landed, "jumped_after": jumped_after}


func test_saut_memorise() -> void:
	var l := await make_level(box(20, 16, 12))
	var dry := await _drop_and_press(l, -1)
	check(dry["landed"] > 10, "Sépia lâchée en l'air retombe au sol (image %d)" % dry["landed"])
	var early := int(Player.BUFFER * HZ) - 6
	var r := await _drop_and_press(l, dry["landed"] - early)
	check(r["jumped_after"] >= 0 and r["jumped_after"] <= 2, "saut appuyé %d images avant l'atterrissage : part dès l'atterrissage" % early)
	var too_early := int(Player.BUFFER * HZ) + 20
	r = await _drop_and_press(l, dry["landed"] - too_early)
	eq(r["jumped_after"], -1, "saut appuyé %d images trop tôt : oublié" % too_early)


func test_mur_arrete_la_course() -> void:
	var l := await make_level(box(14, 16, 12))
	var p: CharacterBody2D = l.player
	await place(l, 8, 12)
	p.auto_input["x"] = 1.0
	await phys(120)
	var wall_x := 12 * TS
	check(p.global_position.x <= wall_x - 12 + 1.0, "Sépia ne traverse pas le mur (x=%.1f, mur à %.1f)" % [p.global_position.x, wall_x])
	check(p.global_position.x > wall_x - 20, "Sépia court jusqu'au mur")
	check(absf(p.velocity.x) < 1.0 or p.is_on_wall(), "contre le mur, plus de vitesse horizontale")
	check(p.is_on_floor(), "toujours au sol")


func test_plafond() -> void:
	var extra := {}
	for x in range(2, 18):
		extra[Vector2i(x, 10)] = "#"   # plafond 2 cases au-dessus du sol (ligne 12)
	var l := await make_level(box(20, 16, 12, extra))
	var p: CharacterBody2D = l.player
	await place(l, 8, 12)
	var y0 := p.global_position.y
	tap(l, "jump", true)
	var top := y0
	var bumped := false
	for i in 60:
		await phys(1)
		top = minf(top, p.global_position.y)
		if p.is_on_ceiling():
			bumped = true
	p.auto_input["jump"] = false
	check(bumped, "Sépia touche le plafond")
	check((y0 - top) / TS <= 1.2, "le plafond arrête le saut (%.2f case)" % ((y0 - top) / TS))
	check(p.global_position.y >= 11 * TS, "pas de passage à travers le plafond")
	check(await until(func() -> bool: return p.is_on_floor(), 120), "retombe au sol après le choc")


func test_plateforme_traversable() -> void:
	var extra := {}
	for x in range(6, 11):
		extra[Vector2i(x, 10)] = "="
	var l := await make_level(box(20, 16, 12, extra))
	var p: CharacterBody2D = l.player
	await place(l, 8, 12)
	tap(l, "jump", true)
	await phys(50)
	p.auto_input["jump"] = false
	await until(func() -> bool: return p.is_on_floor() and p.velocity.y >= 0.0, 240)
	await phys(10)
	near(p.global_position.y, 10 * TS, 2.0, "on traverse la plateforme par-dessous et on se pose dessus")
	check(p.is_on_floor(), "Sépia tient debout sur la plateforme")


func test_rebond_mural() -> void:
	var l := await make_level(box(14, 20, 16))
	var p: CharacterBody2D = l.player
	await place(l, 10, 16)
	p.global_position = foot(11, 10)
	p.velocity = Vector2(100, 0)
	p.auto_input["x"] = 1.0
	await until(func() -> bool: return p.wall_dir == 1, 120)
	eq(p.wall_dir, 1, "Sépia détecte le mur à sa droite en l'air")
	await phys(6)
	check(p.velocity.y <= Player.WALL_SLIDE + 1.0, "glissade lente le long du mur")
	tap(l, "jump", true)
	await phys(2)
	check(p.velocity.x < 0.0 and p.velocity.y < -Player.WALL_JUMP_Y * 0.8, "rebond mural : repart en haut et à l'opposé du mur")
	eq(p.facing, -1, "Sépia se tourne à l'opposé du mur")


func test_escalade_d_un_mur() -> void:
	var l := await make_level(box(14, 30, 26))
	var p: CharacterBody2D = l.player
	await place(l, 10, 26)
	var y0 := p.global_position.y
	p.auto_input["x"] = 1.0
	var top := y0
	for k in 8:
		tap(l, "jump", true)
		await phys(30)
		top = minf(top, p.global_position.y)
	check((y0 - top) / TS > 8.0, "en rebondissant contre un seul mur, Sépia grimpe (%.1f cases)" % ((y0 - top) / TS))


func test_trait_d_encre() -> void:
	var l := await make_level(box(40, 16, 12))
	var p: CharacterBody2D = l.player
	await place(l, 6, 12)
	Game.has_brush = false
	p.can_dash = false
	tap(l, "dash", false)
	await phys(30)   # laisse expirer l'appui mémorisé
	check(p.dashing <= 0.0 and l.strokes.is_empty(), "sans le pinceau, pas de Trait d'encre")
	Game.has_brush = true
	p.can_dash = true
	var x0 := p.global_position.x
	tap(l, "jump", true)
	await phys(30)
	p.auto_input["x"] = 1.0
	tap(l, "dash", false)
	await phys(2)
	check(p.dashing > 0.0 and p.is_attacking(), "le trait part")
	check(not p.can_dash, "le trait est consommé")
	eq(l.strokes.size(), 1, "un trait peint apparaît")
	await phys(int(Player.DASH_TIME * HZ) + 2)
	check(p.global_position.x - x0 > 3.0 * TS, "le trait propulse Sépia (%.1f cases)" % ((p.global_position.x - x0) / TS))
	check(l.strokes[0].solid, "le trait sèche en plateforme")
	p.auto_input = {"x": 0.0, "y": 0.0, "jump": false, "dash": false}
	var on_stroke := await until(func() -> bool: return p.on_stroke, 120)
	check(on_stroke, "Sépia se pose sur son propre trait")
	await phys(6)
	check(not p.can_dash, "se poser sur son trait ne le recharge pas")
	await until(func() -> bool: return p.is_on_floor() and not p.on_stroke, 600)
	await phys(4)
	check(p.can_dash, "le trait sec, Sépia retombe sur le vrai sol, qui recharge le trait")


func test_recharges() -> void:
	var extra := {Vector2i(8, 6): "D", Vector2i(14, 12): "O"}
	var l := await make_level(box(24, 16, 12, extra))
	var p: CharacterBody2D = l.player
	Game.has_brush = true
	await place(l, 8, 12)
	p.can_dash = false
	p.global_position = foot(8, 7)
	p.velocity = Vector2.ZERO
	await phys(2)
	check(p.can_dash, "la goutte rouge recharge le trait en plein vol")
	check(not p.refill_dash(), "déjà rechargé : la goutte ne fait rien de plus")
	await place(l, 12, 12)
	p.can_dash = false
	p.global_position = foot(14, 10)
	p.velocity = Vector2(0, 200)
	var launched := await until(func() -> bool: return p.velocity.y < -Player.BOUNCE_V * 0.9, 60)
	check(launched, "la fleur-ressort propulse très haut")
	check(p.can_dash, "la fleur-ressort recharge le trait")


func test_chute_hors_du_niveau() -> void:
	var extra := {}
	for y in range(13, 16):
		for x in range(10, 13):
			extra[Vector2i(x, y)] = "."   # un puits sans fond
	var l := await make_level(box(24, 16, 12, extra))
	var p: CharacterBody2D = l.player
	await place(l, 6, 12)
	await phys(30)   # assez longtemps au sol pour en faire le dernier sol sûr
	var safe: Vector2 = p.last_safe
	check(safe.distance_to(foot(6, 12)) < 4.0, "le sol où l'on se tient devient le dernier sol sûr")
	var hp: int = p.hp
	p.global_position = foot(11, 12) + Vector2(0, 40)
	var back := await until(func() -> bool: return not l.hazard_lock and p.global_position.distance_to(safe) < 4.0, 600)
	check(back, "après une chute dans le vide, Sépia revient au dernier sol sûr")
	eq(p.hp, hp - 1, "la chute coûte une goutte de vie")
	check(not p.dead, "pas de mort pour une simple chute")


func test_ronces() -> void:
	var extra := {}
	for x in range(10, 13):
		extra[Vector2i(x, 12)] = "^"
	var l := await make_level(box(24, 16, 12, extra))
	var p: CharacterBody2D = l.player
	await place(l, 6, 12)
	await phys(30)
	var hp: int = p.hp
	p.global_position = foot(11, 12)
	var hit := await until(func() -> bool: return p.hp < hp, 30)
	check(hit, "les ronces blessent")
	check(await until(func() -> bool: return not l.hazard_lock, 600), "Sépia est renvoyée hors des ronces")
	check(p.global_position.distance_to(foot(6, 12)) < 4.0, "renvoyée au dernier sol sûr, pas dans les ronces")


func test_mort_et_reprise() -> void:
	var l := await make_level(box(24, 16, 12, {Vector2i(4, 12): "S"}))
	var p: CharacterBody2D = l.player
	await place(l, 12, 12)
	Game.deaths = 0
	p.invuln = 0.0
	p.hp = 1
	p.hurt(p.global_position + Vector2(10, 0))
	check(p.dead, "la dernière goutte de vie perdue : Sépia meurt")
	eq(Game.deaths, 1, "la chute est comptée")
	check(await until(func() -> bool: return not p.dead, 600), "Sépia revient")
	check(p.global_position.distance_to(foot(4, 12)) < 4.0, "sans chevalet, retour au départ du chapitre")
	eq(p.hp, Game.max_hp(), "vie pleine au retour")
	check(p.invuln > 0.0, "brève invulnérabilité au retour")

extends Node
## Mesure les capacités de Sépia (hauteur de saut, distances...) dans une arène de test.

var main
var L
var P

func _ready() -> void:
	main = get_parent()
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	Game.new_game()
	Game.has_brush = true
	main.goto("level", 99)
	await w(1.5)
	L = main.current
	P = L.player
	L.hud.visible = false
	await run()
	print("METRICS FINI")
	get_tree().quit()

func w(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout

func phys(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func reset(x_tile: float) -> void:
	P.auto_input = {"x": 0.0, "y": 0.0, "jump": false, "dash": false}
	P.global_position = Vector2(x_tile * 48, 21 * 48)
	P.velocity = Vector2.ZERO
	P.can_dash = true
	await phys(20)

func run() -> void:
	# 1. saut sur place (maintenu)
	await reset(10)
	var y0: float = P.global_position.y
	P.auto_input["jump"] = true
	P.auto_input["jump_p"] = true
	var miny := y0
	for i in 120:
		await phys(1)
		miny = minf(miny, P.global_position.y)
	print("saut_hauteur_cases ", (y0 - miny) / 48.0)
	# 2. saut court (tapé)
	await reset(10)
	P.auto_input["jump_p"] = true
	P.auto_input["jump"] = true
	await phys(3)
	P.auto_input["jump"] = false
	miny = y0
	for i in 100:
		await phys(1)
		miny = minf(miny, P.global_position.y)
	print("petit_saut_cases ", (y0 - miny) / 48.0)
	# 3. saut en courant : distance horizontale jusqu'au retour au même niveau
	await reset(4)
	P.auto_input["x"] = 1.0
	await phys(60)
	var x0: float = P.global_position.x
	P.auto_input["jump_p"] = true
	P.auto_input["jump"] = true
	await phys(3)
	var x1 := x0
	for i in 200:
		await phys(1)
		if P.is_on_floor():
			x1 = P.global_position.x
			break
	print("saut_long_cases ", (x1 - x0) / 48.0)
	# 4. saut + trait vers le haut au sommet
	await reset(10)
	P.auto_input["jump_p"] = true
	P.auto_input["jump"] = true
	await phys(40)
	P.auto_input["y"] = -1.0
	P.auto_input["dash_p"] = true
	miny = y0
	for i in 150:
		await phys(1)
		miny = minf(miny, P.global_position.y)
	print("saut_plus_trait_haut_cases ", (y0 - miny) / 48.0)
	# 5. saut en courant + trait horizontal au sommet
	await reset(4)
	P.auto_input["x"] = 1.0
	await phys(60)
	x0 = P.global_position.x
	P.auto_input["jump_p"] = true
	P.auto_input["jump"] = true
	await phys(40)
	P.auto_input["dash_p"] = true
	for i in 300:
		await phys(1)
		if P.is_on_floor() and not P.on_stroke:
			break
	print("saut_plus_trait_horizontal_cases ", (P.global_position.x - x0) / 48.0)
	# 6. enchaînement : saut, trait, atterrir sur le trait, ressauter
	await reset(4)
	P.auto_input["x"] = 1.0
	await phys(60)
	x0 = P.global_position.x
	P.auto_input["jump_p"] = true
	P.auto_input["jump"] = true
	await phys(38)
	P.auto_input["jump"] = false
	P.auto_input["dash_p"] = true
	var on_s := false
	for i in 300:
		await phys(1)
		if P.on_stroke and not on_s:
			on_s = true
			print("  atterri_sur_trait a ", (P.global_position.x - x0) / 48.0)
			P.auto_input["jump_p"] = true
			P.auto_input["jump"] = true
		if P.is_on_floor() and not P.on_stroke and i > 30:
			break
	print("chaine_trait_cases ", (P.global_position.x - x0) / 48.0, " (trait utilise: ", on_s, ")")
	# 7. escalade entre deux murs (puits de 4 cases entre x=52 et x=55)
	P.auto_input = {"x": 0.0, "y": 0.0, "jump": false, "dash": false}
	P.global_position = Vector2(53.5 * 48, 21 * 48)
	P.velocity = Vector2.ZERO
	await phys(20)
	y0 = P.global_position.y
	var dir := 1.0
	P.auto_input["x"] = dir
	miny = y0
	for k in 14:
		P.auto_input["jump_p"] = true
		P.auto_input["jump"] = true
		for i in 40:
			await phys(1)
			if i > 4 and P.wall_dir != 0:
				break
		dir = -dir
		P.auto_input["x"] = dir
		miny = minf(miny, P.global_position.y)
	print("escalade_puits_cases ", (y0 - miny) / 48.0)
	# 8. escalade d'un seul mur (x=56 mur à droite)
	P.auto_input = {"x": 1.0, "y": 0.0, "jump": false, "dash": false}
	P.global_position = Vector2(54.5 * 48, 21 * 48)
	P.velocity = Vector2.ZERO
	await phys(30)
	y0 = P.global_position.y
	miny = y0
	for k in 10:
		P.auto_input["jump_p"] = true
		P.auto_input["jump"] = true
		await phys(30)
		miny = minf(miny, P.global_position.y)
	print("escalade_un_mur_cases ", (y0 - miny) / 48.0)

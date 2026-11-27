extends Node2D
## Un chapitre de Kevencre : construit le niveau à partir de sa grille, gère caméra, couleur, mort et reprise.

const TS := Game.TS
const E := "res://scripts/ent/"

var num := 1
var grid: Array = []
var W := 0
var H := 0
var player: CharacterBody2D
var cam: Camera2D
var fx: Node2D
var decals: Node2D
var hud: CanvasLayer
var world: Node2D
var color_rect: ColorRect
var color_mat: ShaderMaterial
var ground_color := Color(0.45, 0.4, 0.35)
var start_pos := Vector2.ZERO
var strokes: Array = []
var waves: Array = []           # [pos, radius, target]
var base_sat := 0.3
var shake_amt := 0.0
var cam_look := 0.0
var hazard_lock := false
var combo := 0
var combo_t := 0.0
var finished := false
var boss: Node2D = null
var checkpoints: Array = []
var intro_done := false

var SIGNS := {
	1: [
		"← → (ou A / D) pour courir.  Espace pour sauter : garde la touche appuyée pour sauter plus haut.",
		"Des Taches grises ! Elles boivent les couleurs. Saute-leur sur la tête pour les repeindre.",
		"Contre un mur, saute à nouveau : Sépia rebondit. Enchaîne d'un mur à l'autre pour grimper.",
		"X (ou J, ou Maj) + une direction : Trait d'encre !  Ton trait reste dans l'air un instant : tu peux marcher dessus et sauter depuis.  Il se recharge en touchant le vrai sol.",
		"Ce papier est fragile : il se déchire si on reste dessus. Il revient un peu plus tard.",
		"Trop haut ? Saute, puis Trait d'encre vers le haut (↑ + X).  Un trait vertical devient un mur sur lequel rebondir.",
	],
	2: [
		"Les fleurs-ressorts te lancent très haut et rechargent ton Trait d'encre.",
		"La grande cascade. Rebondis entre les murs et attrape les gouttes rouges : elles rechargent ton trait en plein vol.",
	],
	3: [
		"Les Falaises d'Ocre. Tout en haut, l'atelier du Délaveur. Les chevalets te soignent quand tu les touches.",
	],
}

# ------------------------------------------------------------------ construction
var replay := false   # lancé depuis le menu Chapitres : ne remplace pas la sauvegarde

func _ready() -> void:
	Game.level = num
	_load_grid()
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	_build_background()
	_build_terrain_visual()
	_build_collision()
	decals = load("res://scripts/Fx.gd").new()
	world.add_child(decals)
	decals.z_index = 1
	fx = load("res://scripts/Fx.gd").new()
	world.add_child(fx)
	_spawn_entities()
	_build_player()
	_build_color_layer()
	hud = load("res://scripts/Hud.gd").new()
	hud.level = self
	add_child(hud)
	if Game.checkpoint.has(num):
		player.global_position = Game.checkpoint[num]
		player.last_safe = player.global_position
		for c in checkpoints:
			if c.global_position.distance_to(Game.checkpoint[num]) < 4:
				c.activate(false)
	if Game.restored.has(num):
		for p in Game.restored[num]:
			waves.append([p[0], p[1], p[1]])
	cam.global_position = player.global_position
	cam.reset_smoothing()
	Game.timing = true
	if not replay:
		Game.save_game()  # début de chapitre
	Game.music(["", "music_meadow", "music_forest", "music_cliffs", "music_boss"][mini(num, 4)])
	hud.banner("Chapitre %d" % num if num < 4 else "Dernier chapitre", Game.CHAPTERS[mini(num, 4)])
	if num == 4:
		_start_boss()
	else:
		intro_done = true

func _load_grid() -> void:
	if num == 4:
		grid = _arena()
	elif num == 99:
		grid = []
		for y in 24:
			var row := ""
			for x in 70:
				var c := "."
				if y >= 21 or x < 2 or x > 67:
					c = "#"
				elif x >= 50 and x <= 51 and y <= 17 and y >= 2:
					c = "#"
				elif x >= 56 and y <= 20 and y >= 2:
					c = "#"
				elif y == 20 and x == 4:
					c = "S"
				row += c
			grid.append(row)
	else:
		var f := FileAccess.open("res://levels/%d.txt" % num, FileAccess.READ)
		grid = []
		while not f.eof_reached():
			var l := f.get_line()
			if l.length() > 0:
				grid.append(l)
	H = grid.size()
	W = grid[0].length()
	ground_color = [Color(), Color(0.42, 0.36, 0.28), Color(0.25, 0.32, 0.34), Color(0.55, 0.36, 0.24), Color(0.3, 0.27, 0.35)][mini(num, 4)]

func _arena() -> Array:
	var g: Array = []
	for y in 20:
		var row := ""
		for x in 34:
			var ch := "."
			if x < 2 or x > 31 or y > 16 or y == 0:
				ch = "#"
			elif y == 13 and ((x >= 5 and x <= 9) or (x >= 24 and x <= 28)):
				ch = "="
			elif y == 9 and x >= 14 and x <= 19:
				ch = "="
			elif y == 16 and x == 4:
				ch = "S"
			row += ch
		g.append(row)
	return g

func ch(x: int, y: int) -> String:
	if x < 0 or x >= W or y < 0:
		return "#" if (x < 0 or x >= W) else "."
	if y >= H:
		return "."
	return grid[y][x]

func _meta() -> Dictionary:
	var p := "res://art/l%d/meta.json" % num
	if not FileAccess.file_exists(p):
		return {}
	var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
	return j if j is Dictionary else {}

func _tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null

func _build_background() -> void:
	var meta := _meta()
	var pb := ParallaxBackground.new()
	add_child(pb)
	var sky := ColorRect.new()
	var cl := CanvasLayer.new()
	cl.layer = -110
	add_child(cl)
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.color = [Color(), Color(0.78, 0.86, 0.9), Color(0.62, 0.78, 0.8), Color(0.95, 0.72, 0.55), Color(0.2, 0.18, 0.28)][mini(num, 4)]
	cl.add_child(sky)
	if meta.has("sky"):
		var tr := TextureRect.new()
		tr.texture = _tex("res://art/l%d/%s" % [num, meta["sky"]])
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		cl.add_child(tr)
	for b in meta.get("bg", []):
		var tex := _tex("res://art/l%d/%s" % [num, b["file"]])
		if tex == null:
			continue
		var layer := ParallaxLayer.new()
		layer.motion_scale = Vector2(b["motion"], b.get("motion_y", b["motion"] * 0.5))
		var sc: float = b.get("scale", 2.0)
		layer.motion_mirroring = Vector2(tex.get_width() * sc, tex.get_height() * sc if b.get("mirror_y", false) else 0.0)
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.scale = Vector2(sc, sc)
		s.position = Vector2(0, b.get("y", 0.0))
		layer.add_child(s)
		pb.add_child(layer)

func _build_terrain_visual() -> void:
	var meta := _meta()
	if meta.has("chunks"):
		var sc: float = meta.get("scale", 2.0)
		for c in meta["chunks"]:
			var tex := _tex("res://art/l%d/%s" % [num, c["file"]])
			if tex == null:
				continue
			var s := Sprite2D.new()
			s.texture = tex
			s.centered = false
			s.scale = Vector2(sc, sc)
			s.position = Vector2(c["x"], c["y"])
			s.z_index = 0
			world.add_child(s)
	else:
		var d: Node2D = load("res://scripts/TerrainDraw.gd").new()
		d.level = self
		world.add_child(d)

func _build_collision() -> void:
	var body := StaticBody2D.new()
	body.add_to_group("terrain")
	body.collision_layer = 1
	world.add_child(body)
	# rectangles fusionnés pour le sol plein
	var runs := {}     # "x1:x2" -> [y_start, y_end] en cours
	var rects: Array = []
	for y in H:
		var row_runs := {}
		var x := 0
		while x < W:
			if ch(x, y) == "#":
				var x2 := x
				while x2 + 1 < W and ch(x2 + 1, y) == "#":
					x2 += 1
				row_runs["%d:%d" % [x, x2]] = true
				x = x2 + 1
			else:
				x += 1
		for k in runs.keys():
			if not row_runs.has(k):
				rects.append([k, runs[k][0], runs[k][1]])
				runs.erase(k)
		for k in row_runs.keys():
			if runs.has(k):
				runs[k][1] = y
			else:
				runs[k] = [y, y]
	for k in runs.keys():
		rects.append([k, runs[k][0], runs[k][1]])
	for r in rects:
		var xs: PackedStringArray = r[0].split(":")
		var x1 := int(xs[0])
		var x2 := int(xs[1])
		var cs := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = Vector2((x2 - x1 + 1) * TS, (r[2] - r[1] + 1) * TS)
		cs.shape = rs
		cs.position = Vector2(x1 * TS, r[1] * TS) + rs.size / 2
		body.add_child(cs)
	# plateformes traversables
	var ow := StaticBody2D.new()
	ow.add_to_group("terrain")
	world.add_child(ow)
	for y in H:
		var x := 0
		while x < W:
			if ch(x, y) == "=":
				var x2 := x
				while x2 + 1 < W and ch(x2 + 1, y) == "=":
					x2 += 1
				var cs := CollisionShape2D.new()
				var rs := RectangleShape2D.new()
				rs.size = Vector2((x2 - x + 1) * TS, 14)
				cs.shape = rs
				cs.position = Vector2(x * TS, y * TS) + rs.size / 2
				cs.one_way_collision = true
				cs.one_way_collision_margin = 8.0
				ow.add_child(cs)
				x = x2 + 1
			else:
				x += 1

func _spawn_entities() -> void:
	var sign_list: Array = []
	var fake := {}
	var pig_i := 0
	var pig_base: int = [0, 0, 2, 4, 5][mini(num, 4)]
	for y in H:
		for x in W:
			var c := ch(x, y)
			var foot := Vector2((x + 0.5) * TS, (y + 1) * TS)
			var mid := Vector2((x + 0.5) * TS, (y + 0.5) * TS)
			var key := "%d:%d:%d" % [num, x, y]
			match c:
				"S":
					start_pos = foot
				"*":
					if not Game.drops_level.has(key):
						var d: Variant = _ent("Drop", mid, x, y)
						d.key = key
				"P":
					var idx: int = min(pig_base + pig_i, 4)
					pig_i += 1
					if not Game.pigments.has(key):
						var p: Variant = _ent("Pigment", mid, x, y)
						p.key = key
						p.index = idx
				"D":
					_ent("Crystal", mid, x, y)
				"O":
					_ent("Flower", foot, x, y)
				"C":
					checkpoints.append(_ent("Checkpoint", foot, x, y))
				"K":
					_ent("Shrine", foot, x, y)
				"!":
					sign_list.append(_ent("Sign", foot, x, y))
				"G":
					_ent("Goal", foot, x, y)
				"E":
					_ent("Tache", foot + Vector2(0, -18), x, y)
				"F":
					_ent("Corbac", mid, x, y)
				"T":
					_ent("Crachin", mid, x, y)
				"X":
					fake[Vector2i(x, y)] = true
				"^":
					if ch(x - 1, y) != "^":
						var x2 := x
						while ch(x2 + 1, y) == "^":
							x2 += 1
						var th: Variant = _ent("Thorns", Vector2(x * TS, y * TS), x, y)
						th.width = x2 - x + 1
						th.ceiling = ch(x, y - 1) == "#" and ch(x, y + 1) != "#"
				"c":
					if ch(x - 1, y) != "c":
						var x2 := x
						while ch(x2 + 1, y) == "c":
							x2 += 1
						var cr := StaticBody2D.new()
						cr.set_script(load(E + "Crumble.gd"))
						cr.level = self
						cr.position = Vector2(x * TS, y * TS)
						world.add_child(cr)
						cr.setup(x2 - x + 1)
	sign_list.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
	var texts: Array = SIGNS.get(num, [])
	for i in sign_list.size():
		sign_list[i].text = texts[i] if i < texts.size() else ""
	# faux murs : regroupés par blocs voisins
	var seen := {}
	var meta := _meta()
	var covers: Array = meta.get("covers", [])
	for cell in fake.keys():
		if seen.has(cell):
			continue
		var group: Array = []
		var stack: Array = [cell]
		while stack.size() > 0:
			var c2: Vector2i = stack.pop_back()
			if seen.has(c2) or not fake.has(c2):
				continue
			seen[c2] = true
			group.append(c2)
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				stack.append(c2 + d)
		var fw := Node2D.new()
		fw.set_script(load(E + "FakeWall.gd"))
		fw.level = self
		fw.cells = group
		world.add_child(fw)
		for cv in covers:
			var r := Rect2(cv["tx"], cv["ty"], cv["tw"], cv["th"])
			if r.has_point(Vector2(group[0]) + Vector2(0.5, 0.5)):
				var tex := _tex("res://art/l%d/%s" % [num, cv["file"]])
				if tex:
					var s := Sprite2D.new()
					s.texture = tex
					s.centered = false
					s.scale = Vector2(meta.get("scale", 2.0), meta.get("scale", 2.0))
					s.position = Vector2(cv["x"], cv["y"])
					fw.add_child(s)
					fw.sprite = s

func _ent(kind: String, pos: Vector2, x: int, y: int) -> Node2D:
	var n := Node2D.new()
	n.set_script(load(E + kind + ".gd"))
	n.level = self
	n.tile = Vector2i(x, y)
	n.position = pos
	world.add_child(n)
	return n

func _build_player() -> void:
	player = CharacterBody2D.new()
	player.set_script(load("res://scripts/Player.gd"))
	player.level = self
	player.position = start_pos
	world.add_child(player)
	player.can_dash = Game.has_brush
	player.died.connect(_on_died)
	cam = Camera2D.new()
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(W * TS)
	cam.limit_bottom = int(H * TS)
	cam.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	world.add_child(cam)
	cam.make_current()
	if num == 4:
		cam.zoom = Vector2(0.78, 0.78)

func _build_color_layer() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 5
	add_child(cl)
	color_rect = ColorRect.new()
	color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	color_mat = ShaderMaterial.new()
	color_mat.shader = load("res://shaders/couleur.gdshader")
	var paper := _tex("res://art/papier.png")
	if paper:
		color_mat.set_shader_parameter("paper", paper)
	color_rect.material = color_mat
	cl.add_child(color_rect)

# ------------------------------------------------------------------ boucle
func _physics_process(delta: float) -> void:
	if player == null:
		return
	# caméra : regarde devant, un peu au-dessus
	var p := player.global_position
	cam_look = lerpf(cam_look, player.facing * 110.0 + clampf(player.velocity.x * 0.12, -60, 60), 1.0 - exp(-2.5 * delta))
	var target := p + Vector2(cam_look, -60 + clampf(player.velocity.y * 0.1, -20, 90))
	if boss:
		target = target.lerp(Vector2(W * TS / 2, H * TS / 2 - 40), 0.6)
	cam.global_position = cam.global_position.lerp(target, 1.0 - exp(-7.0 * delta))
	shake_amt = move_toward(shake_amt, 0, 40 * delta)
	cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amt
	combo_t -= delta
	if combo_t <= 0:
		combo = 0
	for w in waves:
		w[1] = move_toward(w[1], w[2], delta * maxf(400.0, w[2] * 0.9))
	strokes = strokes.filter(func(s): return is_instance_valid(s))

func _process(_delta: float) -> void:
	_update_color()

func _update_color() -> void:
	if color_mat == null or cam == null:
		return
	var vs := get_viewport().get_visible_rect().size
	var xf := get_viewport().get_canvas_transform()
	color_mat.set_shader_parameter("view_size", vs)
	color_mat.set_shader_parameter("base_sat", base_sat)
	var pp: Vector2 = xf * (player.global_position + Vector2(0, -20))
	color_mat.set_shader_parameter("player_pos", pp)
	color_mat.set_shader_parameter("player_r", 0.0 if player.dead else 150.0)
	var arr: Array = []
	var screen := Rect2(Vector2.ZERO, vs)
	for w in waves:
		var sp: Vector2 = xf * w[0]
		var r: float = w[1]
		if screen.grow(r).has_point(sp) and arr.size() < 32:
			arr.append(Vector3(sp.x, sp.y, r))
	var n := arr.size()
	while arr.size() < 32:
		arr.append(Vector3(-9999, -9999, 0))
	color_mat.set_shader_parameter("circles", PackedVector3Array(arr))
	color_mat.set_shader_parameter("count", n)

# ------------------------------------------------------------------ services pour les entités
func solid_px(p: Vector2) -> bool:
	return ch(floori(p.x / TS), floori(p.y / TS)) == "#"

func floor_px(p: Vector2) -> bool:
	var c := ch(floori(p.x / TS), floori(p.y / TS))
	return c == "#" or c == "=" or c == "c"

func ground_below(p: Vector2) -> Vector2:
	var tx := floori(p.x / TS)
	var ty := floori(p.y / TS)
	for y in range(ty, mini(ty + 6, H)):
		if ch(tx, y) in ["#", "="]:
			return Vector2(p.x, y * TS)
	return p

func is_safe_ground(p: Vector2) -> bool:
	var ty := floori((p.y + 4) / TS)
	for dx in [-12, 0, 12]:
		var c := ch(floori((p.x + dx) / TS), ty)
		if c != "#" and c != "=":
			return false
	var tx := floori(p.x / TS)
	for x in range(tx - 1, tx + 2):
		if ch(x, ty - 1) == "^":
			return false
	return true

func bottom_y() -> float:
	return H * TS + 80

func new_stroke(dir: Vector2, facing: int) -> Node2D:
	var s := StaticBody2D.new()
	s.set_script(load("res://scripts/Stroke.gd"))
	world.add_child(s)
	s.setup(dir, facing, Game.next_stroke_color())
	strokes.append(s)
	while strokes.size() > 3:
		var old: Variant = strokes.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	return s

func spawn_projectile(pos: Vector2, vel: Vector2, grav := 0.0, r := 9.0) -> Node2D:
	var n := Node2D.new()
	n.set_script(load(E + "Projectile.gd"))
	n.level = self
	n.position = pos
	n.vel = vel
	n.grav = grav
	n.r = r
	n.z_index = 6
	world.add_child(n)
	return n

func shake(a: float) -> void:
	shake_amt = maxf(shake_amt, a)

func hitstop(t: float) -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(t, true, false, true).timeout
	Engine.time_scale = 1.0

func drop_combo() -> void:
	combo += 1
	combo_t = 0.9
	Game.sfx("drop", -8, 1.0 + minf(combo, 12) * 0.06)

func restore_at(p: Vector2, r := 1500.0) -> void:
	waves.append([p, 0.0, r])
	if not Game.restored.has(num):
		Game.restored[num] = []
	Game.restored[num].append([p, r])

func restore_small(p: Vector2) -> void:
	restore_at(p, 230.0)

func hazard_hit(p: Variant) -> void:
	if hazard_lock or p.dead or finished:
		return
	hazard_lock = true
	p.invuln = 0.0
	p.hurt(p.global_position + Vector2(0, 30))
	if p.dead:
		hazard_lock = false
		return
	p.frozen = true
	await get_tree().create_timer(0.25).timeout
	await Game.main.flash_fade(0.18, 0.3)
	p.global_position = p.last_safe
	p.velocity = Vector2.ZERO
	p.frozen = false
	p.invuln = 1.0
	cam.global_position = p.global_position
	hazard_lock = false

func _on_died() -> void:
	shake(14)
	await get_tree().create_timer(0.9).timeout
	await Game.main.flash_fade(0.3, 0.45)
	var at: Vector2 = Game.checkpoint.get(num, start_pos)
	player.respawn(at)
	cam.global_position = at
	cam.reset_smoothing()
	hazard_lock = false
	if boss and boss.has_method("on_player_respawn"):
		boss.on_player_respawn()

func on_pigment(info: Array, idx: int) -> void:
	restore_at(player.global_position, 600)
	hud.toast("Pigment légendaire : " + info[0], info[1] + "\n(+1 goutte de vie)", Game.PALETTE[idx])

func shrine_event(shrine: Node2D) -> void:
	player.frozen = true
	Game.sfx("pigment", -4, 0.8)
	await get_tree().create_timer(0.5).timeout
	await hud.say([
		["Vieux Pinceau", "Oh... une goutte d'encre. Une vraie, toute pleine. Je croyais qu'il n'en restait plus une seule."],
		["Vieux Pinceau", "Je suis le Vieux Pinceau. Mes poils sont secs depuis que le Délaveur a bu les couleurs du monde."],
		["Vieux Pinceau", "Mais toi, petite Sépia, tu peux encore tracer. Prends mon dernier geste : le Trait d'encre."],
		["Vieux Pinceau", "Fends l'air d'un coup de pinceau. Ton trait restera un instant avant de sécher : pose-toi dessus, saute depuis, rebondis contre lui."],
		["Vieux Pinceau", "Le Délaveur se cache dans son atelier, tout en haut des Falaises d'Ocre. Va, et rends au monde ses couleurs."],
	])
	Game.has_brush = true
	player.can_dash = true
	fx.burst(shrine.global_position + Vector2(0, -90), 50)
	restore_at(shrine.global_position + Vector2(0, -60), 1300)
	Game.sfx("checkpoint", 0, 1.2)
	hud.toast("Trait d'encre", "X / J / Maj + direction.  Se recharge au sol, sur les fleurs et les gouttes rouges.", Game.PALETTE[1])
	player.frozen = false

func complete() -> void:
	if finished:
		return
	finished = true
	player.frozen = true
	Game.sfx("victory", -2)
	restore_at(player.global_position, 6000)
	var tw := create_tween()
	tw.tween_property(self, "base_sat", 1.0, 2.0)
	fx.burst(player.global_position + Vector2(0, -60), 60)
	await get_tree().create_timer(2.4).timeout
	Game.checkpoint.erase(num)
	Game.main.goto("level", num + 1)

# ------------------------------------------------------------------ boss
func _start_boss() -> void:
	player.frozen = true
	boss = Node2D.new()
	boss.set_script(load("res://scripts/Boss.gd"))
	boss.level = self
	boss.position = Vector2(W * TS / 2, 5.2 * TS)
	world.add_child(boss)
	await get_tree().create_timer(1.6).timeout
	await hud.say([
		["???", "Encore une couleur ? Je les ai toutes bues, pourtant. Le rouge des fruits, le bleu des rivières, le vert des feuilles..."],
		["Le Délaveur", "Le gris est calme. Le gris ne fait pas mal aux yeux. Le gris ne se fane jamais."],
		["Sépia", "..."],
		["Le Délaveur", "Viens, petite goutte. Je vais te diluer, toi aussi."],
	])
	player.frozen = false
	intro_done = true
	boss.begin()

func boss_defeated() -> void:
	finished = true
	player.frozen = true
	Game.stop_music()
	await get_tree().create_timer(1.8).timeout
	restore_at(boss.global_position, 6000)
	var tw := create_tween()
	tw.tween_property(self, "base_sat", 1.0, 2.5)
	Game.sfx("victory", 0)
	await get_tree().create_timer(2.0).timeout
	await hud.say([
		["Le Délaveur", "Oh... c'est donc ça, le rouge ? C'est... chaud."],
		["Le Délaveur", "J'avais oublié. Avant d'être gris, j'étais un simple pot d'eau, à côté du chevalet d'un peintre. On rinçait les pinceaux en moi. Toutes les couleurs passaient par moi..."],
		["Sépia", "!"],
		["Le Délaveur", "Va, petite goutte. Le peintre dort encore. Réveille-le."],
	])
	Game.timing = false
	Game.main.goto("ending")

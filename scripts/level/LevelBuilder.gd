extends RefCounted
## Construction d'un chapitre à partir de sa grille : fonds, terrain peint, collisions,
## objets et ennemis, Sépia et sa caméra, couche de couleur. Fonctions statiques appelées par Level.

const TS := Game.TS
const E := "res://scripts/ent/"
const LevelStory := preload("res://scripts/level/LevelStory.gd")

const SKY := [Color(), Color(0.78, 0.86, 0.9), Color(0.62, 0.78, 0.8), Color(0.95, 0.72, 0.55), Color(0.2, 0.18, 0.28)]
const GROUND := [Color(), Color(0.42, 0.36, 0.28), Color(0.25, 0.32, 0.34), Color(0.55, 0.36, 0.24), Color(0.3, 0.27, 0.35)]
const PIGMENT_BASE := [0, 0, 2, 4, 5]   # index du premier pigment de chaque chapitre


static func meta(num: int) -> Dictionary:
	var p := "res://art/l%d/meta.json" % num
	if not FileAccess.file_exists(p):
		return {}
	var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
	return j if j is Dictionary else {}


static func tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null


static func ground_color(num: int) -> Color:
	return GROUND[mini(num, 4)]


static func build_background(L: Node2D, m: Dictionary) -> void:
	var num: int = L.num
	var pb := ParallaxBackground.new()
	L.add_child(pb)
	var sky := ColorRect.new()
	var cl := CanvasLayer.new()
	cl.layer = -110
	L.add_child(cl)
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.color = SKY[mini(num, 4)]
	cl.add_child(sky)
	if m.has("sky"):
		var tr := TextureRect.new()
		tr.texture = tex("res://art/l%d/%s" % [num, m["sky"]])
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		cl.add_child(tr)
	for b in m.get("bg", []):
		var t := tex("res://art/l%d/%s" % [num, b["file"]])
		if t == null:
			continue
		var layer := ParallaxLayer.new()
		layer.motion_scale = Vector2(b["motion"], b.get("motion_y", b["motion"] * 0.5))
		var sc: float = b.get("scale", 2.0)
		layer.motion_mirroring = Vector2(t.get_width() * sc, t.get_height() * sc if b.get("mirror_y", false) else 0.0)
		var s := Sprite2D.new()
		s.texture = t
		s.centered = false
		s.scale = Vector2(sc, sc)
		s.position = Vector2(0, b.get("y", 0.0))
		layer.add_child(s)
		pb.add_child(layer)


static func build_terrain_visual(L: Node2D, m: Dictionary) -> void:
	if m.has("chunks"):
		var sc: float = m.get("scale", 2.0)
		for c in m["chunks"]:
			var t := tex("res://art/l%d/%s" % [L.num, c["file"]])
			if t == null:
				continue
			var s := Sprite2D.new()
			s.texture = t
			s.centered = false
			s.scale = Vector2(sc, sc)
			s.position = Vector2(c["x"], c["y"])
			s.z_index = 0
			L.world.add_child(s)
	else:
		var d: Node2D = load("res://scripts/TerrainDraw.gd").new()
		d.level = L
		L.world.add_child(d)


## Rectangles [x1, x2, y1, y2] (cases, bornes incluses) qui couvrent le sol plein :
## les suites horizontales de # sont fusionnées verticalement quand elles se répètent à l'identique.
static func solid_rects(L: Node) -> Array:
	var runs := {}     # Vector2i(x1, x2) -> [y_start, y_end] en cours
	var rects: Array = []
	for y in L.H:
		var row_runs := {}
		var x := 0
		while x < L.W:
			if L.ch(x, y) == "#":
				var x2 := x
				while x2 + 1 < L.W and L.ch(x2 + 1, y) == "#":
					x2 += 1
				row_runs[Vector2i(x, x2)] = true
				x = x2 + 1
			else:
				x += 1
		for k in runs.keys():
			if not row_runs.has(k):
				rects.append([k.x, k.y, runs[k][0], runs[k][1]])
				runs.erase(k)
		for k in row_runs.keys():
			if runs.has(k):
				runs[k][1] = y
			else:
				runs[k] = [y, y]
	for k in runs.keys():
		rects.append([k.x, k.y, runs[k][0], runs[k][1]])
	return rects


static func build_collision(L: Node2D) -> void:
	var body := StaticBody2D.new()
	body.add_to_group("terrain")
	body.collision_layer = 1
	L.world.add_child(body)
	for r in solid_rects(L):
		var cs := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = Vector2((r[1] - r[0] + 1) * TS, (r[3] - r[2] + 1) * TS)
		cs.shape = rs
		cs.position = Vector2(r[0] * TS, r[2] * TS) + rs.size / 2
		body.add_child(cs)
	# plateformes traversables
	var ow := StaticBody2D.new()
	ow.add_to_group("terrain")
	L.world.add_child(ow)
	for y in L.H:
		var x := 0
		while x < L.W:
			if L.ch(x, y) == "=":
				var x2 := x
				while x2 + 1 < L.W and L.ch(x2 + 1, y) == "=":
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


static func ent(L: Node2D, kind: String, pos: Vector2, x: int, y: int) -> Node2D:
	var n := Node2D.new()
	n.set_script(load(E + kind + ".gd"))
	n.level = L
	n.tile = Vector2i(x, y)
	n.position = pos
	L.world.add_child(n)
	return n


static func spawn_entities(L: Node2D, m: Dictionary) -> void:
	var num: int = L.num
	var sign_list: Array = []
	var fake := {}
	var pig_i := 0
	var pig_base: int = PIGMENT_BASE[mini(num, 4)]
	var w: int = L.W
	var h: int = L.H
	for y in h:
		for x in w:
			var c: String = L.ch(x, y)
			var foot := Vector2((x + 0.5) * TS, (y + 1) * TS)
			var mid := Vector2((x + 0.5) * TS, (y + 0.5) * TS)
			var key := "%d:%d:%d" % [num, x, y]
			match c:
				"S":
					L.start_pos = foot
				"*":
					if not Game.drops_level.has(key):
						ent(L, "Drop", mid, x, y).key = key
				"P":
					var idx: int = mini(pig_base + pig_i, 4)
					pig_i += 1
					if not Game.pigments.has(key):
						var p := ent(L, "Pigment", mid, x, y)
						p.key = key
						p.index = idx
				"D":
					ent(L, "Crystal", mid, x, y)
				"O":
					ent(L, "Flower", foot, x, y)
				"C":
					L.checkpoints.append(ent(L, "Checkpoint", foot, x, y))
				"K":
					ent(L, "Shrine", foot, x, y)
				"!":
					sign_list.append(ent(L, "Sign", foot, x, y))
				"G":
					ent(L, "Goal", foot, x, y)
				"E":
					ent(L, "Tache", foot + Vector2(0, -18), x, y)
				"F":
					ent(L, "Corbac", mid, x, y)
				"T":
					ent(L, "Crachin", mid, x, y)
				"X":
					fake[Vector2i(x, y)] = true
				"^":
					if L.ch(x - 1, y) != "^":
						var x2 := x
						while L.ch(x2 + 1, y) == "^":
							x2 += 1
						var th := ent(L, "Thorns", Vector2(x * TS, y * TS), x, y)
						th.width = x2 - x + 1
						th.ceiling = L.ch(x, y - 1) == "#" and L.ch(x, y + 1) != "#"
				"c":
					if L.ch(x - 1, y) != "c":
						var x2 := x
						while L.ch(x2 + 1, y) == "c":
							x2 += 1
						var cr := StaticBody2D.new()
						cr.set_script(load(E + "Crumble.gd"))
						cr.level = L
						cr.position = Vector2(x * TS, y * TS)
						L.world.add_child(cr)
						cr.setup(x2 - x + 1)
	sign_list.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
	var texts: Array = LevelStory.SIGNS.get(num, [])
	for i in sign_list.size():
		sign_list[i].text = texts[i] if i < texts.size() else ""
	_build_fake_walls(L, fake, m)


## Faux murs : les cases X voisines forment un seul mur, recouvert de sa peinture si elle existe.
static func _build_fake_walls(L: Node2D, fake: Dictionary, m: Dictionary) -> void:
	var seen := {}
	var covers: Array = m.get("covers", [])
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
		fw.level = L
		fw.cells = group
		L.world.add_child(fw)
		for cv in covers:
			var r := Rect2(cv["tx"], cv["ty"], cv["tw"], cv["th"])
			if r.has_point(Vector2(group[0]) + Vector2(0.5, 0.5)):
				var t := tex("res://art/l%d/%s" % [L.num, cv["file"]])
				if t:
					var s := Sprite2D.new()
					s.texture = t
					s.centered = false
					s.scale = Vector2(m.get("scale", 2.0), m.get("scale", 2.0))
					s.position = Vector2(cv["x"], cv["y"])
					fw.add_child(s)
					fw.sprite = s


static func build_player(L: Node2D) -> void:
	var player := CharacterBody2D.new()
	player.set_script(load("res://scripts/Player.gd"))
	player.level = L
	player.position = L.start_pos
	L.world.add_child(player)
	player.can_dash = Game.has_brush
	player.died.connect(L._on_died)
	L.player = player
	var cam := Camera2D.new()
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(L.W * TS)
	cam.limit_bottom = int(L.H * TS)
	cam.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	L.world.add_child(cam)
	cam.make_current()
	if L.num == 4:
		cam.zoom = Vector2(0.78, 0.78)
	L.cam = cam


static func build_color_layer(L: Node2D) -> ShaderMaterial:
	var cl := CanvasLayer.new()
	cl.layer = 5
	L.add_child(cl)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/couleur.gdshader")
	var paper := tex("res://art/papier.png")
	if paper:
		mat.set_shader_parameter("paper", paper)
	rect.material = mat
	cl.add_child(rect)
	L.color_rect = rect
	return mat

extends Node2D
## Un chapitre de Kevencre : caméra, couleur, mort et reprise, événements du chapitre.
## La construction (grille -> nœuds) est dans level/LevelBuilder.gd, les textes dans level/LevelStory.gd.

const TS := Game.TS
const E := "res://scripts/ent/"
const LevelGrid := preload("res://scripts/level/LevelGrid.gd")
const LevelBuilder := preload("res://scripts/level/LevelBuilder.gd")
const LevelStory := preload("res://scripts/level/LevelStory.gd")
const MAX_CIRCLES := 32          # taille du tableau "circles" du shader de couleur

var num := 1
var grid: Array = []
var custom_grid: Array = []     # tests : grille fournie à la place de levels/N.txt
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
var replay := false   # lancé depuis le menu Chapitres : ne remplace pas la sauvegarde
var _circles := PackedVector3Array()   # réutilisé à chaque image (pas d'allocation dans _process)

# ------------------------------------------------------------------ construction
func _ready() -> void:
	Game.level = num
	grid = custom_grid if not custom_grid.is_empty() else LevelGrid.load_grid(num)
	H = grid.size()
	W = grid[0].length()
	ground_color = LevelBuilder.ground_color(num)
	_circles.resize(MAX_CIRCLES)
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	var m := LevelBuilder.meta(num) if custom_grid.is_empty() else {}
	LevelBuilder.build_background(self, m)
	LevelBuilder.build_terrain_visual(self, m)
	LevelBuilder.build_collision(self)
	decals = load("res://scripts/Fx.gd").new()
	world.add_child(decals)
	decals.z_index = 1
	fx = load("res://scripts/Fx.gd").new()
	world.add_child(fx)
	LevelBuilder.spawn_entities(self, m)
	LevelBuilder.build_player(self)
	color_mat = LevelBuilder.build_color_layer(self)
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
	Game.music(LevelStory.MUSIC[mini(num, 4)])
	hud.banner("Chapitre %d" % num if num < 4 else "Dernier chapitre", Game.CHAPTERS[mini(num, 4)])
	if num == 4:
		_start_boss()
	else:
		intro_done = true

func ch(x: int, y: int) -> String:
	return LevelGrid.cell(grid, x, y)

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
	for i in range(strokes.size() - 1, -1, -1):
		if not is_instance_valid(strokes[i]):
			strokes.remove_at(i)

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
	var screen := Rect2(Vector2.ZERO, vs)
	var n := 0
	for w in waves:
		if n >= MAX_CIRCLES:
			break
		var sp: Vector2 = xf * w[0]
		var r: float = w[1]
		if screen.grow(r).has_point(sp):
			_circles[n] = Vector3(sp.x, sp.y, r)
			n += 1
	for i in range(n, MAX_CIRCLES):
		_circles[i] = Vector3(-9999, -9999, 0)
	color_mat.set_shader_parameter("circles", _circles)
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
	await hud.say(LevelStory.SHRINE)
	Game.has_brush = true
	player.can_dash = true
	fx.burst(shrine.global_position + Vector2(0, -90), 50)
	restore_at(shrine.global_position + Vector2(0, -60), 1300)
	Game.sfx("checkpoint", 0, 1.2)
	hud.toast(LevelStory.BRUSH_TOAST[0], LevelStory.BRUSH_TOAST[1], Game.PALETTE[1])
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
	await hud.say(LevelStory.BOSS_INTRO)
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
	await hud.say(LevelStory.BOSS_DEFEAT)
	Game.timing = false
	Game.main.goto("ending")

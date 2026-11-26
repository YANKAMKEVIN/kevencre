extends Node2D
## Le Délaveur : géant de térébenthine grise. Trois phases.
## On le blesse en frappant son cœur (Trait d'encre ou saut) quand il s'ouvre, après un coup de poing.

const FLOOR_Y := 816.0
var level: Node
var hp := 9
var phase := 1
var t := 0.0
var home := Vector2.ZERO
var body_y := 0.0
var sway := 0.0
var exposed := false
var expose_t := 0.0
var flash := 0.0
var started := false
var dying := false
var dead := false
var patches: Array = []        # [offset, couleur, rayon]
var hands: Array = []          # dictionnaires
var markers: Array = []        # [x, temps]
var waves: Array = []          # [x, dir, vitesse]
var flood := 0.0
var flood_target := 0.0
var core_cool := 0.0
var roar_t := 0.0

var haz: Node2D

func _ready() -> void:
	haz = Node2D.new()
	haz.z_as_relative = false
	haz.z_index = 7
	haz.top_level = true
	add_child(haz)
	haz.draw.connect(_draw_haz)
	home = position
	body_y = position.y
	z_index = -1
	for s in [-1, 1]:
		hands.append({"side": s, "pos": home + Vector2(s * 230, 170), "state": "idle", "timer": 0.0, "target": Vector2.ZERO})

func begin() -> void:
	started = true
	_loop()

func _w(s: float) -> void:
	await get_tree().create_timer(s, false, true).timeout

func _alive() -> bool:
	return not dying and is_inside_tree()

# ------------------------------------------------------------------ déroulé
func _loop() -> void:
	await _w(0.8)
	while _alive():
		match phase:
			1:
				await _slam(_pick_hand())
				if not _alive(): return
				await _expose(2.6)
				if not _alive(): return
				await _rain(6)
				await _w(0.8)
			2:
				_wave(1 if randf() < 0.5 else -1)
				await _w(1.4)
				if not _alive(): return
				await _slam(_pick_hand())
				if not _alive(): return
				await _expose(2.2)
				if not _alive(): return
				_rain(7)
				await _w(0.6)
				_wave(-1 if level.player.global_position.x > position.x else 1)
				await _w(1.6)
			3:
				flood_target = 1.0
				Game.sfx("flood", -2)
				await _w(1.2)
				await _rain(9)
				await _w(2.4)
				flood_target = 0.0
				await _w(1.0)
				if not _alive(): return
				_slam(hands[0])
				await _w(0.45)
				await _slam(hands[1])
				if not _alive(): return
				await _expose(2.0)
				if not _alive(): return
				_wave(1)
				await _w(0.9)
				_wave(-1)
				await _w(1.8)
		await _w(0.3)

func _pick_hand() -> Dictionary:
	var px: float = level.player.global_position.x
	return hands[0] if px < position.x else hands[1]

func _slam(h: Dictionary) -> void:
	h["state"] = "rise"
	h["timer"] = 0.0
	var tele := 0.85 if phase == 1 else (0.7 if phase == 2 else 0.6)
	await _w(tele)
	if not _alive(): return
	h["state"] = "slam"
	await _w(0.28)
	if not _alive(): return
	h["state"] = "stuck"
	level.shake(16)
	Game.sfx("slam", 0, randf_range(0.9, 1.05))
	level.fx.splash(Vector2(h["pos"].x, FLOOR_Y), Color(0.5, 0.5, 0.55, 0.8), 22, 420, 6.0)
	if phase >= 2:
		for d in [-1, 1]:
			level.spawn_projectile(Vector2(h["pos"].x + d * 60, FLOOR_Y - 20), Vector2(d * 330, -420), 1300.0, 10.0)
	await _w(1.0)
	h["state"] = "back"

func _expose(time: float) -> void:
	exposed = true
	expose_t = time
	Game.sfx("open", -3)
	while expose_t > 0.0 and exposed and _alive():
		await get_tree().physics_frame
	exposed = false

func _rain(n: int) -> void:
	var xs: Array = []
	var px: float = level.player.global_position.x
	xs.append(clampf(px, 140, 1490))
	for i in n - 1:
		xs.append(randf_range(140, 1490))
	for x in xs:
		markers.append([x, 0.8])
	Game.sfx("rain", -6)
	await _w(0.8)
	for x in xs:
		if not _alive(): return
		level.spawn_projectile(Vector2(x, 70), Vector2(0, 200), 1500.0, 13.0)
		await _w(0.07)

func _wave(dir: int) -> void:
	var x := 110.0 if dir > 0 else 1522.0
	waves.append([x, dir, 470.0 + phase * 40.0])
	Game.sfx("wave", -3)

# ------------------------------------------------------------------ boucle
func _physics_process(delta: float) -> void:
	t += delta
	flash = maxf(0, flash - delta * 3)
	core_cool -= delta
	roar_t -= delta
	var p = level.player
	# corps
	var low := home.y + (150.0 if exposed else 0.0)
	body_y = lerpf(body_y, low, 1.0 - exp(-4.0 * delta))
	if not dying:
		sway = sin(t * 0.6) * 120.0
	position = Vector2(home.x + sway, body_y + sin(t * 1.7) * 8.0)
	if exposed:
		expose_t -= delta
	# mains
	for h in hands:
		var rest: Vector2 = position + Vector2(h["side"] * 240, 150 + sin(t * 2 + h["side"]) * 10)
		match h["state"]:
			"idle", "back":
				h["pos"] = h["pos"].lerp(rest, 1.0 - exp(-5.0 * delta))
				if h["state"] == "back" and h["pos"].distance_to(rest) < 10:
					h["state"] = "idle"
			"rise":
				h["target"] = Vector2(clampf(p.global_position.x, 150, 1480), 300)
				h["pos"] = h["pos"].lerp(h["target"], 1.0 - exp(-9.0 * delta))
			"slam":
				h["pos"].y = move_toward(h["pos"].y, FLOOR_Y - 52, 2200 * delta)
			"stuck":
				pass
		if h["state"] in ["slam", "stuck"] and not p.dead:
			var r := Rect2(h["pos"] - Vector2(58, 52), Vector2(116, 104))
			if Rect2(p.global_position - Vector2(12, 40), Vector2(24, 40)).intersects(r):
				p.hurt(h["pos"])
	# repères de pluie
	var km: Array = []
	for m in markers:
		m[1] -= delta
		if m[1] > 0:
			km.append(m)
	markers = km
	# vagues
	var kw: Array = []
	for w in waves:
		w[0] += w[1] * w[2] * delta
		if w[0] > 60 and w[0] < 1580:
			kw.append(w)
			var r := Rect2(w[0] - 40, FLOOR_Y - 70, 80, 70)
			if not p.dead and Rect2(p.global_position - Vector2(12, 40), Vector2(24, 40)).intersects(r):
				p.hurt(Vector2(w[0], FLOOR_Y))
	waves = kw
	# inondation
	flood = move_toward(flood, flood_target, delta * 1.1)
	if flood > 0.2 and not p.dead:
		var top := FLOOR_Y - 120.0 * flood
		if p.global_position.y > top + 6:
			p.hurt(p.global_position + Vector2(0, 40))
			if not p.dead:
				p.bounce(900, true)
	# cœur
	if started and not dying and not p.dead and core_cool <= 0.0:
		var core := core_pos()
		var pc: Vector2 = p.global_position + Vector2(0, -20)
		if pc.distance_to(core) < 52:
			if exposed and (p.is_attacking() or p.velocity.y > 60):
				_hit(p)
			elif p.is_attacking():
				core_cool = 0.4
				Game.sfx("clink", -4)
				p.velocity = (pc - core).normalized() * 500
				p.dashing = 0.0
	queue_redraw()
	haz.queue_redraw()

func core_pos() -> Vector2:
	return position + Vector2(0, 46)

func _hit(p) -> void:
	hp -= 1
	core_cool = 0.6
	exposed = false
	flash = 1.0
	var c: Color = Game.PALETTE[(9 - hp) % 5]
	patches.append([Vector2(randf_range(-110, 110), randf_range(-150, 80)), c, randf_range(28, 50)])
	level.fx.burst(core_pos(), 40)
	level.hitstop(0.12)
	level.shake(18)
	level.restore_at(core_pos(), 260)
	Game.sfx("bosshit", 0)
	p.dashing = 0.0
	p.velocity = Vector2(signf(p.global_position.x - position.x) * 420, -640)
	p.can_dash = true
	if hp <= 0:
		_die()
		return
	var np := 1 + (9 - hp) / 3
	if np != phase:
		phase = np
		Game.sfx("roar", 0)
		roar_t = 1.2
		level.shake(24)
		level.hud.toast("Le Délaveur s'énerve !", ["", "", "Ses vagues grises balaient le sol. Saute par-dessus !", "Il inonde l'atelier. Reste sur les plateformes et sur tes traits !"][phase], Color(0.4, 0.4, 0.45))

func _die() -> void:
	dying = true
	flood_target = 0.0
	waves.clear()
	for h in hands:
		h["state"] = "idle"
	Game.sfx("roar", 0, 0.8)
	for i in 14:
		level.fx.burst(position + Vector2(randf_range(-150, 150), randf_range(-160, 120)), 24)
		patches.append([Vector2(randf_range(-130, 130), randf_range(-170, 100)), Game.PALETTE[i % 5], randf_range(30, 60)])
		level.shake(10)
		Game.sfx("splat", -2, randf_range(0.7, 1.2))
		await get_tree().create_timer(0.14).timeout
	dead = true
	level.boss_defeated()

func on_player_respawn() -> void:
	flood_target = 0.0
	waves.clear()

# ------------------------------------------------------------------ dessin
func _blob(p: Vector2, r: Vector2, col: Color, wob: float, seed_v: float, n := 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		var k := 1.0 + wob * sin(a * 3.0 + t * 1.5 + seed_v) + wob * 0.5 * sin(a * 7.0 - t * 2.0 + seed_v)
		pts.append(p + Vector2(cos(a) * r.x * k, sin(a) * r.y * k))
	draw_colored_polygon(pts, col)
	return pts

func _draw_haz() -> void:
	# repères au sol (dans le repère du boss)
	for m in markers:
		var lp := Vector2(m[0], FLOOR_Y - 4)
		var a: float = 1.0 - m[1] / 0.8
		haz.draw_set_transform(lp, 0, Vector2(1, 0.3))
		haz.draw_circle(Vector2.ZERO, 26 * a + 8, Color(0.75, 0.15, 0.12, 0.35 + 0.3 * a))
		haz.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# inondation
	if flood > 0.01:
		var top := FLOOR_Y - 120.0 * flood
		var pts := PackedVector2Array()
		for i in 41:
			var x := 96.0 + i * (1440.0 / 40.0)
			pts.append(Vector2(x, top + sin(x * 0.02 + t * 3) * 6))
		pts.append(Vector2(1536, FLOOR_Y + 10))
		pts.append(Vector2(96, FLOOR_Y + 10))
		haz.draw_colored_polygon(pts, Color(0.2, 0.2, 0.27, 0.85))
		var foam := PackedVector2Array()
		for i in 41:
			foam.append(pts[i])
		haz.draw_polyline(foam, Color(0.92, 0.92, 0.96, 0.9), 4.0, true)
	# vagues
	for w in waves:
		var base := Vector2(w[0], FLOOR_Y)
		var pts := PackedVector2Array()
		for i in 13:
			var f := i / 12.0
			var x := lerpf(-50, 50, f)
			var y := -70.0 * sin(f * PI) * (1.0 + 0.15 * sin(t * 10 + f * 6))
			pts.append(base + Vector2(x * w[1], y))
		haz.draw_colored_polygon(pts, Color(0.2, 0.2, 0.27, 0.9))
		var crest := pts.duplicate()
		haz.draw_polyline(crest, Color(0.92, 0.92, 0.96, 0.9), 3.0, true)
		for k in 4:
			haz.draw_circle(base + Vector2(randf_range(-40, 40), randf_range(-70, -10)), 4, Color(0.8, 0.8, 0.84, 0.7))

func _draw() -> void:
	if dead:
		return
	var a_body := 1.0
	if dying:
		a_body = 0.7 + 0.3 * sin(t * 30)
	var grey := Color(0.56, 0.56, 0.6, 0.9 * a_body).lerp(Color(1, 1, 1, a_body), flash * 0.6)
	# coulures
	for k in 9:
		var x := -120 + k * 30
		var len := 60 + sin(t * 1.3 + k) * 20 + (k % 3) * 25
		draw_line(Vector2(x, 120), Vector2(x, 120 + len), Color(grey, 0.8), 14.0, true)
		draw_circle(Vector2(x, 124 + len), 9, Color(grey, 0.8))
	# corps en couches d'aquarelle
	_blob(Vector2(0, 0), Vector2(175, 205), Color(grey.darkened(0.15), 0.6 * a_body), 0.05, 0.0)
	_blob(Vector2(0, 0), Vector2(160, 190), grey, 0.04, 1.3)
	_blob(Vector2(-30, -40), Vector2(100, 110), Color(1, 1, 1, 0.08), 0.06, 2.0)
	for pt in patches:
		_blob(pt[0], Vector2(pt[2], pt[2] * 0.85), Color(pt[1], 0.85), 0.12, pt[2])
	var outline := _blob(Vector2(0, 0), Vector2(160, 190), Color(0, 0, 0, 0), 0.04, 1.3)
	outline.append(outline[0])
	draw_polyline(outline, Color(0.22, 0.22, 0.28, 0.8), 3.0, true)
	# yeux
	var rage := 1.0 if roar_t > 0 or phase == 3 else 0.0
	for s in [-1, 1]:
		var ep := Vector2(s * 55, -70)
		_blob(ep, Vector2(30, 22 + rage * 4), Color(0.18, 0.18, 0.24), 0.05, s)
		draw_circle(ep + Vector2(s * -4, 2), 7, Color(0.92, 0.92, 0.95, 0.9))
		draw_line(ep + Vector2(-34, -30 + s * rage * 8), ep + Vector2(34, -30 - s * rage * 8), Color(0.2, 0.2, 0.25), 6.0, true)
	# bouche
	var mouth := PackedVector2Array()
	var open := 10.0 + rage * 20.0 + (16.0 if exposed else 0.0)
	for i in 11:
		var f := i / 10.0
		mouth.append(Vector2(lerpf(-60, 60, f), -10 + sin(f * PI) * open))
	draw_polyline(mouth, Color(0.18, 0.18, 0.24), 6.0, true)
	# cœur
	var cp := core_pos() - position
	if exposed:
		var pulse := 1.0 + sin(t * 12) * 0.08
		for k in 5:
			var a := t * 2.0 + k * TAU / 5
			draw_circle(cp + Vector2(cos(a), sin(a)) * 46, 8, Game.PALETTE[k])
		draw_circle(cp, 38 * pulse, Color(1, 0.95, 0.75, 0.5))
		draw_circle(cp, 28 * pulse, Color(1, 0.98, 0.9))
		draw_circle(cp, 16, Game.PALETTE[(9 - hp) % 5])
	else:
		draw_circle(cp, 32, grey.darkened(0.2))
		draw_line(cp + Vector2(-28, 0), cp + Vector2(28, 0), Color(0.22, 0.22, 0.28), 3.0, true)
		draw_arc(cp, 32, 0, TAU, 24, Color(0.22, 0.22, 0.28, 0.8), 2.0, true)
	# mains
	for h in hands:
		var hp_l: Vector2 = h["pos"] - position
		if h["state"] == "rise":
			var sx := Vector2(h["pos"].x, FLOOR_Y - 4) - position
			draw_set_transform(sx, 0, Vector2(1, 0.25))
			draw_circle(Vector2.ZERO, 60, Color(0.2, 0.2, 0.26, 0.4))
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		var hc := grey
		var hand := _blob(hp_l, Vector2(58, 50), hc, 0.07, h["side"] * 3.0)
		for f in 4:
			_blob(hp_l + Vector2(-36 + f * 24, 42), Vector2(13, 18), hc, 0.05, f)
		hand.append(hand[0])
		draw_polyline(hand, Color(0.22, 0.22, 0.28, 0.8), 3.0, true)

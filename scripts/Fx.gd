extends Node2D
## Éclaboussures d'encre et taches de couleur laissées au sol.

var parts: Array = []      # [pos, vel, life, max_life, col, size, grav]
var decals: Array = []     # [pos, col, size, seed]
var texts: Array = []      # [pos, text, life, col]

func _ready() -> void:
	z_index = 8

func splash(p: Vector2, col: Color, n: int, speed: float, size: float, grav := 900.0) -> void:
	for i in n:
		var a := randf() * TAU
		var v := Vector2(cos(a), sin(a)) * randf_range(speed * 0.3, speed)
		v.y -= speed * 0.35
		var life := randf_range(0.3, 0.7)
		parts.append([p, v, life, life, col, randf_range(size * 0.5, size * 1.4), grav])

func burst(p: Vector2, n := 26) -> void:
	for i in n:
		var c: Color = Game.PALETTE[randi() % Game.PALETTE.size()]
		var a := randf() * TAU
		var v := Vector2(cos(a), sin(a)) * randf_range(120, 520)
		var life := randf_range(0.4, 0.9)
		parts.append([p, v, life, life, c, randf_range(3, 8), 700.0])

func decal(p: Vector2, col: Color, size := 30.0) -> void:
	decals.append([p, col, size, randi()])
	if decals.size() > 80:
		decals.pop_front()

func float_text(p: Vector2, s: String, col := Color(0.2, 0.18, 0.3)) -> void:
	texts.append([p, s, 1.4, col])

func _process(delta: float) -> void:
	var keep: Array = []
	for q in parts:
		q[2] -= delta
		if q[2] <= 0:
			continue
		q[1].y += q[6] * delta
		q[1] *= 0.985
		q[0] += q[1] * delta
		keep.append(q)
	parts = keep
	var kt: Array = []
	for q in texts:
		q[2] -= delta
		q[0].y -= 30 * delta
		if q[2] > 0:
			kt.append(q)
	texts = kt
	queue_redraw()

func _draw() -> void:
	for d in decals:
		var rng := RandomNumberGenerator.new()
		rng.seed = d[3]
		var p: Vector2 = d[0]
		var s: float = d[2]
		var c: Color = d[1]
		draw_set_transform(p, 0, Vector2(1, 0.35))
		draw_circle(Vector2.ZERO, s, Color(c, 0.55))
		for k in 7:
			draw_circle(Vector2(rng.randf_range(-s, s) * 1.3, rng.randf_range(-s, s) * 0.6), rng.randf_range(s * 0.2, s * 0.5), Color(c, 0.6))
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	for q in parts:
		var f: float = q[2] / q[3]
		var c: Color = q[4]
		draw_circle(q[0], q[5] * (0.4 + 0.6 * f), Color(c, c.a * minf(1.0, f * 1.6)))
	var font := ThemeDB.fallback_font
	for q in texts:
		var a: float = clampf(q[2], 0, 1)
		draw_string(font, q[0] + Vector2(-60, 0), q[1], HORIZONTAL_ALIGNMENT_CENTER, 120, 18, Color(q[3], a))

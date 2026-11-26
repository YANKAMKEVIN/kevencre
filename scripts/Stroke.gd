extends StaticBody2D
## Trait d'encre : la trajectoire du trait devient une plateforme, le temps qu'elle sèche.

const LIFE := 1.9
var pts := PackedVector2Array()       # coordonnées du monde
var col := Color(0.18, 0.36, 0.78)
var vertical := false
var side := 1
var age := 0.0
var done := false
var solid := false
var bristles: Array = []
var splats: Array = []

func setup(dir: Vector2, facing: int, c: Color) -> void:
	col = c
	vertical = absf(dir.x) <= 0.3
	side = facing
	add_to_group("stroke")
	collision_layer = 1
	collision_mask = 0
	z_index = 3
	for i in 5:
		bristles.append(randf_range(-7.0, 7.0))
	top_level = true
	global_position = Vector2.ZERO

func add_point(p: Vector2) -> void:
	if pts.size() > 0 and pts[pts.size() - 1].distance_to(p) < 3.0:
		return
	pts.append(p)
	if randf() < 0.35:
		splats.append([p + Vector2(randf_range(-16, 16), randf_range(-14, 14)), randf_range(1.5, 4.5)])
	queue_redraw()

func finish() -> void:
	if done:
		return
	done = true
	if pts.size() < 2:
		return
	if vertical:
		var a := pts[0]
		var b := pts[pts.size() - 1]
		var top := minf(a.y, b.y) - 14
		var bot := maxf(a.y, b.y) + 14
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(12, bot - top)
		cs.shape = r
		cs.position = Vector2(a.x, (top + bot) / 2)
		add_child(cs)
	else:
		var total := 0.0
		for i in range(pts.size() - 1):
			total += pts[i].distance_to(pts[i + 1])
		var step := 9.0
		var dist := 0.0
		var i := 0
		var acc := 0.0
		while dist <= total and i < pts.size() - 1:
			var seg := pts[i].distance_to(pts[i + 1])
			if acc + seg < dist:
				acc += seg
				i += 1
				continue
			var f := (dist - acc) / maxf(seg, 0.001)
			var p := pts[i].lerp(pts[i + 1], f)
			var cs := CollisionShape2D.new()
			var r := RectangleShape2D.new()
			r.size = Vector2(16, 10)
			cs.shape = r
			cs.position = p + Vector2(0, 5)
			cs.one_way_collision = true
			cs.one_way_collision_margin = 12.0
			add_child(cs)
			dist += step
	solid = true

func _physics_process(delta: float) -> void:
	if not done:
		return
	age += delta
	if age > LIFE and solid:
		solid = false
		for c in get_children():
			if c is CollisionShape2D:
				c.set_deferred("disabled", true)
		Game.sfx("dry", -14, randf_range(0.9, 1.2))
	if age > LIFE + 0.45:
		queue_free()
	queue_redraw()

func _draw() -> void:
	if pts.size() < 1:
		return
	var a := 1.0
	var c := col
	if done:
		var left := LIFE - age
		if left < 0.55 and left > 0:
			a = 0.55 + 0.45 * (0.5 + 0.5 * sin(age * 40.0))
			c = col.lerp(Color(0.6, 0.6, 0.62), 0.35)
		elif left <= 0:
			a = clampf(1.0 + left / 0.45, 0, 1) * 0.6
			c = Color(0.6, 0.6, 0.62)
	if pts.size() == 1:
		draw_circle(pts[0], 9, Color(c, a))
		return
	var dark := Color(c.darkened(0.45), a)
	draw_polyline(pts, dark, 20.0, true)
	draw_polyline(pts, Color(c, a), 15.0, true)
	draw_polyline(pts, Color(c.lightened(0.25), a * 0.8), 6.0, true)
	# poils du pinceau
	for k in bristles.size():
		var off: float = bristles[k]
		var bp := PackedVector2Array()
		for i in pts.size():
			var n := Vector2.ZERO
			if i < pts.size() - 1:
				n = (pts[i + 1] - pts[i]).orthogonal().normalized()
			elif i > 0:
				n = (pts[i] - pts[i - 1]).orthogonal().normalized()
			bp.append(pts[i] + n * off)
		draw_polyline(bp, Color(c.darkened(0.25), a * 0.45), 1.5, true)
	draw_circle(pts[0], 9.0, Color(c, a))
	draw_circle(pts[pts.size() - 1], 10.0, Color(c, a))
	draw_circle(pts[pts.size() - 1] + Vector2(3, -2), 4.0, Color(c.lightened(0.3), a * 0.7))
	for s in splats:
		draw_circle(s[0], s[1], Color(c, a * 0.85))

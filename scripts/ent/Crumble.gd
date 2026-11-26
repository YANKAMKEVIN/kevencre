extends StaticBody2D
## Papier qui se déchire quand on reste dessus.

var level: Node
var width := 1
var timer := -1.0
var gone := 0.0
var shape: CollisionShape2D
var t := 0.0
var seed_v := 0

func setup(w: int) -> void:
	width = w
	add_to_group("crumble")
	add_to_group("terrain_soft")
	shape = CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(w * Game.TS, 16)
	shape.shape = r
	shape.position = Vector2(w * Game.TS / 2.0, 8)
	shape.one_way_collision = true
	shape.one_way_collision_margin = 8.0
	add_child(shape)
	collision_layer = 1
	z_index = 2
	seed_v = randi()

func _physics_process(delta: float) -> void:
	t += delta
	var p = level.player
	if gone > 0.0:
		gone -= delta
		if gone <= 0.0:
			shape.set_deferred("disabled", false)
			Game.sfx("paper", -16, 1.4)
		queue_redraw()
		return
	if timer < 0.0 and p and p.on_floor:
		var c = p.get_last_slide_collision()
		if c and c.get_collider() == self:
			timer = 0.5
			Game.sfx("paper", -10, 1.0)
	if timer >= 0.0:
		timer -= delta
		if timer < 0.0:
			gone = 2.6
			shape.set_deferred("disabled", true)
			Game.sfx("paper", -6, 0.8)
			for i in width * 3:
				level.fx.splash(global_position + Vector2(randf() * width * Game.TS, 6), Color(0.95, 0.92, 0.85), 1, 80, 6.0, 700)
	queue_redraw()

func _draw() -> void:
	if gone > 0.0:
		var a := clampf(1.0 - gone / 0.5, 0, 0.35) if gone < 0.5 else 0.0
		if a > 0:
			draw_rect(Rect2(0, 0, width * Game.TS, 14), Color(0.95, 0.92, 0.85, a))
		return
	var off := Vector2.ZERO
	if timer >= 0.0:
		off = Vector2(randf_range(-2, 2), randf_range(-1, 2))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var w := width * Game.TS
	var top := PackedVector2Array()
	var n := width * 6
	for i in n + 1:
		top.append(off + Vector2(w * i / n, rng.randf_range(-2, 1)))
	var poly := top.duplicate()
	for i in range(n, -1, -1):
		poly.append(off + Vector2(w * i / n, 14 + rng.randf_range(-1, 4)))
	draw_colored_polygon(poly, Color(0.96, 0.93, 0.86))
	poly.append(poly[0])
	draw_polyline(poly, Color(0.45, 0.4, 0.35), 1.5, true)
	for k in width * 2:
		var x := rng.randf_range(6, w - 12)
		draw_line(off + Vector2(x, 5), off + Vector2(x + rng.randf_range(6, 16), 6), Color(0.3, 0.3, 0.45, 0.45), 1.5)
	if timer >= 0.0:
		draw_line(off + Vector2(w * 0.4, 0), off + Vector2(w * 0.5, 14), Color(0.3, 0.25, 0.2), 1.5)

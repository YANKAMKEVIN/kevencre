extends "res://scripts/ent/Entity.gd"
## Goutte de recharge : rend le Trait d'encre en plein vol.

var cd := 0.0

func _physics_process(delta: float) -> void:
	phase += delta
	cd -= delta
	if cd <= 0.0 and touching(Rect2(global_position - Vector2(22, 22), Vector2(44, 44))):
		if pl().refill_dash():
			cd = 2.4
			Game.sfx("refill", -3)
			level.fx.splash(global_position, Color(0.86, 0.25, 0.22), 14, 220, 3.5, 200)
	queue_redraw()

func _draw() -> void:
	var y := sin(phase * 2.5) * 5.0
	if cd > 0.0:
		draw_arc(Vector2(0, y), 12, 0, TAU * (1.0 - cd / 2.4), 24, Color(0.4, 0.4, 0.45, 0.5), 2.0, true)
		return
	var c := Color(0.86, 0.25, 0.22)
	draw_arc(Vector2(0, y), 20 + sin(phase * 4) * 2, 0, TAU, 28, Color(c, 0.35), 3.0, true)
	var pts := PackedVector2Array([Vector2(0, -16), Vector2(10, 2), Vector2(0, 14), Vector2(-10, 2)])
	for i in pts.size():
		pts[i] += Vector2(0, y)
	draw_colored_polygon(pts, c)
	pts.append(pts[0])
	draw_polyline(pts, c.darkened(0.5), 2.0, true)
	draw_line(Vector2(-4, y - 2), Vector2(0, y - 10), Color(1, 1, 1, 0.6), 2.0)

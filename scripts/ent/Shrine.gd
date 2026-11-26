extends "res://scripts/ent/Entity.gd"
## Autel du Vieux Pinceau : donne le Trait d'encre.

var used := false

func _ready() -> void:
	super()
	z_index = 1
	used = Game.has_brush

func _physics_process(delta: float) -> void:
	phase += delta
	if not used and touching(Rect2(global_position + Vector2(-50, -120), Vector2(100, 120))):
		used = true
		level.shrine_event(self)
	queue_redraw()

func _draw() -> void:
	var stone := Color(0.6, 0.58, 0.55)
	var pts := PackedVector2Array([Vector2(-34, 0), Vector2(34, 0), Vector2(26, -34), Vector2(-26, -34)])
	draw_colored_polygon(pts, stone)
	pts.append(pts[0])
	draw_polyline(pts, stone.darkened(0.5), 2.0)
	draw_rect(Rect2(-32, -42, 64, 9), stone.lightened(0.1))
	draw_rect(Rect2(-32, -42, 64, 9), stone.darkened(0.5), false, 2.0)
	if used:
		return
	var y := -95 + sin(phase * 1.6) * 6
	draw_set_transform(Vector2(0, y), 0.5 + sin(phase) * 0.06, Vector2.ONE)
	draw_rect(Rect2(-4, -40, 8, 52), Color(0.55, 0.32, 0.18))
	draw_rect(Rect2(-5, 10, 10, 8), Color(0.75, 0.7, 0.6))
	var tip := PackedVector2Array([Vector2(-6, 18), Vector2(6, 18), Vector2(4, 34), Vector2(0, 44), Vector2(-4, 34)])
	draw_colored_polygon(tip, Game.INK)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	for k in 5:
		var a := phase + k * TAU / 5
		draw_circle(Vector2(cos(a) * 40, y + sin(a) * 18), 3, Color(Game.PALETTE[k], 0.8))

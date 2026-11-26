extends "res://scripts/ent/Entity.gd"
## Panneau peint : affiche un conseil quand Sépia s'approche.

var text := ""
var showing := false

func _ready() -> void:
	super()
	z_index = 1

func _physics_process(delta: float) -> void:
	phase += delta
	var n := near(110)
	if n and not showing:
		showing = true
		level.hud.show_hint(text, self)
	elif not n and showing:
		showing = false
		level.hud.hide_hint(self)

func _draw() -> void:
	var wood := Color(0.42, 0.29, 0.2)
	draw_line(Vector2(0, 0), Vector2(0, -44), wood, 5.0)
	var pts := PackedVector2Array([Vector2(-22, -66), Vector2(22, -68), Vector2(24, -42), Vector2(-23, -40)])
	draw_colored_polygon(pts, Color(0.96, 0.92, 0.82))
	pts.append(pts[0])
	draw_polyline(pts, wood.darkened(0.3), 2.0)
	draw_line(Vector2(-14, -60), Vector2(12, -60), Color(0.3, 0.3, 0.4, 0.6), 2.0)
	draw_line(Vector2(-14, -53), Vector2(8, -53), Color(0.3, 0.3, 0.4, 0.6), 2.0)
	draw_line(Vector2(-14, -47), Vector2(14, -47), Color(0.3, 0.3, 0.4, 0.6), 2.0)

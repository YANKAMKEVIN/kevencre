extends "res://scripts/ent/Entity.gd"
## Cadre vide : la sortie du chapitre.

var used := false

func _ready() -> void:
	super()
	z_index = 1

func _physics_process(delta: float) -> void:
	phase += delta
	if not used and touching(Rect2(global_position + Vector2(-40, -130), Vector2(80, 130))):
		used = true
		level.complete()
	queue_redraw()

func _draw() -> void:
	var gold := Color(0.78, 0.6, 0.25)
	var r := Rect2(-44, -136, 88, 120)
	for k in 6:
		var a := phase * 0.8 + k * TAU / 6
		var c: Color = Game.PALETTE[k % 5]
		draw_circle(r.get_center() + Vector2(cos(a) * 22, sin(a * 1.3) * 34), 22, Color(c, 0.45))
	draw_circle(r.get_center(), 14 + sin(phase * 3) * 3, Color(1, 1, 0.95, 0.8))
	draw_rect(r, gold, false, 9.0)
	draw_rect(r.grow(5), gold.darkened(0.45), false, 2.0)
	draw_rect(r.grow(-5), gold.darkened(0.3), false, 1.5)
	for c in [r.position, r.position + Vector2(r.size.x, 0), r.end, r.position + Vector2(0, r.size.y)]:
		draw_circle(c, 8, gold)
		draw_circle(c, 8, gold.darkened(0.4))
		draw_circle(c, 6, gold.lightened(0.1))
	draw_line(Vector2(-30, -16), Vector2(-44, 0), Color(0.4, 0.3, 0.2), 4)
	draw_line(Vector2(30, -16), Vector2(44, 0), Color(0.4, 0.3, 0.2), 4)

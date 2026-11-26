extends "res://scripts/ent/Entity.gd"
## Fleur-ressort : propulse très haut et rend le Trait d'encre.

var squish := 0.0
var col := Color(0.9, 0.45, 0.6)

func _ready() -> void:
	super()
	col = [Color(0.92, 0.42, 0.55), Color(0.95, 0.66, 0.2), Color(0.55, 0.42, 0.85)][tile.x % 3]

func _physics_process(delta: float) -> void:
	phase += delta
	squish = maxf(0.0, squish - delta * 3.0)
	var p := pl()
	if p and not p.dead and p.velocity.y >= -50 and touching(Rect2(global_position + Vector2(-26, -26), Vector2(52, 26))):
		p.global_position.y = minf(p.global_position.y, global_position.y - 18)
		p.bounce()
		squish = 1.0
		Game.sfx("boing", -2, randf_range(0.95, 1.05))
		level.fx.splash(global_position + Vector2(0, -20), col, 12, 240, 4.0)
	queue_redraw()

func _draw() -> void:
	var s := 1.0 - squish * 0.45
	draw_line(Vector2(0, 0), Vector2(sin(phase) * 2, -14 * s), Color(0.25, 0.45, 0.25), 4.0)
	ellipse(Vector2(-10, -5), Vector2(9, 4), Color(0.3, 0.55, 0.3), -0.5)
	ellipse(Vector2(10, -6), Vector2(9, 4), Color(0.3, 0.55, 0.3), 0.5)
	var c := Vector2(sin(phase) * 2, -18 * s)
	for k in 7:
		var a := TAU * k / 7.0 + phase * 0.3
		ellipse(c + Vector2(cos(a) * 15, sin(a) * 7 * s), Vector2(11, 6 * s), col if k % 2 == 0 else col.lightened(0.15), a)
	ellipse(c, Vector2(9, 5 * s), Color(0.98, 0.85, 0.3))
	ellipse(c, Vector2(9, 5 * s), Color(0.98, 0.85, 0.3))
	draw_arc(c, 9, 0, TAU, 16, col.darkened(0.5), 1.5, true)

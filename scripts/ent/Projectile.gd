extends "res://scripts/ent/Entity.gd"
## Goutte délavée tirée par un Crachin ou par le Délaveur.

var vel := Vector2.ZERO
var life := 4.0
var t := 0.0
var r := 9.0
var grav := 0.0

func _physics_process(delta: float) -> void:
	t += delta
	life -= delta
	vel.y += grav * delta
	global_position += vel * delta
	if life <= 0 or level.solid_px(global_position):
		_pop(false)
		return
	var p := pl()
	if p and not p.dead:
		if (p.global_position + Vector2(0, -20)).distance_to(global_position) < r + 14:
			if p.is_attacking():
				level.fx.burst(global_position, 12)
				Game.sfx("splat", -8, 1.4)
				queue_free()
				return
			p.hurt(global_position)
			_pop(true)
			return
	queue_redraw()

func _pop(_hit: bool) -> void:
	level.fx.splash(global_position, Color(0.5, 0.5, 0.55, 0.8), 8, 140, 3.0)
	queue_free()

func _draw() -> void:
	var a := vel.angle()
	var pts := PackedVector2Array()
	for i in 12:
		var ang := TAU * i / 12.0
		var rr := r * (1.0 + 0.5 * maxf(0, cos(ang + PI)))
		pts.append(Vector2(cos(ang) * rr, sin(ang) * r).rotated(a))
	draw_colored_polygon(pts, Color(0.22, 0.22, 0.3, 0.95))
	pts.append(pts[0])
	draw_polyline(pts, Color(0.9, 0.9, 0.95, 0.8), 1.5, true)
	draw_circle(Vector2(-2, -3), 2.5, Color(1, 1, 1, 0.4))

extends "res://scripts/ent/Enemy.gd"
## Crachin : nuage gris qui crache des gouttes délavées vers Sépia.

var cd := 2.0
var swell := 0.0

func _ready() -> void:
	super()
	radius = 22
	z_index = 4
	cd = randf_range(1.0, 2.5)

func _physics_process(delta: float) -> void:
	t += delta
	if not alive:
		return
	var p := pl()
	if p and not p.dead and near(560):
		cd -= delta
		if cd < 0.55:
			swell = 1.0 - cd / 0.55
		if cd <= 0.0:
			cd = 2.3
			swell = 0.0
			var d: Vector2 = ((p.global_position + Vector2(0, -20)) - global_position).normalized()
			level.spawn_projectile(global_position + d * 24, d * 300.0)
			Game.sfx("spit", -6, randf_range(0.9, 1.1))
	else:
		swell = maxf(0, swell - delta)
	check_player()
	queue_redraw()

func _draw() -> void:
	var g := Color(0.52, 0.53, 0.57)
	var s := 1.0 + swell * 0.25
	blob(Vector2(-12, 2) * s, 14 * s, g, 0.06, t, 14, g.darkened(0.4))
	blob(Vector2(12, 2) * s, 14 * s, g, 0.06, t + 1, 14, g.darkened(0.4))
	blob(Vector2(0, -6) * s, 18 * s, g, 0.06, t + 2, 16, g.darkened(0.4))
	blob(Vector2(0, 0), 15 * s, g, 0.05, t, 14)
	var p := pl()
	var look := Vector2.ZERO
	if p:
		look = ((p.global_position + Vector2(0, -20)) - global_position).normalized() * 2
	for k in [-1, 1]:
		ellipse(Vector2(k * 6, -4) + look, Vector2(3.5, 3.5 + swell * 1.5), Color(0.95, 0.95, 0.92))
		ellipse(Vector2(k * 6, -4) + look * 1.8, Vector2(1.6, 1.8), Color(0.12, 0.12, 0.15))
	ellipse(Vector2(0, 6) + look, Vector2(3 + swell * 3, 2 + swell * 3), Color(0.2, 0.2, 0.25))
	for k in 3:
		var y := fmod(t * 30 + k * 9, 24)
		draw_circle(Vector2(-10 + k * 10, 14 + y), 2, Color(g, 1.0 - y / 24))

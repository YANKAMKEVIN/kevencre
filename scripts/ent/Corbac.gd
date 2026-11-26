extends "res://scripts/ent/Enemy.gd"
## Corbac de papier gris : vole en rond et plonge sur Sépia.

var home := Vector2.ZERO
var state := 0          # 0 ronde, 1 préparation, 2 plongée, 3 retour
var timer := 0.0
var target := Vector2.ZERO
var facing := 1

func _ready() -> void:
	super()
	radius = 18
	z_index = 4
	home = global_position
	timer = randf_range(1.0, 2.0)

func _physics_process(delta: float) -> void:
	t += delta
	if not alive:
		return
	var p := pl()
	match state:
		0:
			var np := home + Vector2(sin(t * 0.9 + phase) * 110, sin(t * 1.8 + phase) * 22)
			facing = 1 if np.x > global_position.x else -1
			global_position = np
			timer -= delta
			if timer <= 0.0 and p and not p.dead and near(330):
				state = 1
				timer = 0.45
				Game.sfx("caw", -8, randf_range(0.9, 1.1))
		1:
			timer -= delta
			global_position.y -= 40 * delta
			if timer <= 0.0:
				state = 2
				target = p.global_position + Vector2(0, -20)
				target = global_position + (target - global_position).normalized() * 420
				facing = 1 if target.x > global_position.x else -1
		2:
			global_position = global_position.move_toward(target, 430 * delta)
			if global_position.distance_to(target) < 4 or level.solid_px(global_position):
				state = 3
		3:
			var back := home + Vector2(sin(t * 0.9 + phase) * 110, 0)
			global_position = global_position.move_toward(back, 170 * delta)
			if global_position.distance_to(back) < 6:
				state = 0
				timer = randf_range(1.6, 2.6)
	check_player()
	queue_redraw()

func _draw() -> void:
	var g := Color(0.5, 0.5, 0.54)
	var flap := sin(t * (16.0 if state == 2 else 9.0)) * 14.0
	if state == 2:
		flap = -6
	draw_set_transform(Vector2.ZERO, 0, Vector2(facing, 1))
	var body := PackedVector2Array([Vector2(-20, 2), Vector2(-6, -8), Vector2(12, -6), Vector2(22, -1), Vector2(12, 6), Vector2(-6, 8)])
	draw_colored_polygon(body, g)
	body.append(body[0])
	draw_polyline(body, g.darkened(0.5), 2.0, true)
	var apex := Vector2(-6, -6 - (10.0 + flap))
	if absf(apex.y + 4) > 2.0:
		var wing := PackedVector2Array([Vector2(-8, -4), Vector2(10, -4), apex])
		draw_colored_polygon(wing, g.lightened(0.15))
		wing.append(wing[0])
		draw_polyline(wing, g.darkened(0.5), 1.5, true)
	else:
		draw_line(Vector2(-8, -4), Vector2(10, -4), g.darkened(0.3), 3.0)
	draw_colored_polygon(PackedVector2Array([Vector2(22, -3), Vector2(31, 0), Vector2(22, 2)]), Color(0.75, 0.65, 0.4))
	draw_circle(Vector2(13, -2), 2.4, Color(0.95, 0.95, 0.9))
	draw_circle(Vector2(13.6, -2), 1.2, Color(0.1, 0.1, 0.12))
	draw_colored_polygon(PackedVector2Array([Vector2(-20, 2), Vector2(-30, -4), Vector2(-28, 6)]), g.darkened(0.2))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

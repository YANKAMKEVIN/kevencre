extends "res://scripts/ent/Enemy.gd"
## Tache grise : avance et fait demi-tour au bord du vide ou contre un mur.

var dir := -1
var speed := 62.0

func _ready() -> void:
	super()
	radius = 20
	z_index = 4
	dir = -1 if randf() < 0.5 else 1

func _physics_process(delta: float) -> void:
	t += delta
	if not alive:
		return
	var nx := global_position.x + dir * speed * delta
	var ahead_x := nx + dir * 22
	var feet_y := global_position.y + 18
	var wall: bool = level.solid_px(Vector2(ahead_x, global_position.y))
	var ground: bool = level.floor_px(Vector2(ahead_x, feet_y + 6))
	if wall or not ground:
		dir = -dir
	else:
		global_position.x = nx
	check_player()
	queue_redraw()

func _draw() -> void:
	var g := Color(0.55, 0.55, 0.58)
	var hop := absf(sin(t * 6.0)) * 3.0
	blob(Vector2(0, 2 - hop), 21, Color(g, 0.92), 0.07, t, 18, g.darkened(0.45), 0.85)
	blob(Vector2(-5, -4 - hop), 9, Color(1, 1, 1, 0.12), 0.1, t)
	# coulures
	for k in 3:
		var x := -12 + k * 12
		draw_line(Vector2(x, 12 - hop), Vector2(x, 18 + sin(t * 2 + k) * 2), g.darkened(0.2), 4.0)
	var ex := 5.0 * dir
	for s in [-1, 1]:
		ellipse(Vector2(ex + s * 6, -3 - hop), Vector2(3.5, 4.5), Color(0.95, 0.95, 0.93))
		ellipse(Vector2(ex + s * 6 + dir, -2 - hop), Vector2(1.6, 2.4), Color(0.15, 0.15, 0.18))
	draw_line(Vector2(ex - 9, -10 - hop), Vector2(ex - 3, -8 - hop), Color(0.2, 0.2, 0.25), 2.0)
	draw_line(Vector2(ex + 9, -10 - hop), Vector2(ex + 3, -8 - hop), Color(0.2, 0.2, 0.25), 2.0)

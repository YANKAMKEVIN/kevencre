extends "res://scripts/ent/Entity.gd"
## Chevalet : point de reprise. En le touchant, la couleur revient autour.

var active := false
var paint := 0.0

func _ready() -> void:
	super()
	z_index = 2

func _physics_process(delta: float) -> void:
	phase += delta
	if active:
		paint = minf(1.0, paint + delta * 2.0)
	if not active and touching(Rect2(global_position + Vector2(-30, -90), Vector2(60, 90))):
		activate(true)
	queue_redraw()

func activate(fx := true) -> void:
	if active:
		return
	active = true
	Game.checkpoint[level.num] = global_position
	if fx:
		Game.sfx("checkpoint", -2)
		level.restore_at(global_position + Vector2(0, -50))
		level.fx.burst(global_position + Vector2(0, -55), 30)
		pl().hp = Game.max_hp()
	else:
		paint = 1.0

func _draw() -> void:
	var wood := Color(0.45, 0.3, 0.2)
	draw_line(Vector2(-18, 0), Vector2(-4, -88), wood, 5.0, true)
	draw_line(Vector2(18, 0), Vector2(4, -88), wood, 5.0, true)
	draw_line(Vector2(0, -80), Vector2(10, 0), wood.darkened(0.2), 4.0, true)
	draw_line(Vector2(-16, -30), Vector2(16, -30), wood, 4.0)
	var r := Rect2(-24, -84, 48, 50)
	draw_rect(r, Color(0.97, 0.95, 0.9))
	if paint > 0:
		var rng := RandomNumberGenerator.new()
		rng.seed = tile.x * 31 + tile.y
		for k in 9:
			var c: Color = Game.PALETTE[k % 5]
			var p := Vector2(rng.randf_range(-16, 16), rng.randf_range(-76, -44))
			draw_circle(p, rng.randf_range(5, 11) * paint, Color(c, 0.75))
		draw_arc(Vector2(0, -66), 9 * paint, PI, TAU, 12, Color(0.95, 0.8, 0.2), 3.0)
	else:
		draw_line(Vector2(-14, -70), Vector2(12, -50), Color(0.6, 0.6, 0.6, 0.4), 2.0)
	draw_rect(r, Color(0.3, 0.25, 0.2), false, 2.0)

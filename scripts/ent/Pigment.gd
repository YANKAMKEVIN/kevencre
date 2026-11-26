extends "res://scripts/ent/Entity.gd"
## Pigment légendaire (secret) : +1 goutte de vie et un souvenir.

var key := ""
var index := 0

func _ready() -> void:
	super()
	z_index = 4

func _physics_process(delta: float) -> void:
	phase += delta
	if touching(Rect2(global_position - Vector2(22, 22), Vector2(44, 44))):
		Game.pigments[key] = index
		var info: Array = Game.PIGMENT_INFO[index]
		level.fx.burst(global_position, 40)
		Game.sfx("pigment", 0)
		pl().hp = Game.max_hp()
		level.on_pigment(info, index)
		queue_free()
	queue_redraw()

func _draw() -> void:
	var c: Color = Game.PALETTE[index]
	var y := sin(phase * 2.0) * 6.0
	for k in 3:
		var r := 26.0 + k * 9 + sin(phase * 3 + k) * 3
		draw_arc(Vector2(0, y), r, 0, TAU, 32, Color(c, 0.18 - k * 0.05), 4.0, true)
	for k in 6:
		var a := phase * 1.5 + k * TAU / 6.0
		draw_circle(Vector2(cos(a), sin(a)) * 24 + Vector2(0, y), 2.5, Color(Game.PALETTE[k % 5], 0.8))
	blob(Vector2(0, y), 15, c, 0.08, phase, 18, c.darkened(0.5))
	draw_circle(Vector2(-5, y - 5), 4, Color(1, 1, 1, 0.5))

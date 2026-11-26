extends "res://scripts/ent/Entity.gd"
## Goutte d'encre à ramasser.

var key := ""
var taken := false
var col: Color

func _ready() -> void:
	super()
	col = Game.PALETTE[(tile.x + tile.y) % Game.PALETTE.size()]
	z_index = 4

func _physics_process(delta: float) -> void:
	phase += delta
	if taken:
		return
	if touching(Rect2(global_position - Vector2(16, 16), Vector2(32, 32))):
		taken = true
		Game.drops += 1
		Game.drops_level[key] = true
		level.drop_combo()
		level.fx.splash(global_position, col, 8, 160, 3.0, 300)
		queue_free()
	queue_redraw()

func _draw() -> void:
	var y := sin(phase * 3.0) * 4.0
	var p := Vector2(0, y)
	var pts := PackedVector2Array([p + Vector2(0, -13), p + Vector2(6, -3), p + Vector2(7, 3), p + Vector2(4, 8), p + Vector2(0, 9), p + Vector2(-4, 8), p + Vector2(-7, 3), p + Vector2(-6, -3)])
	draw_colored_polygon(pts, col)
	pts.append(pts[0])
	draw_polyline(pts, col.darkened(0.5), 1.6, true)
	draw_circle(p + Vector2(-2, 1), 2.0, Color(1, 1, 1, 0.55))

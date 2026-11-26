extends "res://scripts/ent/Entity.gd"
## Ronces grises : blessent et renvoient au dernier sol sûr.

var width := 1
var ceiling := false

func _physics_process(_delta: float) -> void:
	var r := Rect2(global_position + Vector2(4, 20 if not ceiling else 0), Vector2(width * Game.TS - 8, 28))
	if touching(r):
		level.hazard_hit(pl())

func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(global_position.x) * 7 + int(global_position.y)
	var w := width * Game.TS
	var base_y := 48.0 if not ceiling else 0.0
	var dir := -1.0 if not ceiling else 1.0
	var vine := PackedVector2Array()
	for i in width * 4 + 1:
		vine.append(Vector2(w * i / (width * 4.0), base_y + dir * (8 + rng.randf_range(-4, 4))))
	for k in width * 3:
		var x := (k + 0.5) * w / (width * 3.0) + rng.randf_range(-5, 5)
		var h := rng.randf_range(24, 36)
		var pts := PackedVector2Array([Vector2(x - 8, base_y), Vector2(x + rng.randf_range(-4, 4), base_y + dir * h), Vector2(x + 8, base_y)])
		draw_colored_polygon(pts, Color(0.32, 0.31, 0.35))
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2]]), Color(0.15, 0.14, 0.18), 2.0, true)
	draw_polyline(vine, Color(0.22, 0.21, 0.25), 4.0, true)

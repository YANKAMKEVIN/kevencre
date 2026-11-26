extends Node2D
## Base des objets du niveau : accès au joueur et tests de contact simples.

var level: Node
var tile := Vector2i.ZERO
var phase := 0.0

func _ready() -> void:
	phase = randf() * TAU

func pl() -> CharacterBody2D:
	return level.player

func prect() -> Rect2:
	var p := pl().global_position
	return Rect2(p.x - 12, p.y - 40, 24, 40)

func touching(r: Rect2) -> bool:
	if pl() == null or pl().dead:
		return false
	return prect().intersects(r)

func near(dist: float) -> bool:
	if pl() == null:
		return false
	return (pl().global_position + Vector2(0, -20)).distance_to(global_position) < dist

func ellipse(p: Vector2, r: Vector2, col: Color, rot := 0.0) -> void:
	var pts := PackedVector2Array()
	for i in 18:
		var a := TAU * i / 18.0
		pts.append(p + Vector2(cos(a) * r.x, sin(a) * r.y).rotated(rot))
	draw_colored_polygon(pts, col)

func blob(p: Vector2, r: float, col: Color, wob: float, t: float, n := 16, outline := Color(0, 0, 0, 0), sy := 1.0) -> void:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		var rr := r * (1.0 + wob * sin(a * 3.0 + t * 3.0) + wob * 0.6 * sin(a * 5.0 - t * 2.3))
		pts.append(p + Vector2(cos(a) * rr, sin(a) * rr * sy))
	draw_colored_polygon(pts, col)
	if outline.a > 0:
		pts.append(pts[0])
		draw_polyline(pts, outline, 2.0, true)

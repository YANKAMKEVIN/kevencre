extends Node2D
## Faux mur : on passe à travers et il s'efface (secret).

var level: Node
var cells: Array = []      # Vector2i
var sprite: Sprite2D = null
var alpha := 1.0
var found := false

func _ready() -> void:
	z_index = 6

func _physics_process(delta: float) -> void:
	var p = level.player
	var inside := false
	if p:
		var c := Vector2i(floori(p.global_position.x / Game.TS), floori((p.global_position.y - 20) / Game.TS))
		for cc in cells:
			if (cc - c).length_squared() <= 2:
				inside = true
				break
	var target := 0.12 if inside else 1.0
	if inside and not found:
		found = true
		Game.sfx("secret", -2)
	alpha = move_toward(alpha, target, delta * 3.0)
	modulate.a = alpha
	if sprite == null:
		queue_redraw()

func _draw() -> void:
	if sprite != null:
		return
	for c in cells:
		draw_rect(Rect2(Vector2(c) * Game.TS, Vector2(Game.TS, Game.TS)), level.ground_color)

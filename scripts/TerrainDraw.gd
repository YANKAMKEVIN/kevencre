extends Node2D
## Dessin de secours du terrain (si les peintures ne sont pas encore générées).

var level: Node

func _draw() -> void:
	var TS := Game.TS
	for y in level.H:
		for x in level.W:
			var c: String = level.ch(x, y)
			var r := Rect2(x * TS, y * TS, TS, TS)
			if c == "#" or c == "X":
				draw_rect(r, level.ground_color)
				if level.ch(x, y - 1) != "#":
					draw_rect(Rect2(r.position, Vector2(TS, 10)), level.ground_color.lightened(0.3))
			elif c == "=":
				draw_rect(Rect2(r.position, Vector2(TS, 14)), Color(0.5, 0.36, 0.22))

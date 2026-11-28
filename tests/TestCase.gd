extends Node
## Base des fichiers de test (tests/unit, tests/integration) lancés par tests/Runner.gd.
## Chaque méthode test_* est appelée (et attendue si elle utilise await) sur une partie neuve.

const TS := Game.TS
const LevelScript := preload("res://scripts/Level.gd")

var fails := 0
var count := 0
var current := ""


func check(cond: bool, what: String) -> void:
	count += 1
	print(("OK    " if cond else "ECHEC ") + current + " : " + what)
	if not cond:
		fails += 1


func eq(got: Variant, want: Variant, what: String) -> void:
	check(got == want, "%s (attendu %s, obtenu %s)" % [what, str(want), str(got)])


func near(got: float, want: float, tol: float, what: String) -> void:
	check(absf(got - want) <= tol, "%s (attendu %.2f ± %.2f, obtenu %.2f)" % [what, want, tol, got])


## Avance de n images physiques.
func phys(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Avance jusqu'à ce que cond soit vraie (au plus max_frames images physiques). Renvoie cond.
func until(cond: Callable, max_frames := 600) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await get_tree().physics_frame
	return cond.call()


## Chapitre construit à partir d'une petite grille (voir la légende de scripts/level/LevelGrid.gd).
## replay = true : ne touche pas à la sauvegarde.
func make_level(grid: Array, num := 1, replay := true) -> Node2D:
	var l: Node2D = LevelScript.new()
	l.num = num
	l.custom_grid = grid
	l.replay = replay
	add_child(l)
	l.hud.visible = false
	l.player.auto_input = {"x": 0.0, "y": 0.0, "jump": false, "dash": false}
	await phys(4)
	return l


## Grille rectangulaire : un sol de 3 cases sous la ligne floor_y, murs sur les côtés,
## puis les caractères de extra posés aux cases données ({Vector2i: "C"}).
static func box(w: int, h: int, floor_y: int, extra := {}) -> Array:
	var g: Array = []
	for y in h:
		var row := ""
		for x in w:
			var c := "."
			if x < 2 or x >= w - 2 or y > floor_y:
				c = "#"
			if extra.has(Vector2i(x, y)):
				c = extra[Vector2i(x, y)]
			row += c
		g.append(row)
	return g


## Position au sol (pieds) de la case (x, y).
static func foot(x: float, y: float) -> Vector2:
	return Vector2((x + 0.5) * TS, (y + 1) * TS)


## Pose Sépia immobile sur la case (x, y) et la laisse se stabiliser.
func place(l: Node2D, x: float, y: float) -> void:
	var p: CharacterBody2D = l.player
	p.global_position = foot(x, y)
	p.velocity = Vector2.ZERO
	p.auto_input = {"x": 0.0, "y": 0.0, "jump": false, "dash": false}
	await phys(12)


## Appui bref (une image) sur une action, maintenue ou non ensuite.
func tap(l: Node2D, action: String, hold := true) -> void:
	l.player.auto_input[action + "_p"] = true
	l.player.auto_input[action] = hold

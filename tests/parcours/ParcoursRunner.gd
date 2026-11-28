extends "res://tests/TestCase.gd"
## Parcours complet : godot --headless --path . --fixed-fps 60 -- --parcours
## 1. Modèle contre moteur : les mêmes programmes d'entrées sont joués par la vraie Sépia (moteur physique
##    de Godot) et par MoveSim ; hauteurs et points d'arrivée doivent concorder, sinon l'analyse ne vaut rien.
## 2. Atteignabilité : pour chaque chapitre, depuis le départ, MoveSim doit atteindre l'autel (sans le pinceau
##    au chapitre 1), chaque chevalet, chaque pigment et la sortie. Les gouttes inatteignables sont listées.
## Code de sortie 1 au moindre échec.

const Reachability := preload("res://tests/parcours/Reachability.gd")
const MoveSim := preload("res://tests/parcours/MoveSim.gd")
const Driver := preload("res://tests/parcours/Driver.gd")
const LevelGrid := preload("res://scripts/level/LevelGrid.gd")
const TOL_X := 0.5     # cases
const TOL_Y := 0.3

var verbose := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.pause_on_focus_loss = false
	verbose = "--verbose" in OS.get_cmdline_user_args()
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--niveau="):
			only = a.substr(9)
	var old_path := Game.save_path
	Game.save_path = "user://test_parcours_sauvegarde.json"
	await get_tree().process_frame
	var t0 := Time.get_ticks_msec()
	current = "modèle"
	await model_vs_engine()
	for n in [1, 2, 3]:
		if only == "" or only == str(n):
			current = "chapitre %d" % n
			reach_level(n)
	DirAccess.remove_absolute(Game.save_path)
	Game.save_path = old_path
	print("RESULTAT : %d vérification(s), %d échec(s) en %.1f s" % [count, fails, (Time.get_ticks_msec() - t0) / 1000.0])
	get_tree().quit(1 if fails > 0 else 0)


# ------------------------------------------------------------------ 1. modèle contre moteur
const CASES := [
	["saut maintenu", Vector2i(10, 20), {"dir": 0, "jump": 999, "release": 9999}],
	["saut tapé", Vector2i(10, 20), {"dir": 0, "jump": 6, "release": 9999}],
	["saut en courant", Vector2i(6, 20), {"dir": 1, "jump": 999, "release": 9999}],
	["saut court, direction lâchée", Vector2i(6, 20), {"dir": 1, "jump": 14, "release": 16}],
	["course sans saut", Vector2i(6, 20), {"dir": 1, "jump": 0, "release": 28}],
	["saut + trait horizontal", Vector2i(6, 20), {"dir": 1, "jump": 999, "release": 9999, "dash_at": 22, "dash": Vector2(1, 0)}],
	["saut + trait en diagonale", Vector2i(6, 20), {"dir": 1, "jump": 999, "release": 9999, "dash_at": 22, "dash": Vector2(1, -1)}],
	["saut + trait vers le haut", Vector2i(10, 20), {"dir": 0, "jump": 999, "release": 9999, "dash_at": 42, "dash": Vector2(0, -1)}],
	["trait au sol", Vector2i(6, 20), {"dir": 1, "jump": 0, "release": 9999, "dash_at": 4, "dash": Vector2(1, 0)}],
	["saut, trait, ressaut sur le trait", Vector2i(6, 20), {"dir": 1, "jump": 999, "release": 9999, "dash_at": 42, "dash": Vector2(1, 0), "chain": true}],
	["escalade d'un mur", Vector2i(54, 20), {"dir": 1, "jump": 999, "release": 9999, "climb": true}],
	["escalade d'un puits", Vector2i(53, 20), {"dir": 1, "jump": 999, "release": 9999, "climb": true, "zigzag": true}],
]


func model_vs_engine() -> void:
	var grid := LevelGrid.metrics_arena()
	var l := await make_level(grid, 99)
	Game.has_brush = true
	var sim := MoveSim.new(grid)
	for c in CASES:
		var real := await _play_real(l, c[1], c[2])
		var model := _play_sim(sim, c[1], c[2])
		var dx: float = absf(real["end"].x - model["end"].x) / TS
		var dy: float = absf(real["end"].y - model["end"].y) / TS
		var da: float = absf(real["apex"] - model["apex"]) / TS
		check(dx <= TOL_X and dy <= TOL_Y and da <= TOL_Y,
			"%s : moteur (%.2f, %.2f) sommet %.2f / modèle (%.2f, %.2f) sommet %.2f" % [c[0],
			real["end"].x / TS, real["end"].y / TS, real["apex"] / TS, model["end"].x / TS, model["end"].y / TS, model["apex"] / TS])
	l.queue_free()
	await phys(2)


func _play_real(l: Node2D, start: Vector2i, prog: Dictionary) -> Dictionary:
	for s in l.strokes:
		if is_instance_valid(s):
			s.queue_free()
	l.strokes.clear()
	await place(l, start.x, start.y)
	var p: CharacterBody2D = l.player
	p.can_dash = true
	p.facing = 1
	p.hp = 99
	var drv := Driver.new(prog)
	var y0 := p.global_position.y
	var apex := 0.0
	for f in drv.max_frames:
		var inp := drv.inputs(f, p.is_on_floor(), _on_stroke(p), p.wall_dir, p.wall_coyote, p.velocity.y, p.can_dash)
		p.auto_input = {"x": inp[0], "y": inp[1], "jump": inp[3], "dash": false}
		if inp[2]:
			p.auto_input["jump_p"] = true
		if inp[4]:
			p.auto_input["dash_p"] = true
		await get_tree().physics_frame
		apex = maxf(apex, y0 - p.global_position.y)
		if drv.finished(f, p.is_on_floor(), _on_stroke(p), p.velocity.x):
			break
	p.auto_input = {"x": 0.0, "y": 0.0, "jump": false, "dash": false}
	return {"end": p.global_position, "apex": apex}


## Posée sur un trait d'encre, d'après la dernière collision (Player.on_stroke a une image de retard).
static func _on_stroke(p: CharacterBody2D) -> bool:
	if not p.is_on_floor():
		return false
	var c := p.get_last_slide_collision()
	var col: Node = c.get_collider() as Node if c else null
	return col != null and col.is_in_group("stroke")


func _play_sim(sim: MoveSim, start: Vector2i, prog: Dictionary) -> Dictionary:
	sim.reset(Reachability.foot_of(start), true)
	var drv := Driver.new(prog)
	var y0 := sim.pos.y
	var apex := 0.0
	for f in drv.max_frames:
		var inp := drv.inputs(f, sim.on_floor, sim.on_stroke, sim.wall_dir, sim.wall_coyote, sim.vel.y, sim.can_dash)
		sim.step(inp[0], inp[1], inp[2], inp[3], inp[4])
		apex = maxf(apex, y0 - sim.pos.y)
		if drv.finished(f, sim.on_floor, sim.on_stroke, sim.vel.x):
			break
	return {"end": sim.pos, "apex": apex}


# ------------------------------------------------------------------ 2. atteignabilité
func reach_level(n: int) -> void:
	var t0 := Time.get_ticks_msec()
	var grid := LevelGrid.load_grid(n)
	for pb in LevelGrid.problems(grid):
		check(false, "grille : " + pb)
	var r := Reachability.new(grid)
	var start: Vector2i = LevelGrid.find(grid, "S")[0]
	var goal: Array[Vector2i] = LevelGrid.find(grid, "G")
	var shrines: Array[Vector2i] = LevelGrid.find(grid, "K")
	var musts: Array = goal + LevelGrid.find(grid, "C") + LevelGrid.find(grid, "P") + shrines
	var drops: Array[Vector2i] = LevelGrid.find(grid, "*")
	check(goal.size() == 1, "une sortie G")
	var reached := {}
	if n == 1:
		# avant l'autel, Sépia n'a pas le Trait d'encre
		reached = r.explore([start], false, shrines)
		check(shrines.size() == 1 and r.touched.has(shrines[0]), "l'autel du Vieux Pinceau est atteignable sans le Trait d'encre")
		var from: Array = reached.keys()
		reached.merge(r.explore(from, true, musts + drops))
	else:
		reached = r.explore([start], true, musts + drops)
	for c in musts:
		var what: String = {"G": "la sortie", "C": "le chevalet", "P": "le pigment", "K": "l'autel"}[grid[c.y][c.x]]
		check(r.touched.has(c), "%s en %s est atteignable" % [what, str(c)])
	var missing: Array = drops.filter(func(c: Vector2i) -> bool: return not r.touched.has(c))
	check(true, "%d / %d gouttes atteignables%s" % [drops.size() - missing.size(), drops.size(),
		("" if missing.is_empty() else " (hors de portée du modèle : %s)" % str(missing))])
	print("      %d cases atteintes, %d programmes joués, %.1f s" % [reached.size(), r.programs_run, (Time.get_ticks_msec() - t0) / 1000.0])
	if verbose and r.touched.has(goal[0]):
		var near_goal: Vector2i = reached.keys().reduce(func(a: Vector2i, b: Vector2i) -> Vector2i:
			return a if a.distance_to(goal[0]) < b.distance_to(goal[0]) else b)
		for step in r.path_to(near_goal):
			print("      ", step[0], " ", step[1])

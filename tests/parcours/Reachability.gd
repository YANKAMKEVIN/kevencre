extends RefCounted
## Analyse d'atteignabilité d'un chapitre : depuis le départ S, quelles cases peut-on atteindre
## avec les vrais mouvements de Sépia ? Chaque arête du graphe est une suite d'entrées (un « programme ») :
## courir, sauter plus ou moins longtemps, lâcher la direction, rebondir contre les murs, Trait d'encre
## dans une direction donnée à un instant donné, puis ressauter depuis le trait. Ces programmes sont joués
## dans MoveSim, image par image, à partir de chaque case atteinte (parcours en largeur).
##
## Le modèle ignore les ennemis (on peut les repeindre ou les éviter) et la fragilité du papier
## (on a 0,5 s pour ressauter). Les ronces et le vide font échouer un programme.

const MoveSim := preload("res://tests/parcours/MoveSim.gd")
const Driver := preload("res://tests/parcours/Driver.gd")
const LevelGrid := preload("res://scripts/level/LevelGrid.gd")
const TS := 48.0

var grid: Array
var sim: MoveSim
var W := 0
var H := 0
var programs_run := 0
## Case de départ de chaque case atteinte (pour reconstruire un chemin) : Vector2i -> [Vector2i, programme]
var came_from := {}
## Cases d'objets touchées : Vector2i -> true
var touched := {}
var _targets := {}       # Vector2i -> Rect2 de contact (mêmes rectangles que les entités)
var _near := {}          # case -> objets dont le rectangle de contact la recouvre (Array de Vector2i)


func _init(g: Array) -> void:
	grid = g
	H = g.size()
	W = g[0].length()
	sim = MoveSim.new(g)
	for c in ["P", "*", "C", "K", "G"]:
		for cell in LevelGrid.find(g, c):
			var r := contact_rect(c, cell)
			_targets[cell] = r
			for y in range(floori(r.position.y / TS), floori(r.end.y / TS) + 1):
				for x in range(floori(r.position.x / TS), floori(r.end.x / TS) + 1):
					if not _near.has(Vector2i(x, y)):
						_near[Vector2i(x, y)] = []
					_near[Vector2i(x, y)].append(cell)


## Rectangle de contact de l'objet c posé en case cell (copié des scripts de scripts/ent/).
static func contact_rect(c: String, cell: Vector2i) -> Rect2:
	var foot := Vector2((cell.x + 0.5) * TS, (cell.y + 1) * TS)
	var mid := Vector2((cell.x + 0.5) * TS, (cell.y + 0.5) * TS)
	match c:
		"P": return Rect2(mid - Vector2(22, 22), Vector2(44, 44))
		"*": return Rect2(mid - Vector2(16, 16), Vector2(32, 32))
		"C": return Rect2(foot + Vector2(-30, -90), Vector2(60, 90))
		"K": return Rect2(foot + Vector2(-50, -120), Vector2(100, 120))
		"G": return Rect2(foot + Vector2(-40, -130), Vector2(80, 130))
	return Rect2()


## Case où l'on peut se tenir : vide (ou objet), pas de ronces, et un sol juste dessous.
func standable(x: int, y: int) -> bool:
	var c := sim.code(x, y)
	if c == MoveSim.SOLID or c == MoveSim.THORNS:
		return false
	if sim.code(x, y - 1) == MoveSim.SOLID:
		return false
	var below := sim.code(x, y + 1)
	return below == MoveSim.SOLID or below == MoveSim.ONEWAY or below == MoveSim.CRUMBLE


static func foot_of(cell: Vector2i) -> Vector2:
	return Vector2((cell.x + 0.5) * TS, (cell.y + 1) * TS)


## Tous les programmes d'entrées essayés depuis une case.
## Un programme : {dir, jump (images maintenues, 0 = pas de saut), release (image où l'on lâche la direction),
## climb (ressauter contre les murs), zigzag (changer de sens à chaque mur), dash_at, dash (Vector2), chain, redash}
static func programs(with_dash: bool) -> Array:
	var out: Array = []
	for dir in [-1, 0, 1]:
		for jump in [0, 6, 14, 999]:
			for release in ([9999] if dir == 0 else [9999, 8, 16, 28]):
				out.append({"dir": dir, "jump": jump, "release": release})
	for dir in [-1, 1]:
		out.append({"dir": dir, "jump": 999, "release": 9999, "climb": true})
		out.append({"dir": dir, "jump": 999, "release": 9999, "climb": true, "zigzag": true})
	if with_dash:
		for dir in [-1, 0, 1]:
			var dirs: Array = [Vector2(dir, 0), Vector2(dir, -1), Vector2(0, -1)] if dir != 0 else [Vector2(0, -1), Vector2(-1, 0), Vector2(1, 0)]
			for jump in [0, 999]:
				for dash_at in [4, 22, 42]:
					for d in dirs:
						for chain in [false, true]:
							out.append({"dir": dir, "jump": jump, "release": 9999, "dash_at": dash_at, "dash": d, "chain": chain, "redash": true})
	return out


## Joue un programme depuis la case start. Renvoie les cases où l'on s'est tenu sur un vrai sol
## (dans l'ordre), vide si le programme finit dans les ronces ou le vide. Note les objets touchés.
func run_program(start: Vector2i, prog: Dictionary, brush: bool) -> Array[Vector2i]:
	programs_run += 1
	var s := sim
	s.reset(foot_of(start), brush)
	var drv := Driver.new(prog)
	var stood: Array[Vector2i] = []
	var hits: Array[Vector2i] = []
	for f in drv.max_frames:
		var inp := drv.inputs(f, s.on_floor, s.on_stroke, s.wall_dir, s.wall_coyote, s.vel.y, s.can_dash)
		s.step(inp[0], inp[1], inp[2], inp[3], inp[4])
		_note_touches(hits)
		if s.dead:
			for h in hits:
				touched[h] = true
			return []
		if s.on_floor and not s.on_stroke:
			var cell := cell_at(s.pos)
			if standable(cell.x, cell.y) and (stood.is_empty() or stood[stood.size() - 1] != cell):
				stood.append(cell)
		if drv.finished(f, s.on_floor, s.on_stroke, s.vel.x):
			break
	for h in hits:
		touched[h] = true
	return stood


## Case où se tient Sépia, pieds en p (si elle déborde d'un bord, la case du sol qui la porte).
func cell_at(p: Vector2) -> Vector2i:
	var cell := Vector2i(floori(p.x / TS), floori((p.y - 1.0) / TS))
	if not standable(cell.x, cell.y):
		var side := cell + Vector2i(1 if fmod(p.x, TS) > TS / 2 else -1, 0)
		if standable(side.x, side.y):
			return side
	return cell


func _note_touches(hits: Array[Vector2i]) -> void:
	var box := sim.aabb_at(sim.pos)
	for y in range(floori(box.position.y / TS), floori(box.end.y / TS) + 1):
		for x in range(floori(box.position.x / TS), floori(box.end.x / TS) + 1):
			var cands: Variant = _near.get(Vector2i(x, y))
			if cands == null:
				continue
			for cell in cands:
				if not hits.has(cell) and (_targets[cell] as Rect2).intersects(box):
					hits.append(cell)


## Parcours en largeur depuis les cases de départ. stop_when : cases dont l'atteinte suffit (vide = tout explorer).
## Renvoie l'ensemble des cases atteintes (Vector2i -> true).
func explore(starts: Array, brush: bool, stop_when: Array = []) -> Dictionary:
	var seen := {}
	var queue: Array[Vector2i] = []
	for s in starts:
		if not seen.has(s):
			seen[s] = true
			queue.append(s)
	var progs := programs(brush)
	var head := 0
	while head < queue.size():
		if not stop_when.is_empty() and stop_when.all(func(c: Vector2i) -> bool: return touched.has(c)):
			break
		var cell: Vector2i = queue[head]
		head += 1
		for prog in progs:
			for nxt in run_program(cell, prog, brush):
				if not seen.has(nxt):
					seen[nxt] = true
					came_from[nxt] = [cell, prog]
					queue.append(nxt)
	return seen


## Chemin (liste de [case, programme]) qui mène du départ à la case cell, d'après came_from.
func path_to(cell: Vector2i) -> Array:
	var out: Array = []
	var c := cell
	while came_from.has(c):
		out.push_front(came_from[c])
		c = came_from[c][0]
	return out

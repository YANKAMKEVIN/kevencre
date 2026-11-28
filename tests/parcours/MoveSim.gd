extends RefCounted
## Modèle cinématique de Sépia sur une grille de cases (sans nœuds, sans moteur physique),
## qui reprend image par image la logique de scripts/Player.gd (mêmes constantes, lues dans le script).
## Il sert à l'analyse de parcours : on y essaie des milliers de suites d'entrées en quelques secondes.
## Sa fidélité au vrai moteur est vérifiée à chaque lancement (ParcoursRunner, « modèle contre moteur »).

const P := preload("res://scripts/Player.gd")
const LevelGrid := preload("res://scripts/level/LevelGrid.gd")
const TS := 48.0
const DT := 1.0 / 120.0
const HALF_W := 12.0
const HEIGHT := 40.0
const STROKE_LIFE := 1.9

enum { EMPTY, SOLID, ONEWAY, CRUMBLE, THORNS }

# --- grille
var W := 0
var H := 0
var cells := PackedByteArray()
var springs: Array[Rect2] = []
var crystals: Array[Rect2] = []
var thorns: Array[Rect2] = []

# --- état de Sépia (mêmes noms que Player.gd)
var pos := Vector2.ZERO
var vel := Vector2.ZERO
var facing := 1
var coyote := 0.0
var jump_buf := 0.0
var dash_buf := 0.0
var wall_coyote := 0.0
var last_wall := 0
var wall_dir := 0
var jumping := false
var lock := 0.0
var dashing := 0.0
var dash_dir := Vector2.RIGHT
var dash_cd := 0.0
var can_dash := true
var has_brush := true
var on_floor := false
var on_stroke := false
var time := 0.0
var used_crystal := -1
var dead := false          # ronces ou chute hors du niveau
var refilled_in_air := false

# traits d'encre : murs (traits verticaux) et marches (autres traits), [Rect2, expiration]
var wall_strokes: Array = []
var step_strokes: Array = []
var _stroke_pts := PackedVector2Array()
var _stroke_vertical := false


func _init(grid: Array) -> void:
	H = grid.size()
	W = grid[0].length()
	cells.resize(W * H)
	for y in H:
		var row: String = grid[y]
		for x in W:
			var c := row[x]
			var code := EMPTY
			match c:
				"#": code = SOLID
				"=": code = ONEWAY
				"c": code = CRUMBLE
				"^": code = THORNS
			cells[y * W + x] = code
			var foot := Vector2((x + 0.5) * TS, (y + 1) * TS)
			var mid := Vector2((x + 0.5) * TS, (y + 0.5) * TS)
			if c == "O":
				springs.append(Rect2(foot + Vector2(-26, -26), Vector2(52, 26)))
			elif c == "D":
				crystals.append(Rect2(mid - Vector2(22, 22), Vector2(44, 44)))
			elif c == "^" and (x == 0 or row[x - 1] != "^"):
				var x2 := x
				while x2 + 1 < W and row[x2 + 1] == "^":
					x2 += 1
				var ceiling := LevelGrid.cell(grid, x, y - 1) == "#" and LevelGrid.cell(grid, x, y + 1) != "#"
				thorns.append(Rect2(Vector2(x * TS + 4, y * TS + (0 if ceiling else 20)), Vector2((x2 - x + 1) * TS - 8, 28)))


func code(x: int, y: int) -> int:
	if x < 0 or x >= W:
		return SOLID
	if y < 0 or y >= H:
		return EMPTY
	return cells[y * W + x]


## Remet Sépia debout, immobile, les pieds en p.
func reset(p: Vector2, brush: bool) -> void:
	pos = p
	vel = Vector2.ZERO
	facing = 1
	coyote = 0.0; jump_buf = 0.0; dash_buf = 0.0; wall_coyote = 0.0; lock = 0.0; dashing = 0.0; dash_cd = 0.0
	last_wall = 0
	wall_dir = 0
	jumping = false
	has_brush = brush
	can_dash = brush
	on_floor = true
	on_stroke = false
	time = 0.0
	used_crystal = -1
	dead = false
	refilled_in_air = false
	wall_strokes.clear()
	step_strokes.clear()
	_stroke_pts.clear()


# ------------------------------------------------------------------ collisions
func aabb_at(p: Vector2) -> Rect2:
	return Rect2(p.x - HALF_W, p.y - HEIGHT, HALF_W * 2.0, HEIGHT)


## Sol plein ou trait vertical dans le rectangle r ?
func solid_in(r: Rect2) -> bool:
	var x0 := floori(r.position.x / TS)
	var x1 := floori((r.end.x - 0.001) / TS)
	var y0 := floori(r.position.y / TS)
	var y1 := floori((r.end.y - 0.001) / TS)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if code(x, y) == SOLID:
				return true
	for s in wall_strokes:
		if s[1] > time and (s[0] as Rect2).intersects(r):
			return true
	return false


## Dessus de plateforme (case = / c, ou trait horizontal) franchi en descendant de y_from à y_to,
## sous les pieds entre x - 12 et x + 12. Renvoie [hauteur, est_un_trait] ou [] si rien.
func oneway_hit(x: float, y_from: float, y_to: float) -> Array:
	var best := INF
	var is_stroke := false
	var x0 := floori((x - HALF_W) / TS)
	var x1 := floori((x + HALF_W - 0.001) / TS)
	var ty0 := floori(y_from / TS)
	var ty1 := floori(y_to / TS)
	for ty in range(ty0, ty1 + 1):
		var top := ty * TS
		if top < y_from - 8.0 or top > y_to:
			continue
		for tx in range(x0, x1 + 1):
			var c := code(tx, ty)
			if (c == ONEWAY or c == CRUMBLE) and top < best:
				best = top
				is_stroke = false
	for s in step_strokes:
		if s[1] <= time:
			continue
		var r: Rect2 = s[0]
		var top := r.position.y
		if top >= y_from - 12.0 and top <= y_to and r.position.x < x + HALF_W and r.end.x > x - HALF_W and top < best:
			best = top
			is_stroke = true
	return [] if best == INF else [best, is_stroke]


func _move() -> void:
	var was_floor := on_floor
	on_floor = false
	on_stroke = false
	# horizontal
	var dx := vel.x * DT
	var n := maxi(1, ceili(absf(dx) / 6.0))
	for i in n:
		var np := pos + Vector2(dx / n, 0)
		if solid_in(aabb_at(np)):
			if dx > 0:
				pos.x = floorf((np.x + HALF_W) / TS) * TS - HALF_W - 0.01
			else:
				pos.x = (floorf((np.x - HALF_W) / TS) + 1.0) * TS + HALF_W + 0.01
			if solid_in(aabb_at(pos)):   # bord d'un trait vertical : on reste où l'on était
				pos = np - Vector2(dx / n, 0)
			vel.x = 0.0
			break
		pos = np
	# vertical (le vrai moteur colle au sol quand on y était : petite descente minimale)
	var dy := vel.y * DT
	if was_floor and dy >= 0.0 and dy < 1.0:
		dy = 1.0
	n = maxi(1, ceili(absf(dy) / 6.0))
	for i in n:
		var np := pos + Vector2(0, dy / n)
		if dy > 0:
			var hit := oneway_hit(pos.x, pos.y, np.y)
			if solid_in(aabb_at(np)):
				var top := floorf(np.y / TS) * TS
				if hit.is_empty() or hit[0] > top:
					hit = [top, false]
			elif not hit.is_empty() and solid_in(aabb_at(Vector2(np.x, hit[0]))):
				hit = []
			if not hit.is_empty():
				pos.y = hit[0]
				on_floor = true
				on_stroke = hit[1]
				vel.y = 0.0
				break
		elif solid_in(aabb_at(np)):
			pos.y = (floorf((np.y - HEIGHT) / TS) + 1.0) * TS + HEIGHT + 0.01
			if dashing <= 0.0:
				vel.y = 0.0
			break
		pos = np
	# accroche au sol (floor_snap_length = 6 px dans Player.gd) : on ne décolle pas d'une petite marche
	if was_floor and not on_floor and vel.y >= 0.0 and dashing <= 0.0:
		var hit := oneway_hit(pos.x, pos.y, pos.y + 6.0)
		for k in range(1, 7):
			if solid_in(aabb_at(pos + Vector2(0, k))):
				if hit.is_empty() or hit[0] > pos.y + k - 1:
					hit = [pos.y + k - 1, false]
				break
		if not hit.is_empty():
			pos.y = hit[0]
			on_floor = true
			on_stroke = hit[1]
			vel.y = 0.0


func _test_wall(dir: int) -> bool:
	return solid_in(aabb_at(pos + Vector2(dir * 3.0, 0)))


# ------------------------------------------------------------------ une image
## Entrées : ix, iy dans {-1, 0, 1} ; jump/dash_pressed : appui pendant cette image ; jump_held : maintenu.
func step(ix: float, iy: float, jump_pressed: bool, jump_held: bool, dash_pressed: bool) -> void:
	time += DT
	if jump_pressed:
		jump_buf = P.BUFFER
	if dash_pressed:
		dash_buf = 0.1
	jump_buf -= DT
	dash_buf -= DT
	coyote -= DT
	wall_coyote -= DT
	lock -= DT
	dash_cd -= DT
	if on_floor:
		coyote = P.COYOTE
		jumping = false
		refilled_in_air = false
		if not on_stroke and has_brush and not can_dash and dashing <= 0.0:
			can_dash = true
	wall_dir = 0
	if not on_floor:
		if _test_wall(-1):
			wall_dir = -1
		elif _test_wall(1):
			wall_dir = 1
		if wall_dir != 0:
			wall_coyote = 0.11
			last_wall = wall_dir
	if dashing > 0.0:
		dashing -= DT
		vel = dash_dir * P.DASH_SPEED
		_stroke_pts.append(pos)
		if dashing <= 0.0:
			_end_dash()
	else:
		var target := ix * P.RUN
		var a: float
		if on_floor:
			a = P.ACC if ix != 0.0 else P.DEC
			if ix != 0.0 and signf(vel.x) != ix and absf(vel.x) > 10:
				a = P.ACC * 1.6
		else:
			a = P.AIR_ACC if ix != 0.0 else P.AIR_DEC
		if absf(vel.x) > P.RUN and signf(vel.x) == ix:
			a = 700.0
		if lock > 0.0:
			a *= 0.25
		vel.x = move_toward(vel.x, target, a * DT)
		var g := P.GRAV if vel.y < 0 else P.FALL_GRAV
		if absf(vel.y) < 100 and jump_held and jumping:
			g *= 0.5
		vel.y += g * DT
		vel.y = minf(vel.y, P.MAX_FALL * (1.25 if iy > 0 else 1.0))
		if wall_dir != 0 and vel.y > 0 and ix == wall_dir:
			vel.y = minf(vel.y, P.WALL_SLIDE)
		if jump_buf > 0.0:
			if coyote > 0.0:
				vel.y = -P.JUMP_V
				jumping = true
				coyote = 0.0
				jump_buf = 0.0
			elif wall_coyote > 0.0 and not on_floor:
				vel.x = -last_wall * P.WALL_JUMP_X
				vel.y = -P.WALL_JUMP_Y
				facing = -last_wall
				lock = 0.13
				jumping = true
				wall_coyote = 0.0
				jump_buf = 0.0
		if jumping and vel.y < 0 and not jump_held:
			vel.y *= 0.45
			jumping = false
		if dash_buf > 0.0 and can_dash and has_brush and dash_cd <= 0.0:
			_start_dash(ix, iy)
	if ix != 0.0 and dashing <= 0.0 and lock <= 0.0:
		facing = int(ix)
	_move()
	_touch_things()
	if pos.y > H * TS + 80:
		dead = true


func _start_dash(ix: float, iy: float) -> void:
	var d := Vector2(ix, iy)
	if d == Vector2.ZERO:
		d = Vector2(facing, 0)
	dash_dir = d.normalized()
	dashing = P.DASH_TIME
	can_dash = false
	dash_buf = 0.0
	dash_cd = 0.22
	jumping = false
	if d.x != 0:
		facing = int(signf(d.x))
	_stroke_vertical = absf(dash_dir.x) <= 0.3
	_stroke_pts.clear()
	_stroke_pts.append(pos)


func _end_dash() -> void:
	dashing = 0.0
	vel = dash_dir * P.DASH_SPEED * 0.42
	if dash_dir.y < -0.5:
		vel.y = -520.0
	elif dash_dir.y < 0:
		vel.y = -380.0
	_finish_stroke()


## Même géométrie que Stroke.finish() : un mur de 12 px pour un trait vertical,
## sinon des marches de 16 × 10 px tous les 9 px le long du trajet (traversables par-dessous).
func _finish_stroke() -> void:
	if _stroke_pts.size() < 2:
		return
	var until_t := time + STROKE_LIFE
	if _stroke_vertical:
		var a := _stroke_pts[0] + Vector2(-facing * 19, -20)
		var b := _stroke_pts[_stroke_pts.size() - 1] + Vector2(-facing * 19, -20)
		var top := minf(a.y, b.y) - 14
		var bot := maxf(a.y, b.y) + 14
		wall_strokes.append([Rect2(a.x - 6, top, 12, bot - top), until_t])
		return
	var pts := PackedVector2Array()
	for p in _stroke_pts:
		pts.append(p + Vector2(0, -2))
	var total := 0.0
	for i in range(pts.size() - 1):
		total += pts[i].distance_to(pts[i + 1])
	var dist := 0.0
	var i := 0
	var acc := 0.0
	while dist <= total and i < pts.size() - 1:
		var seg := pts[i].distance_to(pts[i + 1])
		if acc + seg < dist:
			acc += seg
			i += 1
			continue
		var p := pts[i].lerp(pts[i + 1], (dist - acc) / maxf(seg, 0.001))
		step_strokes.append([Rect2(p.x - 8, p.y, 16, 10), until_t])
		dist += 9.0


func _touch_things() -> void:
	var box := aabb_at(pos)
	for r in thorns:
		if r.intersects(box):
			dead = true
			return
	if vel.y >= -50:
		for r in springs:
			if r.intersects(box):
				pos.y = minf(pos.y, r.end.y - 18)
				vel.y = -P.BOUNCE_V
				jumping = false
				dashing = 0.0
				if has_brush:
					if not can_dash:
						refilled_in_air = true
					can_dash = true
	for i in crystals.size():
		if i != used_crystal and not can_dash and has_brush and crystals[i].intersects(box):
			can_dash = true
			used_crystal = i
			refilled_in_air = true

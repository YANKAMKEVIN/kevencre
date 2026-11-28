extends RefCounted
## Interprète un programme d'entrées (voir Reachability.programs) image par image.
## Le même pilote commande le modèle (MoveSim) et la vraie Sépia (Player.auto_input),
## ce qui permet de comparer les deux sur les mêmes entrées.

var prog: Dictionary
var dir := 0.0
var jump := 0
var release := 9999
var climb := false
var zigzag := false
var dash_at := -1
var dash := Vector2.ZERO
var chain := false
var redash := false
var chained := false
var redash_at := -1
var jump_t := -1
var airborne := false
var _could_dash := false
var max_frames := 420      # une escalade peut durer plus longtemps (grande cascade du chapitre 2)


func _init(p: Dictionary) -> void:
	prog = p
	dir = p["dir"]
	jump = p["jump"]
	release = p["release"]
	climb = p.get("climb", false)
	zigzag = p.get("zigzag", false)
	dash_at = p.get("dash_at", -1)
	dash = p.get("dash", Vector2.ZERO)
	chain = p.get("chain", false)
	redash = p.get("redash", false)
	if climb:
		max_frames = 1200


## Entrées de l'image f d'après l'état de Sépia avant cette image : [ix, iy, saut_appuyé, saut_maintenu, trait_appuyé].
func inputs(f: int, on_floor: bool, on_stroke: bool, wall_dir: int, wall_coyote: float, vy: float, can_dash: bool) -> Array:
	var ix := dir if f < release else 0.0
	var iy := 0.0
	var jp := false
	var dp := false
	if f == 0 and jump > 0:
		jp = true
		jump_t = 0
	if climb and wall_dir != 0 and not on_floor and wall_coyote > 0.0 and vy > -200.0:
		if zigzag:
			dir = -wall_dir
			ix = dir
		jp = true
		jump_t = f
	if chain and not chained and on_floor and on_stroke:
		chained = true
		jp = true
		jump_t = f
		jump = 999
	if redash and redash_at < 0 and f > dash_at and dash_at >= 0 and not on_floor and can_dash and not _could_dash:
		redash_at = f + 3   # rechargé en plein vol (goutte rouge, fleur) : second trait
	_could_dash = can_dash
	if f == dash_at or f == redash_at:
		dp = true
		ix = dash.x
		iy = dash.y
	var held := jump_t >= 0 and f - jump_t < jump
	return [ix, iy, jp, held, dp]


## Le programme est-il fini à l'image f (état après l'image) ?
func finished(f: int, on_floor: bool, on_stroke: bool, vx: float) -> bool:
	if not on_floor:
		airborne = true
		return false
	if on_stroke or f < dash_at or f <= 2:
		return false
	if airborne:
		return true
	if f >= release and absf(vx) < 1.0:
		return true
	return dir == 0.0 and jump == 0 and dash_at < 0

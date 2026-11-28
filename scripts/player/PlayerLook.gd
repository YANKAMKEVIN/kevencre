extends RefCounted
## Apparence de Sépia : écrasement, clignement, écharpe qui flotte, dessin de la goutte.
## Fonctions statiques appelées par Player (le dessin a lieu pendant le _draw de Sépia).

const SCARF_LEN := 7
const DROP_SEGMENTS := 22
const EYE_SEGMENTS := 14


static func init_scarf(p: Node2D) -> void:
	p.scarf.clear()
	for i in SCARF_LEN:
		p.scarf.append(p.global_position + Vector2(-i * 5, -22))
	p.scarf_pts.resize(SCARF_LEN)
	p.body_pts.resize(DROP_SEGMENTS + 4)
	p.outline_pts.resize(DROP_SEGMENTS + 5)
	p.eye_pts.resize(EYE_SEGMENTS)


static func reset_scarf(p: Node2D, at: Vector2) -> void:
	for i in p.scarf.size():
		p.scarf[i] = at + Vector2(-i * 5, -22)


static func animate(p: Node2D, delta: float) -> void:
	p.sq = p.sq.lerp(Vector2.ONE, 1.0 - exp(-12.0 * delta))
	if p.on_floor and absf(p.velocity.x) > 20:
		p.run_t += delta * absf(p.velocity.x) / 34.0
	else:
		p.run_t = lerpf(p.run_t, roundf(p.run_t / PI) * PI, 0.2)
	p.blink -= delta
	if p.blink < -0.12:
		p.blink = randf_range(1.8, 4.5)
	var target_col: Color = Color(0.86, 0.25, 0.22) if (p.can_dash or not Game.has_brush) else Color(0.55, 0.53, 0.6)
	p.scarf_col = p.scarf_col.lerp(target_col, 0.25)


static func update_scarf(p: Node2D, delta: float) -> void:
	var scarf: Array = p.scarf
	var facing: int = p.facing
	var vel: Vector2 = p.velocity
	scarf[0] = p.global_position + Vector2(-facing * 3, -24 * p.sq.y)
	for i in range(1, scarf.size()):
		var q: Vector2 = scarf[i]
		q += Vector2(-facing * 34.0 - vel.x * 0.04, 26.0 - vel.y * 0.03 + sin(p.t * 7.0 + i) * 6.0) * delta
		var prev: Vector2 = scarf[i - 1]
		var d := q - prev
		if d.length() > 6.0:
			q = prev + d.normalized() * 6.0
		scarf[i] = q


## Dessin de Sépia, dans des tableaux réutilisés d'une image à l'autre (aucune allocation).
static func draw(p: Node2D) -> void:
	if p.dead:
		return
	if p.invuln > 0.0 and int(p.t * 18.0) % 2 == 0:
		p.modulate.a = 0.45
	else:
		p.modulate.a = 1.0
	var ink := Game.INK
	var facing: int = p.facing
	var vel: Vector2 = p.velocity
	# écharpe (coordonnées du monde -> locales)
	var pts: PackedVector2Array = p.scarf_pts
	for i in pts.size():
		pts[i] = p.scarf[i] - p.global_position
	var dark_scarf: Color = p.scarf_col.darkened(0.35)
	for i in range(pts.size() - 1):
		var w := lerpf(7.0, 2.5, float(i) / pts.size())
		p.draw_line(pts[i], pts[i + 1], dark_scarf, w + 2.5, true)
	for i in range(pts.size() - 1):
		var w := lerpf(7.0, 2.5, float(i) / pts.size())
		p.draw_line(pts[i], pts[i + 1], p.scarf_col, w, true)
	# corps : goutte, déformée autour des pieds
	var lean := clampf(vel.x / p.RUN, -1.3, 1.3) * 0.13
	if p.dashing > 0.0:
		lean = p.dash_dir.x * 0.3
	p.draw_set_transform(Vector2.ZERO, lean, p.sq)
	# pieds
	var fa := sin(p.run_t) * 5.0
	var lift := absf(cos(p.run_t)) * 3.0 if p.on_floor and absf(vel.x) > 20 else 0.0
	if not p.on_floor:
		fa = 3.0
	p.draw_circle(Vector2(-6 + fa, -3 - lift), 5.0, ink.darkened(0.3))
	p.draw_circle(Vector2(6 - fa, -3 - (3.0 - lift if lift > 0 else 0.0)), 5.0, ink.darkened(0.3))
	# goutte
	var tip := Vector2(-facing * 7.0 - clampf(vel.x * 0.02, -9, 9), -46.0 + clampf(vel.y * 0.008, -4, 6))
	var body: PackedVector2Array = p.body_pts
	var c := Vector2(0, -17)
	var R := 15.0
	var n := DROP_SEGMENTS
	for i in n + 1:
		var a := lerpf(-PI / 2 + 0.75, PI * 1.5 - 0.75, float(i) / n)
		body[i] = c + Vector2(cos(a), sin(a)) * R
	var lt := body[n]
	var rt := body[0]
	body[n + 1] = lt.lerp(tip, 0.5) + Vector2(-2.5, 0)
	body[n + 2] = tip
	body[n + 3] = rt.lerp(tip, 0.5) + Vector2(2.5, 0)
	p.draw_colored_polygon(body, ink)
	var outline: PackedVector2Array = p.outline_pts
	for i in body.size():
		outline[i] = body[i]
	outline[body.size()] = body[0]
	p.draw_polyline(outline, ink.darkened(0.45), 2.0, true)
	# reflet
	p.draw_circle(c + Vector2(-6 * facing, -6), 3.5, Color(1, 1, 1, 0.22))
	p.draw_circle(c + Vector2(-8 * facing, -1), 1.8, Color(1, 1, 1, 0.18))
	# yeux
	var ey := -19.0
	var ex := 4.0 * facing
	var h := 6.0 if p.blink > 0 else 1.2
	for s in [-1, 1]:
		var ep := Vector2(ex + s * 5.5, ey)
		_ellipse(p, ep, Vector2(3.6, h), Color(0.98, 0.96, 0.9))
		if p.blink > 0:
			var look := Vector2(facing * 1.3, clampf(vel.y * 0.003, -1.5, 1.5))
			_ellipse(p, ep + look, Vector2(1.8, 3.2), ink.darkened(0.5))
	p.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


static func _ellipse(p: Node2D, at: Vector2, r: Vector2, col: Color) -> void:
	var pts: PackedVector2Array = p.eye_pts
	for i in EYE_SEGMENTS:
		var a := TAU * i / float(EYE_SEGMENTS)
		pts[i] = at + Vector2(cos(a) * r.x, sin(a) * r.y)
	p.draw_colored_polygon(pts, col)

extends CharacterBody2D
## Sépia, la dernière goutte d'encre. Entrées, déplacements, Trait d'encre, dégâts.
## L'apparence (écharpe, dessin) est dans player/PlayerLook.gd.

const PlayerLook := preload("res://scripts/player/PlayerLook.gd")

const RUN := 345.0
const ACC := 3400.0
const DEC := 3900.0
const AIR_ACC := 2500.0
const AIR_DEC := 1500.0
const GRAV := 2300.0
const FALL_GRAV := 2950.0
const JUMP_V := 880.0
const MAX_FALL := 920.0
const WALL_SLIDE := 150.0
const WALL_JUMP_X := 370.0
const WALL_JUMP_Y := 800.0
const DASH_SPEED := 990.0
const DASH_TIME := 0.16
const COYOTE := 0.1
const BUFFER := 0.13
const BOUNCE_V := 1460.0

signal died
signal hurt_signal

var level: Node
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
var stroke: Node2D = null
var hp := 5
var invuln := 0.0
var dead := false
var frozen := false          # dialogues, cinématiques
var last_safe := Vector2.ZERO
var safe_t := 0.0
var on_floor := false
var on_stroke := false
var was_floor := false
var fall_peak := 0.0
var auto_input := {}         # pour les tests automatiques : {"x":1, "jump":true...}

# animation
var sq := Vector2.ONE
var t := 0.0
var run_t := 0.0
var blink := 2.0
var scarf: Array = []
var scarf_col := Color(0.85, 0.24, 0.22)
var dust_t := 0.0
# tableaux de dessin réutilisés (PlayerLook)
var scarf_pts := PackedVector2Array()
var body_pts := PackedVector2Array()
var outline_pts := PackedVector2Array()
var eye_pts := PackedVector2Array()

func _ready() -> void:
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(24, 40)
	cs.shape = r
	cs.position = Vector2(0, -20)
	add_child(cs)
	floor_snap_length = 6.0
	floor_max_angle = deg_to_rad(50)
	safe_margin = 0.06
	collision_layer = 2
	collision_mask = 1
	PlayerLook.init_scarf(self)
	hp = Game.max_hp()
	last_safe = global_position
	z_index = 5

# ------------------------------------------------------------------ entrées
func _ix() -> float:
	if auto_input.has("x"):
		return auto_input["x"]
	var v := Input.get_axis("move_left", "move_right")
	return 0.0 if absf(v) < 0.35 else signf(v)

func _iy() -> float:
	if auto_input.has("y"):
		return auto_input["y"]
	var v := Input.get_axis("move_up", "move_down")
	return 0.0 if absf(v) < 0.45 else signf(v)

func _held(a: String) -> bool:
	if auto_input.has(a):
		return auto_input[a]
	return Input.is_action_pressed(a)

func _pressed(a: String) -> bool:
	if auto_input.has(a + "_p"):
		var v: bool = auto_input[a + "_p"]
		auto_input.erase(a + "_p")
		return v
	return Input.is_action_just_pressed(a)

# ------------------------------------------------------------------ physique
func _physics_process(delta: float) -> void:
	t += delta
	if dead:
		return
	if frozen:
		velocity.x = move_toward(velocity.x, 0, DEC * delta)
		velocity.y = minf(velocity.y + GRAV * delta, MAX_FALL)
		move_and_slide()
		PlayerLook.update_scarf(self, delta)
		queue_redraw()
		return
	var ix := _ix()
	var iy := _iy()
	if _pressed("jump"):
		jump_buf = BUFFER
	if _pressed("dash"):
		dash_buf = 0.1
	jump_buf -= delta
	dash_buf -= delta
	coyote -= delta
	wall_coyote -= delta
	lock -= delta
	dash_cd -= delta
	invuln -= delta

	on_floor = is_on_floor()
	on_stroke = false
	if on_floor:
		var c := get_last_slide_collision()
		var col: Node = c.get_collider() as Node if c else null
		on_stroke = col != null and col.is_in_group("stroke")
		coyote = COYOTE
		jumping = false
		if not on_stroke:
			if Game.has_brush and not can_dash and dashing <= 0.0:
				can_dash = true
				_refill_fx()
			if col != null and col.is_in_group("terrain"):
				safe_t += delta
				if safe_t > 0.15 and level and level.is_safe_ground(global_position):
					last_safe = global_position
		elif col != null and col.is_in_group("crumble"):
			pass
	else:
		safe_t = 0.0

	wall_dir = 0
	if not on_floor:
		if test_move(global_transform, Vector2(-3, 0)):
			wall_dir = -1
		elif test_move(global_transform, Vector2(3, 0)):
			wall_dir = 1
		if wall_dir != 0:
			wall_coyote = 0.11
			last_wall = wall_dir

	if dashing > 0.0:
		dashing -= delta
		velocity = dash_dir * DASH_SPEED
		if stroke:
			stroke.add_point(global_position + Vector2(0, -2) if absf(dash_dir.x) > 0.3 else global_position + Vector2(-facing * 19, -20))
		if dashing <= 0.0:
			_end_dash()
	else:
		# horizontal
		var target := ix * RUN
		var a: float
		if on_floor:
			a = ACC if ix != 0.0 else DEC
			if ix != 0.0 and signf(velocity.x) != ix and absf(velocity.x) > 10:
				a = ACC * 1.6
		else:
			a = AIR_ACC if ix != 0.0 else AIR_DEC
		if absf(velocity.x) > RUN and signf(velocity.x) == ix:
			a = 700.0   # garde l'élan après un trait
		if lock > 0.0:
			a *= 0.25
		velocity.x = move_toward(velocity.x, target, a * delta)
		# vertical
		var g := GRAV if velocity.y < 0 else FALL_GRAV
		if absf(velocity.y) < 100 and _held("jump") and jumping:
			g *= 0.5
		velocity.y += g * delta
		var mf := MAX_FALL * (1.25 if iy > 0 else 1.0)
		velocity.y = minf(velocity.y, mf)
		if wall_dir != 0 and velocity.y > 0 and ix == wall_dir:
			velocity.y = minf(velocity.y, WALL_SLIDE)
			dust_t -= delta
			if dust_t <= 0.0 and level:
				dust_t = 0.07
				level.fx.splash(global_position + Vector2(wall_dir * 12, -30), Color(0.35, 0.33, 0.4, 0.5), 1, 40, 2.5)
		# sauts
		if jump_buf > 0.0:
			if coyote > 0.0:
				_jump()
			elif wall_coyote > 0.0 and not on_floor:
				_wall_jump()
		if jumping and velocity.y < 0 and not _held("jump"):
			velocity.y *= 0.45
			jumping = false
		# Trait d'encre
		if dash_buf > 0.0 and can_dash and Game.has_brush and dash_cd <= 0.0:
			_start_dash(ix, iy)
	if ix != 0.0 and dashing <= 0.0 and lock <= 0.0:
		facing = int(ix)

	was_floor = on_floor
	var vy_before := velocity.y
	move_and_slide()
	if is_on_ceiling() and velocity.y < 0 and dashing <= 0.0:
		velocity.y = 0
	if not was_floor:
		fall_peak = maxf(fall_peak, vy_before)
	if is_on_floor() and not was_floor:
		_land(fall_peak)
		fall_peak = 0.0

	# chute hors du niveau
	if level and global_position.y > level.bottom_y():
		level.hazard_hit(self)

	PlayerLook.animate(self, delta)
	PlayerLook.update_scarf(self, delta)
	queue_redraw()

func _jump() -> void:
	velocity.y = -JUMP_V
	jumping = true
	coyote = 0.0
	jump_buf = 0.0
	sq = Vector2(0.72, 1.32)
	Game.sfx("jump", -6, randf_range(0.95, 1.08))
	if level:
		level.fx.splash(global_position, Color(0.3, 0.28, 0.36, 0.6), 6, 120, 3.0)

func _wall_jump() -> void:
	velocity.x = -last_wall * WALL_JUMP_X
	velocity.y = -WALL_JUMP_Y
	facing = -last_wall
	lock = 0.13
	jumping = true
	wall_coyote = 0.0
	jump_buf = 0.0
	sq = Vector2(0.75, 1.28)
	Game.sfx("jump", -6, 1.15)
	if level:
		level.fx.splash(global_position + Vector2(last_wall * 12, -20), Color(0.3, 0.28, 0.36, 0.6), 6, 120, 3.0)

func bounce(v := BOUNCE_V, refill := true) -> void:
	velocity.y = -v
	jumping = false
	dashing = 0.0
	if refill and Game.has_brush:
		if not can_dash:
			_refill_fx()
		can_dash = true
	sq = Vector2(0.65, 1.4)

func refill_dash() -> bool:
	if can_dash or not Game.has_brush:
		return false
	can_dash = true
	_refill_fx()
	return true

func _refill_fx() -> void:
	if level:
		level.fx.splash(global_position + Vector2(0, -20), scarf_col.lightened(0.2), 8, 160, 3.0)

func _start_dash(ix: float, iy: float) -> void:
	var d := Vector2(ix, iy)
	if d == Vector2.ZERO:
		d = Vector2(facing, 0)
	dash_dir = d.normalized()
	dashing = DASH_TIME
	can_dash = false
	dash_buf = 0.0
	dash_cd = 0.22
	jumping = false
	if d.x != 0:
		facing = int(signf(d.x))
	sq = Vector2(1.35, 0.7) if absf(dash_dir.x) > 0.5 else Vector2(0.7, 1.35)
	Game.sfx("dash", -3, randf_range(0.92, 1.08))
	if level:
		stroke = level.new_stroke(dash_dir, facing)
		stroke.add_point(global_position + Vector2(0, -2) if absf(dash_dir.x) > 0.3 else global_position + Vector2(-facing * 19, -20))
		level.shake(4.0)

func _end_dash() -> void:
	dashing = 0.0
	velocity = dash_dir * DASH_SPEED * 0.42
	if dash_dir.y < -0.5:
		velocity.y = -520.0
	elif dash_dir.y < 0:
		velocity.y = -380.0
	if stroke:
		stroke.finish()
		stroke = null

func is_attacking() -> bool:
	return dashing > 0.0

func _land(speed: float) -> void:
	if speed > 250:
		sq = Vector2(1.0 + speed / 2400.0, 1.0 - speed / 3000.0)
		if level:
			level.fx.splash(global_position, Color(0.3, 0.28, 0.36, 0.55), int(clampf(speed / 90, 3, 10)), 140, 3.0)
		Game.sfx("land", -10 + clampf(speed / 200, 0, 6), randf_range(0.9, 1.1))

# ------------------------------------------------------------------ dégâts
func hurt(from: Vector2, dmg := 1) -> void:
	if invuln > 0.0 or dead or frozen:
		return
	hp -= dmg
	invuln = 1.25
	var d := signf(global_position.x - from.x)
	if d == 0:
		d = -facing
	velocity = Vector2(d * 330, -480)
	lock = 0.28
	dashing = 0.0
	if stroke:
		stroke.finish()
		stroke = null
	Game.sfx("hurt", -2)
	hurt_signal.emit()
	if level:
		level.shake(10.0)
		level.hitstop(0.09)
		level.fx.splash(global_position + Vector2(0, -20), Game.INK, 14, 260, 4.0)
	if hp <= 0:
		die()

func die() -> void:
	if dead:
		return
	dead = true
	Game.deaths += 1
	Game.sfx("die", -2)
	if level:
		level.fx.splash(global_position + Vector2(0, -20), Game.INK, 30, 380, 5.0)
	died.emit()

func respawn(at: Vector2) -> void:
	global_position = at
	velocity = Vector2.ZERO
	dead = false
	dashing = 0.0
	hp = Game.max_hp()
	invuln = 1.0
	can_dash = Game.has_brush
	last_safe = at
	PlayerLook.reset_scarf(self, at)

func _draw() -> void:
	PlayerLook.draw(self)

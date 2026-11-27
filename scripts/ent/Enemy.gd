extends "res://scripts/ent/Entity.gd"
## Base des Délavés : on les repeint d'un Trait d'encre ou en leur sautant dessus.

var radius := 20.0
var alive := true
var hit_flash := 0.0
var t := 0.0

func check_player() -> void:
	if not alive:
		return
	var p := pl()
	if p == null or p.dead:
		return
	var pc := p.global_position + Vector2(0, -20)
	var d := pc.distance_to(global_position)
	if d > radius + 18:
		return
	if p.is_attacking():
		repaint(p)
		p.refill_dash()
		return
	if p.velocity.y > 60 and p.global_position.y < global_position.y - radius * 0.3:
		repaint(p)
		p.bounce(720, true)
		return
	p.hurt(global_position)

func repaint(_p: Variant) -> void:
	alive = false
	var c: Color = Game.PALETTE[randi() % Game.PALETTE.size()]
	level.fx.burst(global_position, 30)
	level.decals.decal(level.ground_below(global_position), c, 34)
	level.hitstop(0.05)
	level.shake(5.0)
	level.restore_small(global_position)
	Game.sfx("splat", -1, randf_range(0.9, 1.15))
	queue_free()

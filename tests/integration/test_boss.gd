extends "res://tests/TestCase.gd"
## Le Délaveur : cœur exposé ou non, phases, défaite, reprise après une mort.

const LevelGrid := preload("res://scripts/level/LevelGrid.gd")
const BossScript := preload("res://scripts/Boss.gd")


## Arène du Délaveur (sans le dialogue d'ouverture) avec le boss posé comme dans Level._start_boss.
func _arena() -> Node2D:
	var l := await make_level(LevelGrid.arena(), 99)
	var b: Node2D = BossScript.new()
	b.level = l
	b.position = Vector2(l.W * TS / 2, 5.2 * TS)
	l.boss = b
	l.world.add_child(b)
	await phys(2)
	return l


## Frappe le cœur d'un Trait d'encre vers le haut, comme le joueur.
func _strike(l: Node2D) -> void:
	var b: Node2D = l.boss
	var p: CharacterBody2D = l.player
	p.global_position = b.core_pos() + Vector2(0, 30)
	p.velocity = Vector2.ZERO
	p.dashing = 0.1
	p.dash_dir = Vector2.UP
	await phys(1)


func test_coeur_ferme() -> void:
	var l := await _arena()
	var b: Node2D = l.boss
	b.started = true
	b.exposed = false
	await _strike(l)
	eq(b.hp, 9, "cœur fermé : le trait rebondit sans dégâts")
	check(b.core_cool > 0.0, "petit temps de recharge après le rebond")


func test_phases_et_defaite() -> void:
	var l := await _arena()
	var b: Node2D = l.boss
	b.started = true
	var phases: Array = []
	for i in 9:
		b.core_cool = 0.0
		b.exposed = true
		b.expose_t = 2.0
		await _strike(l)
		phases.append(b.phase)
	eq(b.hp, 0, "9 coups au cœur exposé")
	eq(phases.slice(0, 8), [1, 1, 2, 2, 2, 3, 3, 3], "3 phases : la 2e à 6 PV, la 3e à 3 PV")
	check(b.dying, "le Délaveur s'effondre")
	check(await until(func() -> bool: return b.dead, 900), "le Délaveur est vaincu")
	check(l.finished, "la victoire termine le combat")
	l.queue_free()


func test_coup_en_tombant() -> void:
	var l := await _arena()
	var b: Node2D = l.boss
	var p: CharacterBody2D = l.player
	b.started = true
	b.exposed = true
	b.expose_t = 2.0
	b.core_cool = 0.0
	p.global_position = b.core_pos() + Vector2(0, 20)
	p.velocity = Vector2(0, 400)
	await phys(1)
	eq(b.hp, 8, "tomber sur le cœur exposé le frappe aussi")
	check(p.velocity.y < 0.0, "Sépia rebondit après le coup")
	check(p.can_dash, "le coup recharge le trait")


func test_vague_et_reprise() -> void:
	var l := await _arena()
	var b: Node2D = l.boss
	var p: CharacterBody2D = l.player
	b.started = true
	await place(l, 16, 16)
	p.invuln = 0.0
	var hp: int = p.hp
	b.waves.append([p.global_position.x - 30, 1, 400.0])
	await phys(2)
	eq(p.hp, hp - 1, "une vague grise blesse au sol")
	b.flood_target = 1.0
	b.on_player_respawn()
	check(b.waves.is_empty() and b.flood_target == 0.0, "après une mort, vagues et inondation sont retirées")


func test_deroule_du_combat() -> void:
	var l := await _arena()
	var b: Node2D = l.boss
	var p: CharacterBody2D = l.player
	b.begin()
	var seen_exposed := false
	var seen_rain := false
	for i in 120 * 12:
		p.invuln = 99.0
		await phys(1)
		seen_exposed = seen_exposed or b.exposed
		seen_rain = seen_rain or b.markers.size() > 0
		if seen_exposed and seen_rain:
			break
	check(seen_exposed, "phase 1 : le Délaveur frappe le sol et ouvre son cœur")
	check(seen_rain, "phase 1 : pluie grise annoncée par des repères")
	check(not p.dead, "le robot invulnérable survit")

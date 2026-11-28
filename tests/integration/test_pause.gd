extends "res://tests/TestCase.gd"
## Pause automatique quand la fenêtre passe en arrière-plan.


func test_pause_en_arriere_plan() -> void:
	var l := await make_level(box(20, 16, 12))
	Game.pause_on_focus_loss = true
	Game.timing = true
	l.hud.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(l.hud.paused and get_tree().paused, "fenêtre en arrière-plan : le jeu se met en pause")
	var t0 := Game.time
	await get_tree().process_frame
	await get_tree().process_frame
	eq(Game.time, t0, "le temps de jeu ne court plus pendant la pause")
	l.hud._set_pause(false)
	check(not get_tree().paused, "on reprend depuis le menu pause")
	l.hud.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(l.hud.paused, "application mise en veille (mobile) : pause aussi")
	l.hud._set_pause(false)
	Game.pause_on_focus_loss = false


func test_pas_de_pause_pendant_un_dialogue_ou_une_victoire() -> void:
	var l := await make_level(box(20, 16, 12))
	Game.pause_on_focus_loss = true
	l.hud.dlg_active = true
	l.hud.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not l.hud.paused, "un dialogue en cours n'ouvre pas le menu pause par-dessus")
	l.hud.dlg_active = false
	l.finished = true
	l.hud.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not l.hud.paused, "chapitre fini : pas de pause")
	l.finished = false
	Game.pause_on_focus_loss = false
	l.hud.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not l.hud.paused, "les robots de test désactivent la pause automatique")
	get_tree().paused = false

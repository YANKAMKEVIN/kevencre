extends Node
## Aiguillage entre l'écran titre, les niveaux et la fin.

var current: Node
var fade: ColorRect
var busy := false

func _ready() -> void:
	Game.main = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cl := CanvasLayer.new()
	cl.layer = 100
	add_child(cl)
	fade = ColorRect.new()
	fade.color = Game.PAPER
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(fade)
	var args := OS.get_cmdline_user_args()
	if "--check" in args:
		var bad := 0
		for d in ["res://scripts/", "res://scripts/ent/", "res://tools/"]:
			for f in DirAccess.get_files_at(d):
				if f.ends_with(".gd") and f != "check.gd":
					if load(d + f) == null:
						print("ECHEC ", d + f)
						bad += 1
		print("CHECK FINI")
		get_tree().quit(1 if bad > 0 else 0)
		return
	if "--metrics" in args:
		var m = load("res://tools/Metrics.gd").new()
		add_child(m)
		return
	for a in args:
		if a.begins_with("--shots") or a.begins_with("--test"):
			var t = load("res://tools/AutoTest.gd").new()
			t.name = "AutoTest"
			add_child(t)
			return
	goto("title")

func goto(what: String, arg = null) -> void:
	if busy:
		return
	busy = true
	get_tree().paused = false
	var tw := create_tween()
	tw.tween_property(fade, "modulate:a", 1.0, 0.35)
	await tw.finished
	if current:
		current.queue_free()
		current = null
		await get_tree().process_frame
	match what:
		"title":
			current = load("res://scripts/Title.gd").new()
		"intro":
			current = load("res://scripts/Intro.gd").new()
		"level":
			current = load("res://scripts/Level.gd").new()
			current.num = int(arg)
		"ending":
			current = load("res://scripts/Ending.gd").new()
	if current is Control:
		var cl := CanvasLayer.new()
		cl.layer = 0
		cl.add_child(current)
		current = cl
	add_child(current)
	move_child(current, 0)
	await get_tree().process_frame
	var tw2 := create_tween()
	tw2.tween_property(fade, "modulate:a", 0.0, 0.5)
	busy = false

func flash_fade(time_out := 0.25, time_in := 0.35) -> void:
	var tw := create_tween()
	tw.tween_property(fade, "modulate:a", 1.0, time_out)
	await tw.finished
	var tw2 := create_tween()
	tw2.tween_property(fade, "modulate:a", 0.0, time_in)

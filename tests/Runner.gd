extends Node
## Lance tous les tests : godot --headless --path . -- --unit [--tests=motif1,motif2]
## Chaque fichier tests/unit/test_*.gd et tests/integration/test_*.gd est une suite ;
## chaque méthode test_* est lancée sur une partie neuve, avec une sauvegarde de test.
## Code de sortie 1 si un test échoue ou si une suite ne se charge pas.

const DIRS := ["res://tests/unit/", "res://tests/integration/"]
const TEST_SAVE := "user://test_runner_sauvegarde.json"

var total := 0
var fails := 0
var broken := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.pause_on_focus_loss = false
	var filters: PackedStringArray = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tests="):
			filters = a.substr(8).split(",", false)
	var old_path := Game.save_path
	Game.save_path = TEST_SAVE
	await get_tree().process_frame
	var start := Time.get_ticks_msec()
	for path in suites(filters):
		await _run_suite(path)
	_clean_save()
	Game.save_path = old_path
	Game.new_game()
	print("RESULTAT : %d test(s), %d échec(s), %d suite(s) illisible(s) en %.1f s" % [total, fails, broken, (Time.get_ticks_msec() - start) / 1000.0])
	get_tree().quit(1 if fails > 0 or broken > 0 or total == 0 else 0)


static func suites(filters: PackedStringArray = []) -> Array[String]:
	var out: Array[String] = []
	for d in DIRS:
		var files := Array(DirAccess.get_files_at(d))
		files.sort()
		for f in files:
			if not (f.begins_with("test_") and f.ends_with(".gd")):
				continue
			if filters.size() > 0 and not Array(filters).any(func(m: String) -> bool: return f.contains(m)):
				continue
			out.append(d + f)
	return out


func _run_suite(path: String) -> void:
	var script: Script = load(path)
	if script == null or not script.can_instantiate():
		print("ECHEC suite illisible : ", path)
		broken += 1
		return
	var methods: Array[String] = []
	for m in script.get_script_method_list():
		var n: String = m["name"]
		if n.begins_with("test_") and not methods.has(n):
			methods.append(n)
	print("== ", path.get_file(), " (", methods.size(), ")")
	for m in methods:
		_reset_game()
		var suite: Node = script.new()
		suite.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(suite)
		suite.current = m
		await Callable(suite, m).call()
		total += suite.count
		fails += suite.fails
		if suite.count == 0:
			print("ECHEC ", m, " : aucune vérification")
			fails += 1
		remove_child(suite)
		suite.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame


func _reset_game() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	Game.save_path = TEST_SAVE
	_clean_save()
	Game.new_game()
	Game.timing = false


func _clean_save() -> void:
	for p in [TEST_SAVE, TEST_SAVE + ".bak", TEST_SAVE + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)

extends "res://tests/TestCase.gd"
## Numéro de version du jeu.


func test_version() -> void:
	var v := Game.version()
	check(v == ProjectSettings.get_setting("application/config/version"), "Game.version() lit project.godot (%s)" % v)
	var parts := v.split(".")
	check(parts.size() == 3 and Array(parts).all(func(x: String) -> bool: return x.is_valid_int()), "version au format majeur.mineur.correctif")


func test_format_temps() -> void:
	eq(Game.format_time(0.0), "0 min 00 s", "temps nul")
	eq(Game.format_time(125.9), "2 min 05 s", "minutes et secondes")

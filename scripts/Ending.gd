extends Control
## Fin : le monde a retrouvé ses couleurs.

var t := 0.0
var cool := 2.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_deferred("size", get_viewport_rect().size)
	get_viewport().size_changed.connect(_on_vp)
	var all := Game.pigment_count() >= 5
	var bg := TextureRect.new()
	var path := "res://art/fin_vraie.png" if all and ResourceLoader.exists("res://art/fin_vraie.png") else "res://art/fin.png"
	if ResourceLoader.exists(path):
		bg.texture = load(path)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(bg)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.97, 0.94, 0.87, 0.9)
	sb.border_color = Game.INK
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 34
	sb.content_margin_right = 34
	sb.content_margin_top = 22
	sb.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-390, -230)
	panel.custom_minimum_size = Vector2(780, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var title := Label.new()
	title.text = "Les couleurs sont revenues"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", load("res://fonts/Cinzel.ttf"))
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.7, 0.2, 0.18))
	v.add_child(title)
	var story := Label.new()
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story.custom_minimum_size = Vector2(700, 0)
	story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story.add_theme_font_size_override("font_size", 21)
	story.add_theme_color_override("font_color", Game.INK)
	if all:
		story.text = "Avec les cinq pigments légendaires, Sépia peignit un lever de soleil si vif que le vieux peintre ouvrit les yeux. Il sourit, trempa son pinceau dans la petite goutte d'encre... et se remit au travail. Le Délaveur, redevenu simple pot d'eau claire, chante désormais près du chevalet."
	else:
		story.text = "Le Délaveur, redevenu simple pot d'eau, repose près du chevalet. Le monde a retrouvé ses couleurs, mais le vieux peintre dort encore. Il manque peut-être quelques pigments légendaires pour le réveiller tout à fait..."
	v.add_child(story)
	var stats := Label.new()
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 22)
	stats.add_theme_color_override("font_color", Game.INK)
	stats.text = "Temps : %s     Chutes : %d\nGouttes d'encre : %d     Pigments légendaires : %d / 5" % [Game.format_time(Game.time), Game.deaths, Game.drops, Game.pigment_count()]
	v.add_child(stats)
	var thanks := Label.new()
	thanks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	thanks.add_theme_font_override("font", load("res://fonts/Cinzel.ttf"))
	thanks.add_theme_font_size_override("font_size", 24)
	thanks.add_theme_color_override("font_color", Color(Game.INK, 0.8))
	thanks.text = "Merci d'avoir joué !\nKevencre · un jeu original pour Kevin"
	v.add_child(thanks)
	add_child(panel)
	Game.music("music_ending")

func _process(delta: float) -> void:
	t += delta
	cool -= delta
	if cool <= 0 and (Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_accept")):
		Game.main.goto("title")

func _on_vp() -> void:
	set_deferred("size", get_viewport_rect().size)

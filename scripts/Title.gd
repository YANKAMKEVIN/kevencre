extends Control
## Écran titre de Kevencre.

var items := ["Nouvelle partie", "Chapitres", "Commandes", "Quitter"]
var sel := 0
var mode := "main"     # main, chapters, help
var labels: Array = []
var menu: VBoxContainer
var menu_panel: PanelContainer
var help: PanelContainer
var t := 0.0
var cinzel: Font
var motes: Array = []

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_deferred("size", get_viewport_rect().size)
	get_viewport().size_changed.connect(_on_vp)
	cinzel = load("res://fonts/Cinzel.ttf")
	var bg := TextureRect.new()
	if ResourceLoader.exists("res://art/titre.png"):
		bg.texture = load("res://art/titre.png")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(bg)
	var deco := Control.new()
	deco.set_anchors_preset(Control.PRESET_FULL_RECT)
	deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(deco)
	deco.draw.connect(_deco.bind(deco))
	var title := Label.new()
	title.text = "KEVENCRE"
	title.add_theme_font_override("font", cinzel)
	title.add_theme_font_size_override("font_size", 118)
	title.add_theme_color_override("font_color", Game.INK)
	title.add_theme_color_override("font_outline_color", Color(0.97, 0.94, 0.87, 0.9))
	title.add_theme_constant_override("outline_size", 18)
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-420, 70)
	title.custom_minimum_size = Vector2(840, 0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var sub := Label.new()
	sub.text = "la dernière goutte d'encre"
	sub.add_theme_font_override("font", cinzel)
	sub.add_theme_font_size_override("font_size", 30)
	sub.add_theme_color_override("font_color", Color(0.7, 0.22, 0.2))
	sub.add_theme_color_override("font_outline_color", Color(0.97, 0.94, 0.87, 0.9))
	sub.add_theme_constant_override("outline_size", 10)
	sub.set_anchors_preset(Control.PRESET_CENTER_TOP)
	sub.position = Vector2(-420, 215)
	sub.custom_minimum_size = Vector2(840, 0)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)
	var mp := PanelContainer.new()
	var msb := StyleBoxFlat.new()
	msb.bg_color = Color(0.97, 0.94, 0.87, 0.88)
	msb.border_color = Color(Game.INK, 0.8)
	msb.set_border_width_all(3)
	msb.set_corner_radius_all(16)
	msb.content_margin_left = 26
	msb.content_margin_right = 26
	msb.content_margin_top = 16
	msb.content_margin_bottom = 16
	mp.add_theme_stylebox_override("panel", msb)
	mp.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	mp.position = Vector2(90, -60)
	add_child(mp)
	menu_panel = mp
	menu = VBoxContainer.new()
	menu.custom_minimum_size = Vector2(430, 0)
	menu.add_theme_constant_override("separation", 6)
	mp.add_child(menu)
	help = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.97, 0.94, 0.87, 0.96)
	sb.border_color = Game.INK
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	help.add_theme_stylebox_override("panel", sb)
	help.set_anchors_preset(Control.PRESET_CENTER)
	help.position = Vector2(-380, -150)
	help.custom_minimum_size = Vector2(760, 0)
	var hl := Label.new()
	hl.add_theme_font_size_override("font_size", 21)
	hl.add_theme_color_override("font_color", Game.INK)
	hl.text = "Courir : ← → ou A / D (Q sur clavier AZERTY)   ·   manette : croix ou stick\nSauter : Espace, C ou K   ·   manette : A\n   (maintenir pour sauter plus haut, sauter contre un mur pour rebondir)\nTrait d'encre : X, J ou Maj + direction   ·   manette : X ou RB\n   (8 directions, ton trait devient une plateforme un instant)\nPasser les dialogues : Espace ou Entrée\nPause : Échap ou P\n\nAstuce : le Trait d'encre se recharge en touchant le vrai sol,\nles fleurs-ressorts et les gouttes rouges.  Repeindre une Tache aussi !"
	help.add_child(hl)
	help.visible = false
	add_child(help)
	var ver := Label.new()
	ver.text = "Kevencre · v" + Game.version()
	ver.add_theme_font_size_override("font_size", 16)
	ver.add_theme_color_override("font_color", Color(Game.INK, 0.55))
	ver.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.position = Vector2(-200, -34)
	add_child(ver)
	_build()
	Game.music("music_title")
	for i in 40:
		motes.append([Vector2(randf() * 1400, randf() * 800), randf_range(10, 40), randi() % 5, randf() * TAU])

func _main_items() -> Array:
	return (["Continuer"] if not Game.read_save().is_empty() else []) + items

func _build() -> void:
	for c in menu.get_children():
		c.queue_free()
	labels.clear()
	var list := _main_items() if mode == "main" else ["Chapitre 1 · Les Prés Délavés", "Chapitre 2 · La Forêt d'Aquarelle", "Chapitre 3 · Les Falaises d'Ocre", "Chapitre 4 · Le Délaveur", "Retour"]
	for s in list:
		var l := Label.new()
		l.text = s
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 30 if mode == "main" else 25)
		menu.add_child(l)
		labels.append(l)
	sel = 0
	_refresh()

func _refresh() -> void:
	for i in labels.size():
		var on := i == sel
		labels[i].add_theme_color_override("font_color", Color(0.75, 0.2, 0.18) if on else Game.INK)
		labels[i].scale = Vector2.ONE

func _process(delta: float) -> void:
	t += delta
	for m in motes:
		m[0].y -= m[1] * delta
		m[0].x += sin(t + m[3]) * 10 * delta
		if m[0].y < -20:
			m[0].y = 820
	for c in get_children():
		if c is Control and c.draw.get_connections().size() > 0:
			c.queue_redraw()
	if mode == "help":
		if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("pause") or Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_cancel"):
			help.visible = false
			menu_panel.visible = true
			mode = "main"
			_build()
			sel = 2
			_refresh()
		return
	if Input.is_action_just_pressed("move_down") or Input.is_action_just_pressed("ui_down"):
		sel = (sel + 1) % labels.size()
		Game.sfx("blip", -8)
		_refresh()
	if Input.is_action_just_pressed("move_up") or Input.is_action_just_pressed("ui_up"):
		sel = (sel + labels.size() - 1) % labels.size()
		Game.sfx("blip", -8)
		_refresh()
	if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_accept"):
		Game.sfx("confirm", -4)
		_choose()
	if Input.is_action_just_pressed("pause") and mode == "chapters":
		mode = "main"
		_build()

func _choose() -> void:
	if mode == "main":
		match labels[sel].text:
			"Continuer":
				var n := Game.load_game()
				if n > 0:
					Game.main.goto("level", n)
			"Nouvelle partie":
				Game.new_game()
				Game.main.goto("intro")
			"Chapitres":
				mode = "chapters"
				_build()
			"Commandes":
				mode = "help"
				menu_panel.visible = false
				help.visible = true
			"Quitter":
				get_tree().quit()
	else:
		if sel == 4:
			mode = "main"
			_build()
			return
		Game.new_game()
		var n := sel + 1
		Game.has_brush = n > 1
		Game.main.goto("level", n, true)  # rejeu : la sauvegarde n'est pas écrasée

func _deco(c: Control) -> void:
	for m in motes:
		var col: Color = Game.PALETTE[m[2]]
		c.draw_circle(m[0], 3 + sin(t * 2 + m[3]) * 1.5, Color(col, 0.55))
	# soulignement à l'encre sous le menu sélectionné
	if labels.size() > sel and menu_panel.visible:
		var l: Label = labels[sel]
		var r := l.get_global_rect()
		var w := l.get_theme_font("font").get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x
		var cx := r.get_center().x
		var y := r.end.y - 4
		var pts := PackedVector2Array()
		for i in 12:
			var f := i / 11.0
			pts.append(Vector2(cx - w / 2 - 10 + f * (w + 20), y + sin(f * 9 + t * 4) * 1.5))
		c.draw_polyline(pts, Color(0.75, 0.2, 0.18, 0.7), 4.0, true)

func _on_vp() -> void:
	set_deferred("size", get_viewport_rect().size)

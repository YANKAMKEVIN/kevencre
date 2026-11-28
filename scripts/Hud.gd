extends CanvasLayer
## Interface : vies, Trait d'encre, gouttes, panneaux, dialogues, pause.

signal dialogue_done

var level: Node
var ctl: Control
var hint_panel: PanelContainer
var hint_label: Label
var hint_owner: Variant = null
var banner_box: VBoxContainer
var toast_box: PanelContainer
var toast_title: Label
var toast_text: Label
var dlg: PanelContainer
var dlg_name: Label
var dlg_text: Label
var dlg_lines: Array = []
var dlg_i := 0
var dlg_active := false
var dlg_cool := 0.0
var pause_box: PanelContainer
var pause_btns: Array = []
var pause_i := 0
var paused := false
var t := 0.0
var cinzel: Font
var shown_hp := 5.0

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	cinzel = load("res://fonts/Cinzel.ttf")
	ctl = Control.new()
	ctl.set_anchors_preset(Control.PRESET_FULL_RECT)
	ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ctl)
	ctl.draw.connect(_draw_hud)
	# panneau d'aide
	hint_panel = _panel()
	hint_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint_panel.position = Vector2(-380, -150)
	hint_panel.custom_minimum_size = Vector2(760, 0)
	hint_label = _label(21)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.custom_minimum_size = Vector2(720, 0)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_panel.add_child(hint_label)
	hint_panel.modulate.a = 0
	add_child(hint_panel)
	# bandeau de chapitre
	banner_box = VBoxContainer.new()
	banner_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner_box.position = Vector2(-400, 110)
	banner_box.custom_minimum_size = Vector2(800, 0)
	banner_box.modulate.a = 0
	add_child(banner_box)
	# toast
	toast_box = _panel()
	toast_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_box.position = Vector2(-330, 90)
	toast_box.custom_minimum_size = Vector2(660, 0)
	var v := VBoxContainer.new()
	toast_title = _label(26, cinzel)
	toast_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_text = _label(19)
	toast_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_text.custom_minimum_size = Vector2(620, 0)
	toast_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(toast_title)
	v.add_child(toast_text)
	toast_box.add_child(v)
	toast_box.modulate.a = 0
	add_child(toast_box)
	# dialogue
	dlg = _panel(Color(0.97, 0.94, 0.87, 0.97))
	dlg.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	dlg.position = Vector2(-440, -210)
	dlg.custom_minimum_size = Vector2(880, 170)
	var dv := VBoxContainer.new()
	dlg_name = _label(24, cinzel)
	dlg_name.add_theme_color_override("font_color", Color(0.65, 0.2, 0.18))
	dlg_text = _label(22)
	dlg_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dlg_text.custom_minimum_size = Vector2(840, 0)
	dv.add_child(dlg_name)
	dv.add_child(dlg_text)
	dlg.add_child(dv)
	dlg.visible = false
	add_child(dlg)
	# pause
	pause_box = _panel(Color(0.97, 0.94, 0.87, 0.97))
	pause_box.set_anchors_preset(Control.PRESET_CENTER)
	pause_box.position = Vector2(-200, -150)
	pause_box.custom_minimum_size = Vector2(400, 300)
	var pv := VBoxContainer.new()
	pv.alignment = BoxContainer.ALIGNMENT_CENTER
	pv.add_theme_constant_override("separation", 14)
	var pt := _label(34, cinzel)
	pt.text = "Pause"
	pt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(pt)
	for s in ["Reprendre", "Revenir au chevalet", "Écran titre"]:
		var l := _label(24)
		l.text = s
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pv.add_child(l)
		pause_btns.append(l)
	pause_box.add_child(pv)
	pause_box.visible = false
	add_child(pause_box)

func _panel(bg := Color(0.97, 0.94, 0.87, 0.93)) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = Color(0.2, 0.18, 0.3, 0.9)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 8
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

func _label(size: int, font: Font = null) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.17, 0.15, 0.25))
	if font:
		l.add_theme_font_override("font", font)
	return l

# ------------------------------------------------------------------ messages
func show_hint(text: String, who: Variant) -> void:
	if text == "":
		return
	hint_owner = who
	hint_label.text = text
	var tw := create_tween()
	tw.tween_property(hint_panel, "modulate:a", 1.0, 0.25)

func hide_hint(who: Variant) -> void:
	if who != hint_owner:
		return
	hint_owner = null
	var tw := create_tween()
	tw.tween_property(hint_panel, "modulate:a", 0.0, 0.3)

func banner(top: String, title: String) -> void:
	for c in banner_box.get_children():
		c.queue_free()
	var a := _label(24, cinzel)
	a.text = top
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var b := _label(52, cinzel)
	b.text = title
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_color_override("font_outline_color", Color(0.97, 0.94, 0.87))
	b.add_theme_constant_override("outline_size", 10)
	a.add_theme_color_override("font_outline_color", Color(0.97, 0.94, 0.87))
	a.add_theme_constant_override("outline_size", 8)
	banner_box.add_child(a)
	banner_box.add_child(b)
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(banner_box, "modulate:a", 1.0, 0.8)
	tw.tween_interval(2.6)
	tw.tween_property(banner_box, "modulate:a", 0.0, 1.0)

func toast(title: String, text: String, col := Color(0.2, 0.2, 0.3)) -> void:
	toast_title.text = title
	toast_title.add_theme_color_override("font_color", col.darkened(0.2))
	toast_text.text = text
	var tw := create_tween()
	tw.tween_property(toast_box, "modulate:a", 1.0, 0.3)
	tw.tween_interval(5.0)
	tw.tween_property(toast_box, "modulate:a", 0.0, 0.6)

func say(lines: Array) -> void:
	dlg_lines = lines
	dlg_i = 0
	dlg_active = true
	dlg.visible = true
	dlg_cool = 0.3
	get_tree().paused = true
	_show_line()
	await dialogue_done

func _show_line() -> void:
	var l: Array = dlg_lines[dlg_i]
	dlg_name.text = l[0]
	dlg_text.text = l[1]
	dlg_text.visible_ratio = 0.0
	Game.sfx("blip", -12, 1.0 + randf() * 0.1)

func _advance() -> void:
	if dlg_text.visible_ratio < 1.0:
		dlg_text.visible_ratio = 1.0
		return
	dlg_i += 1
	if dlg_i >= dlg_lines.size():
		dlg_active = false
		dlg.visible = false
		get_tree().paused = false
		dialogue_done.emit()
	else:
		_show_line()

# ------------------------------------------------------------------ boucle
func _process(delta: float) -> void:
	t += delta
	dlg_cool -= delta
	if dlg_active:
		var n := dlg_text.text.length()
		if n > 0:
			dlg_text.visible_ratio = minf(1.0, dlg_text.visible_ratio + delta * 55.0 / n)
		if dlg_cool <= 0 and (Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_accept")):
			dlg_cool = 0.12
			_advance()
	elif paused:
		if Input.is_action_just_pressed("move_up") or Input.is_action_just_pressed("ui_up"):
			pause_i = (pause_i + 2) % 3
			Game.sfx("blip", -10)
		if Input.is_action_just_pressed("move_down") or Input.is_action_just_pressed("ui_down"):
			pause_i = (pause_i + 1) % 3
			Game.sfx("blip", -10)
		if Input.is_action_just_pressed("pause"):
			_set_pause(false)
		elif Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_accept"):
			match pause_i:
				0:
					_set_pause(false)
				1:
					_set_pause(false)
					if level.player and not level.player.dead and not level.finished:
						level.player.die()
				2:
					_set_pause(false)
					Game.timing = false
					Game.main.goto("title")
		for i in 3:
			pause_btns[i].add_theme_color_override("font_color", Color(0.75, 0.22, 0.2) if i == pause_i else Color(0.17, 0.15, 0.25))
			pause_btns[i].text = ("›  " if i == pause_i else "") + ["Reprendre", "Revenir au chevalet", "Écran titre"][i]
	elif Input.is_action_just_pressed("pause") and not level.finished:
		_set_pause(true)
	ctl.queue_redraw()

## Fenêtre ou onglet en arrière-plan, application mise en veille : le jeu se met en pause
## (le temps de jeu s'arrête, rien ne bouge) et attend le retour du joueur sur le menu pause.
func _notification(what: int) -> void:
	if what != NOTIFICATION_APPLICATION_FOCUS_OUT and what != NOTIFICATION_APPLICATION_PAUSED:
		return
	if Game.pause_on_focus_loss and not paused and not dlg_active and level and not level.finished and is_inside_tree():
		_set_pause(true)

func _set_pause(on: bool) -> void:
	paused = on
	pause_box.visible = on
	pause_i = 0
	get_tree().paused = on
	Game.sfx("blip", -8, 0.8 if on else 1.1)

func _draw_hud() -> void:
	var p: Variant = level.player
	if p == null:
		return
	shown_hp = lerpf(shown_hp, p.hp, 0.3)
	var mh := Game.max_hp()
	for i in mh:
		var c := Vector2(40 + i * 38, 42)
		var full: bool = i < p.hp
		var pts := PackedVector2Array()
		for k in 16:
			var a := TAU * k / 16.0
			var r := 13.0 + sin(a * 3 + i) * 1.5
			if k == 12:
				pts.append(c + Vector2(0, -20))
			else:
				pts.append(c + Vector2(cos(a) * r, sin(a) * r * 1.05) + Vector2(0, 3))
		if full:
			var wob := sin(t * 3 + i) * 1.0
			for k in pts.size():
				pts[k].y += wob
			ctl.draw_colored_polygon(pts, Game.INK)
			ctl.draw_circle(c + Vector2(-4, 0), 3.5, Color(1, 1, 1, 0.3))
		else:
			pts.append(pts[0])
			ctl.draw_polyline(pts, Color(Game.INK, 0.45), 2.0, true)
	# Trait d'encre
	if Game.has_brush:
		var bc := Vector2(40, 88)
		var col: Color = Color(0.86, 0.25, 0.22) if p.can_dash else Color(0.6, 0.58, 0.62)
		ctl.draw_line(bc + Vector2(-12, 10), bc + Vector2(14, -10), col.darkened(0.3), 10.0, true)
		ctl.draw_line(bc + Vector2(-12, 10), bc + Vector2(14, -10), col, 6.0, true)
		ctl.draw_circle(bc + Vector2(14, -10), 5, col)
		var fn: Font = load("res://fonts/Nunito.ttf")
		# contour papier : le libellé reste lisible sur un ciel clair comme sur une falaise sombre
		ctl.draw_string_outline(fn, bc + Vector2(26, 7), "Trait d'encre", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 6, Color(Game.PAPER, 0.85))
		ctl.draw_string(fn, bc + Vector2(26, 7), "Trait d'encre", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(Game.INK, 0.95 if p.can_dash else 0.5))
	# barre de vie du Délaveur
	var b: Variant = level.boss
	if b and b.started and not b.dead:
		var vs0 := ctl.size
		var bw := 420.0
		var bx := vs0.x / 2 - bw / 2
		var f0: Font = load("res://fonts/Cinzel.ttf")
		ctl.draw_string(f0, Vector2(bx, vs0.y - 46), "Le Délaveur", HORIZONTAL_ALIGNMENT_CENTER, bw, 22, Color(0.97, 0.94, 0.87))
		for i in 9:
			var r := Rect2(bx + i * (bw / 9) + 2, vs0.y - 36, bw / 9 - 4, 16)
			ctl.draw_rect(r, Color(0.2, 0.2, 0.26, 0.85))
			if i < b.hp:
				ctl.draw_rect(r.grow(-2), Color(0.62, 0.62, 0.68))
			else:
				ctl.draw_rect(r.grow(-2), Game.PALETTE[i % 5])
	# gouttes et pigments (en haut à droite)
	var vs := ctl.size
	var f: Font = load("res://fonts/Nunito.ttf")
	var dp := Vector2(vs.x - 180, 46)
	ctl.draw_circle(dp, 9, Game.PALETTE[1])
	ctl.draw_colored_polygon(PackedVector2Array([dp + Vector2(-6, -4), dp + Vector2(0, -18), dp + Vector2(6, -4)]), Game.PALETTE[1])
	ctl.draw_string(f, dp + Vector2(18, 8), "%d" % Game.drops, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Game.INK)
	for i in 5:
		var have := false
		for k in Game.pigments.keys():
			if Game.pigments[k] == i:
				have = true
		var pc := Vector2(vs.x - 160 + i * 26, 84)
		if have:
			ctl.draw_circle(pc, 9, Game.PALETTE[i])
			ctl.draw_arc(pc, 9, 0, TAU, 16, Game.PALETTE[i].darkened(0.4), 1.5, true)
		else:
			ctl.draw_arc(pc, 8, 0, TAU, 16, Color(Game.INK, 0.3), 1.5, true)

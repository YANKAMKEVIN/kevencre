extends Control
## Le conte d'ouverture.

var pages := [
	"Il était une fois un monde peint à la main.\nLes rivières étaient d'outremer, les coquelicots de vermillon,\net chaque matin un vieux peintre ajoutait une touche de lumière au ciel.",
	"Puis le peintre s'endormit.\nEt du fond de son atelier sortit le Délaveur, un géant de térébenthine grise.\nIl but les couleurs de tout ce qu'il touchait.",
	"Il ne resta qu'une seule goutte d'encre,\ntombée du pinceau au moment où le peintre fermait les yeux.\nElle s'appelait Sépia.",
]
var i := 0
var label: Label
var hint: Label
var t := 0.0
var cool := 0.5

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_deferred("size", get_viewport_rect().size)
	get_viewport().size_changed.connect(_on_vp)
	var bg := TextureRect.new()
	if ResourceLoader.exists("res://art/intro.png"):
		bg.texture = load("res://art/intro.png")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.modulate = Color(1, 1, 1, 0.55)
	add_child(bg)
	label = Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", load("res://fonts/Cinzel.ttf"))
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Game.INK)
	label.add_theme_color_override("font_outline_color", Color(0.97, 0.94, 0.87, 0.9))
	label.add_theme_constant_override("outline_size", 12)
	label.add_theme_constant_override("line_spacing", 10)
	add_child(label)
	hint = Label.new()
	hint.text = "Espace pour continuer"
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.position = Vector2(-200, -70)
	hint.custom_minimum_size = Vector2(400, 0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(Game.INK, 0.6))
	add_child(hint)
	Game.music("music_title")
	_show()

func _show() -> void:
	label.text = pages[i]
	label.modulate.a = 0
	var tw := create_tween()
	tw.tween_property(label, "modulate:a", 1.0, 0.8)

func _process(delta: float) -> void:
	t += delta
	cool -= delta
	hint.modulate.a = 0.5 + 0.5 * sin(t * 3)
	if cool <= 0 and (Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_accept")):
		cool = 0.5
		i += 1
		Game.sfx("blip", -8)
		if i >= pages.size():
			Game.main.goto("level", 1)
		else:
			_show()
	if Input.is_action_just_pressed("pause"):
		Game.main.goto("level", 1)

func _on_vp() -> void:
	set_deferred("size", get_viewport_rect().size)

extends Node
## État global de Kevencre : progression, sons, musique, constantes.

const TS := 48.0                      # taille d'une case
const PAPER := Color(0.94, 0.91, 0.85)
const INK := Color(0.16, 0.15, 0.27)
const PALETTE := [
	Color(0.86, 0.27, 0.22),   # vermillon
	Color(0.18, 0.36, 0.78),   # outremer
	Color(0.93, 0.68, 0.18),   # ocre jaune
	Color(0.16, 0.6, 0.45),    # viridian
	Color(0.68, 0.25, 0.62),   # pourpre
]
const CHAPTERS := [
	"",
	"Les Prés Délavés",
	"La Forêt d'Aquarelle",
	"Les Falaises d'Ocre",
	"L'Atelier du Délaveur",
]
const PIGMENT_INFO := [
	["Outremer", "On le broyait dans une pierre bleue venue de très loin. Le ciel s'en souvient encore."],
	["Vermillon", "Le rouge des coquelicots et des joues après la course. Il chauffe la main qui le tient."],
	["Ocre", "La terre elle-même, cuite au soleil. La plus vieille couleur du monde."],
	["Viridian", "Le vert profond des sous-bois mouillés. Il sent la mousse et la pluie."],
	["Pourpre", "La couleur des rois et des crépuscules. Rare, précieuse, un peu fière."],
]

var main: Node
var level := 1
var has_brush := false
var pigments := {}          # clé "niveau:x:y" -> index du pigment
var drops := 0
var drops_level := {}       # clés des gouttes déjà ramassées
var deaths := 0
var time := 0.0
var timing := false
var checkpoint := {}        # niveau -> Vector2 (position au sol)
var restored := {}          # niveau -> Array de Vector2 (vagues de couleur)
var stroke_i := 0

var _sfx: Array = []
var _sfx_i := 0
var _music: AudioStreamPlayer
var _music_name := ""
var _cache := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 14:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_sfx.append(p)
	_music = AudioStreamPlayer.new()
	add_child(_music)

func _process(delta: float) -> void:
	if timing and not get_tree().paused:
		time += delta

func new_game() -> void:
	level = 1
	has_brush = false
	pigments.clear()
	drops = 0
	drops_level.clear()
	deaths = 0
	time = 0.0
	checkpoint.clear()
	restored.clear()

func max_hp() -> int:
	return 5 + pigments.size()

func pigment_count() -> int:
	return pigments.size()

func next_stroke_color() -> Color:
	stroke_i = (stroke_i + 1) % PALETTE.size()
	return PALETTE[stroke_i]

func _stream(name: String) -> AudioStream:
	if _cache.has(name):
		return _cache[name]
	var s: AudioStream = null
	for ext in [".ogg", ".wav"]:
		var p: String = "res://audio/" + name + ext
		if ResourceLoader.exists(p):
			s = load(p)
			break
	_cache[name] = s
	return s

func sfx(name: String, vol := 0.0, pitch := 1.0) -> void:
	var s := _stream(name)
	if s == null:
		return
	var p: AudioStreamPlayer = _sfx[_sfx_i]
	_sfx_i = (_sfx_i + 1) % _sfx.size()
	p.stream = s
	p.volume_db = vol
	p.pitch_scale = pitch
	p.play()

func music(name: String, vol := -6.0) -> void:
	if name == _music_name and _music.playing:
		return
	_music_name = name
	var s := _stream(name)
	if s == null:
		_music.stop()
		return
	if s is AudioStreamOggVorbis:
		s.loop = true
	elif s is AudioStreamWAV:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_end = int(s.data.size() / 2)
	var tw := create_tween()
	if _music.playing:
		tw.tween_property(_music, "volume_db", -40.0, 0.6)
	tw.tween_callback(func():
		_music.stream = s
		_music.volume_db = vol
		_music.play())

func stop_music() -> void:
	_music_name = ""
	var tw := create_tween()
	tw.tween_property(_music, "volume_db", -40.0, 1.0)
	tw.tween_callback(_music.stop)

func format_time(t: float) -> String:
	var m := int(t) / 60
	var s := int(t) % 60
	return "%d min %02d s" % [m, s]

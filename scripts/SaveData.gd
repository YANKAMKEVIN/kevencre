class_name SaveData
extends RefCounted
## Format de la sauvegarde, versionné. Logique pure (aucun nœud) : testée par tools/UnitTests.gd.
##
## Règle : toute modification du format incrémente VERSION et ajoute une étape à
## migrate(). Une sauvegarde plus récente que le jeu est refusée plutôt qu'écrasée.

const VERSION := 1
const LEVELS := 4        # 3 chapitres + le Délaveur
const MAX_PIGMENTS := 5
const MAX_BYTES := 1 << 20   # au-delà, le fichier n'est pas une sauvegarde du jeu


## Photographie de la partie (au début d'un chapitre ou à un chevalet).
## checkpoint : niveau -> Vector2 ; restored : niveau -> Array de [Vector2, rayon].
static func make(level: int, has_brush: bool, pigments: Dictionary, drops: int, drops_level: Dictionary,
		deaths: int, time: float, checkpoint: Dictionary, restored: Dictionary) -> Dictionary:
	var cp := {}
	for n in checkpoint:
		var v: Vector2 = checkpoint[n]
		cp[str(n)] = [v.x, v.y]
	var rs := {}
	for n in restored:
		var waves: Array = []
		for w in restored[n]:
			waves.append([w[0].x, w[0].y, float(w[1])])
		rs[str(n)] = waves
	var pg := {}
	for k in pigments:
		pg[str(k)] = int(pigments[k])
	var dl: Array[String] = []
	for k in drops_level:
		dl.append(str(k))
	dl.sort()
	return {
		"version": VERSION, "level": level, "has_brush": has_brush, "pigments": pg,
		"drops": drops, "drops_level": dl, "deaths": deaths, "time": time,
		"checkpoint": cp, "restored": rs,
	}


## Texte JSON -> sauvegarde valide à la version courante, ou {} si illisible,
## abîmée ou venant d'une version plus récente du jeu.
static func parse(text: String) -> Dictionary:
	if text.length() > MAX_BYTES:
		return {}
	var json := JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {}
	var d := migrate(json.data)
	return d if is_valid(d) else {}


## Amène une sauvegarde d'une version antérieure à VERSION, et remet en entiers
## les nombres que JSON relit en flottants. Renvoie {} si la version est absente,
## inconnue ou plus récente que le jeu.
static func migrate(d: Dictionary) -> Dictionary:
	return migrate_with(d, MIGRATIONS, VERSION)


## Étapes de migration : version de départ -> nom de la fonction statique qui la fait passer à la suivante.
## Exemple, le jour où le format change : VERSION = 2 et MIGRATIONS = {1: "_v1_to_v2"}.
const MIGRATIONS := {}


## Migration générique (testée avec de fausses étapes dans tests/unit/test_save.gd).
## steps : version -> Callable (Dictionary -> Dictionary) ou nom d'une fonction statique de SaveData.
static func migrate_with(d: Dictionary, steps: Dictionary, target: int) -> Dictionary:
	var out := d.duplicate(true)
	var v: Variant = out.get("version", null)
	if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT:
		return {}
	if typeof(v) == TYPE_FLOAT and float(v) != floorf(v):
		return {}
	var version := int(v)
	if version < 1 or version > target:
		return {}
	while version < target:
		if not steps.has(version):
			return {}
		var step: Variant = steps[version]
		var next: Variant = step.call(out) if step is Callable else Callable(SaveData, str(step)).call(out)
		if not (next is Dictionary) or next.is_empty():
			return {}
		out = next
		version += 1
	out["version"] = version
	for k in ["level", "drops", "deaths"]:
		if typeof(out.get(k)) == TYPE_FLOAT:
			out[k] = int(out[k])
	if out.get("pigments") is Dictionary:
		for k in out["pigments"]:
			if typeof(out["pigments"][k]) == TYPE_FLOAT:
				out["pigments"][k] = int(out["pigments"][k])
	return out


static func is_valid(d: Dictionary) -> bool:
	if d.is_empty() or int(d.get("version", 0)) != VERSION:
		return false
	if typeof(d.get("level")) != TYPE_INT or d["level"] < 1 or d["level"] > LEVELS:
		return false
	if typeof(d.get("has_brush")) != TYPE_BOOL:
		return false
	for k in ["drops", "deaths"]:
		if typeof(d.get(k)) != TYPE_INT or d[k] < 0:
			return false
	if typeof(d.get("time")) != TYPE_FLOAT and typeof(d.get("time")) != TYPE_INT:
		return false
	if not (d.get("pigments") is Dictionary) or d["pigments"].size() > MAX_PIGMENTS:
		return false
	for k in d["pigments"]:
		var i: Variant = d["pigments"][k]
		if typeof(i) != TYPE_INT or i < 0 or i >= MAX_PIGMENTS:
			return false
	if not (d.get("drops_level") is Array):
		return false
	if not (d.get("checkpoint") is Dictionary) or not (d.get("restored") is Dictionary):
		return false
	for n in d["checkpoint"]:
		if not _level_key(n) or not _numbers(d["checkpoint"][n], 2):
			return false
	for n in d["restored"]:
		if not _level_key(n) or not (d["restored"][n] is Array):
			return false
		for w in d["restored"][n]:
			if not _numbers(w, 3):
				return false
	return true


static func _level_key(n: Variant) -> bool:
	return str(n).is_valid_int() and int(n) >= 1 and int(n) <= LEVELS


static func _numbers(a: Variant, count: int) -> bool:
	if not (a is Array) or a.size() != count:
		return false
	for x in a:
		if typeof(x) != TYPE_FLOAT and typeof(x) != TYPE_INT:
			return false
	return true


## Sauvegarde -> valeurs prêtes pour Game (Vector2, clés de niveau entières).
static func checkpoints_of(d: Dictionary) -> Dictionary:
	var out := {}
	for n in d["checkpoint"]:
		var a: Array = d["checkpoint"][n]
		out[int(n)] = Vector2(a[0], a[1])
	return out


static func restored_of(d: Dictionary) -> Dictionary:
	var out := {}
	for n in d["restored"]:
		var waves: Array = []
		for w in d["restored"][n]:
			waves.append([Vector2(w[0], w[1]), float(w[2])])
		out[int(n)] = waves
	return out


static func to_text(d: Dictionary) -> String:
	return JSON.stringify(d, "  ", true)

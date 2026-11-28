extends RefCounted
## Grilles des niveaux (logique pure, aucun nœud) : lecture des fichiers levels/N.txt,
## arène du Délaveur (4) et arène de mesure (99). Utilisée par Level, les tests et l'analyse de parcours.
##
## Légende : # sol plein · = plateforme traversable · c papier qui se déchire · ^ ronces
## S départ · G sortie · C chevalet · K autel du Vieux Pinceau · P pigment · * goutte
## D goutte de recharge · O fleur-ressort · E Tache · F Corbac · T Crachin · X faux mur · ! panneau

const BOSS_LEVEL := 4
const METRICS_LEVEL := 99


## Grille du niveau num (Array de String, toutes de même longueur).
static func load_grid(num: int) -> Array:
	if num == BOSS_LEVEL:
		return arena()
	if num == METRICS_LEVEL:
		return metrics_arena()
	var grid: Array = []
	var f := FileAccess.open("res://levels/%d.txt" % num, FileAccess.READ)
	if f == null:
		return grid
	while not f.eof_reached():
		var l := f.get_line()
		if l.length() > 0:
			grid.append(l)
	return grid


## Arène du combat contre le Délaveur.
static func arena() -> Array:
	var g: Array = []
	for y in 20:
		var row := ""
		for x in 34:
			var c := "."
			if x < 2 or x > 31 or y > 16 or y == 0:
				c = "#"
			elif y == 13 and ((x >= 5 and x <= 9) or (x >= 24 and x <= 28)):
				c = "="
			elif y == 9 and x >= 14 and x <= 19:
				c = "="
			elif y == 16 and x == 4:
				c = "S"
			row += c
		g.append(row)
	return g


## Arène de mesure des sauts (tools/Metrics.gd).
static func metrics_arena() -> Array:
	var g: Array = []
	for y in 24:
		var row := ""
		for x in 70:
			var c := "."
			if y >= 21 or x < 2 or x > 67:
				c = "#"
			elif x >= 50 and x <= 51 and y <= 17 and y >= 2:
				c = "#"
			elif x >= 56 and y <= 20 and y >= 2:
				c = "#"
			elif y == 20 and x == 4:
				c = "S"
			row += c
		g.append(row)
	return g


## Case (x, y) : les bords gauche et droit sont des murs, le haut et le bas sont ouverts.
static func cell(grid: Array, x: int, y: int) -> String:
	var w: int = grid[0].length() if grid.size() > 0 else 0
	if x < 0 or x >= w:
		return "#"
	if y < 0 or y >= grid.size():
		return "."
	return grid[y][x]


## Toutes les cases qui portent le caractère c, dans l'ordre de lecture.
static func find(grid: Array, c: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in grid.size():
		var row: String = grid[y]
		var x := row.find(c)
		while x != -1:
			out.append(Vector2i(x, y))
			x = row.find(c, x + 1)
	return out


## Défauts de forme d'une grille (vide si elle est correcte).
static func problems(grid: Array) -> Array[String]:
	var out: Array[String] = []
	if grid.is_empty():
		out.append("grille vide")
		return out
	var w: int = grid[0].length()
	for y in grid.size():
		if grid[y].length() != w:
			out.append("ligne %d : longueur %d au lieu de %d" % [y, grid[y].length(), w])
	if find(grid, "S").size() != 1:
		out.append("il faut exactement un départ S")
	return out

extends "res://tests/TestCase.gd"
## L'analyse de parcours elle-même : elle doit dire « faisable » et « infaisable » à bon escient.

const Reachability := preload("res://tests/parcours/Reachability.gd")


## Deux sols séparés par un vide de `gap` cases (fond ouvert : tomber = mourir), sortie G à droite.
func _gap(gap: int) -> Array:
	var w := 10 + gap + 10
	var g: Array = []
	for y in 12:
		var row := ""
		for x in w:
			var c := "."
			if y >= 9 and (x < 10 or x >= 10 + gap):
				c = "#"
			if x < 2 or x >= w - 2:
				c = "#"
			if y == 8 and x == 4:
				c = "S"
			if y == 8 and x == w - 4:
				c = "G"
			row += c
		g.append(row)
	return g


func _goal_reached(g: Array, brush: bool) -> bool:
	var r := Reachability.new(g)
	var goal: Vector2i = LevelGrid.find(g, "G")[0]
	r.explore([LevelGrid.find(g, "S")[0]], brush, [goal])
	return r.touched.has(goal)


func test_vide_franchissable_en_sautant() -> void:
	check(_goal_reached(_gap(4), false), "un vide de 4 cases se saute sans le pinceau")


func test_vide_trop_large_sans_pinceau() -> void:
	check(not _goal_reached(_gap(9), false), "un vide de 9 cases est infranchissable sans le pinceau")
	check(_goal_reached(_gap(9), true), "mais franchissable avec le Trait d'encre (trait puis ressaut)")


func test_vide_infranchissable() -> void:
	check(not _goal_reached(_gap(30), true), "un vide de 30 cases est infranchissable même avec le pinceau")


func test_piece_fermee() -> void:
	var g := _gap(0)
	g[0] = "#".repeat(g[0].length())   # plafond : on ne peut pas passer par-dessus les murs
	for y in range(0, 9):
		g[y][12] = "#"
	check(not _goal_reached(g, true), "un mur du sol au plafond bloque la sortie, même avec le pinceau")
	for y in range(5, 9):
		g[y][12] = "X"
	check(_goal_reached(g, false), "on traverse un faux mur posé au sol")


func test_mur_escaladable() -> void:
	var g := _gap(0)
	for y in range(1, 9):
		g[y][12] = "#"
	check(_goal_reached(g, false), "un mur sans plafond au-dessus s'escalade en rebondissant contre lui")


func test_ronces() -> void:
	var g := _gap(0)
	for x in range(6, 16):
		g[8][x] = "^"
	check(not _goal_reached(g, false), "un tapis de ronces de 10 cases bloque la sortie sans le pinceau")


const LevelGrid := preload("res://scripts/level/LevelGrid.gd")

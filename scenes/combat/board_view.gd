## Grille de combat : sol et obstacles en tuiles, surlignage des cases
## atteignables et aperçu du chemin. Ne connaît aucune règle : on lui dit quoi
## dessiner.
##
## Note Godot : un Node2D dessine dans `_draw()`, appelée par le moteur quand
## on demande `queue_redraw()`. C'est du dessin immédiat, sans fichier image.
## Les tuiles, elles, sont des TileMapLayer : une grille de petites images
## prises dans une planche (Kenney Tiny Town, 16 px, agrandies ×4).
class_name BoardView
extends Node2D

## Émis au clic sur une case de la grille.
signal cell_clicked(cell: Vector2i)
## Émis quand la souris change de case (`NO_CELL` hors de la grille).
signal cell_hovered(cell: Vector2i)
## Clic droit sur une case : la fiche du combattant qui s'y trouve.
signal cell_right_clicked(cell: Vector2i)

const CELL_SIZE := 64
const NO_CELL := Vector2i(-1, -1)

## Planche de tuiles et taille d'une tuile dans la planche.
const TILES: Texture2D = preload("res://assets/tiles/tiny_town.png")
const TILE_SIZE := 16
## Herbe : unie, touffue, fleurie (coordonnées dans la planche).
const GRASS_TILES: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
## Obstacles : buisson, sapin, arbre d'automne.
const OBSTACLE_TILES: Array[Vector2i] = [Vector2i(5, 0), Vector2i(4, 2), Vector2i(3, 2)]
## Murets, dessinés en barrières de bois : à l'horizontale (bout gauche,
## milieu, bout droit) et à la verticale (haut, milieu, bas).
const FENCE_H_TILES: Array[Vector2i] = [Vector2i(8, 6), Vector2i(9, 6), Vector2i(10, 6)]
const FENCE_V_TILES: Array[Vector2i] = [Vector2i(11, 3), Vector2i(11, 4), Vector2i(11, 5)]
## Terrain difficile : broussailles (pousses de fougère) sur herbe touffue.
const UNDERGROWTH_TILE := Vector2i(5, 1)

const LINE_COLOR := Color(0.05, 0.1, 0.04, 0.22)
const REACHABLE_COLOR := Color(0.3, 0.55, 0.95, 0.28)
const ATTACKABLE_COLOR := Color(0.95, 0.3, 0.25, 0.35)
const PATH_COLOR := Color(0.55, 0.8, 1.0, 0.9)
## Chemin qui provoque une attaque d'opportunité.
const PATH_WARNING_COLOR := Color(1.0, 0.4, 0.3, 0.95)
## Hachures des cases attaquables : une forme en plus de la couleur, pour
## qui distingue mal le rouge.
const HATCH_COLOR := Color(1.0, 0.55, 0.5, 0.7)
const HATCH_SPACING := 12.0
const HOVER_COLOR := Color(1, 1, 1, 0.6)
## Zone de menace (attaque d'opportunité) : bord rouge et hachures.
const THREAT_COLOR := Color(1.0, 0.35, 0.3, 0.85)
const THREAT_FILL_COLOR := Color(1.0, 0.35, 0.3, 0.15)
## Ligne de tir vers la cible visée, et bouclier sur la case qui l'abrite.
const AIM_COLOR := Color(1.0, 0.9, 0.55, 0.85)
const AIM_DASH := 10.0
const SHIELD_COLOR := Palette.GOLD
const SHIELD_TEXT_COLOR := Color(0.16, 0.11, 0.06)
## Aperçus d'une action survolée : portée de Foncer, cases pour se cacher,
## combattants concernés (anneau).
const REACH_PREVIEW_COLOR := Color(0.55, 0.8, 1.0, 0.22)
const REACH_PREVIEW_BORDER := Color(0.6, 0.85, 1.0, 0.7)
const HIDING_COLOR := Color(0.45, 0.3, 0.75, 0.35)
const HIDING_BORDER := Color(0.75, 0.6, 1.0, 0.85)
const RING_COLOR := Palette.GOLD
## Vue tactique : chaque case colorée selon ce qu'elle est.
const TACTICAL_OBSTACLE_COLOR := Color(0.05, 0.05, 0.08, 0.6)
const TACTICAL_WALL_COLOR := Color(1.0, 0.85, 0.3, 0.3)
const TACTICAL_WALL_BORDER := Color(1.0, 0.85, 0.3, 0.9)
const TACTICAL_DIFFICULT_COLOR := Color(0.65, 0.4, 0.15, 0.35)
const TACTICAL_DIFFICULT_BORDER := Color(0.85, 0.55, 0.25, 0.9)
const TACTICAL_TAG_SIZE := 16
## Coût du trajet, écrit sur la case d'arrivée.
const COST_FONT_SIZE := 26
const COST_OUTLINE := 6

var grid_size: Vector2i
var blocked_cells: Array[Vector2i] = []
var low_walls: Array[Vector2i] = []
var difficult_cells: Array[Vector2i] = []
## Cases où le combattant actif peut aller (affichées en bleu).
var reachable: Dictionary[Vector2i, int] = {}:
	set(value):
		reachable = value
		queue_redraw()
## Cases des ennemis attaquables (affichées en rouge).
var attackable: Array[Vector2i] = []:
	set(value):
		attackable = value
		queue_redraw()
## Chemin prévu au survol (case de départ exclue).
var path_preview: Array[Vector2i] = []:
	set(value):
		path_preview = value
		queue_redraw()
## Le chemin prévu provoque-t-il une attaque d'opportunité ?
var path_warning := false:
	set(value):
		path_warning = value
		queue_redraw()

## Coût du trajet prévu, écrit sur sa dernière case (0 : rien).
var path_cost := 0:
	set(value):
		path_cost = value
		queue_redraw()
## Zones de menace à montrer (les cases que l'on quitterait au risque d'une
## attaque d'opportunité).
var threat_preview: Array[Vector2i] = []:
	set(value):
		threat_preview = value
		queue_redraw()
## Ligne de tir : [case de l'attaquant, case de la cible], ou vide.
var aim: Array[Vector2i] = []:
	set(value):
		aim = value
		queue_redraw()
## Cases qui abritent la cible visée (murets, créatures) : un bouclier +2.
var cover_marks: Array[Vector2i] = []:
	set(value):
		cover_marks = value
		queue_redraw()

## Aperçu de Foncer : les cases en plus que l'action rendrait atteignables.
var reach_preview: Array[Vector2i] = []:
	set(value):
		reach_preview = value
		queue_redraw()
## Aperçu de Se cacher : cases hors de vue de tous les ennemis.
var hiding_preview: Array[Vector2i] = []:
	set(value):
		hiding_preview = value
		queue_redraw()
## Combattants concernés par l'action survolée : un anneau sur leur case.
var ring_cells: Array[Vector2i] = []:
	set(value):
		ring_cells = value
		queue_redraw()
## Zones de menace montrées éteintes (aperçu de Se désengager).
var threats_faded := false:
	set(value):
		threats_faded = value
		queue_redraw()

## Vue tactique (touche Alt maintenue) : nature des cases et zones de menace
## de tous les ennemis (`tactical_threats`).
var tactical := false:
	set(value):
		tactical = value
		queue_redraw()
var tactical_threats: Array[Vector2i] = []:
	set(value):
		tactical_threats = value
		queue_redraw()

var _hovered := NO_CELL
## Couches de tuiles déjà créées (le sol, puis les obstacles).
var _layer_count := 0


func setup(encounter: EncounterDef) -> void:
	grid_size = encounter.grid_size
	blocked_cells = encounter.blocked_cells
	low_walls = encounter.low_walls
	difficult_cells = encounter.difficult_cells
	_build_tiles()
	queue_redraw()


## Sol et obstacles. Le choix de la tuile dépend seulement de la case : le
## même combat a toujours le même décor.
func _build_tiles() -> void:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	var source := TileSetAtlasSource.new()
	source.texture = TILES
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for coords: Vector2i in GRASS_TILES + OBSTACLE_TILES + FENCE_H_TILES + FENCE_V_TILES + [UNDERGROWTH_TILE]:
		source.create_tile(coords)
	tile_set.add_source(source, 0)

	var floor_layer := _make_layer(tile_set, "Floor")
	var obstacle_layer := _make_layer(tile_set, "Obstacles")
	for x in grid_size.x:
		for y in grid_size.y:
			var cell := Vector2i(x, y)
			var variant := _variant(cell)
			floor_layer.set_cell(cell, 0, GRASS_TILES[0] if variant % 5 > 1 else GRASS_TILES[1 + variant % 2])
			if difficult_cells.has(cell):
				floor_layer.set_cell(cell, 0, GRASS_TILES[1])
				obstacle_layer.set_cell(cell, 0, UNDERGROWTH_TILE)
			elif blocked_cells.has(cell):
				obstacle_layer.set_cell(cell, 0, OBSTACLE_TILES[variant % OBSTACLE_TILES.size()])
			elif low_walls.has(cell):
				obstacle_layer.set_cell(cell, 0, _fence_tile(cell))


## Tuile de barrière d'un muret, raccordée à ses voisins : une ligne
## verticale si un muret est au-dessus ou en dessous, horizontale sinon.
func _fence_tile(cell: Vector2i) -> Vector2i:
	var up := low_walls.has(cell + Vector2i.UP)
	var down := low_walls.has(cell + Vector2i.DOWN)
	if up or down:
		return FENCE_V_TILES[1 if up and down else (2 if up else 0)]
	var left := low_walls.has(cell + Vector2i.LEFT)
	var right := low_walls.has(cell + Vector2i.RIGHT)
	return FENCE_H_TILES[0 if right and not left else (2 if left and not right else 1)]


# Note Godot : `show_behind_parent` dessine ce nœud sous le dessin de son
# parent : les surlignages du plateau restent au-dessus de l'herbe.
func _make_layer(tile_set: TileSet, layer_name: String) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = tile_set
	layer.scale = Vector2.ONE * (CELL_SIZE / float(TILE_SIZE))
	layer.show_behind_parent = true
	add_child(layer)
	# Avant les pions (Tokens), après les couches déjà créées.
	move_child(layer, _layer_count)
	_layer_count += 1
	return layer


## Nombre pseudo-aléatoire stable pour une case.
static func _variant(cell: Vector2i) -> int:
	return absi(cell.x * 73856093 ^ cell.y * 19349663) % 97


## Centre d'une case, dans le repère du plateau.
func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell) * CELL_SIZE + Vector2.ONE * CELL_SIZE / 2.0


func _cell_under_mouse() -> Vector2i:
	# get_local_mouse_position() tient compte de la position du plateau et
	# de la mise à l'échelle de la fenêtre (stretch canvas_items).
	var cell := Vector2i((get_local_mouse_position() / CELL_SIZE).floor())
	if cell.x < 0 or cell.y < 0 or cell.x >= grid_size.x or cell.y >= grid_size.y:
		return NO_CELL
	return cell


# Note Godot : _unhandled_input ne reçoit que les événements qu'aucun
# contrôle d'interface (bouton, panneau) n'a déjà consommés.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var cell := _cell_under_mouse()
		if cell != _hovered:
			_hovered = cell
			queue_redraw()
			cell_hovered.emit(cell)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := _cell_under_mouse()
		if cell != NO_CELL:
			cell_clicked.emit(cell)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var cell := _cell_under_mouse()
		if cell != NO_CELL:
			cell_right_clicked.emit(cell)


func _draw() -> void:
	for x in grid_size.x:
		for y in grid_size.y:
			var cell := Vector2i(x, y)
			var rect := Rect2(Vector2(cell) * CELL_SIZE, Vector2.ONE * CELL_SIZE)
			if reachable.has(cell):
				draw_rect(rect, REACHABLE_COLOR)
			if attackable.has(cell):
				draw_rect(rect, ATTACKABLE_COLOR)
				_draw_hatching(rect)
			draw_rect(rect, LINE_COLOR, false, 1.0)

	if tactical:
		_draw_tactical()

	for cell in reach_preview:
		var reach_rect := Rect2(Vector2(cell) * CELL_SIZE, Vector2.ONE * CELL_SIZE)
		draw_rect(reach_rect, REACH_PREVIEW_COLOR)
		draw_rect(reach_rect.grow(-4), REACH_PREVIEW_BORDER, false, 1.5)
	for cell in hiding_preview:
		var hiding_rect := Rect2(Vector2(cell) * CELL_SIZE, Vector2.ONE * CELL_SIZE)
		draw_rect(hiding_rect, HIDING_COLOR)
		draw_rect(hiding_rect.grow(-3), HIDING_BORDER, false, 2.0)

	for cell in threat_preview:
		var threat_rect := Rect2(Vector2(cell) * CELL_SIZE, Vector2.ONE * CELL_SIZE)
		if threats_faded:
			# Désengagé : la menace est barrée, en pointillés.
			draw_dashed_line(threat_rect.position + Vector2(4, 4), threat_rect.end - Vector2(4, 4), THREAT_COLOR, 2.0, 6.0)
			draw_rect(threat_rect.grow(-3), Color(THREAT_COLOR, 0.35), false, 2.0)
			continue
		draw_rect(threat_rect, THREAT_FILL_COLOR)
		draw_rect(threat_rect.grow(-3), THREAT_COLOR, false, 3.0)
	for cell in ring_cells:
		draw_arc(cell_center(cell), CELL_SIZE * 0.45, 0.0, TAU, 48, RING_COLOR, 3.0)

	for cell in path_preview:
		if path_warning:
			# Une croix en plus de la couleur : le danger se lit sans elle.
			var center := cell_center(cell)
			draw_line(center + Vector2(-6, -6), center + Vector2(6, 6), PATH_WARNING_COLOR, 3.0)
			draw_line(center + Vector2(-6, 6), center + Vector2(6, -6), PATH_WARNING_COLOR, 3.0)
		else:
			draw_circle(cell_center(cell), 6.0, PATH_COLOR)

	if path_cost > 0 and not path_preview.is_empty():
		_draw_centered_text(cell_center(path_preview.back()), str(path_cost), COST_FONT_SIZE, Color.WHITE)

	if aim.size() == 2:
		draw_dashed_line(cell_center(aim[0]), cell_center(aim[1]), AIM_COLOR, 2.0, AIM_DASH)
	for cell in cover_marks:
		_draw_shield(cell_center(cell))

	if _hovered != NO_CELL:
		draw_rect(Rect2(Vector2(_hovered) * CELL_SIZE, Vector2.ONE * CELL_SIZE).grow(-2), HOVER_COLOR, false, 2.0)


## Vue tactique : arbres assombris, palissades dorées « +2 », broussailles
## « x2 », et les zones de menace en rouge. Des marques en plus des
## couleurs, pour qui les distingue mal.
func _draw_tactical() -> void:
	for cell in blocked_cells:
		var rect := Rect2(Vector2(cell) * CELL_SIZE, Vector2.ONE * CELL_SIZE)
		draw_rect(rect, TACTICAL_OBSTACLE_COLOR)
		draw_line(rect.position + Vector2(10, 10), rect.end - Vector2(10, 10), Color(0, 0, 0, 0.7), 3.0)
		draw_line(Vector2(rect.end.x - 10, rect.position.y + 10), Vector2(rect.position.x + 10, rect.end.y - 10), Color(0, 0, 0, 0.7), 3.0)
	for cell in low_walls:
		_draw_tagged_cell(cell, TACTICAL_WALL_COLOR, TACTICAL_WALL_BORDER, "+%d" % CombatState.HALF_COVER_BONUS)
	for cell in difficult_cells:
		_draw_tagged_cell(cell, TACTICAL_DIFFICULT_COLOR, TACTICAL_DIFFICULT_BORDER, "x2")
	for cell in tactical_threats:
		var rect := Rect2(Vector2(cell) * CELL_SIZE, Vector2.ONE * CELL_SIZE)
		draw_rect(rect, THREAT_FILL_COLOR)
		draw_rect(rect.grow(-3), THREAT_COLOR, false, 2.0)
		_draw_hatching(rect)


func _draw_tagged_cell(cell: Vector2i, fill: Color, border: Color, tag: String) -> void:
	var rect := Rect2(Vector2(cell) * CELL_SIZE, Vector2.ONE * CELL_SIZE)
	draw_rect(rect, fill)
	draw_rect(rect.grow(-2), border, false, 2.0)
	_draw_centered_text(rect.position + Vector2(CELL_SIZE - 16, 14), tag, TACTICAL_TAG_SIZE, Color.WHITE)


## Texte centré sur un point, avec un contour sombre pour rester lisible sur
## l'herbe.
func _draw_centered_text(center: Vector2, text: String, font_size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var origin := center + Vector2(-text_size.x / 2.0, text_size.y / 3.0)
	draw_string_outline(font, origin, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, COST_OUTLINE, Color(0, 0, 0, 0.85))
	draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)


## Petit écusson doré « +2 » : cette case abrite la cible (abri partiel).
func _draw_shield(center: Vector2) -> void:
	var half := 13.0
	var points := PackedVector2Array([
		center + Vector2(-half, -half), center + Vector2(half, -half),
		center + Vector2(half, 2.0), center + Vector2(0, half + 3.0), center + Vector2(-half, 2.0),
	])
	draw_colored_polygon(points, SHIELD_COLOR)
	points.append(points[0])
	draw_polyline(points, Color(0, 0, 0, 0.8), 2.0)
	var font := ThemeDB.fallback_font
	var text := "+%d" % CombatState.HALF_COVER_BONUS
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 15)
	draw_string(font, center + Vector2(-text_size.x / 2.0, 3.0), text, HORIZONTAL_ALIGNMENT_CENTER, -1, 15, SHIELD_TEXT_COLOR)


## Hachures diagonales dans une case : des segments x + y = constante,
## coupés aux bords de la case.
func _draw_hatching(rect: Rect2) -> void:
	var offset := HATCH_SPACING
	while offset < rect.size.x * 2.0:
		var start := Vector2(minf(offset, rect.size.x), maxf(offset - rect.size.x, 0.0))
		var end := Vector2(maxf(offset - rect.size.y, 0.0), minf(offset, rect.size.y))
		draw_line(rect.position + start, rect.position + end, HATCH_COLOR, 1.5)
		offset += HATCH_SPACING

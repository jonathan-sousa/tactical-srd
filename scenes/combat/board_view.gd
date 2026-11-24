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

const CELL_SIZE := 64
const NO_CELL := Vector2i(-1, -1)

## Planche de tuiles et taille d'une tuile dans la planche.
const TILES: Texture2D = preload("res://assets/tiles/tiny_town.png")
const TILE_SIZE := 16
## Herbe : unie, touffue, fleurie (coordonnées dans la planche).
const GRASS_TILES: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
## Obstacles : buisson, sapin, arbre d'automne.
const OBSTACLE_TILES: Array[Vector2i] = [Vector2i(5, 0), Vector2i(4, 2), Vector2i(3, 2)]

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

var grid_size: Vector2i
var blocked_cells: Array[Vector2i] = []
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

var _hovered := NO_CELL
## Couches de tuiles déjà créées (le sol, puis les obstacles).
var _layer_count := 0


func setup(encounter: EncounterDef) -> void:
	grid_size = encounter.grid_size
	blocked_cells = encounter.blocked_cells
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
	for coords: Vector2i in GRASS_TILES + OBSTACLE_TILES:
		source.create_tile(coords)
	tile_set.add_source(source, 0)

	var floor_layer := _make_layer(tile_set, "Floor")
	var obstacle_layer := _make_layer(tile_set, "Obstacles")
	for x in grid_size.x:
		for y in grid_size.y:
			var cell := Vector2i(x, y)
			var variant := _variant(cell)
			floor_layer.set_cell(cell, 0, GRASS_TILES[0] if variant % 5 > 1 else GRASS_TILES[1 + variant % 2])
			if blocked_cells.has(cell):
				obstacle_layer.set_cell(cell, 0, OBSTACLE_TILES[variant % OBSTACLE_TILES.size()])


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

	for cell in path_preview:
		if path_warning:
			# Une croix en plus de la couleur : le danger se lit sans elle.
			var center := cell_center(cell)
			draw_line(center + Vector2(-6, -6), center + Vector2(6, 6), PATH_WARNING_COLOR, 3.0)
			draw_line(center + Vector2(-6, 6), center + Vector2(6, -6), PATH_WARNING_COLOR, 3.0)
		else:
			draw_circle(cell_center(cell), 6.0, PATH_COLOR)

	if _hovered != NO_CELL:
		draw_rect(Rect2(Vector2(_hovered) * CELL_SIZE, Vector2.ONE * CELL_SIZE).grow(-2), HOVER_COLOR, false, 2.0)


## Hachures diagonales dans une case : des segments x + y = constante,
## coupés aux bords de la case.
func _draw_hatching(rect: Rect2) -> void:
	var offset := HATCH_SPACING
	while offset < rect.size.x * 2.0:
		var start := Vector2(minf(offset, rect.size.x), maxf(offset - rect.size.x, 0.0))
		var end := Vector2(maxf(offset - rect.size.y, 0.0), minf(offset, rect.size.y))
		draw_line(rect.position + start, rect.position + end, HATCH_COLOR, 1.5)
		offset += HATCH_SPACING

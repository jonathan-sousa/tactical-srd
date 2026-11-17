## Grille de combat : cases, obstacles, surlignage des cases atteignables et
## aperçu du chemin. Ne connaît aucune règle : on lui dit quoi dessiner.
##
## Note Godot : un Node2D dessine dans `_draw()`, appelée par le moteur quand
## on demande `queue_redraw()`. C'est du dessin immédiat, sans fichier image.
class_name BoardView
extends Node2D

## Émis au clic sur une case de la grille.
signal cell_clicked(cell: Vector2i)
## Émis quand la souris change de case (`NO_CELL` hors de la grille).
signal cell_hovered(cell: Vector2i)

const CELL_SIZE := 64
const NO_CELL := Vector2i(-1, -1)

const FLOOR_COLOR := Color(0.23, 0.22, 0.2)
const FLOOR_ALT_COLOR := Color(0.25, 0.24, 0.22)
const LINE_COLOR := Color(0.12, 0.11, 0.1)
const OBSTACLE_COLOR := Color(0.42, 0.38, 0.33)
const OBSTACLE_EDGE_COLOR := Color(0.3, 0.27, 0.23)
const REACHABLE_COLOR := Color(0.3, 0.55, 0.95, 0.28)
const ATTACKABLE_COLOR := Color(0.95, 0.3, 0.25, 0.35)
const PATH_COLOR := Color(0.55, 0.8, 1.0, 0.9)
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

var _hovered := NO_CELL


func setup(encounter: EncounterDef) -> void:
	grid_size = encounter.grid_size
	blocked_cells = encounter.blocked_cells
	queue_redraw()


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
			draw_rect(rect, FLOOR_COLOR if (x + y) % 2 == 0 else FLOOR_ALT_COLOR)
			if blocked_cells.has(cell):
				draw_rect(rect.grow(-6), OBSTACLE_COLOR)
				draw_rect(rect.grow(-6), OBSTACLE_EDGE_COLOR, false, 3.0)
			elif reachable.has(cell):
				draw_rect(rect, REACHABLE_COLOR)
			if attackable.has(cell):
				draw_rect(rect, ATTACKABLE_COLOR)
			draw_rect(rect, LINE_COLOR, false, 1.0)

	for cell in path_preview:
		draw_circle(cell_center(cell), 6.0, PATH_COLOR)

	if _hovered != NO_CELL:
		draw_rect(Rect2(Vector2(_hovered) * CELL_SIZE, Vector2.ONE * CELL_SIZE).grow(-2), HOVER_COLOR, false, 2.0)

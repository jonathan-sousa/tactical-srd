## Recherche de chemin sur la grille de combat.
##
## Règles (brief) : 8 directions, une diagonale coûte 1 case comme un pas
## droit, pas de coupe de coin le long d'un obstacle, cases occupées
## infranchissables.
##
## Note Godot : AStarGrid2D est un RefCounted, il a donc sa place dans le
## moteur de règles. Avec l'heuristique Chebyshev, la distance entre deux
## cases voisines vaut 1 même en diagonale : c'est la règle de grille du SRD.
class_name GridPathfinder
extends RefCounted

var _astar := AStarGrid2D.new()


func _init(grid_size: Vector2i, blocked_cells: Array[Vector2i]) -> void:
	_astar.region = Rect2i(Vector2i.ZERO, grid_size)
	# Diagonale autorisée seulement si les deux cases qu'elle longe sont libres.
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_CHEBYSHEV
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_CHEBYSHEV
	# Piège Godot : update() doit être appelé après avoir changé la région et
	# avant de marquer des cases, sinon set_point_solid échoue.
	_astar.update()
	for cell in blocked_cells:
		_astar.set_point_solid(cell)


## Distance en cases quand une diagonale coûte 1 (distance de Chebyshev).
static func chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


func is_inside(cell: Vector2i) -> bool:
	return _astar.is_in_boundsv(cell)


func is_blocked(cell: Vector2i) -> bool:
	return _astar.is_point_solid(cell)


## Plus court chemin de `from` à `to`, sans la case de départ. Vide si `to`
## est hors grille, bloquée, occupée ou inaccessible. Avec un coût de 1 par
## pas, la longueur du tableau est le coût en cases.
func find_path(from: Vector2i, to: Vector2i, occupied: Array[Vector2i]) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	if not is_inside(to) or is_blocked(to) or occupied.has(to) or from == to:
		return path

	# Les combattants bloquent le passage le temps du calcul seulement.
	var marked := _mark_solid(occupied)
	var id_path := _astar.get_id_path(from, to)
	for cell in marked:
		_astar.set_point_solid(cell, false)

	for i in range(1, id_path.size()):
		path.append(id_path[i])
	return path


## Cases atteignables en `max_steps` pas au plus, avec leur coût. La case de
## départ n'en fait pas partie.
func reachable_cells(from: Vector2i, max_steps: int, occupied: Array[Vector2i]) -> Dictionary[Vector2i, int]:
	var reachable: Dictionary[Vector2i, int] = {}
	if max_steps <= 0:
		return reachable
	var region := _astar.region
	for x in range(maxi(region.position.x, from.x - max_steps), mini(region.end.x, from.x + max_steps + 1)):
		for y in range(maxi(region.position.y, from.y - max_steps), mini(region.end.y, from.y + max_steps + 1)):
			var cell := Vector2i(x, y)
			var path := find_path(from, cell, occupied)
			if not path.is_empty() and path.size() <= max_steps:
				reachable[cell] = path.size()
	return reachable


## Marque comme infranchissables les cases libres de `cells` et renvoie
## celles qui ont été marquées, pour les libérer ensuite sans jamais
## toucher à un vrai obstacle.
func _mark_solid(cells: Array[Vector2i]) -> Array[Vector2i]:
	var marked: Array[Vector2i] = []
	for cell in cells:
		if is_inside(cell) and not _astar.is_point_solid(cell):
			_astar.set_point_solid(cell, true)
			marked.append(cell)
	return marked

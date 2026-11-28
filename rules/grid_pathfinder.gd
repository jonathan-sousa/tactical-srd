## Recherche de chemin sur la grille de combat.
##
## Règles de grille du SRD (« Combat on a Grid ») :
## - 8 directions, une diagonale coûte 1 case comme un pas droit ;
## - entrer dans une case de terrain difficile coûte 2 cases (« Entering a
##   Square ») ;
## - en rampant (créature à terre), chaque case coûte 1 de plus, 2 de plus
##   en terrain difficile (« Crawling ») : 2 cases, ou 3 ;
## - une diagonale ne peut pas couper le coin d'un élément de décor qui
##   remplit sa case (« Corners ») : arbre, muret. Une créature ne l'empêche
##   pas.
##
## Trois sortes de cases occupées : celles qu'on ne traverse pas
## (`blocking`, les ennemis conscients), celles qu'on traverse sans pouvoir
## s'y arrêter (`no_stop`, les alliés et les créatures neutralisées : SRD
## « Moving Around Other Creatures »), et parmi elles celles qui sont en plus
## un terrain difficile (`difficult`, la case d'une créature qui n'est pas
## notre alliée).
##
## Algorithme : Dijkstra, puisque les cases n'ont pas toutes le même coût.
## La grille fait une centaine de cases : une file triée à la main suffit.
## À coût égal, on préfère le chemin qui fait le moins de diagonales (pas de
## zigzag), puis le premier trouvé dans l'ordre des voisins ci-dessous : le
## résultat est toujours le même.
class_name GridPathfinder
extends RefCounted

## Coût d'une case normale et d'une case de terrain difficile, debout et en
## rampant.
const NORMAL_COST := 1
const DIFFICULT_COST := 2
const CRAWL_COST := 2
const CRAWL_DIFFICULT_COST := 3

## Les huit cases voisines.
const NEIGHBOUR_OFFSETS: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
]

var _size: Vector2i
var _solid: Dictionary[Vector2i, bool] = {}
var _difficult: Dictionary[Vector2i, bool] = {}


## `blocked_cells` : décor infranchissable (obstacles et murets).
## `difficult_cells` : terrain difficile (broussailles…).
func _init(grid_size: Vector2i, blocked_cells: Array[Vector2i], difficult_cells: Array[Vector2i] = []) -> void:
	_size = grid_size
	for cell in blocked_cells:
		_solid[cell] = true
	for cell in difficult_cells:
		_difficult[cell] = true


## Distance en cases quand une diagonale coûte 1 (distance de Chebyshev).
static func chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < _size.x and cell.y < _size.y


## Décor infranchissable ?
func is_blocked(cell: Vector2i) -> bool:
	return _solid.has(cell)


## Terrain difficile du décor ? (Les créatures n'y comptent pas.)
func is_difficult(cell: Vector2i) -> bool:
	return _difficult.has(cell)


## Coût pour entrer dans `cell`. `difficult` : cases de créatures qui sont
## un terrain difficile pour celui qui se déplace. Le terrain difficile ne se
## cumule pas : une case l'est ou ne l'est pas. `crawling` : il rampe.
func step_cost(cell: Vector2i, difficult: Array[Vector2i] = [], crawling: bool = false) -> int:
	var rough := is_difficult(cell) or difficult.has(cell)
	if crawling:
		return CRAWL_DIFFICULT_COST if rough else CRAWL_COST
	return DIFFICULT_COST if rough else NORMAL_COST


## Coût total d'un chemin (sans la case de départ, comme `find_path`).
func path_cost(path: Array[Vector2i], difficult: Array[Vector2i] = [], crawling: bool = false) -> int:
	var total := 0
	for cell in path:
		total += step_cost(cell, difficult, crawling)
	return total


## Chemin le moins coûteux de `from` à `to`, sans la case de départ. Vide si
## `to` est hors grille, bloquée, occupée ou inaccessible. Le chemin peut
## passer par les cases `no_stop`, mais pas y finir.
func find_path(from: Vector2i, to: Vector2i, blocking: Array[Vector2i], no_stop: Array[Vector2i] = [], difficult: Array[Vector2i] = [], crawling: bool = false) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	if not is_inside(to) or is_blocked(to) or blocking.has(to) or no_stop.has(to) or from == to:
		return path
	var parents := _search(from, -1, blocking, difficult, crawling, to)[1] as Dictionary
	if not parents.has(to):
		return path
	var cell := to
	while cell != from:
		path.push_front(cell)
		cell = parents[cell]
	return path


## Cases où l'on peut finir un déplacement d'au plus `budget` cases, avec
## leur coût. La case de départ et les cases `no_stop` n'en font pas partie.
func reachable_cells(from: Vector2i, budget: int, blocking: Array[Vector2i], no_stop: Array[Vector2i] = [], difficult: Array[Vector2i] = [], crawling: bool = false) -> Dictionary[Vector2i, int]:
	var reachable: Dictionary[Vector2i, int] = {}
	if budget <= 0:
		return reachable
	var costs := _search(from, budget, blocking, difficult, crawling)[0] as Dictionary
	for cell: Vector2i in costs:
		if cell != from and not no_stop.has(cell):
			reachable[cell] = costs[cell]
	return reachable


## Dijkstra depuis `from`. `budget` < 0 : sans limite. S'arrête dès que
## `goal` est fixé, s'il est donné. Renvoie [coûts, parents].
func _search(from: Vector2i, budget: int, blocking: Array[Vector2i], difficult: Array[Vector2i], crawling: bool, goal := Vector2i(-1, -1)) -> Array:
	var costs: Dictionary[Vector2i, int] = {from: 0}
	var diagonals: Dictionary[Vector2i, int] = {from: 0}
	var parents: Dictionary[Vector2i, Vector2i] = {}
	var done: Dictionary[Vector2i, bool] = {}
	var open: Array[Vector2i] = [from]
	while not open.is_empty():
		# Case ouverte la moins chère ; à égalité, la première ouverte.
		var best := 0
		for i in range(1, open.size()):
			if _before(open[i], open[best], costs, diagonals):
				best = i
		var cell: Vector2i = open[best]
		open.remove_at(best)
		done[cell] = true
		if cell == goal:
			break
		for offset in NEIGHBOUR_OFFSETS:
			var next := cell + offset
			if done.has(next) or not _is_free(next, blocking):
				continue
			# Coins : seul le décor les bloque.
			if offset.x != 0 and offset.y != 0:
				if is_blocked(cell + Vector2i(offset.x, 0)) or is_blocked(cell + Vector2i(0, offset.y)):
					continue
			var cost: int = costs[cell] + step_cost(next, difficult, crawling)
			var diagonal: int = diagonals[cell] + (1 if offset.x != 0 and offset.y != 0 else 0)
			if budget >= 0 and cost > budget:
				continue
			if not costs.has(next):
				open.append(next)
			elif cost > costs[next] or (cost == costs[next] and diagonal >= diagonals[next]):
				continue
			costs[next] = cost
			diagonals[next] = diagonal
			parents[next] = cell
	return [costs, parents]


## `a` passe-t-elle avant `b` dans la file ? Moins chère, ou aussi chère
## avec moins de diagonales.
static func _before(a: Vector2i, b: Vector2i, costs: Dictionary[Vector2i, int], diagonals: Dictionary[Vector2i, int]) -> bool:
	if costs[a] != costs[b]:
		return costs[a] < costs[b]
	return diagonals[a] < diagonals[b]


func _is_free(cell: Vector2i, blocking: Array[Vector2i]) -> bool:
	return is_inside(cell) and not is_blocked(cell) and not blocking.has(cell)

## Ligne de vue sur la grille : les obstacles la bloquent.
##
## Le SRD ne définit pas la ligne de vue sur une grille. Choix du jeu (voir
## docs/rules-deviations.md) : on trace un segment entre les centres des deux
## cases ; il est bloqué s'il traverse l'intérieur d'une case obstacle. Un
## segment qui frôle seulement le coin d'un obstacle n'est pas bloqué. Les
## combattants ne bloquent jamais la vue.
class_name LineOfSight
extends RefCounted

## Marge pour qu'un segment passant pile sur un bord ou un coin ne compte
## pas comme traversant l'obstacle.
const EPSILON := 0.000001

var _blocked: Array[Vector2i] = []


func _init(blocked_cells: Array[Vector2i]) -> void:
	_blocked = blocked_cells.duplicate()


func is_clear(from: Vector2i, to: Vector2i) -> bool:
	return not crosses_any(from, to, _blocked)


## Le segment entre les centres de `from` et `to` traverse-t-il l'intérieur
## d'une des cases `cells` (hors `from` et `to`) ? Sert aussi à l'abri
## partiel (murets et créatures).
static func crosses_any(from: Vector2i, to: Vector2i, cells: Array[Vector2i]) -> bool:
	var start := Vector2(from) + Vector2(0.5, 0.5)
	var end := Vector2(to) + Vector2(0.5, 0.5)
	for cell in cells:
		if cell == from or cell == to:
			continue
		if _segment_crosses_square(start, end, cell):
			return true
	return false


## Le segment traverse-t-il l'intérieur de la case `cell` ? Méthode des
## « dalles » : on intersecte les intervalles où le segment est entre les
## deux bords verticaux, puis entre les deux bords horizontaux.
static func _segment_crosses_square(start: Vector2, end: Vector2, cell: Vector2i) -> bool:
	var low := Vector2(cell) + Vector2(EPSILON, EPSILON)
	var high := Vector2(cell) + Vector2(1.0 - EPSILON, 1.0 - EPSILON)
	var direction := end - start
	var t_min := 0.0
	var t_max := 1.0
	for axis: int in [0, 1]:
		if is_zero_approx(direction[axis]):
			if start[axis] <= low[axis] or start[axis] >= high[axis]:
				return false
			continue
		var t1 := (low[axis] - start[axis]) / direction[axis]
		var t2 := (high[axis] - start[axis]) / direction[axis]
		t_min = maxf(t_min, minf(t1, t2))
		t_max = minf(t_max, maxf(t1, t2))
		if t_min >= t_max:
			return false
	return true

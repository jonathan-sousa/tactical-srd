## Ce que l'on sait d'une case du plateau, du point de vue d'un combattant :
## sa nature (décor, terrain difficile…), ce qu'elle coûte et ce qu'elle
## bloque, et qui s'y trouve. Sert aux aides de l'interface, qui affichent
## ces faits sans les recalculer.
class_name CellInfo
extends RefCounted

enum Terrain {
	## Hors du plateau.
	OUTSIDE,
	## Terrain normal (herbe).
	OPEN,
	## Terrain difficile (broussailles) : 2 cases de déplacement.
	DIFFICULT,
	## Muret : infranchissable, on voit par-dessus, abri partiel.
	LOW_WALL,
	## Obstacle (arbre, buisson) : infranchissable, bloque la vue (abri total).
	OBSTACLE,
}

var cell: Vector2i
var terrain: Terrain = Terrain.OPEN
## Coût pour y entrer, en cases (0 si on ne peut pas y entrer).
var movement_cost: int = 0
var blocks_movement: bool = false
var blocks_sight: bool = false
## Abri que la case donne à qui est derrière elle (muret : +2).
var cover_bonus: int = 0
## Combattant vivant que l'observateur sait sur cette case, ou `null` (un
## ennemi caché de lui n'y figure pas).
var occupant: Combatant = null


static func of(state: CombatState, p_cell: Vector2i, observer: Combatant) -> CellInfo:
	var info := CellInfo.new()
	info.cell = p_cell
	if not state.pathfinder.is_inside(p_cell):
		info.terrain = Terrain.OUTSIDE
		info.blocks_movement = true
		return info
	if state.encounter.blocked_cells.has(p_cell):
		info.terrain = Terrain.OBSTACLE
		info.blocks_movement = true
		info.blocks_sight = true
	elif state.encounter.low_walls.has(p_cell):
		info.terrain = Terrain.LOW_WALL
		info.blocks_movement = true
		info.cover_bonus = CombatState.HALF_COVER_BONUS
	elif state.is_difficult_terrain(p_cell):
		info.terrain = Terrain.DIFFICULT
	if not info.blocks_movement:
		info.movement_cost = state.pathfinder.step_cost(p_cell)
	var occupant := state.combatant_at(p_cell)
	if occupant != null and not state.is_hidden_from(occupant, observer):
		info.occupant = occupant
	return info


## La case a-t-elle une règle à expliquer ? Une case d'herbe libre n'en a
## pas : l'interface n'affiche alors rien.
func has_rule() -> bool:
	return terrain != Terrain.OPEN and terrain != Terrain.OUTSIDE

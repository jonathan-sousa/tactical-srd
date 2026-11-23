## Déplacement vers une case, par le plus court chemin, dans la limite du
## déplacement restant. Peut être fractionné avant et après l'attaque.
## Quitter l'allonge d'un ennemi peut provoquer une attaque d'opportunité.
class_name MoveAction
extends Action

var destination: Vector2i


func _init(p_actor: Combatant, p_destination: Vector2i) -> void:
	super(p_actor)
	destination = p_destination


func _validate(state: CombatState) -> StringName:
	if destination == actor.position:
		return SAME_CELL
	var path := state.find_path(actor, destination)
	if path.is_empty():
		return CELL_UNREACHABLE
	if path.size() > state.movement_left:
		return NOT_ENOUGH_MOVEMENT
	return &""


## Le déplacement se fait case par case : il peut s'arrêter en chemin sur
## une fenêtre de réaction (attaque d'opportunité), puis reprendre.
func _execute(state: CombatState, _dice: Dice) -> Array[CombatEvent]:
	return state.walk(actor, state.find_path(actor, destination))

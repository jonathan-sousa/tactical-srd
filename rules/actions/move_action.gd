## Déplacement vers une case, par le plus court chemin, dans la limite du
## déplacement restant. Peut être fractionné avant et après l'attaque.
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


func _execute(state: CombatState, _dice: Dice) -> Array[CombatEvent]:
	var from := actor.position
	var path := state.find_path(actor, destination)
	actor.position = destination
	state.movement_left -= path.size()
	return [MovedEvent.new(actor, from, path)]

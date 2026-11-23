## Un combattant a pris une action sans jet de dés (Foncer, Se désengager,
## Esquiver). `action` est l'un des codes de StandardAction.
class_name ActionTakenEvent
extends CombatEvent

var combatant: Combatant
var action: StringName


func _init(p_combatant: Combatant, p_action: StringName) -> void:
	combatant = p_combatant
	action = p_action

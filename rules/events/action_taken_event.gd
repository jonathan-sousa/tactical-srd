## Un combattant a pris une action sans jet de dés (Foncer, Se désengager,
## Esquiver). `action` est l'un des codes de StandardAction.
class_name ActionTakenEvent
extends CombatEvent

var combatant: Combatant
var action: StringName
## Par une action bonus (Nimble Escape du Gobelin) plutôt qu'une action.
var bonus_action: bool


func _init(p_combatant: Combatant, p_action: StringName, p_bonus_action: bool = false) -> void:
	combatant = p_combatant
	action = p_action
	bonus_action = p_bonus_action

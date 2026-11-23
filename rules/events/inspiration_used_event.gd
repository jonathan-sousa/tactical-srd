## Un combattant a dépensé son Inspiration héroïque pour relancer un d20.
## L'attaque relancée suit dans un AttackRolledEvent.
class_name InspirationUsedEvent
extends CombatEvent

var combatant: Combatant
## Dé remplacé et nouveau dé.
var old_value: int
var new_value: int


func _init(p_combatant: Combatant, p_old_value: int, p_new_value: int) -> void:
	combatant = p_combatant
	old_value = p_old_value
	new_value = p_new_value

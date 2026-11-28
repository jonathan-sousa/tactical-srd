## Un combattant a tenté de se cacher (action Se cacher) : jet de Dextérité
## (Discrétion) contre DD 15.
class_name HideAttemptedEvent
extends CombatEvent

var combatant: Combatant
var d20: int
var bonus: int
var total: int
var success: bool
## Par une action bonus (Nimble Escape du Gobelin) plutôt qu'une action.
var bonus_action: bool
## Un 1 a été relancé grâce à la Chance du Halfelin (`d20` est le nouveau jet).
var lucky: bool = false


func _init(p_combatant: Combatant, p_d20: int, p_bonus: int, p_success: bool, p_bonus_action: bool) -> void:
	combatant = p_combatant
	d20 = p_d20
	bonus = p_bonus
	total = p_d20 + p_bonus
	success = p_success
	bonus_action = p_bonus_action

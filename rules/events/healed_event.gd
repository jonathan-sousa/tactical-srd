## Un combattant a regagné des PV (Second Wind).
class_name HealedEvent
extends CombatEvent

var combatant: Combatant
## PV réellement rendus (le jet peut dépasser le maximum).
var amount: int
var roll: DiceRoll
var hp_after: int


func _init(p_combatant: Combatant, p_amount: int, p_roll: DiceRoll, p_hp_after: int) -> void:
	combatant = p_combatant
	amount = p_amount
	roll = p_roll
	hp_after = p_hp_after

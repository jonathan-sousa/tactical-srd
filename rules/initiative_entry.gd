## Une ligne de l'ordre d'initiative : qui, et avec quel jet.
class_name InitiativeEntry
extends RefCounted

var combatant: Combatant
## Dé retenu.
var d20: int
## Jet complet, avec ses deux dés en cas d'avantage ou de désavantage.
var roll: D20Roll
var bonus: int
var total: int


func _init(p_combatant: Combatant, p_roll: D20Roll, p_bonus: int) -> void:
	combatant = p_combatant
	roll = p_roll
	d20 = p_roll.natural
	bonus = p_bonus
	total = d20 + p_bonus

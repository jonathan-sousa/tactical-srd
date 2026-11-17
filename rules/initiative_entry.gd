## Une ligne de l'ordre d'initiative : qui, et avec quel jet.
class_name InitiativeEntry
extends RefCounted

var combatant: Combatant
var d20: int
var bonus: int
var total: int


func _init(p_combatant: Combatant, p_d20: int, p_bonus: int) -> void:
	combatant = p_combatant
	d20 = p_d20
	bonus = p_bonus
	total = p_d20 + p_bonus

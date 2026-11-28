## Action Aider sur un allié mourant : test de Sagesse (Médecine) DD 10.
## Réussi, l'allié est stabilisé : il reste inconscient à 0 PV, sans jet
## contre la mort.
class_name StabilizeAttemptedEvent
extends CombatEvent

var helper: Combatant
var patient: Combatant
var d20: int
var bonus: int
var total: int
var success: bool
## Un 1 a été relancé grâce à la Chance du Halfelin (`d20` est le nouveau jet).
var lucky: bool = false


func _init(p_helper: Combatant, p_patient: Combatant, p_d20: int, p_bonus: int, p_success: bool) -> void:
	helper = p_helper
	patient = p_patient
	d20 = p_d20
	bonus = p_bonus
	total = p_d20 + p_bonus
	success = p_success

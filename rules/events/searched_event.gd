## Un combattant a pris l'action Chercher : test de Sagesse (Perception)
## contre le jet de Discrétion de chaque ennemi caché.
class_name SearchedEvent
extends CombatEvent

var combatant: Combatant
var d20: int
var bonus: int
var total: int
## Ennemis trouvés, et le DD de chacun (le total de son jet de Discrétion).
var found: Array[Combatant] = []
var found_dcs: Array[int] = []
## Un 1 a été relancé grâce à la Chance du Halfelin (`d20` est le nouveau jet).
var lucky: bool = false


func _init(p_combatant: Combatant, p_d20: int, p_bonus: int) -> void:
	combatant = p_combatant
	d20 = p_d20
	bonus = p_bonus
	total = p_d20 + p_bonus

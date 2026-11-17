## Un combattant s'est déplacé de `from` en suivant `path` (case de départ
## exclue, dernière case = arrivée).
class_name MovedEvent
extends CombatEvent

var combatant: Combatant
var from: Vector2i
var path: Array[Vector2i]


func _init(p_combatant: Combatant, p_from: Vector2i, p_path: Array[Vector2i]) -> void:
	combatant = p_combatant
	from = p_from
	path = p_path

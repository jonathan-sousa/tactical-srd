## Un combattant s'est déplacé de `from` en suivant `path` (case de départ
## exclue, dernière case = arrivée).
class_name MovedEvent
extends CombatEvent

var combatant: Combatant
var from: Vector2i
var path: Array[Vector2i]
## Déplacement d'un combattant caché : ses ennemis ne le voient pas.
var unseen: bool


func _init(p_combatant: Combatant, p_from: Vector2i, p_path: Array[Vector2i], p_unseen: bool = false) -> void:
	combatant = p_combatant
	from = p_from
	path = p_path
	unseen = p_unseen

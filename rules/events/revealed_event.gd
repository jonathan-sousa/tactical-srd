## Un combattant caché ne l'est plus : il a attaqué, ou un ennemi l'a trouvé.
## `cell` est la case où il se trouvait à ce moment-là.
class_name RevealedEvent
extends CombatEvent

## Il a fait un jet d'attaque : sa position est révélée.
const ATTACKED := &"attacked"
## Un ennemi l'a trouvé (action Chercher).
const FOUND := &"found"

var combatant: Combatant
var cell: Vector2i
var reason: StringName


func _init(p_combatant: Combatant, p_cell: Vector2i, p_reason: StringName) -> void:
	combatant = p_combatant
	cell = p_cell
	reason = p_reason

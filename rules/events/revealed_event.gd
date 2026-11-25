## Un combattant caché ne l'est plus : il a attaqué, ou un ennemi l'a trouvé.
## `cell` est la case où il se trouvait à ce moment-là.
class_name RevealedEvent
extends CombatEvent

## Il a fait un jet d'attaque : sa position est révélée.
const ATTACKED := &"attacked"
## Un ennemi l'a trouvé avec l'action Chercher.
const FOUND := &"found"
## Un ennemi conscient a une vue dégagée sur lui : à la fin du tour du
## caché, à la fin du déplacement de l'ennemi, ou quand l'ennemi reprend
## connaissance.
const SEEN := &"seen"
## Un ennemi l'a remarqué en train de se déplacer à découvert, grâce à sa
## Perception passive.
const NOTICED := &"noticed"
## Un ennemi est entré dans sa case sans le savoir et l'a heurté.
const BUMPED := &"bumped"

var combatant: Combatant
var cell: Vector2i
var reason: StringName
## L'ennemi qui l'a trouvé (`null` s'il s'est révélé en attaquant).
var observer: Combatant


func _init(p_combatant: Combatant, p_cell: Vector2i, p_reason: StringName, p_observer: Combatant = null) -> void:
	combatant = p_combatant
	cell = p_cell
	reason = p_reason
	observer = p_observer

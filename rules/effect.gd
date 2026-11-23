## Effet temporaire sur un combattant : esquive, désengagement…
##
## Le SRD donne à chaque effet une durée liée au tour d'un combattant
## précis (« jusqu'au début de ton prochain tour », « pour le reste du tour
## en cours »). `source` est ce combattant, `expiry` le moment où l'effet
## prend fin. CombatState retire les effets échus à chaque changement de tour.
##
## Les effets sont rangés dans CombatState, pas dans Combatant : un effet
## sur soi-même (Esquiver) créerait sinon un cycle combattant → effet →
## combattant, que le comptage de références de Godot ne libère jamais.
class_name Effect
extends RefCounted

## Action Esquiver : les attaques contre ce combattant ont le désavantage
## s'il voit l'attaquant, jusqu'au début de son prochain tour.
const DODGING := &"dodging"
## Action Se désengager : ses déplacements ne provoquent pas d'attaque
## d'opportunité pour le reste du tour.
const DISENGAGED := &"disengaged"

enum Expiry {
	## Au début du prochain tour de `source`.
	START_OF_SOURCE_TURN,
	## À la fin du tour en cours de `source`.
	END_OF_SOURCE_TURN,
}

var id: StringName
## Combattant qui subit l'effet.
var target: Combatant
## Combattant dont le tour fixe la fin de l'effet.
var source: Combatant
var expiry: Expiry


func _init(p_id: StringName, p_target: Combatant, p_source: Combatant, p_expiry: Expiry) -> void:
	id = p_id
	target = p_target
	source = p_source
	expiry = p_expiry

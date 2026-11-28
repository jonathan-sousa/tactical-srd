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
## Maîtrise Sap : désavantage à sa prochaine attaque, avant le début du
## prochain tour de celui qui l'a touché.
const SAPPED := &"sapped"
## Maîtrise Slow : vitesse réduite de 10 ft jusqu'au début du prochain tour
## de celui qui l'a touché. Ne se cumule pas.
const SLOWED := &"slowed"
## Action Se cacher réussie : condition Invisible tant qu'on reste caché.
## `value` garde le total du jet de Discrétion, le DD pour le trouver.
const HIDDEN := &"hidden"
## Condition À terre (Prone) : ramper ou se relever, attaques affectées.
const PRONE := &"prone"
## Maîtrise Vex : `source` a l'avantage à sa prochaine attaque contre ce
## combattant, avant la fin de son prochain tour.
const VEXED := &"vexed"
## Action Aider : distrait par `source`. La prochaine attaque d'un allié de
## `source` contre ce combattant a l'avantage, jusqu'au début du prochain
## tour de `source`.
const HELPED := &"helped"

enum Expiry {
	## Au début du prochain tour de `source`.
	START_OF_SOURCE_TURN,
	## À la fin du tour en cours de `source`.
	END_OF_SOURCE_TURN,
	## À la fin du prochain tour de `source` : à la fin du tour en cours,
	## l'effet passe à END_OF_SOURCE_TURN.
	END_OF_SOURCE_NEXT_TURN,
	## Jamais d'elle-même : une règle la retire (trouvé, relevé…).
	UNTIL_REMOVED,
}

var id: StringName
## Combattant qui subit l'effet.
var target: Combatant
## Combattant dont le tour fixe la fin de l'effet.
var source: Combatant
var expiry: Expiry
## Valeur propre à l'effet (DD d'une cachette), 0 sinon.
var value: int


func _init(p_id: StringName, p_target: Combatant, p_source: Combatant, p_expiry: Expiry, p_value: int = 0) -> void:
	id = p_id
	target = p_target
	source = p_source
	expiry = p_expiry
	value = p_value

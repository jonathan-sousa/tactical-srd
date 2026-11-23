## Fenêtre de réaction : un déplacement est suspendu parce qu'il ferait
## sortir `mover` de l'allonge de `reactor`, qui peut faire une attaque
## d'opportunité (SRD : « right before the creature leaves your reach »).
##
## Tant qu'elle est ouverte, seules les actions de réaction de `reactor` sont
## possibles. Une fois la réaction décidée, le déplacement reprend sur
## `remaining_path`.
class_name ReactionWindow
extends PendingDecision

var reactor: Combatant
var mover: Combatant
## Cases qu'il reste à parcourir, la prochaine en premier.
var remaining_path: Array[Vector2i] = []
## Combattants déjà sollicités pour le pas en cours : ils ne le sont pas une
## seconde fois quand le déplacement reprend.
var asked: Array[Combatant] = []


func _init(p_reactor: Combatant, p_mover: Combatant, p_remaining_path: Array[Vector2i], p_asked: Array[Combatant]) -> void:
	reactor = p_reactor
	decider = p_reactor
	mover = p_mover
	remaining_path = p_remaining_path
	asked = p_asked

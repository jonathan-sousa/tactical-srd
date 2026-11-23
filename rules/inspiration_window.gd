## Jet d'attaque raté d'un combattant qui a l'Inspiration héroïque : il peut
## relancer le d20 (SRD « Heroic Inspiration ») avant que l'attaque ne se
## termine. Si l'attaque était une attaque d'opportunité, le déplacement de
## la cible reprend ensuite (`resume`).
class_name InspirationWindow
extends PendingDecision

var result: AttackResult
## Déplacement à reprendre après l'attaque, ou `null`.
var resume: ReactionWindow


func _init(p_result: AttackResult, p_resume: ReactionWindow) -> void:
	result = p_result
	decider = p_result.attacker
	resume = p_resume

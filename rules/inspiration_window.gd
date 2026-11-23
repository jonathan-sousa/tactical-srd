## Un d20 raté d'un combattant qui a l'Inspiration héroïque : il peut le
## relancer (SRD « Heroic Inspiration ») avant que la suite ne se joue.
##
## Deux cas dans le jeu : une attaque ratée (`result`), et un jet contre la
## mort raté (`death_save`). Si l'attaque était une attaque d'opportunité,
## le déplacement de la cible reprend ensuite (`resume`).
class_name InspirationWindow
extends PendingDecision

## Attaque ratée, ou `null` pour un jet contre la mort.
var result: AttackResult
## d20 du jet contre la mort raté, ou 0 pour une attaque.
var death_save: int = 0
## Déplacement à reprendre après l'attaque, ou `null`.
var resume: ReactionWindow


func _init(p_decider: Combatant) -> void:
	decider = p_decider


static func for_attack(p_result: AttackResult, p_resume: ReactionWindow) -> InspirationWindow:
	var window := InspirationWindow.new(p_result.attacker)
	window.result = p_result
	window.resume = p_resume
	return window


static func for_death_save(p_decider: Combatant, natural: int) -> InspirationWindow:
	var window := InspirationWindow.new(p_decider)
	window.death_save = natural
	return window


## d20 qu'on peut relancer.
func failed_roll() -> int:
	return death_save if result == null else result.d20.natural

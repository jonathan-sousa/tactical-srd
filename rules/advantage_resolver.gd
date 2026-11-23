## Avantage et désavantage d'une attaque (SRD 5.2.1, « Advantage/Disadvantage »).
##
## Le résolveur rassemble toutes les sources, puis applique la règle : les
## sources ne se cumulent pas (deux d20 au plus) et un avantage annule un
## désavantage, quel que soit le nombre de chaque côté.
##
## Chaque nouvelle source (maîtrise Sap, cible inconsciente, tir au
## contact…) s'ajoute ici, au même endroit, avec son code de raison.
class_name AdvantageResolver
extends RefCounted

## La cible esquive (action Esquiver) et voit l'attaquant.
const TARGET_DODGING := &"target_dodging"


static func for_attack(state: CombatState, attacker: Combatant, target: Combatant, _weapon: WeaponDef) -> AdvantageResult:
	var result := AdvantageResult.new()
	if state.has_effect(target, Effect.DODGING) and state.can_see(target, attacker):
		result.disadvantages.append(TARGET_DODGING)
	result.mode = combine(result.advantages.size(), result.disadvantages.size())
	return result


## Règle du SRD : au moins un avantage et au moins un désavantage
## s'annulent ; sinon, un seul des deux s'applique, une seule fois.
static func combine(advantage_count: int, disadvantage_count: int) -> Dice.RollMode:
	if advantage_count > 0 and disadvantage_count == 0:
		return Dice.RollMode.ADVANTAGE
	if disadvantage_count > 0 and advantage_count == 0:
		return Dice.RollMode.DISADVANTAGE
	return Dice.RollMode.NORMAL

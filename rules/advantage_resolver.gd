## Avantage et désavantage d'une attaque (SRD 5.2.1, « Advantage/Disadvantage »).
##
## Le résolveur rassemble toutes les sources, puis applique la règle : les
## sources ne se cumulent pas (deux d20 au plus) et un avantage annule un
## désavantage, quel que soit le nombre de chaque côté.
##
## Chaque nouvelle source s'ajoute ici, au même endroit, avec son code de
## raison.
class_name AdvantageResolver
extends RefCounted

## La cible esquive (action Esquiver) et voit l'attaquant.
const TARGET_DODGING := &"target_dodging"
## L'attaquant a été touché par une arme à maîtrise Sap.
const ATTACKER_SAPPED := &"attacker_sapped"
## Attaque à distance au-delà de la portée normale.
const LONG_RANGE := &"long_range"
## Attaque à distance avec un ennemi au contact qui voit l'attaquant.
const HOSTILE_NEARBY := &"hostile_nearby"
## L'attaquant est caché : la cible ne le voit pas (condition Invisible).
const ATTACKER_HIDDEN := &"attacker_hidden"
## L'attaquant ne voit pas la cible, cachée : il vise une case à l'aveugle.
const TARGET_UNSEEN := &"target_unseen"
## La cible est inconsciente (à 0 PV).
const TARGET_UNCONSCIOUS := &"target_unconscious"
## La cible est à terre et l'attaquant à 5 ft (avantage) ou plus loin
## (désavantage).
const TARGET_PRONE := &"target_prone"
const TARGET_PRONE_FAR := &"target_prone_far"
## L'attaquant est à terre.
const ATTACKER_PRONE := &"attacker_prone"


static func for_attack(state: CombatState, attacker: Combatant, target: Combatant, weapon: WeaponDef) -> AdvantageResult:
	var result := AdvantageResult.new()
	if state.is_hidden_from(attacker, target):
		result.advantages.append(ATTACKER_HIDDEN)
	if state.is_hidden_from(target, attacker):
		result.disadvantages.append(TARGET_UNSEEN)
	if target.is_down():
		result.advantages.append(TARGET_UNCONSCIOUS)
	if state.has_effect(target, Effect.PRONE):
		if state.distance_feet(attacker, target) <= CombatState.FEET_PER_SQUARE:
			result.advantages.append(TARGET_PRONE)
		else:
			result.disadvantages.append(TARGET_PRONE_FAR)
	if state.has_effect(attacker, Effect.PRONE):
		result.disadvantages.append(ATTACKER_PRONE)
	# Esquiver ne protège que si la cible voit l'attaquant, et pas si elle
	# est neutralisée.
	if state.has_effect(target, Effect.DODGING) and state.can_see(target, attacker):
		result.disadvantages.append(TARGET_DODGING)
	if state.has_effect(attacker, Effect.SAPPED):
		result.disadvantages.append(ATTACKER_SAPPED)
	if state.attack_kind(attacker, target, weapon) == CombatState.AttackKind.RANGED:
		if state.distance_feet(attacker, target) > weapon.range_normal_feet:
			result.disadvantages.append(LONG_RANGE)
		if not state.hostiles_next_to(attacker).is_empty():
			result.disadvantages.append(HOSTILE_NEARBY)
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

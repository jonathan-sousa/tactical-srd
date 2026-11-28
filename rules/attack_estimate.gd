## Prévision d'une attaque, avant de la lancer : chances de toucher, dégâts
## possibles, avantage ou désavantage. Sert aux aides de survol ; la
## présentation affiche ces nombres sans rien recalculer.
##
## Fonction pure : aucun dé n'est lancé, rien n'est modifié.
class_name AttackEstimate
extends RefCounted

## Chance de toucher, de 0.0 à 1.0 (20 naturel toujours touché, 1 naturel
## toujours raté).
var hit_chance: float
## Chance d'un coup critique, de 0.0 à 1.0.
var critical_chance: float
## Dégâts d'une touche, du plus petit au plus grand jet. Contre une cible
## inconsciente au contact, toute touche est critique : ce sont alors les
## dégâts d'un critique.
var damage_min: int
var damage_max: int
## Dégâts de la maîtrise Graze sur un échec, 0 sinon.
var graze_damage: int
## Bonus d'abri de la cible (0 ou +2), compté dans `hit_chance`.
var cover_bonus: int
## L'Attaque sournoise s'ajouterait sur une touche (comptée dans les dégâts).
var sneak_attack: bool
var advantage: AdvantageResult


## `off_hand` : attaque de la main libre, sans modificateur aux dégâts.
static func of(state: CombatState, attacker: Combatant, target: Combatant, weapon: WeaponDef, off_hand: bool = false) -> AttackEstimate:
	var estimate := AttackEstimate.new()
	estimate.advantage = AdvantageResolver.for_attack(state, attacker, target, weapon)
	var mode := estimate.advantage.mode
	estimate.cover_bonus = state.cover_bonus(attacker, target)
	var single := _single_hit_chance(attacker.attack_bonus(weapon), target.armor_class() + estimate.cover_bonus)
	estimate.hit_chance = _with_mode(single, mode)
	var always_critical := AttackSequence.critical_on_hit(state, attacker, target)
	estimate.critical_chance = estimate.hit_chance if always_critical else _with_mode(1.0 / 20.0, mode)

	var is_ranged := state.attack_kind(attacker, target, weapon) == CombatState.AttackKind.RANGED
	var gwf := AttackSequence.uses_great_weapon_fighting(attacker, weapon, is_ranged)
	var dice := DiceExpression.parse(weapon.damage_dice)
	var count := dice.count * (2 if always_critical else 1)
	var lowest_die := mini(AttackResolver.GREAT_WEAPON_FIGHTING_MINIMUM, dice.sides) if gwf else 1
	var modifier := attacker.damage_modifier(weapon)
	if off_hand:
		modifier = mini(modifier, 0)
	estimate.damage_min = count * lowest_die + modifier
	estimate.damage_max = count * dice.sides + modifier

	var extra_text := attacker.definition.advantage_damage_dice
	if mode == Dice.RollMode.ADVANTAGE and not extra_text.is_empty():
		var extra := DiceExpression.parse(extra_text)
		var extra_count := extra.count * (2 if always_critical else 1)
		estimate.damage_min += extra_count
		estimate.damage_max += extra_count * extra.sides
	estimate.sneak_attack = AttackSequence.sneak_attack_applies(state, attacker, target, weapon, mode)
	if estimate.sneak_attack:
		var sneak := DiceExpression.parse(attacker.definition.sneak_attack_dice)
		var sneak_count := sneak.count * (2 if always_critical else 1)
		estimate.damage_min += sneak_count
		estimate.damage_max += sneak_count * sneak.sides
	estimate.damage_min = maxi(estimate.damage_min, 0)
	estimate.damage_max = maxi(estimate.damage_max, 0)

	if attacker.definition.masters(weapon) and weapon.mastery == WeaponDef.GRAZE:
		estimate.graze_damage = maxi(modifier, 0)
	return estimate


## Chance de toucher sur un seul d20.
static func _single_hit_chance(attack_bonus: int, armor_class: int) -> float:
	var hits := 1
	for natural in range(2, 20):
		if natural + attack_bonus >= armor_class:
			hits += 1
	return hits / 20.0


## Deux d20 : au moins un réussit (avantage), ou les deux (désavantage).
static func _with_mode(single: float, mode: Dice.RollMode) -> float:
	match mode:
		Dice.RollMode.ADVANTAGE:
			return 1.0 - (1.0 - single) * (1.0 - single)
		Dice.RollMode.DISADVANTAGE:
			return single * single
	return single

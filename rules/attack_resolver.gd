## Résolution d'un jet d'attaque et de ses dégâts (SRD 5.2.1).
##
## Fonctions pures : elles calculent un résultat sans toucher aux PV. Le
## déroulé complet d'une attaque (dégâts appliqués, maîtrises, relance) est
## dans AttackSequence.
class_name AttackResolver
extends RefCounted

## Great Weapon Fighting : un 1 ou un 2 sur un dé de dégâts compte comme 3.
const GREAT_WEAPON_FIGHTING_MINIMUM := 3


## Attaque complète sans capacité particulière : jet d'attaque, puis dégâts
## si elle touche.
static func resolve(
	attacker: Combatant,
	target: Combatant,
	weapon: WeaponDef,
	dice: Dice,
	mode: Dice.RollMode = Dice.RollMode.NORMAL,
) -> AttackResult:
	var result := roll_attack(attacker, target, weapon, dice, mode)
	if result.is_hit:
		roll_damage(result, dice)
	return result


## Jet d'attaque seul : d20, total, touché ou raté. Pas de dégâts.
## `critical_on_hit` : toute touche est un coup critique.
static func roll_attack(
	attacker: Combatant,
	target: Combatant,
	weapon: WeaponDef,
	dice: Dice,
	mode: Dice.RollMode = Dice.RollMode.NORMAL,
	critical_on_hit: bool = false,
) -> AttackResult:
	var result := AttackResult.new()
	result.attacker = attacker
	result.target = target
	result.weapon = weapon
	result.damage_type = weapon.damage_type
	result.critical_on_hit = critical_on_hit
	# Jet d'attaque : d20 + modificateur de caractéristique + maîtrise.
	result.attack_bonus = attacker.attack_bonus(weapon)
	result.target_armor_class = target.armor_class()
	_apply_d20(result, dice.roll_d20(mode))
	return result


## Même attaque avec un autre d20 (relance de l'Inspiration héroïque).
static func with_d20(previous: AttackResult, d20: D20Roll) -> AttackResult:
	var result := AttackResult.new()
	result.attacker = previous.attacker
	result.target = previous.target
	result.weapon = previous.weapon
	result.damage_type = previous.damage_type
	result.attack_bonus = previous.attack_bonus
	result.target_armor_class = previous.target_armor_class
	result.advantage = previous.advantage
	result.is_opportunity = previous.is_opportunity
	result.is_ranged = previous.is_ranged
	result.critical_on_hit = previous.critical_on_hit
	_apply_d20(result, d20)
	return result


## Dégâts d'une attaque qui touche : dés de l'arme + modificateur. Au
## critique, seuls les dés sont doublés. Avec Savage Attacker, les dés de
## l'arme sont lancés deux fois et le meilleur total est gardé. Si le jet
## d'attaque avait l'avantage, les dés de `advantage_damage_dice` de
## l'attaquant s'ajoutent (doublés eux aussi au critique).
static func roll_damage(result: AttackResult, dice: Dice, great_weapon_fighting: bool = false, savage_attacker: bool = false) -> void:
	var weapon_dice := DiceExpression.parse(result.weapon.damage_dice)
	assert(weapon_dice != null, "Dés de dégâts invalides pour %s : %s" % [result.weapon.id, result.weapon.damage_dice])
	var expression := weapon_dice.with_modifier(result.attacker.damage_modifier(result.weapon))
	if result.is_critical:
		expression = expression.with_doubled_dice()

	result.great_weapon_fighting = great_weapon_fighting
	var roll := _roll_weapon_dice(expression, dice, great_weapon_fighting)
	if savage_attacker:
		var second := _roll_weapon_dice(expression, dice, great_weapon_fighting)
		if second.total > roll.total:
			result.discarded_damage_roll = roll
			roll = second
		else:
			result.discarded_damage_roll = second
	result.damage_roll = roll
	result.damage = maxi(roll.total, 0)

	var extra_text := result.attacker.definition.advantage_damage_dice
	if not extra_text.is_empty() and result.d20.mode == Dice.RollMode.ADVANTAGE:
		var extra := DiceExpression.parse(extra_text)
		assert(extra != null, "Dés invalides pour %s : %s" % [result.attacker.definition.id, extra_text])
		if result.is_critical:
			extra = extra.with_doubled_dice()
		result.advantage_damage_roll = dice.roll(extra)
		result.damage += result.advantage_damage_roll.total


static func _apply_d20(result: AttackResult, d20: D20Roll) -> void:
	result.d20 = d20
	result.attack_total = d20.natural + result.attack_bonus
	# 20 naturel : touché automatique et critique. 1 naturel : raté
	# automatique. Sinon, touché si le total atteint la CA.
	if d20.is_natural_20():
		result.is_hit = true
	elif d20.is_natural_1():
		result.is_hit = false
	else:
		result.is_hit = result.attack_total >= result.target_armor_class
	result.is_critical = d20.is_natural_20() or (result.is_hit and result.critical_on_hit)


static func _roll_weapon_dice(expression: DiceExpression, dice: Dice, great_weapon_fighting: bool) -> DiceRoll:
	var roll := dice.roll(expression)
	if not great_weapon_fighting:
		return roll
	var adjusted: Array[int] = []
	for value in roll.rolls:
		adjusted.append(maxi(value, GREAT_WEAPON_FIGHTING_MINIMUM))
	return DiceRoll.new(expression, adjusted, roll.rolls)

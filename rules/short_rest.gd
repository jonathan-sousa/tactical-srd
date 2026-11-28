## Repos court (SRD « Short Rest »), entre deux combats de l'histoire.
##
## - Dés de vie : un personnage blessé dépense un dé de vie s'il lui en reste.
##   Il lance le dé de sa classe et ajoute son modificateur de Constitution :
##   il regagne ce total, au moins 1 PV. Au niveau 1, on n'a qu'un dé de vie,
##   et il ne revient qu'au repos long, absent du jeu.
## - Second Wind : une utilisation dépensée revient.
##
## Écart (docs/rules-deviations.md) : le dé de vie est dépensé d'office dès
## qu'on est blessé ; le SRD laisse le choix.
class_name ShortRest
extends RefCounted


## Repos court d'un personnage. Modifie `member` et renvoie ce qui a changé.
static func take(member: PartyMember, definition: CharacterDef, dice: Dice) -> ShortRestResult:
	var result := ShortRestResult.new()
	result.member_id = member.id
	if member.hp < definition.max_hp and member.hit_dice > 0:
		member.hit_dice -= 1
		result.hit_die_roll = dice.roll_die(definition.hit_die)
		var total := maxi(result.hit_die_roll + Abilities.modifier(definition.constitution), 1)
		var before := member.hp
		member.hp = mini(member.hp + total, definition.max_hp)
		result.healed = member.hp - before
	if member.second_wind_uses < definition.second_wind_uses:
		member.second_wind_uses += 1
		result.second_wind_regained = true
	return result

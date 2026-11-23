## Ordre d'initiative : d20 + bonus d'initiative de la fiche, du plus haut au
## plus bas. `modes` donne l'avantage (caché, donc Invisible) ou le
## désavantage (surpris) de certains combattants.
##
## Égalité : le camp du joueur passe d'abord (choix du brief, voir
## docs/rules-deviations.md), puis l'ordre de la liste fournie.
class_name Initiative
extends RefCounted


static func roll_order(
	combatants: Array[Combatant],
	dice: Dice,
	modes: Dictionary[Combatant, Dice.RollMode] = {},
) -> Array[InitiativeEntry]:
	var entries: Array[InitiativeEntry] = []
	for combatant in combatants:
		var roll := dice.roll_d20(modes.get(combatant, Dice.RollMode.NORMAL))
		entries.append(InitiativeEntry.new(combatant, roll, combatant.definition.initiative_bonus))

	# sort_custom n'est pas un tri stable : on garde la position d'origine
	# pour départager deux combattants du même camp à égalité.
	var original_index: Dictionary[InitiativeEntry, int] = {}
	for i in entries.size():
		original_index[entries[i]] = i

	entries.sort_custom(func(a: InitiativeEntry, b: InitiativeEntry) -> bool:
		if a.total != b.total:
			return a.total > b.total
		var a_is_player := a.combatant.side == Combatant.Side.PLAYER
		var b_is_player := b.combatant.side == Combatant.Side.PLAYER
		if a_is_player != b_is_player:
			return a_is_player
		return original_index[a] < original_index[b]
	)
	return entries

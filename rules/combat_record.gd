## Enregistrement d'un combat : la graine des dés, la situation de départ et
## chaque choix du joueur, dans l'ordre. Le reste (IA, dés) est déterministe :
## rejouer ces choix avec la même graine redonne exactement le même combat.
##
## Sert de rapport de bug : le fichier JSON suffit à reproduire une partie.
## C'est aussi la base d'une future sauvegarde en plein combat.
##
## Lu depuis `user://`, le fichier est du JSON validé champ par champ, jamais
## une Resource : un fichier modifié à la main ne peut rien exécuter.
class_name CombatRecord
extends RefCounted

## v2 : un groupe de personnages (`party`). Un enregistrement v1, d'avant
## les groupes, se lit encore : un groupe d'un seul Guerrier.
const VERSION := 2

# Types de choix enregistrés.
const MOVE := "move"
const ATTACK := "attack"
const STANDARD := "standard"
const SECOND_WIND := "second_wind"
const SEARCH := "search"
const STAND_UP := "stand_up"
const HIDE := "hide"
const END_TURN := "end_turn"
const OPPORTUNITY_ATTACK := "opportunity_attack"
const DECLINE_REACTION := "decline_reaction"
const USE_INSPIRATION := "use_inspiration"
const DECLINE_INSPIRATION := "decline_inspiration"
const SWAP_INITIATIVE := "swap_initiative"
const DECLINE_SWAP := "decline_swap"
const HELP := "help"

var seed_value: int = 0
var encounter_id: StringName
## Situation des personnages au début du combat (elle dépend de l'histoire),
## dans l'ordre du groupe.
var party: Array[PartyMember] = []
## Choix du joueur, tous personnages confondus, encodés par `encode`. Le
## personnage qui joue un choix est celui dont c'est le tour, ou celui qui
## doit répondre à une décision : on ne l'écrit pas.
var entries: Array[Dictionary] = []
## Résultat constaté à la fin du combat, vide tant qu'il n'est pas fini :
## {"winner": int, "round": int, "hp": [int, …]}.
var outcome: Dictionary = {}


## Résultat d'un combat terminé, dans le format de `outcome`.
static func outcome_of(state: CombatState) -> Dictionary:
	var hp: Array[int] = []
	for combatant in state.combatants:
		hp.append(combatant.hp)
	return {"winner": int(state.winner), "round": state.round, "hp": hp}


## Encode un choix du joueur. Dictionnaire vide si l'action n'est pas un
## choix enregistrable.
static func encode(action: Action) -> Dictionary:
	if action is MoveAction:
		return {"type": MOVE, "cell": _cell_to_array((action as MoveAction).destination)}
	if action is AttackAction:
		var attack := action as AttackAction
		return {"type": ATTACK, "cell": _cell_to_array(attack.cell), "weapon": str(attack.weapon.id), "blind": attack.is_blind(), "off_hand": attack.off_hand}
	if action is StandardAction:
		var standard := action as StandardAction
		return {"type": STANDARD, "kind": str(standard.kind), "bonus": standard.bonus_action}
	if action is HideAction:
		return {"type": HIDE, "bonus": (action as HideAction).bonus_action}
	if action is SecondWindAction:
		return {"type": SECOND_WIND}
	if action is SearchAction:
		return {"type": SEARCH}
	if action is StandUpAction:
		return {"type": STAND_UP}
	if action is EndTurnAction:
		return {"type": END_TURN}
	if action is OpportunityAttackAction:
		return {"type": OPPORTUNITY_ATTACK}
	if action is DeclineReactionAction:
		return {"type": DECLINE_REACTION}
	if action is UseInspirationAction:
		return {"type": USE_INSPIRATION}
	if action is DeclineInspirationAction:
		return {"type": DECLINE_INSPIRATION}
	if action is SwapInitiativeAction:
		return {"type": SWAP_INITIATIVE, "ally": _cell_to_array((action as SwapInitiativeAction).ally.position)}
	if action is DeclineSwapAction:
		return {"type": DECLINE_SWAP}
	if action is HelpAction:
		return {"type": HELP, "cell": _cell_to_array((action as HelpAction).target.position)}
	return {}


## Reconstruit l'action d'un choix enregistré, pour `actor`. `null` si
## l'entrée est invalide.
static func decode(entry: Dictionary, actor: Combatant, state: CombatState) -> Action:
	match entry.get("type", ""):
		MOVE:
			var destination: Variant = _array_to_cell(entry.get("cell"))
			return MoveAction.new(actor, destination) if destination != null else null
		ATTACK:
			var cell: Variant = _array_to_cell(entry.get("cell"))
			var weapon := _weapon(actor, entry.get("weapon"))
			# `off_hand` : absent des enregistrements d'avant le Roublard.
			var off_hand: Variant = entry.get("off_hand", false)
			if cell == null or weapon == null or typeof(entry.get("blind")) != TYPE_BOOL or typeof(off_hand) != TYPE_BOOL:
				return null
			var attack: AttackAction
			if entry["blind"]:
				attack = AttackAction.at_cell(actor, cell, weapon)
			else:
				var target := state.combatant_at(cell)
				if target == null:
					return null
				attack = AttackAction.new(actor, target, weapon)
			attack.off_hand = off_hand
			return attack
		STANDARD:
			var kind: Variant = entry.get("kind")
			if typeof(kind) != TYPE_STRING or not StandardAction.ALL.has(StringName(kind)) or typeof(entry.get("bonus")) != TYPE_BOOL:
				return null
			return StandardAction.new(actor, StringName(kind), entry["bonus"])
		HIDE:
			return HideAction.new(actor, entry["bonus"]) if typeof(entry.get("bonus")) == TYPE_BOOL else null
		SECOND_WIND:
			return SecondWindAction.new(actor)
		SEARCH:
			return SearchAction.new(actor)
		STAND_UP:
			return StandUpAction.new(actor)
		END_TURN:
			return EndTurnAction.new(actor)
		OPPORTUNITY_ATTACK:
			return OpportunityAttackAction.new(actor)
		DECLINE_REACTION:
			return DeclineReactionAction.new(actor)
		USE_INSPIRATION:
			return UseInspirationAction.new(actor)
		DECLINE_INSPIRATION:
			return DeclineInspirationAction.new(actor)
		SWAP_INITIATIVE:
			# L'allié est désigné par sa case : au début du combat, chacun est
			# sur sa case de départ.
			var ally_cell: Variant = _array_to_cell(entry.get("ally"))
			var ally := state.combatant_at(ally_cell) if ally_cell != null else null
			return SwapInitiativeAction.new(actor, ally) if ally != null else null
		DECLINE_SWAP:
			return DeclineSwapAction.new(actor)
		HELP:
			var help_cell: Variant = _array_to_cell(entry.get("cell"))
			var helped := state.combatant_at(help_cell) if help_cell != null else null
			return HelpAction.new(actor, helped) if helped != null else null
	return null


func to_json() -> String:
	return JSON.stringify({
		"version": VERSION,
		"seed": seed_value,
		"encounter": str(encounter_id),
		"party": PartyMember.list_to(party),
		"entries": entries,
		"outcome": outcome,
	}, "  ")


## Lit un enregistrement. `null` si le texte n'en est pas un valide.
static func from_json(text: String) -> CombatRecord:
	var raw: Variant = JSON.parse_string(text)
	if typeof(raw) != TYPE_DICTIONARY:
		return null
	var data: Dictionary = raw
	if data.get("version") == 1.0:
		data = _upgrade_v1(data)
	elif data.get("version") != float(VERSION):
		return null
	if not _is_whole_number(data.get("seed")) or typeof(data.get("encounter")) != TYPE_STRING \
			or typeof(data.get("entries")) != TYPE_ARRAY or typeof(data.get("outcome")) != TYPE_DICTIONARY:
		return null
	var members := PartyMember.list_from(data.get("party"))
	if members.is_empty():
		return null
	var record := CombatRecord.new()
	record.seed_value = int(data["seed"])
	record.encounter_id = StringName(data["encounter"])
	record.party = members
	for entry: Variant in data["entries"]:
		if typeof(entry) != TYPE_DICTIONARY:
			return null
		record.entries.append(entry)
	record.outcome = _normalize_outcome(data["outcome"])
	return record


## v1 : le Guerrier seul, décrit par des champs à part.
static func _upgrade_v1(data: Dictionary) -> Dictionary:
	var upgraded := data.duplicate()
	upgraded["party"] = [{
		"def_id": data.get("player"),
		"hp_current": data.get("player_hp"),
		"second_wind_uses": data.get("second_wind_uses"),
		"heroic_inspiration": data.get("heroic_inspiration"),
	}]
	return upgraded


# Le JSON lit tous les nombres en flottants : on remet des entiers.
static func _normalize_outcome(raw: Dictionary) -> Dictionary:
	if raw.is_empty() or not _is_whole_number(raw.get("winner")) or not _is_whole_number(raw.get("round")) \
			or typeof(raw.get("hp")) != TYPE_ARRAY:
		return {}
	var hp: Array[int] = []
	for value: Variant in raw["hp"]:
		if not _is_whole_number(value):
			return {}
		hp.append(int(value))
	return {"winner": int(raw["winner"]), "round": int(raw["round"]), "hp": hp}


static func _is_whole_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT) and float(value) == floorf(float(value))


static func _cell_to_array(cell: Vector2i) -> Array[int]:
	return [cell.x, cell.y]


static func _array_to_cell(raw: Variant) -> Variant:
	if typeof(raw) != TYPE_ARRAY or (raw as Array).size() != 2:
		return null
	if not _is_whole_number(raw[0]) or not _is_whole_number(raw[1]):
		return null
	return Vector2i(int(raw[0]), int(raw[1]))


static func _weapon(actor: Combatant, raw: Variant) -> WeaponDef:
	if typeof(raw) != TYPE_STRING:
		return null
	for weapon in actor.definition.weapons:
		if str(weapon.id) == raw:
			return weapon
	return null

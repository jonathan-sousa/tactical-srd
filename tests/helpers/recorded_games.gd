## Parties enregistrées pour les tests : le joueur est joué par l'IA, et
## chacun de ses choix est noté dans un CombatRecord, comme le fait la scène
## de combat pour un vrai joueur.
extends RefCounted


## Combat de l'histoire (vraies données) joué jusqu'au bout avec cette
## graine ; renvoie son enregistrement, résultat compris.
static func record(seed_value: int) -> CombatRecord:
	var registry := DataRegistry.load_from()
	var state := CombatState.create(registry.encounter(&"goblin_ambush"), registry.character(&"fighter_lvl1"))
	var dice := Dice.seeded(seed_value)
	var player := state.combatants[0]
	var recorded := CombatRecord.new()
	recorded.seed_value = seed_value
	recorded.encounter_id = &"goblin_ambush"
	recorded.player_id = &"fighter_lvl1"
	recorded.player_hp = player.hp
	recorded.second_wind_uses = player.second_wind_uses
	recorded.heroic_inspiration = player.heroic_inspiration
	state.start(dice)
	var steps := 0
	while not state.is_over and steps < CombatSimulator.MAX_ACTIONS:
		_play(state, dice, EnemyAI.next_action(state, state.active()), player, recorded)
		while state.pending != null and not state.is_over:
			_play(state, dice, EnemyAI.decide(state), player, recorded)
		steps += 1
	recorded.outcome = CombatRecord.outcome_of(state)
	return recorded


## Rejoue un enregistrement : les choix du joueur sont lus dans le fichier,
## l'IA joue le reste. Renvoie l'état final, ou `null` si un choix ne
## correspond plus.
static func replay(recorded: CombatRecord) -> CombatState:
	var registry := DataRegistry.load_from()
	var state := CombatState.create(registry.encounter(recorded.encounter_id), registry.character(recorded.player_id), recorded.player_hp)
	var player := state.combatants[0]
	player.second_wind_uses = recorded.second_wind_uses
	player.heroic_inspiration = recorded.heroic_inspiration
	var dice := Dice.seeded(recorded.seed_value)
	state.start(dice)
	var index := 0
	var steps := 0
	while not state.is_over and steps < CombatSimulator.MAX_ACTIONS:
		var deciding := state.pending.decider if state.pending != null else state.active()
		var action: Action
		if deciding == player:
			if index >= recorded.entries.size():
				return null
			action = CombatRecord.decode(recorded.entries[index], player, state)
			index += 1
		elif state.pending != null:
			action = EnemyAI.decide(state)
		else:
			action = EnemyAI.next_action(state, deciding)
		if action == null or not action.validate(state).is_empty():
			return null
		action.execute(state, dice)
		steps += 1
	return state


static func _play(state: CombatState, dice: Dice, action: Action, player: Combatant, recorded: CombatRecord) -> void:
	if action.actor == player:
		recorded.entries.append(CombatRecord.encode(action))
	action.execute(state, dice)

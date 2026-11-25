## Joue un combat entier sans affichage, les deux camps conduits par l'IA
## (EnemyAI), décisions comprises (réactions, relances).
##
## Avec des dés à graine (`Dice.seeded`), le combat est déterministe : même
## graine, mêmes données et même code donnent exactement la même suite
## d'actions et d'événements. Sert aux tests (combats de référence,
## invariants) et à l'outil scripts/find_seeds.gd.
class_name CombatSimulator
extends RefCounted

## Garde-fous contre un combat qui ne finirait jamais.
const MAX_ACTIONS := 2000
const MAX_ROUNDS := 40

var state: CombatState
var dice: Dice
## Actions jouées, dans l'ordre, réponses aux décisions comprises.
var actions: Array[Action] = []
## Tous les événements produits, dans l'ordre.
var events: Array[CombatEvent] = []
## Actions que l'IA a proposées mais que le moteur a refusées (doit rester
## vide) : « NomDeLAction : raison ».
var refused: Array[String] = []


func _init(p_state: CombatState, p_dice: Dice) -> void:
	state = p_state
	dice = p_dice


## Tire l'initiative (et l'embuscade éventuelle).
func start() -> Array[CombatEvent]:
	var started := state.start(dice)
	events.append_array(started)
	return started


## Joue la prochaine action du combattant actif, puis les décisions qu'elle
## ouvre. Renvoie les événements produits.
func step() -> Array[CombatEvent]:
	var produced: Array[CombatEvent] = []
	var actor := state.active()
	produced.append_array(_play(EnemyAI.next_action(state, actor), actor))
	while state.pending != null and not state.is_over:
		var decision := state.pending
		produced.append_array(_play(EnemyAI.decide(state), decision.decider))
	events.append_array(produced)
	return produced


## Joue jusqu'à la fin du combat (ou jusqu'aux garde-fous).
func run_to_end() -> void:
	while not is_finished():
		step()


func is_finished() -> bool:
	return state.is_over or actions.size() >= MAX_ACTIONS or state.round > MAX_ROUNDS


func _play(action: Action, actor: Combatant) -> Array[CombatEvent]:
	var reason := action.validate(state)
	if not reason.is_empty():
		refused.append("%s : %s" % [action.get_script().get_global_name(), reason])
		# Pour ne jamais rester bloqué : on finit le tour (ou on décline).
		if state.pending is ReactionWindow:
			action = DeclineReactionAction.new(actor)
		elif state.pending is InspirationWindow:
			action = DeclineInspirationAction.new(actor)
		else:
			action = EndTurnAction.new(actor)
	actions.append(action)
	return action.execute(state, dice)

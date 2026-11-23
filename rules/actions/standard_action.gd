## Actions sans jet de dés du SRD 5.2.1 (« Actions ») : Foncer, Se
## désengager, Esquiver. Chacune coûte l'action du tour, sauf Se désengager
## par Nimble Escape (Gobelin), qui coûte l'action bonus.
##
## Une seule classe pour les trois : elles ne diffèrent que par leur effet,
## appliqué dans `_execute`.
class_name StandardAction
extends Action

## Dash : déplacement supplémentaire égal à la vitesse.
const DASH := &"dash"
## Disengage : pas d'attaque d'opportunité pour le reste du tour.
const DISENGAGE := &"disengage"
## Dodge : attaques contre soi au désavantage jusqu'à son prochain tour.
const DODGE := &"dodge"

const ALL: Array[StringName] = [DASH, DISENGAGE, DODGE]

var kind: StringName
## Par une action bonus (Nimble Escape) plutôt que par l'action du tour.
var bonus_action: bool


func _init(p_actor: Combatant, p_kind: StringName, p_bonus_action: bool = false) -> void:
	super(p_actor)
	assert(ALL.has(p_kind), "Action inconnue : %s" % p_kind)
	kind = p_kind
	bonus_action = p_bonus_action


func _validate(state: CombatState) -> StringName:
	if bonus_action:
		if kind != DISENGAGE or not actor.definition.has_trait(CharacterDef.NIMBLE_ESCAPE):
			return FEATURE_UNAVAILABLE
		if state.bonus_action_used:
			return BONUS_ACTION_ALREADY_USED
		return &""
	if state.action_used:
		return ACTION_ALREADY_USED
	return &""


func _execute(state: CombatState, _dice: Dice) -> Array[CombatEvent]:
	if bonus_action:
		state.bonus_action_used = true
	else:
		state.action_used = true
	match kind:
		DASH:
			state.movement_left += state.speed_in_squares(actor)
		DISENGAGE:
			state.add_effect(Effect.new(Effect.DISENGAGED, actor, actor, Effect.Expiry.END_OF_SOURCE_TURN))
		DODGE:
			state.add_effect(Effect.new(Effect.DODGING, actor, actor, Effect.Expiry.START_OF_SOURCE_TURN))
	return [ActionTakenEvent.new(actor, kind, bonus_action)]

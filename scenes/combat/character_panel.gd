## Fiche du personnage joueur : PV et CA, budget du tour (pastilles action,
## action bonus, réaction et jauge de déplacement, voir TurnBudget),
## ressources (Second Wind, Inspiration) et effets.
class_name CharacterPanel
extends VBoxContainer

@onready var _name_label: Label = %NameLabel
@onready var _hp_label: Label = %HpLabel
@onready var _resources_label: Label = %ResourcesLabel
@onready var _effects_label: Label = %EffectsLabel

var budget: TurnBudget


func _ready() -> void:
	budget = TurnBudget.new()
	add_child(budget)
	move_child(budget, _hp_label.get_index() + 1)


func refresh(combatant: Combatant, state: CombatState) -> void:
	var definition := combatant.definition
	var speed := state.speed_in_squares(combatant)
	var is_turn := state.active() == combatant and not state.is_over
	_name_label.text = combatant.display_name
	_hp_label.text = "%s : %d / %d · %s : %d" % [Texts.HIT_POINTS, combatant.hp, definition.max_hp, Texts.ARMOR_CLASS, combatant.armor_class()]
	var movement := state.movement_left if is_turn else speed
	budget.set_budget(not (is_turn and state.action_used), not (is_turn and state.bonus_action_used), combatant.reaction_available, movement, speed)
	_resources_label.text = Texts.resources_line(combatant, combatant.sneak_attack_turn == state.turn_count)
	if combatant.is_dying():
		_resources_label.text = Texts.death_saves_line(combatant)
	_resources_label.visible = not _resources_label.text.is_empty()
	var effects := state.effects_on(combatant)
	_effects_label.visible = not effects.is_empty()
	_effects_label.text = Texts.effects_line(effects)

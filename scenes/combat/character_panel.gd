## Fiche du personnage joueur : PV et CA, déplacement restant, action,
## action bonus, réaction, ressources (Second Wind, Inspiration) et effets.
class_name CharacterPanel
extends VBoxContainer

@onready var _name_label: Label = %NameLabel
@onready var _hp_label: Label = %HpLabel
@onready var _movement_label: Label = %MovementLabel
@onready var _action_label: Label = %ActionLabel
@onready var _bonus_label: Label = %BonusLabel
@onready var _reaction_label: Label = %ReactionLabel
@onready var _resources_label: Label = %ResourcesLabel
@onready var _effects_label: Label = %EffectsLabel


func refresh(combatant: Combatant, state: CombatState) -> void:
	var definition := combatant.definition
	var speed := state.speed_in_squares(combatant)
	var is_turn := state.active() == combatant and not state.is_over
	_name_label.text = combatant.display_name
	_hp_label.text = "%s : %d / %d · %s : %d" % [Texts.HIT_POINTS, combatant.hp, definition.max_hp, Texts.ARMOR_CLASS, combatant.armor_class()]
	var movement := state.movement_left if is_turn else speed
	_movement_label.text = "%s : %d / %s" % [Texts.MOVEMENT, movement, Texts.squares(speed)]
	_action_label.text = Texts.ACTION_USED if is_turn and state.action_used else Texts.ACTION_AVAILABLE
	_bonus_label.text = Texts.bonus_action_line(is_turn and state.bonus_action_used)
	_reaction_label.text = Texts.REACTION_AVAILABLE if combatant.reaction_available else Texts.REACTION_USED
	_resources_label.text = Texts.resources_line(combatant)
	if combatant.is_dying():
		_resources_label.text = Texts.death_saves_line(combatant)
	_resources_label.visible = not _resources_label.text.is_empty()
	var effects := state.effects_on(combatant)
	_effects_label.visible = not effects.is_empty()
	_effects_label.text = Texts.effects_line(effects)

## Fiche du personnage joueur : PV, CA, déplacement restant, action.
class_name CharacterPanel
extends VBoxContainer

@onready var _name_label: Label = %NameLabel
@onready var _hp_label: Label = %HpLabel
@onready var _ac_label: Label = %AcLabel
@onready var _movement_label: Label = %MovementLabel
@onready var _action_label: Label = %ActionLabel


func refresh(combatant: Combatant, state: CombatState) -> void:
	var definition := combatant.definition
	var speed := state.speed_in_squares(combatant)
	var is_turn := state.active() == combatant and not state.is_over
	_name_label.text = definition.display_name
	_hp_label.text = "%s : %d / %d" % [Texts.HIT_POINTS, combatant.hp, definition.max_hp]
	_ac_label.text = "%s : %d" % [Texts.ARMOR_CLASS, combatant.armor_class()]
	var movement := state.movement_left if is_turn else speed
	_movement_label.text = "%s : %d / %s" % [Texts.MOVEMENT, movement, Texts.squares(speed)]
	_action_label.text = Texts.ACTION_USED if is_turn and state.action_used else Texts.ACTION_AVAILABLE

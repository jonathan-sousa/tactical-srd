## Boîte de dialogue générique, pilotée par un DialogueDef.
##
## Texte affiché lettre par lettre ; clic ou Entrée affiche toute la
## réplique d'un coup, puis passe à la suivante. Après la dernière, émet
## `finished` et, dans l'histoire, passe à l'étape suivante.
extends Control

signal finished

const CHARACTERS_PER_SECOND := 45.0

## Dialogue à jouer. Vide : on prend celui de l'étape courante de l'histoire.
@export var dialogue: DialogueDef

var _index := -1
var _shown := 0.0
var _typing := false
var _story_mode := false
var _done := false

@onready var _speaker_label: Label = %SpeakerLabel
@onready var _text_label: Label = %TextLabel
@onready var _portrait: TextureRect = %Portrait
@onready var _hint_label: Label = %HintLabel


func _ready() -> void:
	_hint_label.text = Texts.DIALOGUE_HINT
	if dialogue == null:
		var step := GameState.current_step()
		if step != null and step.kind == StoryStep.Kind.DIALOGUE:
			dialogue = step.dialogue
			_story_mode = true
	if dialogue == null or dialogue.lines.is_empty():
		push_error("Dialogue : aucune réplique à afficher.")
		return
	_show_line(0)


func current_index() -> int:
	return _index


func is_typing() -> bool:
	return _typing


func _process(delta: float) -> void:
	if not _typing:
		return
	_shown += delta * CHARACTERS_PER_SECOND
	_text_label.visible_characters = int(_shown)
	if _text_label.visible_characters >= _text_label.get_total_character_count():
		_complete_line()


func _unhandled_input(event: InputEvent) -> void:
	var clicked: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if clicked or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		advance()


## Affiche toute la réplique si elle s'écrit encore, sinon passe à la suivante.
func advance() -> void:
	if _done or dialogue == null:
		return
	if _typing:
		_complete_line()
	elif _index + 1 < dialogue.lines.size():
		_show_line(_index + 1)
	else:
		_finish()


func _show_line(index: int) -> void:
	_index = index
	var line := dialogue.lines[index]
	_speaker_label.text = line.speaker
	_text_label.text = line.text
	_text_label.visible_characters = 0
	_portrait.texture = line.portrait
	_portrait.visible = line.portrait != null
	_hint_label.modulate.a = 0.0
	_shown = 0.0
	_typing = true


func _complete_line() -> void:
	_typing = false
	_text_label.visible_characters = -1
	_hint_label.modulate.a = 1.0


func _finish() -> void:
	_done = true
	finished.emit()
	if _story_mode:
		GameState.finish_step(GameState.Outcome.DONE)

## Boîte de dialogue générique, pilotée par un DialogueDef.
##
## Texte affiché lettre par lettre ; clic ou Entrée affiche toute la
## réplique d'un coup, puis passe à la suivante. Après la dernière, émet
## `finished` et, dans l'histoire, passe à l'étape suivante.
##
## « Passer » (Tab) saute tout le dialogue ; « Historique » (H) montre les
## répliques déjà lues.
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
@onready var _skip_button: Button = %SkipButton
@onready var _history_button: Button = %HistoryButton
@onready var _history_panel: PanelContainer = %HistoryPanel
@onready var _history_text: RichTextLabel = %HistoryText


func _ready() -> void:
	_hint_label.text = Texts.DIALOGUE_HINT
	AudioManager.play_music(AudioManager.MENU_MUSIC)
	_skip_button.text = Texts.DIALOGUE_SKIP
	_skip_button.shortcut = _key_shortcut(KEY_TAB)
	_skip_button.pressed.connect(skip)
	_history_button.text = Texts.DIALOGUE_HISTORY
	_history_button.shortcut = _key_shortcut(KEY_H)
	_history_button.pressed.connect(toggle_history)
	_apply_text_size()
	Settings.large_text_changed.connect(func(_enabled: bool) -> void: _apply_text_size())
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
	if _done or dialogue == null or _history_panel.visible:
		return
	if _typing:
		_complete_line()
	elif _index + 1 < dialogue.lines.size():
		_show_line(_index + 1)
	else:
		_finish()


## Saute le reste du dialogue.
func skip() -> void:
	if _done or dialogue == null:
		return
	_history_panel.hide()
	_finish()


## Ouvre ou ferme l'historique des répliques déjà lues.
func toggle_history() -> void:
	if dialogue == null:
		return
	if _history_panel.visible:
		_history_panel.hide()
		_history_button.text = Texts.DIALOGUE_HISTORY
		return
	_history_text.clear()
	for i in _index + 1:
		var line := dialogue.lines[i]
		_history_text.push_color(Palette.GOLD)
		_history_text.add_text(line.speaker)
		_history_text.pop()
		_history_text.newline()
		_history_text.add_text(line.text)
		_history_text.newline()
		_history_text.newline()
	_history_panel.show()
	_history_button.text = Texts.DIALOGUE_HISTORY_CLOSE


func is_history_open() -> bool:
	return _history_panel.visible


func _apply_text_size() -> void:
	_text_label.add_theme_font_size_override(&"font_size", Settings.font_size(22, 26))
	_history_text.add_theme_font_size_override(&"normal_font_size", Settings.font_size(18, 22))


static func _key_shortcut(key: Key) -> Shortcut:
	var event := InputEventKey.new()
	event.keycode = key
	var shortcut := Shortcut.new()
	shortcut.events = [event]
	return shortcut


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

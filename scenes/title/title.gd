## Écran titre : nom du jeu et « Appuyez sur une touche ».
##
## Note Godot : `extends Control` équivaut à hériter d'une classe de base.
## Un script est attaché à un Node de la scène, un peu comme un controller
## attaché à une vue, mais le Node *est* l'objet affiché.
extends Control

@onready var _title_label: Label = %TitleLabel
@onready var _press_key_label: Label = %PressKeyLabel

var _leaving := false


func _ready() -> void:
	# ProjectSettings lit les valeurs de project.godot (ici config/name).
	_title_label.text = str(ProjectSettings.get_setting("application/config/name"))
	_press_key_label.text = Texts.PRESS_ANY_KEY
	AudioManager.play_music(AudioManager.MENU_MUSIC)
	# Clignotement doux du message, en boucle.
	var tween := create_tween().set_loops()
	tween.tween_property(_press_key_label, "modulate:a", 0.3, 0.8)
	tween.tween_property(_press_key_label, "modulate:a", 1.0, 0.8)
	if Autoplay.enabled:
		Autoplay.later(self, _leave)


func _unhandled_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventJoypadButton and event.pressed)
	if pressed and not _leaving:
		get_viewport().set_input_as_handled()
		_leave()


func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	SceneRouter.go_to(SceneRouter.MENU)

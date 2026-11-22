## Menu pause (Échap), utilisable dans le dialogue comme en combat.
##
## Note Godot : `get_tree().paused = true` fige tous les nodes en mode
## « pausable » (le défaut) : timers, tweens, _process et entrées. Ce menu
## est en `process_mode = ALWAYS` pour continuer à répondre pendant la pause.
extends CanvasLayer

@onready var _title_label: Label = %PauseTitle
@onready var _resume_button: Button = %ResumeButton
@onready var _options_button: Button = %PauseOptionsButton
@onready var _menu_button: Button = %BackToMenuButton
@onready var _panel: PanelContainer = %Panel
@onready var _options_center: CenterContainer = %OptionsCenter
@onready var _options_panel: PanelContainer = %PauseOptionsPanel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_title_label.text = Texts.PAUSE
	_resume_button.text = Texts.RESUME
	_options_button.text = Texts.OPTIONS
	_menu_button.text = Texts.BACK_TO_MENU
	_resume_button.pressed.connect(close)
	_options_button.pressed.connect(_on_options_pressed)
	_menu_button.pressed.connect(_on_menu_pressed)
	_options_panel.closed.connect(_close_options)


func is_open() -> bool:
	return visible


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not SceneRouter.is_changing():
		get_viewport().set_input_as_handled()
		if visible:
			close()
		else:
			open()


func open() -> void:
	visible = true
	_panel.visible = true
	_options_center.visible = false
	get_tree().paused = true
	_resume_button.grab_focus()


func close() -> void:
	visible = false
	get_tree().paused = false


func _on_options_pressed() -> void:
	_panel.visible = false
	_options_center.visible = true
	_options_panel.sync_from_settings()


## Retour des options vers les boutons de la pause (Échap y compris : le
## panneau d'options, plus profond dans l'arbre, reçoit la touche en premier).
func _close_options() -> void:
	_options_center.visible = false
	_panel.visible = true
	_options_button.grab_focus()


## Quitter un combat en cours le fera recommencer au prochain Continuer :
## la progression n'avance qu'à la fin d'une étape.
func _on_menu_pressed() -> void:
	SceneRouter.go_to(SceneRouter.MENU)

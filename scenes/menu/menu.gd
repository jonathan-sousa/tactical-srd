## Menu principal : Nouvelle partie, Continuer, Options, Crédits, Quitter.
## Navigable à la souris et au clavier (flèches + Entrée).
extends Control

@onready var _new_game_button: Button = %NewGameButton
@onready var _continue_button: Button = %ContinueButton
@onready var _options_button: Button = %OptionsButton
@onready var _credits_button: Button = %CreditsButton
@onready var _quit_button: Button = %QuitButton
@onready var _title_label: Label = %TitleLabel
@onready var _confirm_dialog: ConfirmationDialog = %ConfirmDialog


func _ready() -> void:
	_title_label.text = str(ProjectSettings.get_setting("application/config/name"))
	_new_game_button.text = Texts.NEW_GAME
	_continue_button.text = Texts.CONTINUE
	_options_button.text = Texts.OPTIONS
	_credits_button.text = Texts.CREDITS
	_quit_button.text = Texts.QUIT

	_new_game_button.pressed.connect(_on_new_game_pressed)
	_continue_button.pressed.connect(_on_continue_pressed)
	_options_button.pressed.connect(func() -> void: SceneRouter.go_to(SceneRouter.OPTIONS))
	_credits_button.pressed.connect(func() -> void: SceneRouter.go_to(SceneRouter.CREDITS))
	_quit_button.pressed.connect(func() -> void: get_tree().quit())

	_confirm_dialog.title = Texts.NEW_GAME_CONFIRM_TITLE
	_confirm_dialog.dialog_text = Texts.NEW_GAME_CONFIRM
	_confirm_dialog.ok_button_text = Texts.NEW_GAME
	_confirm_dialog.cancel_button_text = Texts.CANCEL
	_confirm_dialog.confirmed.connect(_start_new_game)

	_options_button.disabled = not ResourceLoader.exists(SceneRouter.OPTIONS)
	_credits_button.disabled = not ResourceLoader.exists(SceneRouter.CREDITS)
	for button: Button in [_options_button, _credits_button]:
		button.tooltip_text = Texts.COMING_SOON if button.disabled else ""

	_continue_button.disabled = not _can_continue()
	_continue_button.tooltip_text = Texts.NO_SAVE if _continue_button.disabled else ""
	# Note Godot : grab_focus() donne le focus clavier à un bouton ; les
	# flèches passent ensuite d'un bouton à l'autre dans le conteneur.
	(_new_game_button if _continue_button.disabled else _continue_button).grab_focus()


func _can_continue() -> bool:
	return GameState.has_game()


func _on_new_game_pressed() -> void:
	if _can_continue():
		_confirm_dialog.popup_centered()
	else:
		_start_new_game()


func _start_new_game() -> void:
	GameState.new_game()
	GameState.go_to_current_step()


func _on_continue_pressed() -> void:
	GameState.go_to_current_step()

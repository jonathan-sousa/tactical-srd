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
@onready var _message_label: Label = %MessageLabel


func _ready() -> void:
	_title_label.text = str(ProjectSettings.get_setting("application/config/name"))
	_new_game_button.text = Texts.NEW_GAME
	AudioManager.play_music(AudioManager.MENU_MUSIC)
	_continue_button.text = Texts.CONTINUE
	_options_button.text = Texts.OPTIONS
	_credits_button.text = Texts.CREDITS
	_quit_button.text = Texts.QUIT

	_new_game_button.pressed.connect(_on_new_game_pressed)
	_continue_button.pressed.connect(_on_continue_pressed)
	_options_button.pressed.connect(func() -> void: SceneRouter.go_to(SceneRouter.OPTIONS))
	_credits_button.pressed.connect(func() -> void: SceneRouter.go_to(SceneRouter.CREDITS))
	_quit_button.pressed.connect(AudioManager.quit_game)

	_confirm_dialog.title = Texts.NEW_GAME_CONFIRM_TITLE
	_confirm_dialog.dialog_text = Texts.NEW_GAME_CONFIRM
	_confirm_dialog.ok_button_text = Texts.NEW_GAME
	_confirm_dialog.cancel_button_text = Texts.CANCEL
	_confirm_dialog.confirmed.connect(_start_new_game)

	_options_button.disabled = not ResourceLoader.exists(SceneRouter.OPTIONS)
	_credits_button.disabled = not ResourceLoader.exists(SceneRouter.CREDITS)
	for button: Button in [_options_button, _credits_button]:
		button.tooltip_text = Texts.COMING_SOON if button.disabled else ""

	_refresh_continue()
	# Note Godot : grab_focus() donne le focus clavier à un bouton ; les
	# flèches passent ensuite d'un bouton à l'autre dans le conteneur.
	(_new_game_button if _continue_button.disabled else _continue_button).grab_focus()


## Partie en mémoire (retour au menu depuis la pause) ou sauvegarde valide.
func _can_continue() -> bool:
	return GameState.has_game() or SaveManager.can_continue()


## Active ou grise « Continuer » et explique pourquoi quand il est grisé.
func _refresh_continue() -> void:
	_continue_button.disabled = not _can_continue()
	var message := ""
	if not GameState.has_game():
		message = SaveManager.status_message()
		if message.is_empty() and SaveManager.status == SaveManager.Status.OK and SaveManager.data["story_completed"]:
			message = Texts.STORY_COMPLETED
	_message_label.text = message
	_continue_button.tooltip_text = (message if not message.is_empty() else Texts.NO_SAVE) if _continue_button.disabled else ""


func _on_new_game_pressed() -> void:
	# Confirmation si une partie ou un fichier de sauvegarde existe déjà.
	if GameState.has_game() or SaveManager.has_save_file():
		_confirm_dialog.popup_centered()
	else:
		_start_new_game()


func _start_new_game() -> void:
	GameState.new_game()
	GameState.go_to_current_step()


func _on_continue_pressed() -> void:
	if not GameState.has_game() and not SaveManager.restore_into(GameState):
		# La sauvegarde ne correspond plus aux données du jeu.
		_refresh_continue()
		_new_game_button.grab_focus()
		return
	GameState.go_to_current_step()

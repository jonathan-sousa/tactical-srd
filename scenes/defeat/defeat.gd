## Écran de défaite : réessayer le combat (repart d'un combat propre) ou
## revenir au menu.
extends Control

@onready var _title_label: Label = %DefeatTitle
@onready var _message_label: Label = %DefeatMessage
@onready var _retry_button: Button = %RetryButton
@onready var _menu_button: Button = %MainMenuButton


func _ready() -> void:
	_title_label.text = Texts.DEFEAT
	_message_label.text = Texts.DEFEAT_MESSAGE
	_retry_button.text = Texts.RETRY_COMBAT
	_menu_button.text = Texts.MAIN_MENU
	# L'étape courante est toujours le combat perdu : y retourner le relance
	# depuis ses données, avec les PV d'avant le combat.
	_retry_button.pressed.connect(func() -> void: GameState.go_to_current_step())
	_menu_button.pressed.connect(func() -> void: SceneRouter.go_to(SceneRouter.MENU))
	_retry_button.grab_focus()
	if Autoplay.enabled:
		Autoplay.later(self, func() -> void: SceneRouter.go_to(SceneRouter.MENU))

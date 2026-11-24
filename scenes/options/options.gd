## Écran Options ouvert depuis le menu principal.
extends Control

@onready var _panel: PanelContainer = %OptionsPanel


func _ready() -> void:
	AudioManager.play_music(AudioManager.MENU_MUSIC)
	_panel.closed.connect(func() -> void: SceneRouter.go_to(SceneRouter.MENU))

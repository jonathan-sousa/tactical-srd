## Panneau d'options réutilisable : écran Options (depuis le menu) et menu
## pause. Chaque changement est appliqué et enregistré tout de suite.
extends PanelContainer

## Émis quand le joueur quitte le panneau (bouton Retour ou Échap).
signal closed

@onready var _title_label: Label = %OptionsTitle
@onready var _volume_label: Label = %VolumeLabel
@onready var _volume_slider: HSlider = %VolumeSlider
@onready var _volume_value: Label = %VolumeValue
@onready var _music_label: Label = %MusicLabel
@onready var _music_slider: HSlider = %MusicSlider
@onready var _music_value: Label = %MusicValue
@onready var _sfx_label: Label = %SfxLabel
@onready var _sfx_slider: HSlider = %SfxSlider
@onready var _sfx_value: Label = %SfxValue
@onready var _fullscreen_check: CheckButton = %FullscreenCheck
@onready var _large_text_check: CheckButton = %LargeTextCheck
@onready var _back_button: Button = %OptionsBackButton


func _ready() -> void:
	_title_label.text = Texts.OPTIONS
	_volume_label.text = Texts.MASTER_VOLUME
	_music_label.text = Texts.MUSIC_VOLUME
	_sfx_label.text = Texts.EFFECTS_VOLUME
	_fullscreen_check.text = Texts.FULLSCREEN
	_large_text_check.text = Texts.LARGE_TEXT
	_back_button.text = Texts.BACK
	sync_from_settings()
	_volume_slider.value_changed.connect(_on_volume_changed)
	_music_slider.value_changed.connect(_on_music_changed)
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	_fullscreen_check.toggled.connect(func(enabled: bool) -> void: Settings.set_fullscreen(enabled))
	_large_text_check.toggled.connect(func(enabled: bool) -> void: Settings.set_large_text(enabled))
	_back_button.pressed.connect(func() -> void: closed.emit())


## Affiche les valeurs actuelles et donne le focus clavier au premier réglage.
func sync_from_settings() -> void:
	# set_value_no_signal : mettre à jour l'affichage sans déclencher
	# l'enregistrement, qui n'est voulu que pour un changement du joueur.
	_volume_slider.set_value_no_signal(roundf(Settings.master_volume * 100.0))
	_music_slider.set_value_no_signal(roundf(Settings.music_volume * 100.0))
	_sfx_slider.set_value_no_signal(roundf(Settings.effects_volume * 100.0))
	_fullscreen_check.set_pressed_no_signal(Settings.fullscreen)
	_large_text_check.set_pressed_no_signal(Settings.large_text)
	_update_volume_label()
	if is_visible_in_tree():
		_volume_slider.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()


func _on_volume_changed(value: float) -> void:
	Settings.set_master_volume(value / 100.0)
	_update_volume_label()


func _on_music_changed(value: float) -> void:
	Settings.set_music_volume(value / 100.0)
	_update_volume_label()


func _on_sfx_changed(value: float) -> void:
	Settings.set_effects_volume(value / 100.0)
	_update_volume_label()
	# Un bruitage pour entendre le nouveau volume des effets.
	AudioManager.play(AudioManager.HIT)


func _update_volume_label() -> void:
	_volume_value.text = "%d %%" % int(_volume_slider.value)
	_music_value.text = "%d %%" % int(_music_slider.value)
	_sfx_value.text = "%d %%" % int(_sfx_slider.value)

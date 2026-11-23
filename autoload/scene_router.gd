## Seul point d'entrée pour changer de scène, avec un fondu au noir.
##
## Note Godot : ce Node est un CanvasLayer haut placé (layer 100), donc son
## voile noir passe au-dessus de toutes les scènes. `process_mode = ALWAYS`
## lui permet de fonctionner même quand le jeu est en pause.
extends CanvasLayer

const TITLE := "res://scenes/title/title.tscn"
const MENU := "res://scenes/menu/menu.tscn"
const DIALOGUE := "res://scenes/dialogue/dialogue.tscn"
const COMBAT := "res://scenes/combat/combat.tscn"
const DEFEAT := "res://scenes/defeat/defeat.tscn"
const OPTIONS := "res://scenes/options/options.tscn"
const CREDITS := "res://scenes/credits/credits.tscn"

const FADE_DURATION := 0.25

var _veil := ColorRect.new()
var _busy := false
## Scène en cours d'ouverture.
var _target := ""
## Dernière demande arrivée pendant un fondu, vers une autre scène. Elle est
## jouée juste après, au lieu d'être perdue.
var _pending := ""


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_veil.color = Color.BLACK
	_veil.modulate.a = 0.0
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_veil)


func is_changing() -> bool:
	return _busy


## Fondu au noir, changement de scène, retour de l'image.
##
## Pendant un changement, une demande vers la même scène est ignorée (double
## clic) ; une demande vers une autre scène est mise en attente et jouée
## ensuite. Seule la dernière demande en attente est gardée.
func go_to(scene_path: String) -> void:
	if _busy:
		_pending = "" if scene_path == _target else scene_path
		return
	_busy = true
	_target = scene_path
	# Pendant le fondu, le voile bloque la souris.
	_veil.mouse_filter = Control.MOUSE_FILTER_STOP
	await _fade_to(1.0)

	get_tree().paused = false
	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("SceneRouter : impossible d'ouvrir %s (%s)." % [scene_path, error_string(error)])
	else:
		await get_tree().scene_changed

	await _fade_to(0.0)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
	_target = ""
	if not _pending.is_empty():
		var next := _pending
		_pending = ""
		go_to(next)


func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(_veil, "modulate:a", alpha, FADE_DURATION)
	await tween.finished

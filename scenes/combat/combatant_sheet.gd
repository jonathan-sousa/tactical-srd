## Fiche complète d'un combattant, ouverte par un clic droit sur son pion :
## un panneau posé sur le plateau. Échap, un clic ou un clic droit la ferme,
## sans rien déclencher d'autre (ni le menu pause, ni une action).
##
## Comme la bulle, elle n'affiche que le texte qu'on lui donne (ui/texts.gd).
class_name CombatantSheet
extends PanelContainer

signal closed

const WIDTH := 560.0
const FONT_SIZE := 16

var _label: RichTextLabel
var _area := Rect2()


func _init() -> void:
	custom_minimum_size = Vector2(WIDTH, 0)
	# La fiche capte la souris : un clic dessus ne passe pas au plateau.
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Fond opaque et liseré doré, comme les infobulles (ui/theme.tres).
	theme_type_variation = &"TooltipPanel"
	hide()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_stylebox_override(&"normal", StyleBoxEmpty.new())
	_label.add_theme_font_size_override(&"normal_font_size", FONT_SIZE)
	_label.add_theme_font_size_override(&"bold_font_size", FONT_SIZE + 2)
	box.add_child(_label)
	var hint := Label.new()
	hint.text = Texts.SHEET_CLOSE
	hint.theme_type_variation = &"MutedLabel"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(hint)


## Ouvre la fiche, centrée dans `area` (coordonnées globales).
func open(bbcode: String, area: Rect2) -> void:
	_label.text = bbcode
	_area = area
	show()
	_fit()
	# Note Godot : le texte n'est mis en page qu'à la frame suivante ; on
	# ajuste donc encore la taille une fois qu'il l'est (call_deferred).
	_fit.call_deferred()


## Taille au plus juste du contenu, centrée dans la zone du plateau.
func _fit() -> void:
	size = Vector2(WIDTH, 0)
	reset_size()
	global_position = (_area.get_center() - size / 2.0).max(_area.position)


func close() -> void:
	if visible:
		hide()
		closed.emit()


## Texte affiché, sans balises : sert aux tests.
func text() -> String:
	return _label.get_parsed_text()


# Note Godot : _input passe avant _unhandled_input : la fiche ouverte
# consomme Échap avant le menu pause, et le clic avant le plateau.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	var button := event as InputEventMouseButton
	var mouse_click := button != null and button.pressed \
		and (button.button_index == MOUSE_BUTTON_LEFT or button.button_index == MOUSE_BUTTON_RIGHT)
	if event.is_action_pressed("ui_cancel") or mouse_click:
		get_viewport().set_input_as_handled()
		close()

## Budget du tour d'un personnage, à lire d'un coup d'œil : trois pastilles
## (action, action bonus, réaction), pleines si disponibles, vides si
## dépensées ; puis le déplacement en jauge de cases.
##
## Note Godot : un Control qui redéfinit _draw dessine lui-même son contenu,
## comme un <canvas>. queue_redraw() demande à le redessiner.
class_name TurnBudget
extends Control

const PIP_RADIUS := 7.0
const ROW_HEIGHT := 22.0
const FONT_SIZE := 15
const GAUGE_HEIGHT := 9.0
const GAUGE_GAP := 3.0
const EMPTY_GAUGE_COLOR := Color(0.16, 0.11, 0.08)

var action_available := true
var bonus_available := true
var reaction_available := true
var movement_left := 0
var speed := 0


func _init() -> void:
	custom_minimum_size = Vector2(0, ROW_HEIGHT * 2.0 + 4.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_budget(p_action: bool, p_bonus: bool, p_reaction: bool, p_movement_left: int, p_speed: int) -> void:
	action_available = p_action
	bonus_available = p_bonus
	reaction_available = p_reaction
	movement_left = p_movement_left
	speed = p_speed
	queue_redraw()


func _draw() -> void:
	var font := get_theme_font(&"font", &"Label")
	var x := 0.0
	var baseline := ROW_HEIGHT / 2.0 + FONT_SIZE / 3.0
	for pip: Array in [
		[Texts.BUDGET_ACTION, action_available, Palette.ACTION],
		[Texts.BUDGET_BONUS, bonus_available, Palette.BONUS_ACTION],
		[Texts.BUDGET_REACTION, reaction_available, Palette.REACTION],
	]:
		var label: String = pip[0]
		var available: bool = pip[1]
		var color: Color = pip[2]
		var center := Vector2(x + PIP_RADIUS, ROW_HEIGHT / 2.0)
		if available:
			draw_circle(center, PIP_RADIUS, color)
		draw_arc(center, PIP_RADIUS, 0.0, TAU, 24, color, 2.0)
		var text_color := Palette.TEXT if available else Palette.MUTED
		draw_string(font, Vector2(center.x + PIP_RADIUS + 6.0, baseline), label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, text_color)
		x += PIP_RADIUS * 2.0 + 12.0 + font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x + 18.0

	# Déplacement : « Déplacement 4 / 6 », puis une case de jauge par case.
	var movement_text := Texts.budget_movement(movement_left, speed)
	var row := ROW_HEIGHT + 4.0
	draw_string(font, Vector2(0, row + baseline), movement_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Palette.TEXT)
	var gauge_x := font.get_string_size(movement_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x + 12.0
	var gauge_width := size.x - gauge_x
	var squares := maxi(speed, movement_left)
	if squares <= 0 or gauge_width <= 0.0:
		return
	var cell_width := (gauge_width - GAUGE_GAP * (squares - 1)) / squares
	for i in squares:
		var rect := Rect2(Vector2(gauge_x + i * (cell_width + GAUGE_GAP), row + (ROW_HEIGHT - GAUGE_HEIGHT) / 2.0), Vector2(cell_width, GAUGE_HEIGHT))
		draw_rect(rect, Palette.MOVEMENT if i < movement_left else EMPTY_GAUGE_COLOR)

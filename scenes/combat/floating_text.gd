## Texte qui monte et s'efface au-dessus d'un pion : dégâts, soins,
## « Raté ! », « Critique ! ». Il ne bloque pas le déroulement du combat et
## se détruit tout seul.
class_name FloatingText
extends Label

const RISE := 44.0
const DURATION := 0.9


## Crée le texte au-dessus de `at` (repère de `parent`) et lance son
## animation.
static func spawn(parent: Node, at: Vector2, text: String, color: Color, font_size: int = 24) -> FloatingText:
	var label := FloatingText.new()
	label.text = text
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_color_override(&"font_outline_color", Color(0.05, 0.05, 0.08))
	label.add_theme_constant_override(&"outline_size", 6)
	label.add_theme_font_size_override(&"font_size", font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size = Vector2(160, 32)
	label.position = at - Vector2(80, 48)
	parent.add_child(label)
	label._rise()
	return label


func _rise() -> void:
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "position:y", position.y - RISE, DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "modulate:a", 0.0, DURATION).set_delay(DURATION * 0.4)
	# Note Godot : `tween_callback` appelle une fonction à la fin du Tween ;
	# `queue_free` libère le nœud proprement à la fin de l'image.
	tween.chain().tween_callback(queue_free)

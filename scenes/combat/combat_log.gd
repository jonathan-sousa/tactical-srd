## Journal de combat : une ligne par événement, la plus récente en bas.
class_name CombatLog
extends RichTextLabel


func _ready() -> void:
	scroll_following = true


func add_line(text: String, color: Color = Color(0.9, 0.9, 0.9)) -> void:
	push_color(color)
	add_text(text)
	pop()
	newline()

## Journal de combat : une ligne par événement, la plus récente en bas.
##
## Trois niveaux de lecture : l'en-tête de chaque round, la ligne
## principale (ce qui s'est passé), et la ligne de détail des jets, plus
## petite et plus discrète.
class_name CombatLog
extends RichTextLabel

const TEXT_COLOR := Palette.TEXT
const DETAIL_COLOR := Color(0.62, 0.62, 0.66)
const HEADER_COLOR := Palette.GOLD


func _ready() -> void:
	scroll_following = true
	_apply_text_size()
	Settings.large_text_changed.connect(func(_enabled: bool) -> void: _apply_text_size())


func add_line(text: String, color: Color = TEXT_COLOR) -> void:
	push_color(color)
	add_text(text)
	pop()
	newline()


## Détail des jets, sous la ligne principale.
func add_detail(text: String) -> void:
	push_font_size(Settings.font_size(13, 16))
	push_color(DETAIL_COLOR)
	add_text("   " + text)
	pop()
	pop()
	newline()


## En-tête de round, séparé du round précédent par une ligne vide.
func add_header(text: String) -> void:
	if get_line_count() > 1:
		newline()
	push_bold()
	push_color(HEADER_COLOR)
	add_text("— %s —" % text)
	pop()
	pop()
	newline()


func _apply_text_size() -> void:
	add_theme_font_size_override(&"normal_font_size", Settings.font_size(15, 19))
	add_theme_font_size_override(&"bold_font_size", Settings.font_size(16, 20))

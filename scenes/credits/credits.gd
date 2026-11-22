## Écran Crédits : attribution du SRD 5.2.1, licence de Godot Engine et de
## ses composants tiers, outils utilisés.
##
## Les licences de Godot sont lues à l'exécution (`Engine.get_*`) : elles
## restent exactes à chaque mise à jour du moteur, sans copie à maintenir.
extends Control

const HEADING_COLOR := Color(1.0, 0.85, 0.3)
const MUTED_COLOR := Color(0.65, 0.65, 0.65)

@onready var _title_label: Label = %CreditsTitle
@onready var _body: RichTextLabel = %CreditsBody
@onready var _back_button: Button = %CreditsBackButton


func _ready() -> void:
	_title_label.text = Texts.CREDITS
	_back_button.text = Texts.BACK
	_back_button.pressed.connect(_back)
	_fill()
	_back_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_back()


func _back() -> void:
	SceneRouter.go_to(SceneRouter.MENU)


func _fill() -> void:
	_body.clear()
	_heading(str(ProjectSettings.get_setting("application/config/name")))

	_heading(Texts.CREDITS_RULES)
	_paragraph(Texts.SRD_ATTRIBUTION)

	_heading(Texts.CREDITS_ENGINE)
	_paragraph("Godot Engine %s — https://godotengine.org" % Engine.get_version_info()["string"])
	_paragraph(Engine.get_license_text(), MUTED_COLOR)

	_heading(Texts.CREDITS_ASSETS)
	_paragraph(Texts.CREDITS_ASSETS_BODY)

	_heading(Texts.CREDITS_TOOLS)
	_paragraph(Texts.CREDITS_TOOLS_BODY)

	_heading(Texts.CREDITS_THIRD_PARTY)
	for component: Dictionary in Engine.get_copyright_info():
		var lines: PackedStringArray = [component["name"]]
		for part: Dictionary in component["parts"]:
			for copyright: String in part["copyright"]:
				lines.append("© " + copyright)
			lines.append("Licence : " + str(part["license"]))
		_paragraph("\n".join(lines), MUTED_COLOR)

	_heading(Texts.CREDITS_LICENSES)
	var licenses: Dictionary = Engine.get_license_info()
	for name: String in licenses:
		_subheading(name)
		_paragraph(licenses[name], MUTED_COLOR)
	_body.scroll_to_line(0)


func _heading(text: String) -> void:
	_body.push_font_size(26)
	_body.push_color(HEADING_COLOR)
	_body.add_text(text)
	_body.pop()
	_body.pop()
	_body.add_text("\n\n")


func _subheading(text: String) -> void:
	_body.push_color(HEADING_COLOR)
	_body.add_text(text)
	_body.pop()
	_body.add_text("\n")


func _paragraph(text: String, color: Color = Color(0.92, 0.9, 0.86)) -> void:
	_body.push_color(color)
	# add_text n'interprète pas le BBCode : les textes de licence s'affichent
	# tels quels, crochets compris.
	_body.add_text(text)
	_body.pop()
	_body.add_text("\n\n")

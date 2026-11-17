## Écran titre provisoire du jalon J0.
##
## Il sert seulement à vérifier que le projet se lance. Le vrai écran titre
## (avec « Appuyez sur une touche » et le passage au menu) arrive au J4.
##
## Note Godot : `extends Control` équivaut à hériter d'une classe de base.
## Un script est attaché à un Node de la scène, un peu comme un controller
## attaché à une vue, mais le Node *est* l'objet affiché.
extends Control

@onready var _title_label: Label = %TitleLabel


func _ready() -> void:
	# ProjectSettings lit les valeurs de project.godot (ici config/name).
	_title_label.text = str(ProjectSettings.get_setting("application/config/name"))

## L'histoire : les étapes et celle par laquelle on commence.
##
## Ajouter un chapitre = ajouter des étapes ici et les relier par leurs ids.
class_name StoryDef
extends Resource

@export var first_step: StringName
@export var steps: Array[StoryStep] = []


## Renvoie l'étape d'id `step_id`, ou `null` si elle n'existe pas.
func get_step(step_id: StringName) -> StoryStep:
	for step in steps:
		if step.id == step_id:
			return step
	return null

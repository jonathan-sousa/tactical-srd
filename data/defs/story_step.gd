## Une étape de l'histoire : un dialogue ou une rencontre, et où aller ensuite.
class_name StoryStep
extends Resource

enum Kind { DIALOGUE, ENCOUNTER }

## Identifiant stable, c'est lui que la sauvegarde retient.
@export var id: StringName
@export var kind: StoryStep.Kind = StoryStep.Kind.DIALOGUE
## Renseigné quand `kind` vaut DIALOGUE.
@export var dialogue: DialogueDef
## Renseigné quand `kind` vaut ENCOUNTER.
@export var encounter: EncounterDef
## Étape suivante après le dialogue, ou après une victoire. Vide = fin de
## l'histoire.
@export var next_step: StringName
## Le groupe prend un repos court en arrivant à cette étape (SRD « Short
## Rest », voir ShortRest), entre deux combats.
@export var short_rest: bool = false
## Étape suivante après une défaite. Vide = écran de défaite standard
## (« Réessayer le combat » / « Menu principal »).
@export var defeat_step: StringName


func is_end() -> bool:
	return next_step.is_empty()

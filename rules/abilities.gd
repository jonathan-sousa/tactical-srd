## Les six caractéristiques et le calcul de leur modificateur (SRD 5.2.1).
##
## Note Godot : `class_name` enregistre la classe dans un namespace global,
## comme une constante Ruby chargée automatiquement : on écrit `Abilities`
## partout sans `require` ni `preload`.
class_name Abilities
extends RefCounted

enum Ability { STRENGTH, DEXTERITY, CONSTITUTION, INTELLIGENCE, WISDOM, CHARISMA }


## Modificateur = (valeur - 10) / 2, arrondi à l'inférieur.
##
## Piège GDScript : la division entière arrondit vers zéro, donc
## `(7 - 10) / 2` vaut -1 au lieu de -2. On divise en flottant puis on
## arrondit explicitement à l'inférieur avec `floori`.
static func modifier(score: int) -> int:
	return floori((score - 10) / 2.0)

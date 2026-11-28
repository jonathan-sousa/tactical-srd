## État de santé d'un combattant vu de l'extérieur : ce qu'on montre des
## ennemis quand leurs PV exacts sont masqués (réglage « PV ennemis exacts »).
##
## Le seuil vient du SRD (« Bloodied ») : « A creature is Bloodied while it
## has half its Hit Points or fewer remaining. » Au-dessus, on distingue
## seulement indemne et blessé.
class_name HealthStatus
extends RefCounted

enum Status {
	## PV au maximum.
	UNHURT,
	## Moins que le maximum, plus de la moitié.
	WOUNDED,
	## La moitié de ses PV ou moins (« Bloodied »), au moins 1 PV.
	BLOODIED,
	## 0 PV : inconscient ou mort.
	DOWN,
}

## Remplissage de la barre de PV pour chaque état, de 0.0 à 1.0 : la barre
## d'un ennemi montre l'état, pas le chiffre.
const BAR_FRACTIONS: Dictionary[Status, float] = {
	Status.UNHURT: 1.0,
	Status.WOUNDED: 0.75,
	Status.BLOODIED: 0.3,
	Status.DOWN: 0.0,
}


static func of(hp: int, max_hp: int) -> Status:
	if hp <= 0:
		return Status.DOWN
	if hp >= max_hp:
		return Status.UNHURT
	# hp ≤ max / 2, sans division : 3 PV sur 7 est en sang, 4 ne l'est pas.
	if hp * 2 <= max_hp:
		return Status.BLOODIED
	return Status.WOUNDED


static func of_combatant(combatant: Combatant) -> Status:
	if combatant.is_dead:
		return Status.DOWN
	return of(combatant.hp, combatant.definition.max_hp)


static func bar_fraction(status: Status) -> float:
	return BAR_FRACTIONS[status]

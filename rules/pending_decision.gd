## Une décision attendue d'un combattant au milieu d'une action : réagir à
## un ennemi qui s'éloigne, relancer un dé raté… Tant qu'elle est ouverte
## (CombatState.pending), l'action en cours est suspendue et seules les
## actions qui y répondent sont possibles (voir Action.answers).
class_name PendingDecision
extends RefCounted

## Combattant qui doit décider.
var decider: Combatant

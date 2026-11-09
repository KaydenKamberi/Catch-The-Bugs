class_name MoveData
extends Resource
## One move a form can use, like "Bite" or "Call for Help".
## Every form has two: Move 1 (left click) and Move 2 (right click).

## What the move does when you use it.
enum Effect {
	MELEE,          ## Hit whatever is right in front of you.
	SUMMON_ALLIES,  ## Bring friendly bugs that fight enemies for a while.
}

@export var move_name: String = ""
@export var effect: Effect = Effect.MELEE
## Damage per hit (MELEE only).
@export var damage: int = 0
## Seconds before you can use this move again.
@export var cooldown: float = 1.0

@export_group("Melee")
## How far in front of you the hit reaches, in meters.
@export var reach: float = 1.0

@export_group("Summon Allies")
## The bug scene to summon (it's turned friendly when it appears).
@export var summon_scene: PackedScene
@export var summon_min: int = 1
@export var summon_max: int = 2
## How long the helpers stay, in seconds.
@export var summon_lifetime: float = 10.0
## How far from you they appear, in meters.
@export var summon_distance: float = 2.5


## A short line for the HUD, like "3 dmg" or "1-2 helpers, 10 s".
func get_summary() -> String:
	match effect:
		Effect.MELEE:
			return "%d dmg" % damage
		Effect.SUMMON_ALLIES:
			return "%d-%d helpers, %d s" % [summon_min, summon_max, int(summon_lifetime)]
	return ""

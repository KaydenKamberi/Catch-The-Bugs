class_name Ant
extends BugEnemy
## The ant. It does everything a BugEnemy does (wander, chase, Bite, drops),
## plus one special ability:
##
## CALL FOR HELP: the first time it gets hurt, it may call 1-2 more ants.
## Ants that were called for help can't call for help themselves,
## so you never get an endless swarm.
##
## The Bite attack is the normal BugEnemy attack: set "Attack Damage" (3) and
## "Attack Cooldown" (1 s) in the Inspector.

@export_group("Call for Help")
## Turned off automatically for ants that were called as helpers.
@export var can_call_for_help: bool = true
## Chance to call for help on the first hit (0.5 = 50%).
@export_range(0.0, 1.0) var call_for_help_chance: float = 0.5
@export var min_helpers: int = 1
@export var max_helpers: int = 2
## How far away the helpers appear, in meters.
@export var helper_spawn_distance: float = 4.0


func _on_first_hit() -> void:
	if not can_call_for_help:
		return
	if randf() >= call_for_help_chance:
		return  # no luck this time

	# `scene_file_path` is the scene this ant was made from (scenes/enemies/ant.tscn),
	# so the helpers are exact copies of this ant.
	var ant_scene: PackedScene = load(scene_file_path)
	var helper_count: int = randi_range(min_helpers, max_helpers)

	for i in helper_count:
		var helper := ant_scene.instantiate() as Ant
		helper.can_call_for_help = false
		# Helpers show up already angry, so they run straight at the player.
		helper.state = State.CHASE
		# Place each helper at a random spot in a circle around this ant.
		var angle: float = randf() * TAU
		# (y = 0.5 puts it a little above the ground, so it doesn't start inside the floor.)
		var offset := Vector3(cos(angle) * helper_spawn_distance, 0.5, sin(angle) * helper_spawn_distance)
		add_sibling_at(helper, global_position + offset)

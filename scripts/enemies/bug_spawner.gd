extends Node3D
## Keeps making bugs around itself, like an ant hill. Works with any bug scene.
##
## It only counts the bugs it made itself, and never keeps more than
## `max_alive` of them alive at once. When one dies, a new one comes after
## `spawn_interval` seconds.

## The bug to spawn (e.g. scenes/enemies/ant.tscn).
@export var bug_scene: PackedScene
## The most bugs from this spawner that can be alive at the same time.
@export var max_alive: int = 3
## Seconds between spawns.
@export var spawn_interval: float = 8.0
## How far from the center the bugs appear, in meters.
@export var spawn_radius: float = 4.5

var alive_count: int = 0
var time_until_spawn: float = 0.0  # 0 = spawn the first bug right away


func _physics_process(delta: float) -> void:
	time_until_spawn -= delta
	if time_until_spawn <= 0.0:
		time_until_spawn = spawn_interval
		if alive_count < max_alive and bug_scene != null:
			spawn_bug()


func spawn_bug() -> void:
	var bug := bug_scene.instantiate() as BugEnemy
	# Count it down again when it dies.
	bug.died.connect(_on_bug_died)
	alive_count += 1

	# A random spot on a circle around us, a little above the ground.
	var angle: float = randf() * TAU
	var spawn_position := global_position + Vector3(cos(angle) * spawn_radius, 0.5, sin(angle) * spawn_radius)
	var parent := get_parent() as Node3D
	bug.position = parent.to_local(spawn_position)
	parent.add_child.call_deferred(bug)


func _on_bug_died(_bug: BugEnemy) -> void:
	alive_count -= 1

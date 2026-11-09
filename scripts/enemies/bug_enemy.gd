class_name BugEnemy
extends CharacterBody3D
## The shared brain for every bug: health, wandering, chasing, attacking,
## flashing red when hit, dying, and dropping loot.
##
## To make a NEW bug:
##   1. Make a scene with a CharacterBody3D root, a CollisionShape3D, and a
##      node called "Body" holding the meshes (the front of the bug faces -Z).
##      (The ant uses an instance of scenes/enemies/ant_model.tscn as its Body.)
##   2. Attach this script (or a script that starts with `extends BugEnemy`,
##      like ant.gd, if the bug needs a special ability).
##   3. Set the numbers and drop names in the Inspector.
##   (When you place a bug in a level, move it but don't rotate it. The script
##   turns the Body by itself.)
##
## A normal (enemy) bug is always in one of two moods ("states"):
##   WANDER - strolls to random spots near where it started.
##   CHASE  - runs at its target (usually the player) and attacks when close.
## If something hits it, that thing becomes its target, so it fights back.
##
## An ALLY bug (is_ally = true) is friendly: it's summoned by the player
## (the ant form's Call for Help), hunts the nearest enemy, follows the player
## when there's nothing to fight, and disappears after `ally_lifetime` seconds.

## Sent just before the bug disappears (killed, not when an ally's time runs out).
signal died(enemy: BugEnemy)

enum State { WANDER, CHASE }

@export_group("Health")
@export var max_health: int = 12

@export_group("Movement")
## Walking speed while wandering (m/s).
@export var wander_speed: float = 2.0
## Running speed while chasing (m/s).
@export var chase_speed: float = 4.5
## How far from its starting spot it will wander, in meters.
@export var wander_radius: float = 8.0
## How long it stands still between walks (a random time in this range, in seconds).
@export var wander_pause_min: float = 1.0
@export var wander_pause_max: float = 3.0
## How quickly it turns to face where it's going.
@export var turn_speed: float = 8.0
## How quickly it speeds up and slows down.
@export var acceleration: float = 20.0

@export_group("Combat")
## Starts chasing when the player is closer than this (meters).
@export var detection_range: float = 10.0
## Gives up chasing when its target is farther than this (meters).
@export var lose_interest_range: float = 18.0
## Attacks when the target is closer than this (meters, measured feet to feet).
@export var attack_range: float = 1.8
## Damage per attack.
@export var attack_damage: int = 3
## Seconds between attacks.
@export var attack_cooldown: float = 1.0
## How long the red "I got hit" flash lasts, in seconds.
@export var hit_flash_time: float = 0.12

@export_group("Ally")
## True for friendly bugs summoned by the player. Set before the bug is added.
@export var is_ally: bool = false
## Seconds an ally stays before disappearing.
@export var ally_lifetime: float = 10.0
## Allies look for enemies this close to them (meters).
@export var ally_search_range: float = 14.0
## With nothing to fight, allies stay about this close to the player (meters).
@export var ally_follow_distance: float = 3.0
## Allies are painted this color so you can tell them apart.
@export var ally_color: Color = Color(0.25, 0.65, 0.3)

@export_group("Drops")
## Always dropped when the bug dies.
@export var parts_item_name: String = "Ant Parts"
@export var parts_amount: int = 1
@export var parts_color: Color = Color(0.55, 0.25, 0.15)
## Sometimes dropped when the bug dies.
@export var token_item_name: String = "Ant Token"
@export_range(0.0, 1.0) var token_drop_chance: float = 0.7
@export var token_color: Color = Color(1.0, 0.8, 0.2)
## The scene used for dropped items.
@export var pickup_scene: PackedScene = preload("res://scenes/items/pickup.tscn")

@onready var body: Node3D = $Body

var health: int
var state: State = State.WANDER
var player: Player
## Who we're chasing and attacking right now (the player, an ally, or an enemy).
var target: Node3D = null
var is_dead: bool = false
var has_been_hit: bool = false

# Wandering
var home_position: Vector3     # where the bug started; it wanders around here
var wander_target: Vector3     # the spot it's walking to right now
var wander_time_left: float    # gives up on a spot after a while (in case it's stuck)
var pause_time_left: float = 0.0

# Combat
var attack_cooldown_left: float = 0.0
var flash_time_left: float = 0.0
var flash_material: StandardMaterial3D
var meshes: Array[Node] = []

# Allies
var ally_time_left: float = 0.0
var retarget_time_left: float = 0.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	health = max_health
	home_position = global_position
	# The player scene is in the "player" group, so we can find it from anywhere.
	player = get_tree().get_first_node_in_group("player") as Player

	# The red flash: a see-through red layer drawn on top of every mesh of the bug.
	flash_material = StandardMaterial3D.new()
	flash_material.albedo_color = Color(1.0, 0.1, 0.1, 0.6)
	flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	meshes = body.find_children("*", "MeshInstance3D", true, false)

	# Start facing a random direction, so the bugs don't all look the same way.
	body.rotation.y = randf() * TAU

	if is_ally:
		_become_ally()
	_pick_wander_target()


## Switch this bug to the player's side.
func _become_ally() -> void:
	ally_time_left = ally_lifetime
	remove_from_group("enemies")
	add_to_group("allies")
	# Layer 5 is "Allies". The player's attacks only hit layer 3 ("Enemies"),
	# so you can't hurt your own helpers. Allies bump into the world (1),
	# enemies (4) and other allies (16), but walk through the player.
	collision_layer = 16
	collision_mask = 1 | 4 | 16
	# Paint it a different color.
	var ally_material := StandardMaterial3D.new()
	ally_material.albedo_color = ally_color
	ally_material.roughness = 0.4
	for mesh in meshes:
		(mesh as MeshInstance3D).material_override = ally_material


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Count down our timers.
	attack_cooldown_left -= delta
	if flash_time_left > 0.0:
		flash_time_left -= delta
		if flash_time_left <= 0.0:
			_set_flash(false)

	# Forget a target that died or disappeared.
	if not _is_target_valid():
		target = null

	if is_ally:
		_ally_think(delta)
	else:
		_enemy_think(delta)

	move_and_slide()


# ---------------------------------------------------------------------------
# Thinking
# ---------------------------------------------------------------------------

## A normal (enemy) bug: wander until the player comes close, then chase.
func _enemy_think(delta: float) -> void:
	match state:
		State.WANDER:
			if player != null and global_position.distance_to(player.global_position) < detection_range:
				state = State.CHASE
				target = player
			else:
				_wander(delta)
		State.CHASE:
			if target == null:
				target = player
			if target == null or global_position.distance_to(target.global_position) > lose_interest_range:
				# Lost them: go back to wandering.
				state = State.WANDER
				target = null
				_pick_wander_target()
			else:
				_chase_target(delta)


## An ally bug: fight the nearest enemy, otherwise stay near the player.
func _ally_think(delta: float) -> void:
	ally_time_left -= delta
	if ally_time_left <= 0.0:
		_vanish()  # time's up
		return

	# Look around for the nearest enemy twice a second.
	retarget_time_left -= delta
	if target == null or retarget_time_left <= 0.0:
		retarget_time_left = 0.5
		target = _find_nearest_enemy()

	if target != null:
		_chase_target(delta)
	elif player != null:
		var to_player: Vector3 = player.global_position - global_position
		to_player.y = 0.0
		if to_player.length() > ally_follow_distance:
			_move(to_player.normalized() * chase_speed, delta)
		else:
			_move(Vector3.ZERO, delta)


func _find_nearest_enemy() -> Node3D:
	var nearest: Node3D = null
	var nearest_distance: float = ally_search_range
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as BugEnemy
		if enemy == null or enemy.is_dead:
			continue
		var distance: float = global_position.distance_to(enemy.global_position)
		if distance < nearest_distance:
			nearest = enemy
			nearest_distance = distance
	return nearest


func _is_target_valid() -> bool:
	if not is_instance_valid(target):
		return false
	if target is BugEnemy and (target as BugEnemy).is_dead:
		return false
	return true


## True if this bug is an enemy that's currently chasing `node`.
## The player uses this to know whether it's "in combat".
func is_chasing(node: Node3D) -> bool:
	return not is_dead and not is_ally and state == State.CHASE and target == node


func _wander(delta: float) -> void:
	# Standing still for a moment?
	if pause_time_left > 0.0:
		pause_time_left -= delta
		_move(Vector3.ZERO, delta)
		if pause_time_left <= 0.0:
			_pick_wander_target()
		return

	var to_target: Vector3 = wander_target - global_position
	to_target.y = 0.0
	wander_time_left -= delta

	# Arrived (or took too long, probably stuck on something)? Take a break.
	if to_target.length() < 0.6 or wander_time_left <= 0.0:
		pause_time_left = randf_range(wander_pause_min, wander_pause_max)
		_move(Vector3.ZERO, delta)
	else:
		_move(to_target.normalized() * wander_speed, delta)


## Run at the target, and attack when close enough.
func _chase_target(delta: float) -> void:
	var to_target: Vector3 = target.global_position - global_position
	var flat_direction: Vector3 = Vector3(to_target.x, 0.0, to_target.z).normalized()

	if to_target.length() <= attack_range:
		# Close enough: stop, look at the target, and attack when ready.
		_move(Vector3.ZERO, delta)
		_face(flat_direction, delta)
		if attack_cooldown_left <= 0.0:
			attack_cooldown_left = attack_cooldown
			_attack()
	else:
		_move(flat_direction * chase_speed, delta)


## Choose a random spot near home to walk to.
func _pick_wander_target() -> void:
	var angle: float = randf() * TAU
	var distance: float = randf() * wander_radius
	wander_target = home_position + Vector3(cos(angle), 0.0, sin(angle)) * distance
	wander_time_left = 6.0


# ---------------------------------------------------------------------------
# Moving and turning
# ---------------------------------------------------------------------------

## Smoothly change our sideways speed toward `target_velocity`, and face that way.
func _move(target_velocity: Vector3, delta: float) -> void:
	var horizontal: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	horizontal = horizontal.move_toward(target_velocity, acceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if target_velocity.length() > 0.1:
		_face(target_velocity.normalized(), delta)


## Turn the body a little toward `direction` (same math as the player).
func _face(direction: Vector3, delta: float) -> void:
	if direction.length() < 0.01:
		return
	var target_angle: float = atan2(-direction.x, -direction.z)
	body.rotation.y = lerp_angle(body.rotation.y, target_angle, minf(turn_speed * delta, 1.0))


# ---------------------------------------------------------------------------
# Combat
# ---------------------------------------------------------------------------

## Hurt the target (for the ant this is its Bite). A bug with a special
## attack can replace this function.
func _attack() -> void:
	if target.has_method("take_damage"):
		target.take_damage(attack_damage, self)
	# A quick lunge forward and back, so you can see the attack happen.
	var forward: Vector3 = body.basis * Vector3(0.0, 0.0, -0.35)
	var tween := create_tween()
	tween.tween_property(body, "position", forward, 0.08)
	tween.tween_property(body, "position", Vector3.ZERO, 0.15)


## Called by anything that hurts this bug. `source` is who did it (the player or
## another bug), so we can fight back.
func take_damage(amount: int, source: Node = null) -> void:
	if is_dead:
		return
	health -= amount
	_set_flash(true)
	flash_time_left = hit_flash_time

	# Enemies get angry and go after whoever hit them.
	if not is_ally:
		state = State.CHASE
		if source is Node3D:
			target = source

	if not has_been_hit:
		has_been_hit = true
		_on_first_hit()

	if health <= 0:
		die()


## Runs the first time this bug gets hurt. Empty here; special bugs (like the
## ant's Call for Help) fill it in by writing their own `_on_first_hit`.
func _on_first_hit() -> void:
	pass


func die() -> void:
	if is_dead:
		return
	died.emit(self)
	if not is_ally:
		_spawn_drops()  # allies don't drop loot
	_vanish()


## Stop thinking, stop colliding, then shrink away and delete ourselves.
func _vanish() -> void:
	is_dead = true
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	var tween := create_tween()
	tween.tween_property(body, "scale", Vector3.ONE * 0.05, 0.25)
	tween.tween_callback(queue_free)


func _set_flash(on: bool) -> void:
	for mesh in meshes:
		(mesh as MeshInstance3D).material_overlay = flash_material if on else null


# ---------------------------------------------------------------------------
# Drops
# ---------------------------------------------------------------------------

func _spawn_drops() -> void:
	# Parts: always.
	spawn_pickup(parts_item_name, parts_amount, parts_color, false)
	# Token: only sometimes. randf() is a random number from 0 to 1.
	if randf() < token_drop_chance:
		spawn_pickup(token_item_name, 1, token_color, true)


## Put a floating pickup in the world near this bug.
func spawn_pickup(item_name: String, amount: int, color: Color, is_token: bool) -> void:
	var pickup := pickup_scene.instantiate() as Node3D
	pickup.item_name = item_name
	pickup.amount = amount
	pickup.color = color
	pickup.is_token = is_token

	# A random spot around the bug, floating a little above the ground.
	var offset := Vector3(randf_range(-0.8, 0.8), 0.7, randf_range(-0.8, 0.8))
	add_sibling_at(pickup, global_position + offset)


## Add `node` next to this bug in the scene tree (so it stays when we're gone),
## at a position in the world. Used for drops and for bugs that spawn helpers.
func add_sibling_at(node: Node3D, world_position: Vector3) -> void:
	var parent := get_parent() as Node3D
	node.position = parent.to_local(world_position)
	# "call_deferred" waits until the end of the frame, which is the safe time
	# to add physics objects.
	parent.add_child.call_deferred(node)

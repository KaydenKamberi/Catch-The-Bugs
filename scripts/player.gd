class_name Player
extends CharacterBody3D
## The tiny human: walks, sprints, jumps, and fights with a spear.
## The camera orbits behind the player on a SpringArm3D, and the mouse turns it.
##
## Scene layout this script expects (see scenes/player.tscn):
##   Player (CharacterBody3D)   <- this script
##   ├─ CollisionShape3D        (capsule)
##   ├─ Body (Node3D)           <- the visible model; we turn this to face where we walk
##   │  ├─ Spear (Node3D)       <- the weapon in our hand
##   │  └─ AttackHitbox (Area3D) <- the zone in front of us that the spear hits
##   └─ CameraPivot (Node3D)    <- turns left/right (yaw) with the mouse
##      └─ SpringArm3D          <- tilts up/down (pitch), pulls the camera in front of walls
##         └─ Camera3D

## Sent whenever our health changes (the HUD listens to this).
signal health_changed(current: int, maximum: int)
## Sent when we craft and put on a new weapon or armor (the HUD listens to this).
signal equipment_changed


# ---------------------------------------------------------------------------
# Settings you can tweak in the Inspector (click the Player node).
# ---------------------------------------------------------------------------

@export_group("Health")
@export var max_health: int = 100

@export_group("Combat")
## True while we're a human. Later, when we shapeshift into a bug, this becomes
## false and the spear is put away.
@export var is_human: bool = true
## The name of the weapon we start with. Crafting a better one replaces it.
@export var weapon_name: String = "Wooden Spear"
## Damage per spear hit.
@export var attack_damage: int = 5
## Seconds you have to wait between attacks.
@export var attack_cooldown: float = 0.5
## Seconds from the click until the hit lands (the middle of the thrust).
@export var attack_hit_delay: float = 0.1

@export_group("Movement")
## Normal walking speed, in meters per second.
@export var walk_speed: float = 5.0
## Speed while holding Shift.
@export var sprint_speed: float = 9.0
## How high a jump goes, in meters. (The player is 1.8 m tall.)
@export var jump_height: float = 1.6
## How fast we speed up when a movement key is held (meters per second, per second).
@export var acceleration: float = 30.0
## How fast we slow down when no movement key is held.
@export var deceleration: float = 40.0
## How much control you have in the air (0 = none, 1 = same as on the ground).
@export_range(0.0, 1.0) var air_control: float = 0.35
## How quickly the body turns to face the direction we're moving.
@export var turn_speed: float = 12.0

@export_group("Camera")
## How much the camera turns per pixel of mouse movement.
@export var mouse_sensitivity: float = 0.003
## How far the camera can look down, in degrees (negative = down).
@export var min_pitch_degrees: float = -70.0
## How far the camera can look up, in degrees.
@export var max_pitch_degrees: float = 30.0


# ---------------------------------------------------------------------------
# Node references. "@onready" means: fill these in when the scene is ready.
# ---------------------------------------------------------------------------

@onready var body: Node3D = $Body
@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var spear: Node3D = $Body/Spear
@onready var attack_hitbox: Area3D = $Body/AttackHitbox
@onready var spear_tip: MeshInstance3D = $Body/Spear/Tip
@onready var torso: MeshInstance3D = $Body/Torso

# Gravity strength, read from Project Settings > Physics > 3D (9.8 by default).
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var health: int = 100
var spawn_position: Vector3        # where we respawn after dying
var attack_cooldown_left: float = 0.0
var attack_facing_time_left: float = 0.0  # while > 0, face the camera direction
var spear_rest_position: Vector3   # where the spear sits when we're not attacking

# What we've crafted and are wearing (null = nothing crafted yet).
var weapon_recipe: Recipe = null
var armor_recipe: Recipe = null


func _ready() -> void:
	# Hide the mouse and lock it to the window so it can turn the camera.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Stop the spring arm from "hitting" our own capsule and zooming in on us.
	spring_arm.add_excluded_object(get_rid())

	health = max_health
	health_changed.emit(health, max_health)
	spawn_position = global_position
	spear_rest_position = spear.position
	spear.visible = is_human


func _unhandled_input(event: InputEvent) -> void:
	# Esc ("ui_cancel" is Godot's built-in action for Esc) frees the mouse.
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Clicking in the window captures the mouse again (this click doesn't attack).
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Left click (the "attack" action) while the mouse is captured: attack!
	elif event.is_action_pressed("attack"):
		attack()

	# Moving the mouse turns the camera, but only while the mouse is captured.
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Left/right: spin the pivot around the vertical (Y) axis.
		camera_pivot.rotation.y -= event.relative.x * mouse_sensitivity
		# Up/down: tilt the spring arm around its X axis, and stop it going too far.
		spring_arm.rotation.x -= event.relative.y * mouse_sensitivity
		spring_arm.rotation.x = clamp(
			spring_arm.rotation.x,
			deg_to_rad(min_pitch_degrees),
			deg_to_rad(max_pitch_degrees)
		)


func _physics_process(delta: float) -> void:
	# --- 0. Count down the attack timers. ---
	attack_cooldown_left -= delta
	attack_facing_time_left -= delta

	# --- 1. Gravity: pull us down while we're in the air. ---
	if not is_on_floor():
		velocity.y -= gravity * delta

	# --- 2. Jump: only when standing on something. ---
	if Input.is_action_just_pressed("jump") and is_on_floor():
		# Physics formula: the upward speed needed to reach a given height.
		velocity.y = sqrt(2.0 * gravity * jump_height)

	# --- 3. Work out which way the keys are pushing us. ---
	# get_vector gives a 2D direction: x = left/right, y = forward/back.
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# Turn it into 3D (on the ground plane), then rotate it to match where the
	# camera is looking, so "W" always means "away from the camera".
	var direction: Vector3 = Vector3(input_dir.x, 0.0, input_dir.y).rotated(Vector3.UP, camera_pivot.rotation.y)

	# --- 4. Speed up or slow down smoothly. ---
	var speed: float = sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	var target_velocity: Vector3 = direction * speed

	# Pick the rate: speeding up or slowing down, and less of it in the air.
	var rate: float = acceleration if direction.length() > 0.0 else deceleration
	if not is_on_floor():
		rate *= air_control

	# Only change the sideways (x/z) part of our speed here; y belongs to gravity/jumping.
	# move_toward changes it a small step each frame, never overshooting the target.
	var horizontal_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	horizontal_velocity = horizontal_velocity.move_toward(target_velocity, rate * delta)
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z

	# --- 5. Turn the body to face the way we're moving. ---
	if attack_facing_time_left > 0.0:
		# While attacking, keep facing where the camera looks, so you hit what you aim at.
		body.rotation.y = camera_pivot.rotation.y
	elif direction.length() > 0.0:
		# In Godot, "forward" is -Z. This angle points the body's -Z along `direction`.
		var target_angle: float = atan2(-direction.x, -direction.z)
		# lerp_angle turns a little each frame, taking the short way around.
		body.rotation.y = lerp_angle(body.rotation.y, target_angle, minf(turn_speed * delta, 1.0))

	# --- 6. Move! move_and_slide uses `velocity` and slides along walls and ramps. ---
	move_and_slide()


# ---------------------------------------------------------------------------
# Combat
# ---------------------------------------------------------------------------

## Thrust the spear. Anything in the hitbox that can take damage gets hurt.
func attack() -> void:
	if not is_human or attack_cooldown_left > 0.0:
		return
	attack_cooldown_left = attack_cooldown

	# Turn to face where the camera is looking.
	attack_facing_time_left = 0.3
	body.rotation.y = camera_pivot.rotation.y

	# Thrust animation: poke the spear forward, then pull it back.
	var tween := create_tween()
	tween.tween_property(spear, "position", spear_rest_position + Vector3(0.0, 0.0, -0.5), 0.08)
	tween.tween_property(spear, "position", spear_rest_position, 0.15)

	# Wait until the middle of the thrust, then check what's in front of us.
	# ("await" pauses this function without freezing the game.)
	await get_tree().create_timer(attack_hit_delay).timeout
	for hit_body in attack_hitbox.get_overlapping_bodies():
		if hit_body.has_method("take_damage"):
			hit_body.take_damage(attack_damage)


## Called by enemies when they hurt us.
func take_damage(amount: int) -> void:
	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	if health == 0:
		respawn()


## Go back to the start with full health. (Your inventory is kept.)
func respawn() -> void:
	global_position = spawn_position
	velocity = Vector3.ZERO
	health = max_health
	health_changed.emit(health, max_health)


# ---------------------------------------------------------------------------
# Equipment (from crafting)
# ---------------------------------------------------------------------------

## Put on something we just crafted. The crafting menu calls this.
func equip(recipe: Recipe) -> void:
	match recipe.kind:
		Recipe.Kind.WEAPON:
			weapon_recipe = recipe
			weapon_name = recipe.display_name
			attack_damage = recipe.weapon_damage
			_paint(spear_tip, recipe.color)
		Recipe.Kind.ARMOR:
			# If we already wear armor, take its bonus off first.
			if armor_recipe != null:
				max_health -= armor_recipe.bonus_max_health
				health = mini(health, max_health)
			armor_recipe = recipe
			max_health += recipe.bonus_max_health
			health += recipe.bonus_max_health  # the new armor also adds health right away
			_paint(torso, recipe.color)
			health_changed.emit(health, max_health)
	equipment_changed.emit()


## True if this exact recipe is what we're wearing right now.
func is_equipped(recipe: Recipe) -> bool:
	return recipe == weapon_recipe or recipe == armor_recipe


## Change a mesh's color by giving it a new material.
func _paint(mesh: MeshInstance3D, color: Color) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.4
	mesh.material_override = material

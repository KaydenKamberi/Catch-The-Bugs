class_name Player
extends CharacterBody3D
## The tiny human: walks, sprints, jumps, fights, and can shapeshift into bugs.
## The camera orbits behind the player on a SpringArm3D, and the mouse turns it.
##
## CLIMBING AND STAMINA
## Walk into anything in the "climbable" group while holding W to grab it.
## W/S climb up/down, A/D climb sideways, Space jumps off. Sprinting and
## climbing use stamina; it refills after a short rest. At 0 stamina you can't
## sprint and you fall off whatever you're climbing.
##
## Scene layout this script expects (see scenes/player.tscn):
##   Player (CharacterBody3D)   <- this script
##   ├─ CollisionShape3D        (capsule; swapped for a smaller one in bug forms)
##   ├─ Body (Node3D)           <- everything visible; we turn this to face where we walk
##   │  ├─ HumanModel (Node3D)  <- the human body (hidden while we're a bug)
##   │  │  └─ Spear (Node3D)    <- the weapon in our hand
##   │  ├─ (a bug model is added here while shapeshifted)
##   │  └─ AttackHitbox (Area3D) <- the zone in front of us that melee moves hit
##   └─ CameraPivot (Node3D)    <- turns left/right (yaw) with the mouse
##      └─ SpringArm3D          <- tilts up/down (pitch), pulls the camera in front of walls
##         └─ Camera3D
##
## FORMS AND MOVES
## Every form has two moves: Move 1 (left click) and Move 2 (right click).
##   Human: Move 1 = the spear. No Move 2.
##   Bugs:  the moves in their FormData file (data/forms/), e.g. the ant's
##          Bite and Call for Help.
## Swallow a bug token (E) to unlock that bug's form for good. Then use the
## Shapeshift Staff (Q) to switch between Human and any unlocked form,
## but not while you're in combat.

## Sent whenever our health changes (the HUD listens to this).
signal health_changed(current: int, maximum: int)
## Sent whenever our stamina changes (the HUD listens to this).
signal stamina_changed(current: float, maximum: float)
## Sent when we craft and put on a new weapon or armor (the HUD listens to this).
signal equipment_changed
## Sent when we switch forms or unlock a new one.
signal form_changed
## Sent with a short message for the HUD to show, like "Can't switch forms in combat".
signal notice(text: String)

## Every bug form in the game. You unlock each one by swallowing its token.
const FORM_FILES: Array[String] = [
	"res://data/forms/ant_form.tres",
]
## The inventory item that lets you open the form list.
const STAFF_ITEM_NAME: String = "Shapeshift Staff"


# ---------------------------------------------------------------------------
# Settings you can tweak in the Inspector (click the Player node).
# ---------------------------------------------------------------------------

@export_group("Health")
## Sugar Cube upgrades will raise this later.
@export var max_health: int = 100
## Falling below this height (in meters) counts as dying, e.g. off the edge of the map.
@export var fall_death_height: float = -50.0

@export_group("Stamina")
## Sugar Cube upgrades will raise this later.
@export var max_stamina: float = 100.0
## Stamina used per second while sprinting.
@export var sprint_stamina_drain: float = 20.0
## Stamina used per second while climbing.
@export var climb_stamina_drain: float = 12.0
## Stamina gained back per second once it starts refilling.
@export var stamina_regen_rate: float = 30.0
## Seconds after you last used stamina before it starts refilling.
@export var stamina_regen_delay: float = 1.0
## After running out, you can't sprint or climb until stamina is back up to this much.
@export var stamina_recover_amount: float = 20.0

@export_group("Combat")
## The name of the weapon we start with. Crafting a better one replaces it.
@export var weapon_name: String = "Wooden Spear"
## Damage per spear hit.
@export var attack_damage: int = 5
## Seconds you have to wait between spear attacks.
@export var attack_cooldown: float = 0.5
## How far in front of you the spear reaches, in meters.
@export var spear_reach: float = 1.6
## Seconds from the click until a melee hit lands (the middle of the swing).
@export var attack_hit_delay: float = 0.1
## You count as "in combat" for this many seconds after dealing or taking damage.
@export var combat_timeout: float = 5.0

@export_group("Shapeshifting")
## DEBUG: start the game holding the Shapeshift Staff, so you can test forms.
## Turn this off once the staff can be crafted (5 Plant Fiber + Mantis Scythe Arm + Mantis Head).
@export var DEBUG_GIVE_STAFF: bool = true

@export_group("Movement")
## Normal walking speed, in meters per second.
@export var walk_speed: float = 5.0
## Speed while holding Shift.
@export var sprint_speed: float = 9.0
## Upward speed when you jump, in meters per second. Higher = higher jumps.
## (5.6 with gravity 9.8 jumps about 1.6 m. The player is 1.8 m tall.)
@export var jump_strength: float = 5.6
## How fast we fall, in meters per second, per second.
@export var gravity: float = 9.8
## How fast we speed up when a movement key is held (meters per second, per second).
@export var acceleration: float = 30.0
## How fast we slow down when no movement key is held.
@export var deceleration: float = 40.0
## How much control you have in the air (0 = none, 1 = same as on the ground).
@export_range(0.0, 1.0) var air_control: float = 0.35
## How quickly the body turns to face the direction we're moving.
@export var turn_speed: float = 12.0

@export_group("Climbing")
## Speed when climbing up, down or sideways, in meters per second.
@export var climb_speed: float = 2.5
## When you jump off a wall: how hard you're pushed away from it.
@export var climb_jump_push: float = 4.0
## When you jump off a wall: how much you're pushed up.
@export var climb_jump_up: float = 3.0
## Seconds after letting go before you can grab a wall again.
@export var climb_regrab_delay: float = 0.4
## When you climb over the top: how much you're boosted up and onto it.
@export var climb_top_boost: float = 4.5

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
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var human_model: Node3D = $Body/HumanModel
@onready var spear: Node3D = $Body/HumanModel/Spear
@onready var spear_tip: MeshInstance3D = $Body/HumanModel/Spear/Tip
@onready var torso: MeshInstance3D = $Body/HumanModel/Torso
@onready var attack_hitbox: Area3D = $Body/AttackHitbox
@onready var attack_hitbox_shape: CollisionShape3D = $Body/AttackHitbox/CollisionShape3D

var health: int = 100
var stamina: float = 100.0
var stamina_regen_wait: float = 0.0  # seconds left before stamina starts refilling
## True after running out of stamina, until it refills to stamina_recover_amount.
var exhausted: bool = false

# Climbing
var is_climbing: bool = false
var wall_normal: Vector3 = Vector3.ZERO  # points out of the wall, toward us
var climb_regrab_time_left: float = 0.0
var spawn_position: Vector3        # where we respawn after dying
var attack_facing_time_left: float = 0.0  # while > 0, face the camera direction
var spear_rest_position: Vector3   # where the spear sits when we're not attacking
var combat_time_left: float = 0.0  # > 0 means we recently dealt or took damage

# What we've crafted and are wearing (null = nothing crafted yet).
var weapon_recipe: Recipe = null
var armor_recipe: Recipe = null

# Forms
## True while we're a human. Only humans can use the spear.
var is_human: bool = true
var all_forms: Array[FormData] = []
var unlocked_forms: Array[FormData] = []
var current_form: FormData = null     # null while human
var current_form_model: Node3D = null
## The human's Move 1. Built in code, because its damage comes from the crafted spear.
var spear_move: MoveData
## Seconds left before each move can be used again, by move name.
var cooldowns: Dictionary = {}
# The human's size and camera, remembered so we can change back.
var human_collider_shape: Shape3D
var human_collider_y: float
var human_camera_height: float
var human_camera_distance: float


func _ready() -> void:
	# Hide the mouse and lock it to the window so it can turn the camera.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Stop the spring arm from "hitting" our own capsule and zooming in on us.
	spring_arm.add_excluded_object(get_rid())

	health = max_health
	health_changed.emit(health, max_health)
	stamina = max_stamina
	stamina_changed.emit(stamina, max_stamina)
	spawn_position = global_position
	spear_rest_position = spear.position

	# The spear as a move, so the human works like any other form.
	spear_move = MoveData.new()
	spear_move.effect = MoveData.Effect.MELEE
	spear_move.reach = spear_reach
	_update_spear_move()

	for path in FORM_FILES:
		all_forms.append(load(path) as FormData)
	human_collider_shape = collision_shape.shape
	human_collider_y = collision_shape.position.y
	human_camera_height = camera_pivot.position.y
	human_camera_distance = spring_arm.spring_length

	if DEBUG_GIVE_STAFF and not has_staff():
		Inventory.add_item(STAFF_ITEM_NAME, 1)


func _unhandled_input(event: InputEvent) -> void:
	# Esc ("ui_cancel" is Godot's built-in action for Esc) frees the mouse.
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Clicking in the window captures the mouse again (this click doesn't attack).
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Left click: Move 1. Right click: Move 2.
	elif event.is_action_pressed("attack"):
		use_move(1)
	elif event.is_action_pressed("attack_2"):
		use_move(2)

	# E: swallow a bug token.
	elif event.is_action_pressed("swallow_token"):
		try_swallow_token()

	# K (debug): hurt ourselves for 10, to test the health bar and dying.
	elif event.is_action_pressed("debug_damage"):
		take_damage(10)

	# (Q, the staff, is handled by the staff menu: scripts/ui/staff_menu.gd.)

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
	# --- 0. Count down timers. ---
	attack_facing_time_left -= delta
	combat_time_left -= delta
	climb_regrab_time_left -= delta
	for move_name in cooldowns:
		cooldowns[move_name] = maxf(cooldowns[move_name] - delta, 0.0)
	_regen_stamina(delta)

	# Fell off the map? That counts as dying.
	if global_position.y < fall_death_height:
		die()
		return

	# --- 1. Work out which way the keys are pushing us. ---
	# get_vector gives a 2D direction: x = left/right, y = forward/back (forward is -1).
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# Turn it into 3D (on the ground plane), then rotate it to match where the
	# camera is looking, so "W" always means "away from the camera".
	var direction: Vector3 = Vector3(input_dir.x, 0.0, input_dir.y).rotated(Vector3.UP, camera_pivot.rotation.y)

	if is_climbing:
		_climb(delta, input_dir)
	else:
		_walk(delta, direction)
		_try_start_climbing(direction)


## Walking, sprinting, jumping and falling.
func _walk(delta: float, direction: Vector3) -> void:
	# Bug forms move differently, so pick the numbers for our current form.
	var current_walk_speed: float = walk_speed if is_human else current_form.move_speed
	var current_sprint_speed: float = sprint_speed if is_human else current_form.sprint_speed

	# --- 2. Gravity: pull us down while we're in the air. ---
	if not is_on_floor():
		velocity.y -= gravity * delta

	# --- 3. Jump: only when standing on something. ---
	if Input.is_action_just_pressed("jump") and is_on_floor():
		if is_human:
			velocity.y = jump_strength
		else:
			# Physics formula: the upward speed needed to reach the form's jump height.
			velocity.y = sqrt(2.0 * gravity * current_form.jump_height)

	# --- 4. Sprint (uses stamina), then speed up or slow down smoothly. ---
	var is_sprinting: bool = Input.is_action_pressed("sprint") and direction.length() > 0.0 and can_use_stamina()
	if is_sprinting:
		_use_stamina(sprint_stamina_drain * delta)
	var speed: float = current_sprint_speed if is_sprinting else current_walk_speed
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
# Climbing
# ---------------------------------------------------------------------------

## After moving: if we walked into a climbable wall while holding forward, grab it.
func _try_start_climbing(direction: Vector3) -> void:
	if climb_regrab_time_left > 0.0 or not can_use_stamina():
		return
	if not Input.is_action_pressed("move_forward"):
		return
	for i in get_slide_collision_count():
		var collision: KinematicCollision3D = get_slide_collision(i)
		var normal: Vector3 = collision.get_normal()
		if absf(normal.y) > 0.3:
			continue  # that's a floor or a ceiling, not a wall
		if not _is_climbable(collision.get_collider()):
			continue
		var flat_normal: Vector3 = Vector3(normal.x, 0.0, normal.z).normalized()
		if direction.dot(-flat_normal) < 0.5:
			continue  # we're only brushing past it, not walking into it
		is_climbing = true
		wall_normal = flat_normal
		velocity = Vector3.ZERO
		return


## While on a wall: W/S climb up/down, A/D climb sideways, Space jumps off.
func _climb(delta: float, input_dir: Vector2) -> void:
	# Space: let go and push off the wall.
	if Input.is_action_just_pressed("jump"):
		_stop_climbing()
		velocity = wall_normal * climb_jump_push + Vector3.UP * climb_jump_up
		move_and_slide()
		return

	# Holding on is tiring. Out of stamina? We fall off.
	_use_stamina(climb_stamina_drain * delta)
	if stamina <= 0.0:
		_stop_climbing()
		notice.emit("Out of stamina!")
		return

	# Look for the wall in front of us again. Tree trunks are round, so the
	# wall's direction changes as we climb around it.
	var hit: Dictionary = _find_wall()
	if hit.is_empty():
		# The wall ended. If we were climbing up, we reached the top: hop onto it.
		_stop_climbing()
		if input_dir.y < 0.0:
			velocity = Vector3.UP * climb_top_boost - wall_normal * 2.0
		move_and_slide()
		return
	var normal: Vector3 = hit.normal
	wall_normal = Vector3(normal.x, 0.0, normal.z).normalized()

	# Stay snug against the wall: close any gap between us and it.
	var gap: float = (hit.position - collision_shape.global_position).dot(-wall_normal) - _collider_radius()
	if gap > 0.02:
		global_position -= wall_normal * (gap - 0.02)

	# Move along the wall. "Right" is to our right as we face the wall.
	var right: Vector3 = (-wall_normal).cross(Vector3.UP)
	var climb_dir: Vector3 = Vector3.UP * -input_dir.y + right * input_dir.x
	velocity = climb_dir.limit_length(1.0) * climb_speed

	# Face the wall.
	body.rotation.y = atan2(wall_normal.x, wall_normal.z)
	move_and_slide()

	# Climbed all the way back down to the ground? Let go.
	if is_on_floor() and input_dir.y > 0.0:
		_stop_climbing()


func _stop_climbing() -> void:
	if not is_climbing:
		return
	is_climbing = false
	climb_regrab_time_left = climb_regrab_delay


## Cast a short ray from our middle toward the wall. Returns the hit, or {} if
## there's no climbable wall there any more.
func _find_wall() -> Dictionary:
	var origin: Vector3 = collision_shape.global_position
	var reach: float = _collider_radius() + 0.5
	var query := PhysicsRayQueryParameters3D.create(origin, origin - wall_normal * reach, 1)  # layer 1 = World
	query.exclude = [get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or absf(hit.normal.y) > 0.5 or not _is_climbable(hit.collider):
		return {}
	return hit


## How wide our collision capsule is (it's smaller in bug forms).
func _collider_radius() -> float:
	var capsule := collision_shape.shape as CapsuleShape3D
	return capsule.radius if capsule else 0.35


## True if this node (or the node it belongs to) is in the "climbable" group.
func _is_climbable(node: Object) -> bool:
	var n := node as Node
	if n == null:
		return false
	return n.is_in_group("climbable") or (n.get_parent() != null and n.get_parent().is_in_group("climbable"))


# ---------------------------------------------------------------------------
# Stamina
# ---------------------------------------------------------------------------

## True if we have the energy to sprint or climb right now.
func can_use_stamina() -> bool:
	return stamina > 0.0 and not exhausted


func _use_stamina(amount: float) -> void:
	stamina = maxf(stamina - amount, 0.0)
	stamina_regen_wait = stamina_regen_delay
	if stamina == 0.0:
		exhausted = true
	stamina_changed.emit(stamina, max_stamina)


## Refill stamina a little, once we haven't used any for stamina_regen_delay seconds.
func _regen_stamina(delta: float) -> void:
	if stamina_regen_wait > 0.0:
		stamina_regen_wait -= delta
		return
	if stamina >= max_stamina:
		return
	stamina = minf(stamina + stamina_regen_rate * delta, max_stamina)
	if exhausted and stamina >= stamina_recover_amount:
		exhausted = false
	stamina_changed.emit(stamina, max_stamina)


# ---------------------------------------------------------------------------
# Moves
# ---------------------------------------------------------------------------

## The move in slot 1 (left click) or 2 (right click) for our current form.
## Returns null if this form has no move in that slot.
func get_move(slot: int) -> MoveData:
	if is_human:
		return spear_move if slot == 1 else null  # the spear only works in human form
	return current_form.move_1 if slot == 1 else current_form.move_2


## Seconds until a move can be used again (0 = ready).
func get_cooldown_left(move: MoveData) -> float:
	return cooldowns.get(move.move_name, 0.0)


func use_move(slot: int) -> void:
	var move: MoveData = get_move(slot)
	if move == null or get_cooldown_left(move) > 0.0:
		return
	cooldowns[move.move_name] = move.cooldown

	match move.effect:
		MoveData.Effect.MELEE:
			_melee_attack(move)
		MoveData.Effect.SUMMON_ALLIES:
			_summon_allies(move)


## Spear thrust (human) or a lunge (bugs, e.g. Bite). Hurts whatever is in front of us.
func _melee_attack(move: MoveData) -> void:
	# Turn to face where the camera is looking.
	attack_facing_time_left = 0.3
	body.rotation.y = camera_pivot.rotation.y

	# Stretch the hitbox to this move's reach: from 0.3 m in front of us to `reach` further.
	var box := attack_hitbox_shape.shape as BoxShape3D
	box.size.z = move.reach
	attack_hitbox.position.z = -(0.3 + move.reach / 2.0)

	var tween := create_tween()
	if is_human:
		# Thrust animation: poke the spear forward, then pull it back.
		tween.tween_property(spear, "position", spear_rest_position + Vector3(0.0, 0.0, -0.5), 0.08)
		tween.tween_property(spear, "position", spear_rest_position, 0.15)
	else:
		# Lunge animation: move the whole body forward and back.
		var forward: Vector3 = body.basis * Vector3(0.0, 0.0, -0.4)
		tween.tween_property(body, "position", forward, 0.08)
		tween.tween_property(body, "position", Vector3.ZERO, 0.15)

	# Wait until the middle of the attack, then check what's in front of us.
	# ("await" pauses this function without freezing the game.)
	await get_tree().create_timer(attack_hit_delay).timeout
	for hit_body in attack_hitbox.get_overlapping_bodies():
		if hit_body.has_method("take_damage"):
			hit_body.take_damage(move.damage, self)
			combat_time_left = combat_timeout  # dealing damage puts us in combat


## Bring friendly bugs (e.g. Call for Help). They fight enemies, then disappear.
func _summon_allies(move: MoveData) -> void:
	if move.summon_scene == null:
		return
	var count: int = randi_range(move.summon_min, move.summon_max)
	var parent := get_parent() as Node3D
	for i in count:
		var ally := move.summon_scene.instantiate() as BugEnemy
		ally.is_ally = true  # must be set before it's added to the world
		ally.ally_lifetime = move.summon_lifetime
		# A random spot on a circle around us, a little above the ground.
		var angle: float = randf() * TAU
		var spot := global_position + Vector3(cos(angle) * move.summon_distance, 0.5, sin(angle) * move.summon_distance)
		ally.position = parent.to_local(spot)
		parent.add_child.call_deferred(ally)
	notice.emit("%s! %d friendly helper(s) for %d seconds." % [move.move_name, count, int(move.summon_lifetime)])


func _update_spear_move() -> void:
	spear_move.move_name = weapon_name
	spear_move.damage = attack_damage
	spear_move.cooldown = attack_cooldown


# ---------------------------------------------------------------------------
# Health and combat
# ---------------------------------------------------------------------------

## Called by enemies when they hurt us. We keep the same HP in every form.
func take_damage(amount: int, _source: Node = null) -> void:
	combat_time_left = combat_timeout  # taking damage puts us in combat
	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	if health == 0:
		die()


## We're "in combat" if we dealt or took damage recently, or an enemy is chasing us.
func is_in_combat() -> bool:
	if combat_time_left > 0.0:
		return true
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as BugEnemy
		if enemy != null and enemy.is_chasing(self):
			return true
	return false


## We ran out of health (or fell off the map): go back to the start point as a
## human with full health and stamina. (Inventory and unlocked forms are kept.)
func die() -> void:
	_stop_climbing()
	switch_to_form(null)
	global_position = spawn_position
	velocity = Vector3.ZERO
	health = max_health
	stamina = max_stamina
	exhausted = false
	stamina_regen_wait = 0.0
	combat_time_left = 0.0
	health_changed.emit(health, max_health)
	stamina_changed.emit(stamina, max_stamina)
	notice.emit("You died! Back to the start.")


# ---------------------------------------------------------------------------
# Swallowing tokens and the staff
# ---------------------------------------------------------------------------

## E: swallow a token for a form we haven't unlocked yet. It's used up, the
## form is unlocked for good, and we turn into that bug right away.
func try_swallow_token() -> void:
	if is_in_combat():
		notice.emit("Can't swallow tokens in combat")
		return

	var known_form_name: String = ""
	for form in all_forms:
		if Inventory.get_count(form.token_item_name) == 0:
			continue
		if form in unlocked_forms:
			known_form_name = form.form_name  # already unlocked; keep the token
			continue
		Inventory.add_item(form.token_item_name, -1)
		unlocked_forms.append(form)
		switch_to_form(form)
		notice.emit("You swallowed the %s. %s form unlocked!" % [form.token_item_name, form.form_name])
		return

	if known_form_name != "":
		notice.emit("You already know the %s form. Use the staff (Q) to switch." % known_form_name)
	else:
		notice.emit("You have no bug tokens to swallow.")


func has_staff() -> bool:
	return Inventory.get_count(STAFF_ITEM_NAME) > 0


## Why the staff can't be opened right now, or "" if it can.
func get_staff_block_reason() -> String:
	if not has_staff():
		return "You need the Shapeshift Staff to switch forms."
	if is_in_combat():
		return "Can't switch forms in combat"
	return ""


# ---------------------------------------------------------------------------
# Switching forms
# ---------------------------------------------------------------------------

## Become a bug form, or a human again (form = null).
func switch_to_form(form: FormData) -> void:
	if form == current_form:
		return
	if form == null:
		is_human = true
		current_form = null
		collision_shape.shape = human_collider_shape
		collision_shape.position.y = human_collider_y
		_move_camera(human_camera_height, human_camera_distance)
	else:
		is_human = false
		current_form = form
		# Become bug-sized: a smaller collision capsule (its bottom stays at our feet).
		var capsule := CapsuleShape3D.new()
		capsule.radius = form.collider_radius
		capsule.height = form.collider_height
		collision_shape.shape = capsule
		collision_shape.position.y = form.collider_height / 2.0
		_move_camera(form.camera_height, form.camera_distance)
	_swap_model(form)
	form_changed.emit()


## The name of the form we're in right now.
func get_form_name() -> String:
	return "Human" if is_human else current_form.form_name


## "Poof" effect: shrink the body away, swap the model, and grow back.
func _swap_model(form: FormData) -> void:
	var tween := create_tween()
	tween.tween_property(body, "scale", Vector3.ONE * 0.05, 0.12)
	tween.tween_callback(_show_model.bind(form))
	tween.tween_property(body, "scale", Vector3.ONE, 0.18)


## Show the human model (form = null) or a bug model.
func _show_model(form: FormData) -> void:
	if current_form_model != null:
		current_form_model.queue_free()
		current_form_model = null
	human_model.visible = form == null  # this also hides the spear in bug forms
	if form != null:
		current_form_model = form.model_scene.instantiate() as Node3D
		body.add_child(current_form_model)


## Smoothly slide the camera to a new height and distance.
func _move_camera(height: float, distance: float) -> void:
	var tween := create_tween().set_parallel()
	tween.tween_property(camera_pivot, "position:y", height, 0.3)
	tween.tween_property(spring_arm, "spring_length", distance, 0.3)


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
			_update_spear_move()
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

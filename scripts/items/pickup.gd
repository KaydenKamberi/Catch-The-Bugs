extends Area3D
## A small floating item lying in the world. Walk into it to put it in your inventory.
##
## Enemies create these when they die (see `spawn_pickup` in bug_enemy.gd),
## but you can also drag scenes/items/pickup.tscn into a level by hand.

## The name shown in the inventory, e.g. "Ant Parts".
@export var item_name: String = "Ant Parts"
## How many you get when you pick it up.
@export var amount: int = 1
## The color of the pickup (and its little glow).
@export var color: Color = Color(0.55, 0.3, 0.2)
## Tokens look like a spinning coin; everything else looks like a small chunk.
@export var is_token: bool = false

@export_group("Look")
## How far it floats up and down, in meters.
@export var bob_height: float = 0.15
## How fast it floats up and down.
@export var bob_speed: float = 2.5
## How fast it spins, in radians per second.
@export var spin_speed: float = 2.0

@onready var visual: Node3D = $Visual
@onready var chunk_mesh: MeshInstance3D = $Visual/ChunkMesh
@onready var coin_mesh: MeshInstance3D = $Visual/CoinMesh
@onready var glow: OmniLight3D = $Glow

# Used for the floating animation.
var time: float = 0.0


func _ready() -> void:
	# Show the right shape.
	chunk_mesh.visible = not is_token
	coin_mesh.visible = is_token

	# Make a material in code, so every pickup can have its own color.
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true  # glows a little, so it's easy to spot
	material.emission = color
	material.emission_energy_multiplier = 0.6
	if is_token:
		material.metallic = 0.8
		material.roughness = 0.3
	chunk_mesh.material_override = material
	coin_mesh.material_override = material
	glow.light_color = color

	# Start each pickup at a random point in the bobbing, so they don't move in sync.
	time = randf() * TAU

	# Call _on_body_entered whenever a physics body walks into our collision shape.
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	time += delta
	visual.position.y = sin(time * bob_speed) * bob_height
	visual.rotate_y(spin_speed * delta)


func _on_body_entered(body: Node3D) -> void:
	# Only the player can pick things up.
	if body.is_in_group("player"):
		Inventory.add_item(item_name, amount)
		queue_free()  # remove the pickup from the world

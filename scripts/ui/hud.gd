extends CanvasLayer
## The on-screen display: health bar, equipment, inventory counts, and a red flash when hurt.
## It listens to signals instead of checking every frame, so it only updates
## when something actually changes.

@onready var health_bar: ProgressBar = $HealthBar
@onready var health_label: Label = $HealthBar/HealthLabel
@onready var inventory_label: Label = $InventoryLabel
@onready var equipment_label: Label = $EquipmentLabel
@onready var damage_flash: ColorRect = $DamageFlash

var last_health: int = -1
var player: Player


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as Player
	if player:
		player.health_changed.connect(_on_health_changed)
		player.equipment_changed.connect(_on_equipment_changed)
		_on_health_changed(player.health, player.max_health)
		_on_equipment_changed()

	Inventory.changed.connect(_on_inventory_changed)
	_on_inventory_changed()


func _on_health_changed(current: int, maximum: int) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_label.text = "HP %d / %d" % [current, maximum]

	# Lost health? Flash the screen red, then fade it out.
	if last_health != -1 and current < last_health:
		damage_flash.modulate.a = 0.35
		var tween := create_tween()
		tween.tween_property(damage_flash, "modulate:a", 0.0, 0.3)
	last_health = current


func _on_inventory_changed() -> void:
	inventory_label.text = "Inventory: " + Inventory.get_summary()


func _on_equipment_changed() -> void:
	var armor_name: String = player.armor_recipe.display_name if player.armor_recipe else "none"
	equipment_label.text = "Weapon: %s (%d dmg)    Armor: %s" % [player.weapon_name, player.attack_damage, armor_name]

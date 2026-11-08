extends CanvasLayer
## The on-screen display: health bar, equipment, inventory, current form,
## short messages, and a red flash when hurt.
## It listens to signals instead of checking every frame, so it only updates
## when something actually changes.

@onready var health_bar: ProgressBar = $HealthBar
@onready var health_label: Label = $HealthBar/HealthLabel
@onready var inventory_label: Label = $InventoryLabel
@onready var equipment_label: Label = $EquipmentLabel
@onready var form_label: Label = $FormLabel
@onready var notice_label: Label = $NoticeLabel
@onready var damage_flash: ColorRect = $DamageFlash

var last_health: int = -1
var player: Player
var notice_time_left: float = 0.0


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as Player
	if player:
		player.health_changed.connect(_on_health_changed)
		player.equipment_changed.connect(_on_equipment_changed)
		player.notice.connect(_on_notice)
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


func _process(delta: float) -> void:
	# The form line has a countdown, so we update it every frame.
	if player:
		if player.is_human:
			form_label.text = "Form: Human"
		else:
			var form: BugForm = player.current_form
			form_label.text = "Form: %s (%d s left)    %s: %d dmg    Q to change back" % [
				form.form_name, ceili(player.form_time_left), form.attack_name, form.attack_damage]

	# Hide the message after a few seconds.
	if notice_time_left > 0.0:
		notice_time_left -= delta
		if notice_time_left <= 0.0:
			notice_label.text = ""


func _on_notice(text: String) -> void:
	notice_label.text = text
	notice_time_left = 3.0

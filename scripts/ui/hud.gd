extends CanvasLayer
## The on-screen display: health bar, equipment, inventory, current form and its
## two moves with cooldowns, unlocked forms, an "In combat" warning, short
## messages, and a red flash when hurt.
##
## Every Control in hud.tscn has Mouse > Filter set to Ignore, so the HUD never
## blocks your clicks.

@onready var health_bar: ProgressBar = $HealthBar
@onready var health_label: Label = $HealthBar/HealthLabel
@onready var stamina_bar: ProgressBar = $StaminaBar
@onready var stamina_label: Label = $StaminaBar/StaminaLabel
@onready var inventory_label: Label = $InventoryLabel
@onready var equipment_label: Label = $EquipmentLabel
@onready var form_label: Label = $FormLabel
@onready var moves_label: Label = $MovesLabel
@onready var forms_label: Label = $FormsLabel
@onready var combat_label: Label = $CombatLabel
@onready var notice_label: Label = $NoticeLabel
@onready var damage_flash: ColorRect = $DamageFlash

var last_health: int = -1
var player: Player
var notice_time_left: float = 0.0


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as Player
	if player:
		player.health_changed.connect(_on_health_changed)
		player.stamina_changed.connect(_on_stamina_changed)
		player.equipment_changed.connect(_on_equipment_changed)
		player.notice.connect(_on_notice)
		_on_health_changed(player.health, player.max_health)
		_on_stamina_changed(player.stamina, player.max_stamina)
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


func _on_stamina_changed(current: float, maximum: float) -> void:
	stamina_bar.max_value = maximum
	stamina_bar.value = current
	stamina_label.text = "Stamina %d / %d" % [ceili(current), ceili(maximum)]
	# Grey the bar out while we're too tired to sprint or climb.
	stamina_bar.modulate = Color(1, 1, 1, 1) if player.can_use_stamina() else Color(0.6, 0.6, 0.6, 1)


func _on_inventory_changed() -> void:
	inventory_label.text = "Inventory: " + Inventory.get_summary()


func _on_equipment_changed() -> void:
	var armor_name: String = player.armor_recipe.display_name if player.armor_recipe else "none"
	equipment_label.text = "Weapon: %s (%d dmg)    Armor: %s" % [player.weapon_name, player.attack_damage, armor_name]


func _process(delta: float) -> void:
	# Cooldowns tick down every frame, so these lines are updated every frame.
	if player:
		form_label.text = "Form: %s" % player.get_form_name()
		moves_label.text = "%s    %s" % [_move_text(1, "LMB"), _move_text(2, "RMB")]
		forms_label.text = _forms_text()
		combat_label.visible = player.is_in_combat()

	# Hide the message after a few seconds.
	if notice_time_left > 0.0:
		notice_time_left -= delta
		if notice_time_left <= 0.0:
			notice_label.text = ""


## Text like "LMB Bite (3 dmg) ready" or "RMB Call for Help (1-2 helpers, 10 s) 14.2 s".
func _move_text(slot: int, button_name: String) -> String:
	var move: MoveData = player.get_move(slot)
	if move == null:
		return "%s -" % button_name
	var time_left: float = player.get_cooldown_left(move)
	var status: String = "ready" if time_left <= 0.0 else "%.1f s" % time_left
	return "%s %s (%s) %s" % [button_name, move.move_name, move.get_summary(), status]


## Text like "Unlocked forms: Human, Ant    Q: staff    E: swallow token".
func _forms_text() -> String:
	var names: Array[String] = ["Human"]
	for form in player.unlocked_forms:
		names.append(form.form_name)
	var staff: String = "Q: staff" if player.has_staff() else "No staff"
	return "Unlocked forms: %s    %s    E: swallow token" % [", ".join(names), staff]


func _on_notice(text: String) -> void:
	notice_label.text = text
	notice_time_left = 3.0

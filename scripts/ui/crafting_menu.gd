extends CanvasLayer
## The crafting menu. Press Tab to open or close it (Esc also closes it).
## The game pauses while it's open, so bugs can't bite you while you shop.
##
## The list of recipes is built in code from RECIPE_FILES, so adding a recipe
## is just: make a new .tres file in data/recipes/, then add its path below.

const RECIPE_FILES: Array[String] = [
	"res://data/recipes/ant_spear.tres",
	"res://data/recipes/ant_armor.tres",
	"res://data/recipes/shapeshift_staff.tres",
]

@onready var recipe_list: VBoxContainer = $Panel/Margin/VBox/RecipeList
@onready var message_label: Label = $Panel/Margin/VBox/MessageLabel
@onready var close_button: Button = $Panel/Margin/VBox/CloseButton

var recipes: Array[Recipe] = []
var player: Player


func _ready() -> void:
	# This node's "Process > Mode" is set to Always in the scene, so it keeps
	# working (and can close itself) while the rest of the game is paused.
	visible = false
	player = get_tree().get_first_node_in_group("player") as Player
	for path in RECIPE_FILES:
		recipes.append(load(path) as Recipe)

	close_button.pressed.connect(close)
	Inventory.changed.connect(_on_inventory_changed)


# We use _input (not _unhandled_input) so Tab works even when a button is
# selected. Otherwise Godot would use Tab to move between buttons.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_crafting"):
		if visible:
			close()
		elif not get_tree().paused:  # don't open on top of another menu (like the staff)
			open()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	visible = true
	get_tree().paused = true                    # freeze the game
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE # show the cursor so you can click
	message_label.text = ""
	_rebuild_list()


func close() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_inventory_changed() -> void:
	if visible:
		_rebuild_list()


## Throw away the old rows and make one row per recipe.
func _rebuild_list() -> void:
	for child in recipe_list.get_children():
		recipe_list.remove_child(child)
		child.queue_free()
	for recipe in recipes:
		recipe_list.add_child(_make_row(recipe))


## One row: name, stats, description and cost on the left, a Craft button on the right.
func _make_row(recipe: Recipe) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var title := Label.new()
	title.text = "%s   (%s)" % [recipe.display_name, recipe.get_stats_text()]
	title.add_theme_font_size_override("font_size", 20)
	info.add_child(title)

	var details := Label.new()
	details.text = recipe.description + "\n" + recipe.get_cost_text()
	details.modulate = Color(1, 1, 1, 0.75)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(details)

	var button := Button.new()
	button.custom_minimum_size = Vector2(120, 40)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if _is_owned(recipe):
		button.text = "Owned"
		button.disabled = true
	else:
		button.text = "Craft"
		button.disabled = not recipe.can_afford()
		# bind() remembers which recipe this button is for.
		button.pressed.connect(_craft.bind(recipe))
	row.add_child(button)

	return row


func _craft(recipe: Recipe) -> void:
	if player == null or not recipe.can_afford() or _is_owned(recipe):
		return
	# Pay for it...
	for item_name in recipe.cost:
		Inventory.add_item(item_name, -recipe.cost[item_name])
	# ...and put it on (weapons and armor) or into the inventory (items).
	if recipe.kind == Recipe.Kind.ITEM:
		Inventory.add_item(recipe.display_name, 1)
	else:
		player.equip(recipe)
	message_label.text = "Crafted %s!" % recipe.display_name
	_rebuild_list()


## True if we already have this: wearing it (weapon/armor) or carrying it (item).
func _is_owned(recipe: Recipe) -> bool:
	if recipe.kind == Recipe.Kind.ITEM:
		return Inventory.get_count(recipe.display_name) > 0
	return player != null and player.is_equipped(recipe)

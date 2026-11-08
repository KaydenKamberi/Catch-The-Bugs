extends CanvasLayer
## The Shapeshift Staff menu: a list of the forms you've unlocked. Press Q to
## open it, click a form to turn into it. Human is always on the list.
##
## It won't open if you don't have the staff, or while you're in combat
## (the player decides that: see get_staff_block_reason() in player.gd).
## The game pauses while it's open.

@onready var form_list: VBoxContainer = $Panel/Margin/VBox/FormList
@onready var close_button: Button = $Panel/Margin/VBox/CloseButton

var player: Player


func _ready() -> void:
	# This node's "Process > Mode" is set to Always in the scene, so it keeps
	# working (and can close itself) while the rest of the game is paused.
	visible = false
	player = get_tree().get_first_node_in_group("player") as Player
	close_button.pressed.connect(close)


# _input (not _unhandled_input) so Q works even when a button is selected.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("open_staff"):
		get_viewport().set_input_as_handled()
		if visible:
			close()
		elif not get_tree().paused:  # don't open on top of another menu (like crafting)
			_try_open()
	elif visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _try_open() -> void:
	if player == null:
		return
	var reason: String = player.get_staff_block_reason()
	if reason != "":
		player.notice.emit(reason)  # e.g. "Can't switch forms in combat"
		return
	open()


func open() -> void:
	visible = true
	get_tree().paused = true                    # freeze the game
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE # show the cursor so you can click
	_rebuild_list()


func close() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## One button for Human, then one for each unlocked form.
func _rebuild_list() -> void:
	for child in form_list.get_children():
		form_list.remove_child(child)
		child.queue_free()

	_add_button("Human   (Spear)", null)
	for form in player.unlocked_forms:
		var moves: String = "%s / %s" % [form.move_1.move_name, form.move_2.move_name]
		_add_button("%s   (%s)" % [form.form_name, moves], form)


func _add_button(text: String, form: FormData) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 44)
	button.add_theme_font_size_override("font_size", 18)
	if form == player.current_form:
		button.text = text + "   - current"
		button.disabled = true
	else:
		button.text = text
		# bind() remembers which form this button is for (null = Human).
		button.pressed.connect(_pick.bind(form))
	form_list.add_child(button)


func _pick(form: FormData) -> void:
	player.switch_to_form(form)
	close()

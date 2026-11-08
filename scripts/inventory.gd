extends Node
## The player's inventory: a list of item names and how many of each you have.
##
## This script is an "autoload" (see Project > Project Settings > Globals).
## Godot creates it once when the game starts, and any script can use it by
## writing `Inventory`, for example: Inventory.add_item("Ant Parts", 1)

## Sent every time the inventory changes, so the HUD knows to redraw.
signal changed

# Item name -> count, e.g. { "Ant Parts": 3, "Ant Token": 1 }
var items: Dictionary = {}


## Add `amount` of an item (use a negative amount to remove some).
func add_item(item_name: String, amount: int = 1) -> void:
	items[item_name] = get_count(item_name) + amount
	if items[item_name] <= 0:
		items.erase(item_name)
	changed.emit()


## How many of an item we have (0 if we have none).
func get_count(item_name: String) -> int:
	return items.get(item_name, 0)


## Text for the HUD, like "Ant Parts: 3, Ant Token: 1".
func get_summary() -> String:
	if items.is_empty():
		return "(empty)"
	var parts: Array[String] = []
	for item_name in items:
		parts.append("%s: %d" % [item_name, items[item_name]])
	return ", ".join(parts)

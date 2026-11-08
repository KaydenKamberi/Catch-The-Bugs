class_name Recipe
extends Resource
## One crafting recipe: what it costs and what you get.
##
## Each recipe is its own file in data/recipes/ (a ".tres" file). Double-click one
## in the FileSystem dock to edit it in the Inspector.
##
## To add a new recipe:
##   1. Right-click data/recipes/ > Create New > Resource... > pick "Recipe".
##   2. Fill in the fields in the Inspector.
##   3. Add its path to RECIPE_FILES in scripts/ui/crafting_menu.gd.

## What kind of thing this recipe makes.
enum Kind {
	WEAPON,  ## Replaces the spear's damage.
	ARMOR,   ## Adds to your max health.
}

## The name shown in the crafting menu, e.g. "Ant Spear".
@export var display_name: String = ""
## A short line of flavor text.
@export_multiline var description: String = ""
## What it costs: item name -> how many, e.g. { "Ant Parts": 3 }.
@export var cost: Dictionary = {}
@export var kind: Kind = Kind.WEAPON

@export_group("Stats")
## Spear damage per hit (WEAPON only).
@export var weapon_damage: int = 0
## Extra max health (ARMOR only).
@export var bonus_max_health: int = 0
## The color the spear tip (weapon) or shirt (armor) changes to.
@export var color: Color = Color.WHITE


## True if the inventory has everything this recipe needs.
func can_afford() -> bool:
	for item_name in cost:
		if Inventory.get_count(item_name) < cost[item_name]:
			return false
	return true


## Text like "Needs: 3 Ant Parts (you have 1)".
func get_cost_text() -> String:
	var parts: Array[String] = []
	for item_name in cost:
		parts.append("%d %s (you have %d)" % [cost[item_name], item_name, Inventory.get_count(item_name)])
	return "Needs: " + ", ".join(parts)


## Text like "Damage: 8" or "Max HP: +25".
func get_stats_text() -> String:
	match kind:
		Kind.WEAPON:
			return "Damage: %d" % weapon_damage
		Kind.ARMOR:
			return "Max HP: +%d" % bonus_max_health
	return ""

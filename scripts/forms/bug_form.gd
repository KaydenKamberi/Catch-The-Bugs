class_name BugForm
extends Resource
## A bug the player can shapeshift into, and how that bug plays.
##
## Each form is its own file in data/forms/ (a ".tres" file). Double-click one
## in the FileSystem dock to edit it in the Inspector.
##
## To add a new form (say, a ladybug):
##   1. Make a model scene for it, like scenes/enemies/ant_model.tscn
##      (a Node3D holding the meshes, front facing -Z, feet at y = 0).
##   2. Right-click data/forms/ > Create New > Resource... > pick "BugForm",
##      fill it in, and point "Model Scene" at your model.
##   3. Add its path to FORM_FILES in scripts/player.gd.

## The name of this form, e.g. "Ant". Bugs whose "Species" matches this name
## don't notice you while you're in this form (unless you attack them).
@export var form_name: String = "Ant"
## The model shown instead of the human body.
@export var model_scene: PackedScene

@export_group("Cost")
## The token you spend to turn into this form.
@export var token_item_name: String = "Ant Token"
@export var token_cost: int = 1
## How long the form lasts before you turn back into a human, in seconds.
@export var duration: float = 30.0

@export_group("Movement")
@export var walk_speed: float = 6.0
@export var sprint_speed: float = 11.0
@export var jump_height: float = 1.0

@export_group("Attack")
## The name of this form's attack, shown on the HUD.
@export var attack_name: String = "Bite"
@export var attack_damage: int = 4
@export var attack_cooldown: float = 0.6

@export_group("Size")
## The collision capsule while in this form. Height must be at least 2 x radius.
@export var collider_radius: float = 0.5
@export var collider_height: float = 1.0
## How high the camera sits, and how far behind you it floats.
@export var camera_height: float = 0.9
@export var camera_distance: float = 3.5

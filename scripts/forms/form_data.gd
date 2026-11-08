class_name FormData
extends Resource
## A bug form the player can turn into: how it looks, moves and fights.
##
## Each form is its own file in data/forms/ (a ".tres" file). Double-click one
## in the FileSystem dock to edit it in the Inspector.
##
## To add a new form (say, a ladybug):
##   1. Make a model scene for it, like scenes/enemies/ant_model.tscn
##      (a Node3D holding the meshes, front facing -Z, feet at y = 0).
##   2. Right-click data/forms/ > Create New > Resource... > pick "FormData".
##      Fill it in, point "Model Scene" at your model, and give it two moves
##      (in "Move 1" / "Move 2", pick New MoveData).
##   3. Add its path to FORM_FILES in scripts/player.gd.
##   4. Make the ladybug enemy drop a "Ladybug Token" (its "Token Item Name").

## The name of this form, e.g. "Ant".
@export var form_name: String = "Ant"
## The model shown instead of the human body.
@export var model_scene: PackedScene
## Swallowing one of these (E) unlocks this form.
@export var token_item_name: String = "Ant Token"

@export_group("Movement")
## Walking speed (m/s). The human walks at 5.
@export var move_speed: float = 6.5
## Speed while holding Shift. The human sprints at 9.
@export var sprint_speed: float = 11.0
## Jump height in meters. The human jumps 1.6.
@export var jump_height: float = 1.0

@export_group("Moves")
## Left click.
@export var move_1: MoveData
## Right click.
@export var move_2: MoveData

@export_group("Size")
## The collision capsule while in this form. Height must be at least 2 x radius.
@export var collider_radius: float = 0.5
@export var collider_height: float = 1.0
## How high the camera sits, and how far behind you it floats.
@export var camera_height: float = 0.9
@export var camera_distance: float = 3.5

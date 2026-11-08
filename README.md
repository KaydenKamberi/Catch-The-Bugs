# Catch the Bugs

A 3D game made with **Godot 4** (GDScript). You play as a tiny human who hunts bugs,
collects their tokens, and shapeshifts into them.

**Current checkpoint: 4.** You can run around a giant backyard test room, fight ants with a
spear, collect the parts and tokens they drop, and craft better gear from Ant Parts.

## How to open the project

1. Install [Godot 4](https://godotengine.org/download) (the standard version, not .NET).
   The project was set up for Godot 4.7; any recent Godot 4 version should work.
2. Clone or download this repo.
3. Open Godot, click **Import**, and pick the `project.godot` file in this folder.
4. Press **F5** (or the ▶ Play button at the top right) to run the game.

The first time you open it, Godot spends a few seconds importing the project and creates
a hidden `.godot/` folder. That folder is in `.gitignore`, so it isn't committed.

## Controls

| Key / Mouse      | Action                         |
| ---------------- | ------------------------------ |
| W A S D          | Move                           |
| Shift (hold)     | Sprint                         |
| Space            | Jump                           |
| Mouse            | Look around                    |
| Left click       | Attack with the spear          |
| Tab              | Open / close the crafting menu |
| Esc              | Free the mouse cursor          |
| Click (mouse free) | Capture the mouse again      |

## Tweaking numbers

Every number is an `@export` variable, so you can change it in the Inspector:

- **Player** (`scenes/player.tscn`, click the Player node): speed, sprint, jump height, mouse
  sensitivity, max health, spear damage and attack cooldown.
- **Ant** (`scenes/enemies/ant.tscn`, click the Ant node): health, speeds, detection range,
  Bite damage and cooldown, drop names and token chance, Call for Help chance.

## Crafting

Press **Tab** to open the crafting menu (the game pauses while it's open).

| Recipe    | Cost         | Effect                              |
| --------- | ------------ | ----------------------------------- |
| Ant Spear | 3 Ant Parts  | Spear damage 5 → 8 (ants die in 2 hits) |
| Ant Armor | 5 Ant Parts  | +25 max HP                          |

Ant Tokens aren't used for crafting; they're saved for shapeshifting later. The ant hill
in the test room keeps spawning ants (up to 3 at a time), so you can always get more parts.

Each recipe is a file in `data/recipes/`. To add one, create a new **Recipe** resource there,
fill it in using the Inspector, and add its path to `RECIPE_FILES` in `scripts/ui/crafting_menu.gd`.

## How enemies work

All bugs share one script, `scripts/enemies/bug_enemy.gd` (health, wander/chase, attacking,
red hit flash, death and drops). Each bug's own script adds its special ability. For example,
`ant.gd` adds Call for Help. To add a new bug, copy `ant.tscn`, change its meshes and numbers,
and give it its own script that starts with `extends BugEnemy` if it needs a special ability.
`bug_spawner.gd` (used by the ant hill) works with any bug scene.

## Folder layout

```
project.godot      Project settings, input actions, main scene
scenes/            world.tscn (test room), player.tscn (the tiny human)
  enemies/         ant.tscn
  items/           pickup.tscn (floating drops)
  ui/              hud.tscn (health bar, inventory), crafting_menu.tscn
scripts/           player.gd (movement, camera, health, spear)
  inventory.gd     Global inventory (an autoload called "Inventory")
  enemies/         bug_enemy.gd (shared by all bugs), ant.gd, bug_spawner.gd
  crafting/        recipe.gd (what a recipe is)
  items/           pickup.gd
  ui/              hud.gd, crafting_menu.gd
data/recipes/      ant_spear.tres, ant_armor.tres
assets/            models/, textures/, audio/ (empty for now)
docs/              Design notes (empty for now)
```

# Catch the Bugs

A 3D game made with **Godot 4** (GDScript). You play as a tiny human who hunts bugs,
collects their tokens, and shapeshifts into them.

**Checkpoint 1 (player) is in:** the game opens in a small test map (`scenes/test_map.tscn`)
where you can walk, sprint, jump onto boxes and climb a giant oak trunk, with health and stamina
bars. The later checkpoints live in `scenes/world.tscn`: open it and press **F6** to play it.

**Latest checkpoint: 4 (shapeshifting).** In `world.tscn` you can run around a giant backyard test room,
fight ants with a spear, collect the parts and tokens they drop, craft better gear from Ant
Parts, swallow an Ant Token to become an ant, and switch forms with the Shapeshift Staff.

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
| Space            | Jump (or let go while climbing) |
| Hold W into a climbable wall | Grab it and climb (W/S up/down, A/D sideways) |
| K                | Debug: take 10 damage          |
| Mouse            | Look around                    |
| Left click       | Move 1 (spear, or Bite as an ant) |
| Right click      | Move 2 (Call for Help as an ant) |
| E                | Swallow a bug token            |
| Q                | Open the Shapeshift Staff      |
| Tab              | Open / close the crafting menu |
| Esc              | Free the mouse cursor          |
| Click (mouse free) | Capture the mouse again      |

## Tweaking numbers

Every number is an `@export` variable, so you can change it in the Inspector:

- **Player** (`scenes/player.tscn`, click the Player node):
  - Movement: walk speed, sprint speed, jump strength, gravity, acceleration, deceleration,
    air control, turn speed.
  - Camera: mouse sensitivity, min/max pitch.
  - Climbing: climb speed, climb jump push/up, regrab delay, top boost.
  - Health: max health, fall death height. Stamina: max stamina, sprint and climb drain,
    regen rate, regen delay, recover amount.
  - Combat: spear damage and cooldown, combat timeout. Shapeshifting: DEBUG_GIVE_STAFF.
- **Forms** (`data/forms/ant_form.tres`): form speeds and jump, and each move's damage,
  cooldown, reach and helper count/duration.
- **Ant** (`scenes/enemies/ant.tscn`, click the Ant node): health, speeds, detection range,
  Bite damage and cooldown, drop names and token chance, Call for Help chance.

## Climbing and stamina

Anything in the **climbable** group can be climbed (in the test map, that's the giant oak trunk).
Walk into it while holding **W** to grab on. **W/S** climb up and down, **A/D** go sideways around
it, and **Space** jumps off. Climb past the top and you hop up onto it.

Sprinting and climbing use **stamina** (the yellow bar). It refills after you rest for a moment.
If it hits 0 you fall off whatever you're climbing and can't sprint or climb again until it
refills a bit (the bar goes grey until then).

To make something climbable, select it (a StaticBody3D, or a CSG shape with Use Collision on),
open the **Node** tab, then **Groups**, and add it to `climbable`.

When your health hits 0 (or you fall off the map), `die()` sends you back to the start point
with full health and stamina.

## Crafting

Press **Tab** to open the crafting menu (the game pauses while it's open).

| Recipe    | Cost         | Effect                              |
| --------- | ------------ | ----------------------------------- |
| Ant Spear | 3 Ant Parts  | Spear damage 5 → 8 (ants die in 2 hits) |
| Ant Armor | 5 Ant Parts  | +25 max HP                          |

Ant Tokens aren't used for crafting; you swallow them to unlock forms (see below). The ant hill
in the test room keeps spawning ants (up to 3 at a time), so you can always get more parts.

Each recipe is a file in `data/recipes/`. To add one, create a new **Recipe** resource there,
fill it in using the Inspector, and add its path to `RECIPE_FILES` in `scripts/ui/crafting_menu.gd`.

## Shapeshifting

1. **Swallow a token (E).** Kill ants until one drops an **Ant Token**, pick it up, and press
   **E**. The token is used up, the **Ant** form is unlocked for good, and you turn into an ant.
2. **Switch forms with the staff (Q).** The **Shapeshift Staff** opens a list of your forms.
   Human is always on it. Click a form to switch.
3. **Combat lock.** You're "in combat" if you dealt or took damage in the last 5 seconds, or an
   enemy is chasing you ("IN COMBAT" shows top-right). You can't open the staff or swallow a
   token while in combat.

Every form has two moves, and you keep the same HP in every form:

| Form  | Left click (Move 1)        | Right click (Move 2)                                  |
| ----- | -------------------------- | ----------------------------------------------------- |
| Human | Spear (5 dmg, or 8 with the Ant Spear) | -                                          |
| Ant   | Bite (3 dmg, short range)  | Call for Help: 1-2 green friendly ants fight enemies for 10 s (20 s cooldown) |

As an ant you're smaller and faster, but jump lower. The spear is hidden and can't be used.

**The staff.** Its real recipe is 5 Plant Fiber + 1 Mantis Scythe Arm + 1 Mantis Head (the
mantis boss comes later), and it's already listed in the crafting menu. For testing, the
player starts with the staff: turn off **DEBUG_GIVE_STAFF** on the Player node to stop that.

**Adding a form.** Each form is a **FormData** file in `data/forms/` (see `ant_form.tres`),
with two **MoveData** moves inside it. To add one, make a model scene like
`scenes/enemies/ant_model.tscn`, create a new FormData that points at it, add its path to
`FORM_FILES` in `scripts/player.gd`, and have that bug drop a token whose name matches the
form's **Token Item Name**.

## How enemies work

All bugs share one script, `scripts/enemies/bug_enemy.gd` (health, wander/chase, attacking,
red hit flash, death and drops). Each bug's own script adds its special ability. For example,
`ant.gd` adds Call for Help. To add a new bug, copy `ant.tscn`, change its meshes and numbers,
and give it its own script that starts with `extends BugEnemy` if it needs a special ability.
`bug_spawner.gd` (used by the ant hill) works with any bug scene.
Any bug can also be a friendly **ally** (`is_ally`): it turns green, hunts the nearest
enemy, follows you when there's nothing to fight, and disappears after a while. Enemies
fight back against whoever hit them, including your allies.

## Folder layout

```
project.godot      Project settings, input actions, main scene (test_map.tscn)
scenes/            test_map.tscn (main scene: Checkpoint 1 test map), world.tscn (backyard
                   test room for combat/crafting/forms), player.tscn (the tiny human)
  enemies/         ant.tscn, ant_model.tscn (the ant's look, shared with the ant form)
  items/           pickup.tscn (floating drops)
  ui/              hud.tscn (health/stamina bars, inventory, form), crafting_menu.tscn, staff_menu.tscn
scripts/           player.gd (movement, camera, climbing, health, stamina, spear)
  inventory.gd     Global inventory (an autoload called "Inventory")
  enemies/         bug_enemy.gd (shared by all bugs), ant.gd, bug_spawner.gd
  crafting/        recipe.gd (what a recipe is)
  forms/           form_data.gd (a form), move_data.gd (one of its moves)
  items/           pickup.gd
  ui/              hud.gd, crafting_menu.gd, staff_menu.gd
data/recipes/      ant_spear.tres, ant_armor.tres, shapeshift_staff.tres
data/forms/        ant_form.tres
assets/            models/, textures/, audio/ (empty for now)
docs/              Design notes (empty for now)
```

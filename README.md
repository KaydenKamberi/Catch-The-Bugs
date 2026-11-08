# Catch the Bugs

A 3D game made with **Godot 4** (GDScript). You play as a tiny human who hunts bugs,
collects their tokens, and shapeshifts into them.

**Current checkpoint: 2.** You can run, jump and look around a giant backyard test room.

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
| Esc              | Free the mouse cursor          |
| Left click       | Capture the mouse again        |

## Tweaking movement

Open `scenes/player.tscn`, click the **Player** node, and look at the Inspector. Speed, sprint
speed, jump height, acceleration, mouse sensitivity and camera limits are all there.

## Folder layout

```
project.godot      Project settings, input actions, main scene
scenes/            world.tscn (test room), player.tscn (the tiny human)
scripts/           player.gd (movement and camera)
assets/            models/, textures/, audio/ (empty for now)
docs/              Design notes (empty for now)
```

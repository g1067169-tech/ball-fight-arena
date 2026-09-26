# BounceForge Arena

A playable Godot 4 desktop/mobile-ready prototype for programmable bouncing physics battles.

## Run

1. Install [Godot 4.2+](https://godotengine.org/download/).
2. Import this folder as a project.
3. Press **F6** or **Run Project**.

No external assets or plugins are required.

## What is already playable

- DVD-screensaver-style bouncing physics inside a contained arena.
- Free-for-all and multi-team combat (team targeting is built into projectile damage).
- Start, pause, restart, and 0.25x / 0.5x / 1x / 2x simulation speed.
- Add named balls, assign them to five teams, and select behavior templates.
- Select an object from the roster and append event blocks in Block Studio.
- Programmable event foundation: `ON_HIT`, `ON_WALL`, `TIMER`, and `RANDOM` blocks.
- Weapons are simulated as independent bouncing projectile entities.
- Bomb and blast effects, health, shields-ready data, collision responses, splitting, and custom arena colors.

## Architecture direction

`main.gd` deliberately keeps entities data-oriented: every object has position, velocity, team, health, and an extensible `blocks` array. The `_event()` dispatcher and independent projectile/effect collections are the foundation for expanding the Scratch-like block runtime without introducing pathfinding or conventional character AI.

The next natural increments are a visual block workspace, custom object definitions/resources, imported sprites/audio, and save/load project files. The core simulation is already independent of those presentation layers.

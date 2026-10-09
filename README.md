# BomberCat

A Bomberman-style Battle game starring five cats. See [CONTEXT.md](CONTEXT.md) for the vocabulary
and [docs/spec-v1.md](docs/spec-v1.md) for what v1 is.

## Layout

| Folder | Contents |
|---|---|
| `game/` | The Godot 4.7 project. Open `game/project.godot`. Models live in `game/assets/models/`. |
| `art/` | Blender sources: `cats.blend` and the Python scripts that generate every model, and the script that synthesises the audio. |
| `renders/` | Reference renders produced by the `art/render_*.py` scripts. |
| `docs/` | Spec, scope, Powerup catalogue, audio credits and ADRs. |

## Playing and testing

```sh
godot --path game        # play: Player 1 WASD + Space, Player 2 arrows + Enter, or a gamepad each;
                         # Q / Right Shift / X to meow, Esc or Start to pause, F11 fullscreen
game/run_tests.sh        # rules-layer tests, headless
```

The game is three layers with one-way dependencies (see [ADR 0002](docs/adr/0002-rules-layer-owns-movement.md)):
`game/rules/` (plain classes, owns all game state), `game/presentation/` (the screens, started by `main.tscn`)
and `game/control/` (Player controllers that issue commands). Balance values live in
`game/config/game_config.tres`.

## Map Studio

Maps are GridMap scenes in `game/maps/` (see [ADR 0001](docs/adr/0001-map-studio-in-godot-editor.md)).
To make or edit one, open it in the Godot editor and select its root node:

- **Paint** Walls (`wall_brick`, `wall_brick_low`, `wall_pillar`), Crates and Spawn Points from the
  GridMap palette, on floor 0. Empty Tiles inside the painted area are Floor, laid automatically.
- **Powerup Pool**: the root node's `powerup_pool` property in the inspector.
- **Validation**: problems appear as the yellow warning icon next to the root node.
- **Test-play**: press F6 (run current scene) with the Map open; it plays Matches on that Map.

A new Map is a new scene whose root is a GridMap with the `maps/map_scene.gd` script.

## Regenerating models

From the repository root:

```sh
blender -b art/cats.blend -P art/build_props.py \
  --python-expr "import bpy; bpy.ops.wm.save_mainfile()"   # only after editing a build script
blender -b art/cats.blend -P art/export_glb.py   # writes game/assets/models/*.glb
godot --headless --path game --import            # re-imports them
```

To change a model, edit `art/build_cat.py` or `art/build_props.py`, run it inside Blender with
`cats.blend` open (see each script's docstring), save, then export as above.

## Regenerating audio

Every sound and music loop is synthesised (see [docs/credits.md](docs/credits.md)):

```sh
python3 art/build_audio.py                       # writes game/assets/audio/*.wav (needs numpy)
godot --headless --path game --import            # re-imports them
```

# BomberCat

A Bomberman-style Battle game starring five cats. See [CONTEXT.md](CONTEXT.md) for the vocabulary
and [docs/spec-v1.md](docs/spec-v1.md) for what v1 is.

## Layout

| Folder | Contents |
|---|---|
| `game/` | The Godot 4.7 project. Open `game/project.godot`. Models live in `game/assets/models/`. |
| `art/` | Blender sources: `cats.blend` and the Python scripts that generate every model. |
| `renders/` | Reference renders produced by the `art/render_*.py` scripts. |
| `docs/` | Spec, scope, Powerup catalogue and ADRs. |

## Playing and testing

```sh
godot --path game        # play: Player 1 WASD + Space, Player 2 arrows + Enter
game/run_tests.sh        # rules-layer tests, headless
```

The game is three layers with one-way dependencies (see [ADR 0002](docs/adr/0002-rules-layer-owns-movement.md)):
`game/rules/` (plain classes, owns all game state), `game/presentation/` (scenes that show it)
and `game/control/` (Player controllers that issue commands). Balance values live in
`game/config/game_config.tres`.

## Regenerating models

From the repository root:

```sh
blender -b art/cats.blend -P art/export_glb.py   # writes game/assets/models/*.glb
godot --headless --path game --import            # re-imports them
```

To change a model, edit `art/build_cat.py` or `art/build_props.py`, run it inside Blender with
`cats.blend` open (see each script's docstring), save, then export as above.

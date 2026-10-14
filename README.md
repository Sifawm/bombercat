# BomberCat

A Bomberman-style Battle game starring five cats. See [CONTEXT.md](CONTEXT.md) for the vocabulary
and [docs/spec-v1.md](docs/spec-v1.md) for what v1 is.

## Layout

| Folder | Contents |
|---|---|
| `game/` | The Godot 4.7 project. Open `game/project.godot`. Models live in `game/assets/models/`. |
| `art/` | Blender sources: `cats.blend` and the Python scripts that generate every model, and the script that imports the audio. |
| `renders/` | Reference renders produced by the `art/render_*.py` scripts. |
| `docs/` | Spec, scope, Powerup catalogue, audio credits and ADRs. |
| `server/` | The online server: NestJS with [Porter](https://github.com/Sifawm/porterkit), the Game's Managers and, in `src/rules/`, the rules in TypeScript. |
| `web/` | The page of the web build: it creates Porter's client and starts the engine. |
| `shared/` | What server and page share: the Game definitions, the Profile, and the Maps and balance values exported from `game/`. |

## Playing and testing

```sh
godot --path game        # play: Player 1 WASD + Space, Player 2 arrows + Enter, or a gamepad each;
                         # Q / Right Shift / X to meow, Esc or Start to pause, F11 fullscreen
game/run_tests.sh        # rules-layer tests, headless; also exports shared/src and fails if it was stale
```

The game is three layers with one-way dependencies (see [ADR 0002](docs/adr/0002-rules-layer-owns-movement.md)):
`game/rules/` (plain classes, owns all game state), `game/presentation/` (the screens, started by `main.tscn`)
and `game/control/` (Player controllers that issue commands). Balance values live in
`game/config/game_config.tres`.

## Playing online

Online play exists only in the web build ([ADR 0005](docs/adr/0005-online-is-web-only.md)) and its
rules run on the server ([ADR 0003](docs/adr/0003-online-rules-run-on-the-server.md)): a User enters a
Room with a name and a Cat, the Admin starts the Match, and everyone in the Room plays it. Each
client sends what its Player asks of its Cat and draws what the server says.

Needs Node 24, pnpm and, until Porter is published, its repository built next to this one at
`../porter`.

```sh
pnpm install
pnpm export:web   # the Godot project into web/public/godot, again after every change to game/
pnpm server       # Porter on :3000
pnpm web          # the page on http://localhost:5173, which forwards /porter to the server
pnpm test         # the server's tests
```

The server has its own rules, a port to TypeScript of `game/rules/` as it was at v1, with the same
tests (`server/src/rules/`). The two are allowed to drift, movement excepted
([ADR 0004](docs/adr/0004-own-cat-is-predicted-with-movement-parity.md)). Maps and balance values
have one source, the Godot project: `game/tools/export_shared.gd` writes them as JSON into
`shared/src/`, and those files are versioned.

`game/addons/porter` is a copy of Porter's addon for Godot; `pnpm addon` refreshes it.

On the client, `game/online/` holds the Round and the Match as the server tells them
(`RemoteRound`, `RemoteMatch`), which the Round view draws as it draws a local one.

## Exporting

Linux and web builds, without Map Studio or the tests. Needs Godot's export templates for the
same version (in the editor: Editor > Manage Export Templates).

```sh
mkdir -p build/linux build/web
godot --headless --path game --export-release Linux   # build/linux/bombercat.x86_64, one file
godot --headless --path game --export-release Web     # build/web/, to put on any web server
python3 -m http.server -d build/web                   # try the web build at http://localhost:8000
```

That web build has Local play only: the online one is the page in `web/`. The web build is single-threaded, so it needs no special server headers. `build/` is not
versioned.

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

## Importing audio

Every sound and music loop is a CC0 file from Kenney or OpenGameArt (see
[docs/credits.md](docs/credits.md)). To change one, edit the table in `art/import_audio.py`
and the matching row of the credits, then:

```sh
python3 art/import_audio.py                      # downloads and writes game/assets/audio/*.ogg (needs ffmpeg)
godot --headless --path game --import            # re-imports them
```

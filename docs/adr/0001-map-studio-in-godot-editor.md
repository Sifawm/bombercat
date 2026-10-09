# Map Studio is a Godot editor workspace; Maps are GridMap scenes

Maps are authored only by the game's creator, never by players, so Map Studio is a GridMap-based workspace inside the Godot editor (mesh palette, validation warnings, test-play) rather than a standalone application or an in-game mode. Each Map is a `.tscn` scene that the game reads Tile by Tile to build its logic.

## Considered Options

- **In-game editor mode** — rejected: players do not create Maps, so it would ship unused UI.
- **Standalone application with its own JSON format** — rejected: days of work re-implementing painting, undo and file handling that GridMap already provides, plus two places to update for every new map element.

## Consequences

The Map format is tied to Godot. If Maps ever need to be read outside the engine (e.g. an online server validating Maps), add a GridMap-to-JSON export script rather than replacing Map Studio.

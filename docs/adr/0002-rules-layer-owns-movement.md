# Game rules are a node-free layer that also owns Cat movement

The game is split into three layers with one-way dependencies: rules (plain classes, no nodes), presentation (scenes that react to the rules' signals) and control (Player controllers issuing commands). Cat movement and collision are computed by the rules layer on the Tile grid with a fixed time step, instead of using Godot physics (`CharacterBody3D` and collision shapes).

## Considered Options

- **Godot physics for movement** — rejected: it needs colliders mirroring the board (two sources of truth), makes the "owner may leave its Bomb's Tile but not re-enter" rule depend on fragile collision exceptions, cannot be tested without a scene, and is not deterministic across machines.

## Consequences

Scenes contain no gameplay colliders; a Cat's model is simply placed where the rules say. The simulation is reproducible from a sequence of commands, which keeps tests, a future AI and any online model open.

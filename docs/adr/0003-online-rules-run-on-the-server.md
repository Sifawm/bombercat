# Online rules run on the server in TypeScript; the GDScript rules stay, frozen, for local play

Online play is built on Porter, where a Game's rules live in a Manager on the server and clients send what their User asks for. So the rules layer is ported to TypeScript and the server owns every online Match. The GDScript rules layer is kept and still runs the local mode, which stays on the title screen; it is frozen at the v1 rules. The port starts as a faithful copy of it, tests included, and from there only the server's rules evolve.

## Considered Options

- **A client hosts the rules and Porter relays** — rejected: the host can cheat, plays with no latency against everyone else, and its state has to migrate when it leaves. It also goes against Porter, where only the Manager changes a Game's state.
- **Porter for the Room only, the Match played on one machine** — rejected: Rooms without remote play add almost nothing.
- **Drop the GDScript rules and play local Matches against the server too** — rejected: it removes the offline game, which we want to keep possible.
- **Keep both implementations at parity** — rejected: every rules change would be made twice for an offline mode that nobody is asking to grow.

## Consequences

There are two implementations of the rules and they are allowed to drift: a rule added online does not reach the local mode. Movement is the one exception ([ADR 0004](0004-own-cat-is-predicted-with-movement-parity.md)).

The server cannot read Godot scenes or resources, so Godot stays the source for Maps and balance values and a headless script exports them as JSON, as [ADR 0001](0001-map-studio-in-godot-editor.md) foresaw. The exported files are versioned and the test run fails when they are stale.

The repository gains a Node part: the server, the web page and what they share.

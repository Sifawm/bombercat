# Online play exists only in the web build

Porter's client is TypeScript and its Binding for Godot reaches it through the page a web export runs in. So the web build offers Local and Online, and the Linux and Windows builds offer Local only. The web build gets a page of its own, which creates the Porter client and then starts the engine, in place of the one Godot generates.

## Considered Options

- **A Porter client in GDScript, for native builds** — rejected: it means writing again, and maintaining, the login, the connection, the state and the Appliers that exist only in TypeScript, for an audience we do not have.
- **A native build that wraps the web one** — not needed yet. It is the cheaper way to an online desktop build if one is ever wanted.

## Consequences

The web build becomes the main target in practice, and the native builds are the offline game.

One browser is one User and one Cat: Porter's Binding takes one client per page. Two people on the same machine play online from two tabs, or play Local.

The server serves Porter's API and the web build from the same origin, as a single process, since a Room lives in the memory of the process that created it.
